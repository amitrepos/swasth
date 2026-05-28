import pytest
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch
from fastapi.testclient import TestClient
import models
from main import app
from report_service import build_doctor_summary, send_doctor_weekly_reports
from models import ReportTriggerType, ReportGenerationStatus, UserRole
from scheduler import doctor_weekly_reports_job

def _add_reading(db, pid, uid, rtype, value, hours_ago=0, status="NORMAL"):
    r = models.HealthReading(
        profile_id=pid, logged_by=uid, reading_type=rtype,
        glucose_value=value if rtype == "glucose" else None,
        systolic=value if rtype == "blood_pressure" else None,
        diastolic=(value - 40) if rtype == "blood_pressure" else None,
        spo2_value=value if rtype == "spo2" else None,
        steps_count=value if rtype == "steps" else None,
        value_numeric=value, unit_display="mg/dL" if rtype == "glucose" else "mmHg",
        status_flag=status, 
        reading_timestamp=datetime.now(timezone.utc) - timedelta(hours=hours_ago),
    )
    db.add(r)
    db.flush()
    return r

class TestDoctorWeeklyReportsV2:

    def test_build_doctor_summary_bulk_loading(self, db):
        # Setup doctor
        doctor = models.User(full_name="Dr. Bulk", role=UserRole.doctor, password_hash="...")
        db.add(doctor)
        db.flush()
        
        # Setup 3 patients
        profiles = []
        for i in range(3):
            p = models.Profile(name=f"Patient {i}")
            db.add(p)
            db.flush()
            link = models.DoctorPatientLink(
                doctor_id=doctor.id, profile_id=p.id, 
                status='active', consent_granted_at=datetime.now(timezone.utc),
                consent_type='in_person_exam'
            )
            db.add(link)
            profiles.append(p)
        db.flush()
        
        # Add readings for p0 and p1, p2 has none
        _add_reading(db, profiles[0].id, 1, "glucose", 120)
        _add_reading(db, profiles[1].id, 1, "blood_pressure", 170) # Critical BP
        
        last_7d = datetime.now(timezone.utc) - timedelta(days=7)
        summary = build_doctor_summary(db, doctor.id, last_7d)
        
        assert summary["total_patients_count"] == 3
        assert summary["patients_with_data_count"] == 2
        assert len(summary["patients"]) == 2
        assert "Patient 1" in summary["critical_patients"]

    def test_send_doctor_weekly_reports_no_config(self, db):
        with patch("report_service.settings") as mock_settings:
            mock_settings.TWILIO_DOCTOR_REPORT_CONTENT_SID = None
            results = send_doctor_weekly_reports(db, trigger_type=ReportTriggerType.MANUAL)
            assert "TWILIO_DOCTOR_REPORT_CONTENT_SID is not configured" in results["errors"][0]

    def test_send_doctor_weekly_reports_no_data_skip_real_path(self, db):
        """Reviewer C2: the existing no-data test (below) was vacuous —
        it omitted DoctorProfile, so the doctor was filtered out by the
        INNER JOIN long before the no-data branch was reached. This
        test exercises the REAL path: doctor + DoctorProfile + active
        link + patient with readings older than 7 days. Asserts:
          (a) Twilio is NOT called
          (b) An audit row IS written with patients_with_data_count=0
              and error_message='no_data_in_window' (the new ops-
              visibility behavior per M1).
        """
        with patch("report_service.settings") as mock_settings, \
             patch("report_service.whatsapp_service") as mock_whatsapp:
            mock_settings.TWILIO_DOCTOR_REPORT_CONTENT_SID = "HX123"

            doctor = models.User(
                full_name="Dr. SparseLogger", phone_number="+919900000000",
                role=UserRole.doctor, password_hash="...",
            )
            db.add(doctor); db.flush()
            db.add(models.DoctorProfile(
                user_id=doctor.id,
                nmc_number="NMC-STALE-001",
                doctor_code="DRSTALE1",
            )); db.flush()

            profile = models.Profile(name="Idle Patient")
            db.add(profile); db.flush()
            db.add(models.DoctorPatientLink(
                doctor_id=doctor.id, profile_id=profile.id, status='active',
                consent_granted_at=datetime.now(timezone.utc),
                consent_type='in_person_exam',
            )); db.flush()
            # Reading is 10 days old → outside the 7-day window.
            _add_reading(db, profile.id, 1, "glucose", 100, hours_ago=240)
            db.commit()

            from report_service import send_doctor_weekly_reports
            send_doctor_weekly_reports(db, trigger_type=ReportTriggerType.MANUAL)

            mock_whatsapp.send_whatsapp_template.assert_not_called()
            gen_log = (
                db.query(models.DoctorReportGenerationLog)
                .filter_by(doctor_id=doctor.id)
                .first()
            )
            assert gen_log is not None, (
                "No-data skip MUST still write an audit row so ops can "
                "distinguish 'processed and skipped' from 'never evaluated'."
            )
            assert gen_log.patients_with_data_count == 0
            assert gen_log.error_message == "no_data_in_window"

    def test_send_doctor_weekly_reports_no_data_skip(self, db):
        with patch("report_service.settings") as mock_settings:
            mock_settings.TWILIO_DOCTOR_REPORT_CONTENT_SID = "HX123"
            doctor = models.User(full_name="Dr. Skip", role=UserRole.doctor, password_hash="...")
            db.add(doctor)
            db.flush()
            # No links or data
            results = send_doctor_weekly_reports(db, trigger_type=ReportTriggerType.MANUAL)
            assert results["successful_deliveries"] == 0

    @patch("report_service.whatsapp_service")
    def test_send_doctor_weekly_reports_critical_flagging(self, mock_whatsapp, db):
        with patch("report_service.settings") as mock_settings:
            mock_settings.TWILIO_DOCTOR_REPORT_CONTENT_SID = "HX123"
            mock_whatsapp.send_whatsapp_template.return_value = (True, "SM123", None)

            doctor = models.User(full_name="Dr. Alert", phone_number="+919999999999", role=UserRole.doctor, password_hash="...")
            db.add(doctor)
            db.flush()

            # send_doctor_weekly_reports JOINs User -> DoctorProfile; without
            # this row the doctor is silently filtered out and no message
            # log is ever created (which is what the previous test asserted
            # on, getting AttributeError on None).
            dp = models.DoctorProfile(
                user_id=doctor.id,
                nmc_number="NMC-TEST-CRIT-001",
                doctor_code="DRCRIT01",
            )
            db.add(dp)
            db.flush()

            p = models.Profile(name="Hyper Patient")
            db.add(p)
            db.flush()

            link = models.DoctorPatientLink(
                doctor_id=doctor.id, profile_id=p.id,
                status='active', consent_granted_at=datetime.now(timezone.utc),
                consent_type='in_person_exam'
            )
            db.add(link)
            db.flush()

            # Critical Glucose — build_doctor_summary uses classify_glucose(v) == "CRITICAL"
            _add_reading(db, p.id, 1, "glucose", 400)

            send_doctor_weekly_reports(db, trigger_type=ReportTriggerType.MANUAL)

            log = db.query(models.WhatsAppMessageLog).filter_by(user_id=doctor.id).first()
            assert log is not None, (
                "WhatsAppMessageLog row missing — send_doctor_weekly_reports "
                "skipped this doctor. Check DoctorProfile setup and "
                "settings.TWILIO_DOCTOR_REPORT_CONTENT_SID mock."
            )

            # DPDPA: the persisted audit snapshot must NOT contain
            # patient names or raw health values. Only aggregate counts.
            snap = log.message_snapshot
            assert "Hyper Patient" not in snap, (
                "Patient name leaked into WhatsAppMessageLog.message_snapshot. "
                "DPDPA 2023 forbids storing third-party PHI in audit columns."
            )
            assert "400" not in snap and "Sugar" not in snap, (
                "Raw glucose value / metric label leaked into the audit "
                "snapshot. Persist only counts."
            )
            # Aggregate counts MUST be present for the audit to be useful.
            assert "critical=1" in snap, (
                f"Aggregate critical count missing from snapshot: {snap!r}"
            )
            assert "patients_with_data=1" in snap

            # Verify the actual outbound WhatsApp message (template args)
            # DID carry the critical header — that render is ephemeral
            # (Twilio doesn't persist the rendered body for us, so
            # leaking PHI into the *outbound* message to the patient's
            # consented doctor is acceptable; leaking PHI into our
            # audit row is not).
            mock_whatsapp.send_whatsapp_template.assert_called_once()
            # send_whatsapp_template(phone, content_sid, template_vars_list)
            template_vars = mock_whatsapp.send_whatsapp_template.call_args[0][2]
            assert "🚨 CRITICAL: Hyper Patient" in template_vars[2]

    def test_manual_trigger_api_permissions(self, client, db):
        # 1. Test Patient 403
        patient = models.User(full_name="I Am Patient", role=UserRole.patient, email="p@test.com", password_hash="...")
        db.add(patient)
        db.flush()
        
        from auth import create_access_token
        token = create_access_token({"sub": "p@test.com"})
        headers = {"Authorization": f"Bearer {token}"}
        
        resp = client.post("/api/doctor/report/manual-trigger", headers=headers)
        assert resp.status_code == 403
        
        # 2. Test Doctor 202
        doctor = models.User(full_name="I Am Doctor", role=UserRole.doctor, email="d@test.com", password_hash="...")
        db.add(doctor)
        db.flush()
        
        token = create_access_token({"sub": "d@test.com"})
        headers = {"Authorization": f"Bearer {token}"}
        
        # Patch background task to avoid actual run
        with patch("routes_doctor.BackgroundTasks.add_task") as mock_task:
            resp = client.post("/api/doctor/report/manual-trigger", headers=headers)
            assert resp.status_code == 202
            assert "Doctor report generation started" in resp.json()["message"]
            mock_task.assert_called_once()

    @patch("scheduler.send_doctor_weekly_reports")
    def test_scheduler_job_callable(self, mock_send):
        # Patch at scheduler.* because scheduler.py imports the symbol at
        # module load (`from report_service import send_doctor_weekly_reports`)
        # — patching report_service.* would only rebind the original module's
        # attribute and the scheduler's local reference would still point to
        # the unpatched function.
        doctor_weekly_reports_job()
        mock_send.assert_called_once_with(trigger_type=ReportTriggerType.SCHEDULED)

    # ──────────────────────────────────────────────────────────────────
    # C1 + M2 — failure logged on every exit path
    # ──────────────────────────────────────────────────────────────────

    def test_no_phone_writes_failed_gen_log_not_success(self, db):
        """Reviewer C1: previously a doctor with no phone hit `continue`
        AFTER a SUCCESS gen log was committed. The audit row falsely
        claimed success when nothing was sent. Now: status=FAILED with
        error_message='no_phone_number'."""
        with patch("report_service.settings") as mock_settings:
            mock_settings.TWILIO_DOCTOR_REPORT_CONTENT_SID = "HX123"

            # Doctor with NO phone number on User AND no DoctorProfile.
            doctor = models.User(
                full_name="Dr. Phoneless", role=UserRole.doctor, password_hash="...",
            )
            db.add(doctor); db.flush()
            dp = models.DoctorProfile(
                user_id=doctor.id, nmc_number="NMC-NOPHONE-001", doctor_code="DRNP0001",
            )
            db.add(dp); db.flush()

            p = models.Profile(name="Patient X"); db.add(p); db.flush()
            db.add(models.DoctorPatientLink(
                doctor_id=doctor.id, profile_id=p.id, status='active',
                consent_granted_at=datetime.now(timezone.utc),
                consent_type='in_person_exam',
            )); db.flush()
            _add_reading(db, p.id, 1, "glucose", 110)

            send_doctor_weekly_reports(db, trigger_type=ReportTriggerType.MANUAL)

            gen_log = (
                db.query(models.DoctorReportGenerationLog)
                .filter_by(doctor_id=doctor.id)
                .first()
            )
            assert gen_log is not None, "Failure path must still leave an audit row."
            assert gen_log.status == models.ReportGenerationStatus.FAILED, (
                f"Expected FAILED, got {gen_log.status}. The SUCCESS-before-"
                "delivery regression has returned."
            )
            assert gen_log.error_message == "no_phone_number"

    # ──────────────────────────────────────────────────────────────────
    # M3 — truncation no longer silently drops patients
    # ──────────────────────────────────────────────────────────────────

    @patch("report_service.whatsapp_service")
    def test_truncation_announces_omitted_patient_count(self, mock_whatsapp, db):
        """Reviewer M3: doctor with 20+ patients used to get a digest
        chopped mid-line with no indication of how many patients were
        cut. Now the message includes "(+N patients omitted — see
        portal)" so the doctor knows to log in to the portal for the
        full list."""
        with patch("report_service.settings") as mock_settings:
            mock_settings.TWILIO_DOCTOR_REPORT_CONTENT_SID = "HX123"
            mock_whatsapp.send_whatsapp_template.return_value = (True, "SM999", None)

            doctor = models.User(
                full_name="Dr. Panel", phone_number="+919900000000",
                role=UserRole.doctor, password_hash="...",
            )
            db.add(doctor); db.flush()
            dp = models.DoctorProfile(
                user_id=doctor.id, nmc_number="NMC-PANEL-001", doctor_code="DRPNL01",
            )
            db.add(dp); db.flush()

            # 25 patients, each with one normal-range glucose reading.
            # Patient names are intentionally long enough that the
            # digest will exceed the 1000-char budget and trigger
            # omission logic.
            for i in range(25):
                p = models.Profile(name=f"Patient With A Reasonably Long Name {i:02d}")
                db.add(p); db.flush()
                db.add(models.DoctorPatientLink(
                    doctor_id=doctor.id, profile_id=p.id, status='active',
                    consent_granted_at=datetime.now(timezone.utc),
                    consent_type='in_person_exam',
                )); db.flush()
                _add_reading(db, p.id, 1, "glucose", 105 + i)

            send_doctor_weekly_reports(db, trigger_type=ReportTriggerType.MANUAL)

            mock_whatsapp.send_whatsapp_template.assert_called_once()
            digest = mock_whatsapp.send_whatsapp_template.call_args[0][2][2]
            assert "patients omitted" in digest, (
                f"Truncated digest missing the omission notice: {digest!r}. "
                "Doctors must be told when the message has been cut."
            )
            assert "see portal" in digest
            assert len(digest) <= 1000, (
                f"Digest exceeded 1000 chars ({len(digest)}). Twilio limit."
            )

    # ──────────────────────────────────────────────────────────────────
    # M1 — manual-trigger cooldown returns 429
    # ──────────────────────────────────────────────────────────────────

    def test_manual_trigger_rate_limited_within_one_hour(self, client, db):
        """Reviewer M1: a doctor with a recent manual delivery row
        (<1h old) must get 429 instead of triggering a second send."""
        doctor = models.User(
            full_name="I Am Doctor", role=UserRole.doctor,
            email="rl-doctor@test.com", password_hash="...",
        )
        db.add(doctor); db.flush()

        # Simulate a delivery that just happened.
        db.add(models.WhatsAppMessageLog(
            user_id=doctor.id,
            phone_number="+919900000000",
            trigger_type=ReportTriggerType.MANUAL,
            report_date=datetime.now(timezone.utc).date(),
            member_ids_included=[],
            status=models.WhatsAppMessageStatus.SENT,
            sent_at=datetime.now(timezone.utc) - timedelta(minutes=15),
        ))
        db.commit()

        from auth import create_access_token
        token = create_access_token({"sub": "rl-doctor@test.com"})
        headers = {"Authorization": f"Bearer {token}"}

        resp = client.post("/api/doctor/report/manual-trigger", headers=headers)
        assert resp.status_code == 429, (
            f"Expected 429 (rate-limited), got {resp.status_code}: {resp.text}. "
            "A delivery row <1h old must block further manual triggers."
        )
        body = resp.json()
        assert "once per hour" in body["detail"]["message"]
        assert "retry_after_seconds" in body["detail"]
        assert "Retry-After" in resp.headers
        
        retry_after = int(resp.headers["Retry-After"])
        assert 1 <= retry_after <= 3600
        assert body["detail"]["retry_after_seconds"] == retry_after

    def test_manual_trigger_NOT_blocked_by_recent_failed_delivery(
        self, client, db,
    ):
        """Reviewer M1 (the headline fix): a FAILED delivery row <1h
        old must NOT block a manual retry. The doctor never got their
        report; a retry is the correct user action. Only SENT or
        QUEUED rows should cooldown."""
        doctor = models.User(
            full_name="Retry After Failure", role=UserRole.doctor,
            email="failed-rl@test.com", password_hash="...",
        )
        db.add(doctor); db.flush()

        # Twilio just failed 5 minutes ago.
        db.add(models.WhatsAppMessageLog(
            user_id=doctor.id,
            phone_number="+919900000000",
            trigger_type=ReportTriggerType.MANUAL,
            report_date=datetime.now(timezone.utc).date(),
            member_ids_included=[],
            status=models.WhatsAppMessageStatus.FAILED,
            sent_at=datetime.now(timezone.utc) - timedelta(minutes=5),
            error_message="twilio error",
        ))
        db.commit()

        from auth import create_access_token
        token = create_access_token({"sub": "failed-rl@test.com"})
        headers = {"Authorization": f"Bearer {token}"}

        with patch("routes_doctor.BackgroundTasks.add_task"):
            resp = client.post("/api/doctor/report/manual-trigger", headers=headers)
        assert resp.status_code == 202, (
            f"Expected 202 (retry allowed after FAILED), got {resp.status_code}: "
            f"{resp.text}. A FAILED row blocking retry is the regression."
        )

    def test_manual_trigger_allowed_when_last_delivery_over_one_hour(
        self, client, db,
    ):
        """The cooldown must release after exactly 1 hour — a 2-hour-old
        row must NOT block a new trigger."""
        doctor = models.User(
            full_name="Old Delivery Doc", role=UserRole.doctor,
            email="old-rl@test.com", password_hash="...",
        )
        db.add(doctor); db.flush()

        db.add(models.WhatsAppMessageLog(
            user_id=doctor.id,
            phone_number="+919900000000",
            trigger_type=ReportTriggerType.MANUAL,
            report_date=datetime.now(timezone.utc).date(),
            member_ids_included=[],
            status=models.WhatsAppMessageStatus.SENT,
            sent_at=datetime.now(timezone.utc) - timedelta(hours=2),
        ))
        db.commit()

        from auth import create_access_token
        token = create_access_token({"sub": "old-rl@test.com"})
        headers = {"Authorization": f"Bearer {token}"}

        with patch("routes_doctor.BackgroundTasks.add_task"):
            resp = client.post("/api/doctor/report/manual-trigger", headers=headers)
        assert resp.status_code == 202, (
            f"Expected 202, got {resp.status_code}. Cooldown is supposed to "
            "release after 1 hour."
        )
