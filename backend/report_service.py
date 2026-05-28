import logging
import re
from datetime import datetime, timedelta, date, timezone
from typing import Optional
from sqlalchemy.orm import Session
from database import SessionLocal
from sqlalchemy import func
from models import (
    User, UserRole, Profile, HealthReading, ProfileAccess,
    ReportGenerationLog, WhatsAppMessageLog,
    ReportTriggerType, WhatsAppMessageStatus, ReportGenerationStatus,
    DoctorPatientLink, DoctorReportGenerationLog, DoctorProfile
)
from health_utils import classify_bp, classify_glucose, classify_spo2
from utils.phone import normalize_phone
from utils.datetime_helpers import ensure_utc
from twilio_service import whatsapp_service
from config import settings
import ai_report_service

logger = logging.getLogger(__name__)

# Doctor Report Digest Constants (C1)
# 1000 is the safe limit for WhatsApp template body to avoid truncation.
_MAX_LEN = 1000
_MARGIN = 80  # Space reserved for the omission notice at the end.
_CRITICAL_BUDGET = _MAX_LEN // 3  # ~333 chars


def build_doctor_summary(db: Session, doctor_id: int, last_7d: datetime) -> dict:
    """Builds an aggregate summary of all active patients for a doctor.

    Returns:
        {
            "patients": [{
                "name": str,
                "metrics": {
                    "glucose": {avg, min, max, count},
                    "bp": {avg_sys, avg_dia, count},
                    "spo2": {avg, min, max, count},
                    "steps": {total}
                },
                "critical_metrics": [str],  # e.g. ["BP", "Glucose"]
            }],
            "critical_patients": [str],     # Names of patients with critical readings
            "patients_with_data_count": int,
            "total_patients_count": int
        }
    """
    # DoctorPatientLink.status is a plain VARCHAR column (models.py line
    # 799), NOT an Enum — so string comparison against 'active' is the
    # correct idiom across both Postgres and SQLite. Valid values are:
    # 'pending_doctor_accept' | 'pending_patient_accept' | 'active' |
    # 'rejected' | 'revoked'. If this column is ever migrated to an
    # Enum, this comparison must switch to the enum value.
    links = db.query(DoctorPatientLink).filter(
        DoctorPatientLink.doctor_id == doctor_id,
        DoctorPatientLink.status == 'active'
    ).all()

    summary = {
        "patients": [],
        "critical_patients": [],
        "patients_with_data_count": 0,
        "total_patients_count": len(links)
    }

    if not links:
        return summary

    profile_ids = [link.profile_id for link in links]
    # Bulk load profiles
    profiles = db.query(Profile).filter(Profile.id.in_(profile_ids)).all()
    profile_map = {p.id: p for p in profiles}

    # Bulk load readings for all profiles in the last 7 days
    all_readings = db.query(HealthReading).filter(
        HealthReading.profile_id.in_(profile_ids),
        HealthReading.reading_timestamp >= last_7d
    ).all()

    # Group readings by profile_id
    readings_by_profile = {}
    for r in all_readings:
        readings_by_profile.setdefault(r.profile_id, []).append(r)

    for link in links:
        profile = profile_map.get(link.profile_id)
        if not profile:
            continue

        readings = readings_by_profile.get(link.profile_id, [])
        if not readings:
            continue

        p_summary = {
            "name": profile.name,
            "metrics": {},
            "critical_metrics": []
        }

        # Aggregate Glucose
        g_readings = [r for r in readings if r.reading_type == 'glucose' and r.glucose_value]
        if g_readings:
            g_vals = [r.glucose_value for r in g_readings]
            p_summary["metrics"]["glucose"] = {
                "avg": sum(g_vals) / len(g_vals),
                "min": min(g_vals),
                "max": max(g_vals),
                "count": len(g_vals)
            }
            if any(classify_glucose(v) == "CRITICAL" for v in g_vals):
                p_summary["critical_metrics"].append("Sugar")

        # Aggregate BP
        bp_readings = [r for r in readings if r.reading_type == 'blood_pressure' and r.systolic and r.diastolic]
        if bp_readings:
            sys_vals = [r.systolic for r in bp_readings]
            dia_vals = [r.diastolic for r in bp_readings]
            avg_sys = sum(sys_vals) / len(sys_vals)
            avg_dia = sum(dia_vals) / len(dia_vals)
            p_summary["metrics"]["bp"] = {
                "avg_sys": avg_sys,
                "avg_dia": avg_dia,
                "count": len(bp_readings)
            }
            # Flag CRITICAL on EITHER:
            #   (a) any single reading in Stage 2 — acute event, doctor needs
            #       to see it even if averages look fine
            #   (b) the week's AVG falling in Stage 1 — sustained mild
            #       hypertension over 7 days is itself a clinical concern;
            #       flagging only Stage 2 missed patients sitting at 135/88
            #       every day, which is exactly the population the weekly
            #       digest exists for.
            # Single-reading Stage 1 is intentionally NOT flagged — too
            # noisy (one stress reading would trigger every week).
            had_stage2 = any(
                classify_bp(s, d) == "HIGH - STAGE 2"
                for s, d in zip(sys_vals, dia_vals)
            )
            sustained_stage1 = classify_bp(avg_sys, avg_dia) == "HIGH - STAGE 1"
            if had_stage2 or sustained_stage1:
                p_summary["critical_metrics"].append("BP")

        # Aggregate SpO2
        s_readings = [r for r in readings if r.reading_type == 'spo2' and r.spo2_value]
        if s_readings:
            s_vals = [r.spo2_value for r in s_readings]
            p_summary["metrics"]["spo2"] = {
                "avg": sum(s_vals) / len(s_vals),
                "min": min(s_vals),
                "max": max(s_vals),
                "count": len(s_vals)
            }
            if any(classify_spo2(v) == "CRITICAL" for v in s_vals):
                p_summary["critical_metrics"].append("SpO2")

        # Aggregate Steps
        steps_readings = [r for r in readings if r.reading_type == 'steps' and r.steps_count]
        if steps_readings:
            p_summary["metrics"]["steps"] = {
                "total": sum(r.steps_count for r in steps_readings)
            }

        # M5: only count + render a patient if at least one metric
        # actually aggregated. A patient with only weight/temperature
        # readings reaches here with metrics={} — they had data but
        # nothing the digest surfaces. Counting them in
        # patients_with_data_count made the audit row diverge from
        # what the doctor sees ("3 patients reported" but digest shows
        # 2 lines). Move the skip upstream so audit = render.
        if not p_summary["metrics"]:
            continue

        summary["patients_with_data_count"] += 1

        if p_summary["critical_metrics"]:
            summary["critical_patients"].append(profile.name)

        summary["patients"].append(p_summary)

    return summary


def send_doctor_weekly_reports(
    db: Optional[Session] = None,
    trigger_type: ReportTriggerType = ReportTriggerType.SCHEDULED,
    doctor_user_id: Optional[int] = None,
) -> dict:
    """Sends a weekly digest report to doctors for all their linked patients."""
    managed_session = False
    if db is None:
        db = SessionLocal()
        managed_session = True

    results = {"total_doctors": 0, "successful_deliveries": 0, "failed_deliveries": 0, "errors": []}

    try:
        if not settings.TWILIO_DOCTOR_REPORT_CONTENT_SID:
            raise ValueError("TWILIO_DOCTOR_REPORT_CONTENT_SID is not configured")

        now = datetime.now(timezone.utc)
        last_7d = now - timedelta(days=7)
        last_week_str = (now - timedelta(days=6)).strftime("%d %b")
        date_str = now.strftime("%d %b %Y")

        # Find all doctors with active links.
        # User.role is a str-Enum (UserRole). Comparing against the raw
        # string 'doctor' works today because the enum's value is also
        # 'doctor', but a future migration that changes case ('Doctor')
        # or renames the value would silently return 0 doctors with
        # NO error — the cron would just stop sending reports. Compare
        # against the enum so a mismatch surfaces at code review,
        # consistent with every other auth check in routes_doctor.py.
        # CRITICAL #1: filter on DoctorProfile.is_verified — an
        # unverified doctor (NMC not admin-approved) must NEVER receive
        # PHI digests. Patient→doctor linking already blocks unverified
        # doctors at routes_doctor._link, but a verification revocation
        # AFTER linking would leave stale active links pointing at a
        # now-unverified doctor. This filter ensures the digest path
        # is the hard gate at delivery time.
        doctor_query = db.query(User).join(
            DoctorProfile, DoctorProfile.user_id == User.id
        ).filter(
            User.role == UserRole.doctor,
            User.is_active == True,
            DoctorProfile.is_verified == True,  # noqa: E712
        )

        if doctor_user_id:
            doctor_query = doctor_query.filter(User.id == doctor_user_id)

        doctors = doctor_query.all()
        results["total_doctors"] = len(doctors)

        # Bulk-fetch all DoctorProfile rows for the result set in ONE
        # query. The previous code re-queried DoctorProfile inside the
        # per-doctor loop whenever User.phone_number was empty — one
        # extra round-trip per doctor with no phone, adding tens of
        # queries per scheduler run at Bihar pilot scale. The outer
        # JOIN already proves a DoctorProfile exists for every doctor
        # we're iterating, so this dict is guaranteed populated.
        doctor_profile_map: dict = {}
        if doctors:
            doctor_ids = [d.id for d in doctors]
            doctor_profile_map = {
                dp.user_id: dp
                for dp in db.query(DoctorProfile)
                .filter(DoctorProfile.user_id.in_(doctor_ids))
                .all()
            }

        # Today's date in UTC. date.today() reads the SERVER local clock;
        # on a non-UTC host (or a host whose TZ flips during DST) the
        # persisted report_date would drift from the `now` we used to
        # bound the data window above. now.date() uses the same UTC
        # anchor end-to-end.
        report_date_utc = now.date()

        for doctor in doctors:
            d_id = doctor.id
            # gen_log is created up-front so EVERY exit path (success,
            # missing phone, Twilio failure, exception inside compose)
            # leaves a row behind for ops + legal audit. Status is
            # finalised at the end of each branch — never committed as
            # SUCCESS before delivery is confirmed.
            #
            # CRITICAL #2: delivery_log is ALSO tracked so the except
            # handler below can mark it FAILED. Without this, a crash
            # between the QUEUED commit and the Twilio response leaves
            # the row stuck at QUEUED with no twilio_sid — and the
            # manual-trigger cooldown in routes_doctor blocks the
            # doctor for 1h on a phantom in-flight request.
            gen_log = None
            delivery_log = None
            gen_log_id = None      # captured for except-handler queries
            delivery_log_id = None # — ORM objects can expire / detach after
                                   # rollback, IDs survive.
            try:
                summary = build_doctor_summary(db, d_id, last_7d)

                if summary["patients_with_data_count"] == 0:
                    # Ops needs an audit row even on the no-data skip so
                    # "doctor processed, nothing to send" is
                    # distinguishable from "doctor was never evaluated".
                    # In the Bihar pilot with sparse logging this is a
                    # common state. ReportGenerationStatus has no
                    # dedicated SKIPPED value (would require migration);
                    # we use SUCCESS with patients_with_data_count=0,
                    # which truthfully reflects what happened: the run
                    # succeeded, there was simply nothing to deliver.
                    db.add(DoctorReportGenerationLog(
                        doctor_id=d_id,
                        trigger_type=trigger_type,
                        report_date=report_date_utc,
                        patients_linked_count=summary["total_patients_count"],
                        patients_with_data_count=0,
                        critical_patients_count=0,
                        status=ReportGenerationStatus.SUCCESS,
                        error_message="no_data_in_window",
                    ))
                    db.commit()
                    logger.info("Doctor %s has no patient data for the week — skipped (audit row written).", d_id)
                    continue

                # Compose the digest message — Critical patients first.
                # critical_block is built with a budget to prevent it
                # from consuming the entire message (C1).
                critical_block = ""
                if summary["critical_patients"]:
                    prefix = "🚨 CRITICAL: "
                    sep = ", "
                    # Reserve space for "+999 more" suffix
                    reserved_suffix_len = len(" +999 more")
                    used = len(prefix) + len(" | ")
                    kept_critical = []
                    for name in summary["critical_patients"]:
                        add = len(name) + (len(sep) if kept_critical else 0)
                        if used + add + reserved_suffix_len > _CRITICAL_BUDGET:
                            break
                        kept_critical.append(name)
                        used += add
                    
                    critical_omitted = len(summary["critical_patients"]) - len(kept_critical)
                    critical_block = prefix + sep.join(kept_critical)
                    if critical_omitted > 0:
                        critical_block += f" +{critical_omitted} more"
                    critical_block += " | "

                # Per-patient summary lines
                patient_lines = []
                for p in summary["patients"]:
                    m = p["metrics"]
                    metric_parts = []
                    if "glucose" in m:
                        g = m["glucose"]
                        metric_parts.append(f"Sugar: {int(g['avg'])} avg ({int(g['min'])}-{int(g['max'])})")
                    if "bp" in m:
                        bp = m["bp"]
                        metric_parts.append(f"BP: {int(bp['avg_sys'])}/{int(bp['avg_dia'])} avg")
                    if "spo2" in m:
                        s = m["spo2"]
                        metric_parts.append(f"SpO2: {int(s['avg'])}% avg")
                    if "steps" in m:
                        metric_parts.append(f"Steps: {m['steps']['total']}")

                    # Render-time skip removed: build_doctor_summary now
                    # filters out patients with empty metrics (M5), so
                    # metric_parts is guaranteed non-empty here. If this
                    # invariant is ever broken, the assertion below will
                    # surface it loudly in tests rather than rendering a
                    # silent "👤 Name: " line.
                    assert metric_parts, "build_doctor_summary must filter empty-metric patients"
                    p_line = f"👤 {p['name']}: " + ", ".join(metric_parts)
                    if p["critical_metrics"]:
                        p_line += " ⚠️"
                    patient_lines.append(p_line)

                # Truncation that DOES NOT silently drop patients.
                # The old behavior — `digest[:997] + "..."` — chopped
                # patient lines from the END with no indication, so a
                # doctor with 20 patients would see a partial list and
                # have no clue. Now we drop whole patient lines from
                # the tail and append "(+N omitted — see portal)" so
                # the doctor knows to log in. Critical block is built
                # first (line above) so it always survives.
                # Reserve budget = MAX - len(critical_block) - margin
                budget = _MAX_LEN - len(critical_block) - _MARGIN
                kept_lines = []
                used = 0
                # Budget bookkeeping: the FIRST kept line has no
                # leading separator (the join only inserts " | "
                # between elements, and critical_block already ends
                # with " | " when non-empty). So we charge 3 chars
                # only for the second-and-later lines.
                for line in patient_lines:
                    add = len(line) + (3 if kept_lines else 0)  # " | " separator
                    if used + add > budget:
                        break
                    kept_lines.append(line)
                    used += add
                omitted = len(patient_lines) - len(kept_lines)
                # critical_block already ends with " | " when non-empty,
                # so no extra separator is needed between it and the
                # first kept patient line — the format is e.g.:
                #   "🚨 CRITICAL: Sita | 👤 Sita: BP 145/92"
                # If critical_block is empty, kept_lines just renders
                # normally with " | " between lines.
                digest_snippet = critical_block + " | ".join(kept_lines)
                if omitted > 0:
                    suffix = f" | (+{omitted} patients omitted — see portal)"
                    digest_snippet += suffix
                # Hard cap as a final safety belt — should never trigger
                # if the budget math is correct, but if it does we want
                # the message to fit Twilio's limit, not error out.
                if len(digest_snippet) > _MAX_LEN:
                    digest_snippet = digest_snippet[:_MAX_LEN - 3] + "..."

                # Create the gen log row up-front with PARTIAL status as
                # a tentative state. It gets finalised to SUCCESS only
                # after Twilio confirms delivery, or to FAILED on any
                # exit path that did not deliver.
                gen_log = DoctorReportGenerationLog(
                    doctor_id=d_id,
                    trigger_type=trigger_type,
                    report_date=report_date_utc,
                    patients_linked_count=summary["total_patients_count"],
                    patients_with_data_count=summary["patients_with_data_count"],
                    critical_patients_count=len(summary["critical_patients"]),
                    status=ReportGenerationStatus.PARTIAL,
                )
                db.add(gen_log)
                db.flush()  # get the PK; defer commit until status is final
                gen_log_id = gen_log.id

                # Delivery
                target_phone = normalize_phone(doctor.phone_number)
                if not target_phone:
                    # Fall back to the DoctorProfile contact numbers.
                    # Use the bulk-loaded map (single query above the
                    # loop) instead of a fresh per-doctor SELECT —
                    # avoids N extra round-trips at scheduled scale.
                    dp = doctor_profile_map.get(d_id)
                    if dp:
                        target_phone = normalize_phone(dp.whatsapp_number) or normalize_phone(dp.phone_number)

                if not target_phone:
                    # FAILED — log it so ops can find this doctor in audit.
                    gen_log.status = ReportGenerationStatus.FAILED
                    gen_log.error_message = "no_phone_number"
                    db.commit()
                    logger.warning("Doctor %s has no phone number — marked FAILED.", d_id)
                    results["failed_deliveries"] += 1
                    results["errors"].append(f"Doctor {d_id}: no_phone_number")
                    continue

                # {{1}} = week start, {{2}} = week end, {{3}} = digest
                # The full digest goes to Twilio's template render (outbound
                # to the doctor's phone); it does NOT get persisted.
                template_vars = [last_week_str, date_str, digest_snippet]

                # DPDPA 2023: WhatsAppMessageLog persists indefinitely as
                # an audit row and ALSO surfaces in the ops dashboard.
                # Persist only aggregate counts — never patient names or
                # raw health values. The outbound message rendered by
                # Twilio is ephemeral and may carry PHI; this audit row
                # is permanent and must not.
                audit_snapshot = (
                    f"doctor_digest patients_with_data="
                    f"{summary['patients_with_data_count']} "
                    f"critical={len(summary['critical_patients'])} "
                    f"omitted={omitted} "
                    f"week_start={last_week_str}"
                )
                delivery_log = WhatsAppMessageLog(
                    user_id=d_id,
                    phone_number=target_phone,
                    trigger_type=trigger_type,
                    report_date=report_date_utc,
                    member_ids_included=[], # not applicable for doctor
                    status=WhatsAppMessageStatus.QUEUED,
                    message_snapshot=audit_snapshot,
                )
                db.add(delivery_log)
                db.commit()
                delivery_log_id = delivery_log.id

                success, sid, err = whatsapp_service.send_whatsapp_template(
                    target_phone, settings.TWILIO_DOCTOR_REPORT_CONTENT_SID, template_vars
                )
                delivery_log.status = WhatsAppMessageStatus.SENT if success else WhatsAppMessageStatus.FAILED
                delivery_log.twilio_sid = sid
                delivery_log.error_message = err
                # Finalise the gen log status to match the delivery outcome.
                gen_log.status = (
                    ReportGenerationStatus.SUCCESS if success
                    else ReportGenerationStatus.FAILED
                )
                if not success:
                    gen_log.error_message = err
                db.commit()

                if success:
                    results["successful_deliveries"] += 1
                else:
                    results["failed_deliveries"] += 1
                    results["errors"].append(f"Doctor {doctor.id}: {err}")

            except Exception as e:
                logger.error("Failed to send report for doctor %s", d_id, exc_info=True)
                results["failed_deliveries"] += 1
                results["errors"].append(f"Doctor {d_id}: {str(e)}")
                # Either finalise the existing gen_log/delivery_log to
                # FAILED, or write a fresh failure gen_log if we crashed
                # before it was created (e.g. inside build_doctor_summary).
                # Use captured IDs rather than ORM references — after the
                # rollback below the ORM objects are detached/expired and
                # accessing their attributes can ObjectDeletedError.
                try:
                    db.rollback()  # discard any half-written state

                    if gen_log_id is not None:
                        existing_gen = (
                            db.query(DoctorReportGenerationLog)
                            .filter(DoctorReportGenerationLog.id == gen_log_id)
                            .first()
                        )
                        if existing_gen is not None:
                            existing_gen.status = ReportGenerationStatus.FAILED
                            existing_gen.error_message = str(e)[:500]
                        else:
                            # gen_log was created in a flushed-but-not-
                            # committed state and the rollback nuked it.
                            # Write a fresh failure row.
                            db.add(DoctorReportGenerationLog(
                                doctor_id=d_id,
                                trigger_type=trigger_type,
                                report_date=report_date_utc,
                                patients_linked_count=0,
                                patients_with_data_count=0,
                                critical_patients_count=0,
                                status=ReportGenerationStatus.FAILED,
                                error_message=str(e)[:500],
                            ))
                    else:
                        db.add(DoctorReportGenerationLog(
                            doctor_id=d_id,
                            trigger_type=trigger_type,
                            report_date=report_date_utc,
                            patients_linked_count=0,
                            patients_with_data_count=0,
                            critical_patients_count=0,
                            status=ReportGenerationStatus.FAILED,
                            error_message=str(e)[:500],
                        ))

                    # CRITICAL #2: if delivery_log was committed as
                    # QUEUED before the crash (Twilio call hung or
                    # process died mid-flight), update it to FAILED so
                    # the cooldown query does NOT treat it as in-flight
                    # for the next hour.
                    if delivery_log_id is not None:
                        existing_delivery = (
                            db.query(WhatsAppMessageLog)
                            .filter(WhatsAppMessageLog.id == delivery_log_id)
                            .first()
                        )
                        if existing_delivery is not None:
                            existing_delivery.status = WhatsAppMessageStatus.FAILED
                            existing_delivery.error_message = (
                                f"crashed_mid_delivery: {str(e)[:400]}"
                            )

                    db.commit()
                except Exception:
                    logger.exception(
                        "Could not persist failure log for doctor %s", d_id
                    )
                    db.rollback()

    except Exception as e:
        logger.error("Error in send_doctor_weekly_reports", exc_info=True)
        results["errors"].append(str(e))
    finally:
        if managed_session:
            db.close()

    return results


def trigger_single_profile_report(
    db: Session,
    profile: Profile,
    trigger_type: ReportTriggerType = ReportTriggerType.SCHEDULED,
    owner: Optional[User] = None,
) -> dict | None:
    """Builds report data for one profile. Returns None if no 7-day data exists.

    Returns a FAILED dict on error so the caller's transaction is not rolled back.
    """
    if owner is None:
        owner_access = db.query(ProfileAccess).filter(
            ProfileAccess.profile_id == profile.id,
            ProfileAccess.access_level == 'owner'
        ).first()
        owner = db.query(User).filter(User.id == owner_access.user_id).first() if owner_access else None

    if not owner:
        logger.warning("No owner found for profile %s — skipping.", profile.id)
        return None

    # Send to the profile's own phone; fall back to owner's phone for profiles
    # that belong to family members without their own smartphone (e.g. elderly parent)
    target_phone = normalize_phone(profile.phone_number) or normalize_phone(owner.phone_number)
    if not target_phone:
        logger.warning(
            "Profile %s (%s) has no phone and owner %s has no phone — skipping.",
            profile.id, profile.name, owner.id
        )
        return None

    logger.info(
        "Profile %s (%s) → sending to %s",
        profile.id, profile.name,
        "profile's own number" if normalize_phone(profile.phone_number) else "owner's number"
    )

    try:
        last_7d = datetime.now(timezone.utc) - timedelta(days=7)

        glucose = db.query(HealthReading).filter(
            HealthReading.profile_id == profile.id,
            HealthReading.reading_type == "glucose",
            HealthReading.reading_timestamp >= last_7d
        ).order_by(HealthReading.reading_timestamp.desc()).first()

        bp = db.query(HealthReading).filter(
            HealthReading.profile_id == profile.id,
            HealthReading.reading_type == "blood_pressure",
            HealthReading.reading_timestamp >= last_7d
        ).order_by(HealthReading.reading_timestamp.desc()).first()

        weight = db.query(HealthReading).filter(
            HealthReading.profile_id == profile.id,
            HealthReading.reading_type == "weight",
            HealthReading.reading_timestamp >= last_7d
        ).order_by(HealthReading.reading_timestamp.desc()).first()

        any_data = db.query(HealthReading).filter(
            HealthReading.profile_id == profile.id,
            HealthReading.reading_timestamp >= last_7d
        ).first()

        if not any_data:
            logger.info("Profile %s (%s) has no 7-day data — skipping.", profile.id, profile.name)
            return None

        insight = ai_report_service.get_weekly_ai_insight(db, profile.id, owner)

        # Build each metric line — no \n anywhere (template variable constraint)
        if glucose:
            g_status = classify_glucose(glucose.glucose_value)
            g_icon = "✅" if g_status == "NORMAL" else "⚠️"
            age_days = (datetime.now(timezone.utc) - ensure_utc(glucose.reading_timestamp)).days
            age_str = f" ({age_days}d ago)" if age_days > 0 else ""
            glucose_line = f"🩸 Sugar: {int(glucose.glucose_value)} mg/dL{age_str} ({g_status.title()}) {g_icon}"
        else:
            glucose_line = "🩸 Sugar: No checks this week"

        if bp:
            bp_status = classify_bp(bp.systolic, bp.diastolic)
            bp_icon = "✅" if bp_status == "NORMAL" else "⚠️"
            age_days = (datetime.now(timezone.utc) - ensure_utc(bp.reading_timestamp)).days
            age_str = f" ({age_days}d ago)" if age_days > 0 else ""
            bp_line = f"💓 BP: {int(bp.systolic)}/{int(bp.diastolic)} mmHg{age_str} ({bp_status.title()}) {bp_icon}"
        else:
            bp_line = "💓 BP: No checks this week"

        weight_line = None
        if weight and weight.weight_value:
            age_days = (datetime.now(timezone.utc) - ensure_utc(weight.reading_timestamp)).days
            age_str = f" ({age_days}d ago)" if age_days > 0 else ""
            weight_line = f"⚖️ Weight: {weight.weight_value:.1f} kg{age_str}"

        insight_line = None
        if insight:
            insight_clean = re.sub(r"\s+", " ", insight).strip()
            insight_line = f"✨ AI: {insight_clean}"

        # {{3}}: profile name + all metrics pipe-separated, no \n
        parts = [f"👤 *{profile.name}*", glucose_line, bp_line]
        if weight_line:
            parts.append(weight_line)
        if insight_line:
            parts.append(insight_line)
        snippet = " | ".join(parts)

        reading_ids = []
        if glucose: reading_ids.append(glucose.id)
        if bp: reading_ids.append(bp.id)
        if weight: reading_ids.append(weight.id)

        return {
            "status": ReportGenerationStatus.SUCCESS,
            "profile_id": profile.id,
            "owner_id": owner.id,
            "target_phone": target_phone,
            "snippet": snippet,
            "reading_ids": reading_ids,
            "profile_name": profile.name,
            "profile_data": {"glucose": glucose, "bp": bp, "weight": weight, "insight": insight},
        }

    except Exception as e:
        logger.error("Error building report for profile %s", profile.id, exc_info=True)
        return {
            "status": ReportGenerationStatus.FAILED,
            "profile_id": profile.id,
            "owner_id": owner.id if owner else None,
            "error_message": str(e),
        }


def send_weekly_reports(
    db: Optional[Session] = None,
    trigger_type: ReportTriggerType = ReportTriggerType.SCHEDULED,
    user_id: Optional[int] = None,
) -> dict:
    """Sends one WhatsApp report per profile to its owner.

    Deepak owns 4 profiles → Deepak's phone receives 4 separate messages,
    each with one profile's weekly health data.
    Profiles with no 7-day data are silently skipped.
    """
    managed_session = False
    if db is None:
        db = SessionLocal()
        managed_session = True

    results = {"total_profiles": 0, "successful_deliveries": 0, "failed_deliveries": 0, "errors": []}

    try:
        if not settings.TWILIO_REPORT_CONTENT_SID:
            raise ValueError("TWILIO_REPORT_CONTENT_SID is not configured")

        now = datetime.now(timezone.utc)
        last_week_str = (now - timedelta(days=6)).strftime("%d %b")
        date_str = now.strftime("%d %b %Y")

        query = db.query(Profile, User).join(
            ProfileAccess, ProfileAccess.profile_id == Profile.id
        ).join(
            User, User.id == ProfileAccess.user_id
        ).filter(
            ProfileAccess.access_level == 'owner',
            User.is_active == True
        )
        if user_id:
            query = query.filter(ProfileAccess.user_id == user_id)

        batch_size = 50
        offset = 0
        while True:
            rows = query.offset(offset).limit(batch_size).all()
            if not rows:
                break

            for p, owner in rows:
                results["total_profiles"] += 1
                data = trigger_single_profile_report(db, p, trigger_type, owner=owner)

                if not data:
                    # No 7-day data — skip silently
                    continue

                if data['status'] == ReportGenerationStatus.FAILED:
                    try:
                        db.add(ReportGenerationLog(
                            user_id=data['owner_id'],
                            trigger_type=trigger_type,
                            report_date=date.today(),
                            members_requested=[data['profile_id']],
                            members_with_data=[],
                            status=ReportGenerationStatus.FAILED,
                            error_message=data.get('error_message'),
                        ))
                        db.commit()
                    except Exception:
                        logger.error("Failed to log generation failure for profile %s", p.id, exc_info=True)
                    results["failed_deliveries"] += 1
                    continue

                # Send individual report for this profile
                phone = data['target_phone']
                try:
                    db.add(ReportGenerationLog(
                        user_id=data['owner_id'],
                        trigger_type=trigger_type,
                        report_date=date.today(),
                        members_requested=[data['profile_id']],
                        members_with_data=[data['profile_id']],
                        status=ReportGenerationStatus.SUCCESS,
                    ))
                    db.commit()

                    # {{1}} = week start, {{2}} = week end, {{3}} = this profile's data
                    template_vars = [last_week_str, date_str, data['snippet']]

                    delivery_log = WhatsAppMessageLog(
                        user_id=data['owner_id'],
                        phone_number=phone,
                        trigger_type=trigger_type,
                        report_date=date.today(),
                        member_ids_included=[data['profile_id']],
                        reading_ids_included=data['reading_ids'],
                        message_snapshot=data['snippet'],
                        status=WhatsAppMessageStatus.QUEUED,
                    )
                    db.add(delivery_log)
                    db.commit()

                    success, sid, err = whatsapp_service.send_whatsapp_template(
                        phone, settings.TWILIO_REPORT_CONTENT_SID, template_vars
                    )
                    delivery_log.status = WhatsAppMessageStatus.SENT if success else WhatsAppMessageStatus.FAILED
                    delivery_log.twilio_sid = sid
                    delivery_log.error_message = err
                    db.commit()

                    if success:
                        results["successful_deliveries"] += 1
                        logger.info(
                            "[REPORT] Sent profile %s (%s) to owner %s → %s",
                            data['profile_id'], data['profile_name'], data['owner_id'], sid
                        )
                    else:
                        results["failed_deliveries"] += 1
                        results["errors"].append(f"Profile {data['profile_name']}: {err}")
                        logger.error(
                            "[REPORT] Failed profile %s (%s): %s",
                            data['profile_id'], data['profile_name'], err
                        )

                except Exception as e:
                    logger.error("Failed to send report for profile %s", p.id, exc_info=True)
                    results["failed_deliveries"] += 1
                    results["errors"].append(f"Profile {data['profile_name']}: {str(e)}")

            offset += batch_size

        logger.info(
            "[REPORT] Run complete — profiles: %d, sent: %d, failed: %d",
            results["total_profiles"], results["successful_deliveries"], results["failed_deliveries"]
        )

    except Exception as e:
        logger.error("Error in send_weekly_reports", exc_info=True)
        results["errors"].append(str(e))
    finally:
        if managed_session:
            db.close()

    return results


if __name__ == "__main__":
    send_weekly_reports(trigger_type=ReportTriggerType.MANUAL)
