import pytest
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch
import models
from report_service import build_doctor_summary, send_doctor_weekly_reports
from models import ReportTriggerType, ReportGenerationStatus

def _add_reading(db, pid, uid, rtype, value, hours_ago=0):
    r = models.HealthReading(
        profile_id=pid, logged_by=uid, reading_type=rtype,
        glucose_value=value if rtype == "glucose" else None,
        systolic=value if rtype == "blood_pressure" else None,
        diastolic=(value - 40) if rtype == "blood_pressure" else None,
        spo2_value=value if rtype == "spo2" else None,
        steps_count=value if rtype == "steps" else None,
        value_numeric=value, unit_display="mg/dL" if rtype == "glucose" else "mmHg",
        status_flag="NORMAL", 
        reading_timestamp=datetime.now(timezone.utc) - timedelta(hours=hours_ago),
    )
    db.add(r)
    db.flush()
    return r

class TestDoctorReportService:

    def test_build_doctor_summary_empty(self, db):
        # Setup doctor
        doctor = models.User(full_name="Dr. Smith", role=models.UserRole.doctor, password_hash="...")
        db.add(doctor)
        db.flush()
        
        last_7d = datetime.now(timezone.utc) - timedelta(days=7)
        summary = build_doctor_summary(db, doctor.id, last_7d)
        
        assert summary["total_patients_count"] == 0
        assert summary["patients_with_data_count"] == 0
        assert len(summary["patients"]) == 0

    def test_build_doctor_summary_with_data(self, db):
        # Setup doctor and patient
        doctor = models.User(full_name="Dr. Smith", role=models.UserRole.doctor, password_hash="...")
        patient_user = models.User(full_name="John Doe", role=models.UserRole.patient, password_hash="...")
        db.add_all([doctor, patient_user])
        db.flush()
        
        profile = models.Profile(name="John's Profile")
        db.add(profile)
        db.flush()
        
        link = models.DoctorPatientLink(
            doctor_id=doctor.id, profile_id=profile.id, 
            status='active', consent_granted_at=datetime.now(timezone.utc),
            consent_type='in_person_exam'
        )
        db.add(link)
        db.flush()
        
        # Add readings
        _add_reading(db, profile.id, patient_user.id, "glucose", 120, hours_ago=2)
        _add_reading(db, profile.id, patient_user.id, "blood_pressure", 120, hours_ago=5) # 120/80
        _add_reading(db, profile.id, patient_user.id, "spo2", 98, hours_ago=10)
        _add_reading(db, profile.id, patient_user.id, "steps", 5000, hours_ago=24)
        
        last_7d = datetime.now(timezone.utc) - timedelta(days=7)
        summary = build_doctor_summary(db, doctor.id, last_7d)
        
        assert summary["total_patients_count"] == 1
        assert summary["patients_with_data_count"] == 1
        assert len(summary["patients"]) == 1
        p0 = summary["patients"][0]

        # Encryption round-trip check (Reviewer M2): Profile.name is
        # stored encrypted (name_enc, AES-256-GCM). The .name property
        # transparently decrypts via decrypt_pii. If the ORM layer ever
        # changed to expose name_enc directly (e.g. someone removes the
        # property), the digest header would surface ciphertext like
        # "🚨 CRITICAL: gAAAAAB..." — clinically meaningless to the doctor
        # and a PHI-leak liability. This assertion proves the value
        # surfaced from build_doctor_summary is plaintext.
        assert p0["name"] == "John's Profile", (
            "Profile name in summary must be the plaintext value passed "
            "into Profile(name=...). If this fails with a base64/hex blob, "
            "the Profile.name property's decrypt round-trip has broken."
        )
        # Belt-and-braces: explicitly assert NOT ciphertext. AES-GCM
        # ciphertext under our scheme is base64 and starts with the
        # version prefix used by encrypt_pii — never with an apostrophe.
        assert not p0["name"].startswith("gAAAAA"), (
            "Profile name leaked as Fernet/AES ciphertext into the doctor "
            "digest. PII_ENCRYPTION_KEY round-trip is broken."
        )

        # Critical-patient header uses the same .name path. If a critical
        # reading flowed through, that name MUST also be plaintext.
        # (No critical readings in this test — verified separately in
        # test_build_doctor_summary_critical.)
        assert "glucose" in p0["metrics"]
        assert "bp" in p0["metrics"]
        assert "spo2" in p0["metrics"]
        assert "steps" in p0["metrics"]
        assert p0["metrics"]["glucose"]["avg"] == 120.0
        assert p0["metrics"]["bp"]["avg_sys"] == 120.0
        assert p0["metrics"]["steps"]["total"] == 5000

    def test_build_doctor_summary_critical(self, db):
        doctor = models.User(full_name="Dr. Smith", role=models.UserRole.doctor, password_hash="...")
        db.add(doctor)
        db.flush()

        profile = models.Profile(name="Critical Patient")
        db.add(profile)
        db.flush()

        link = models.DoctorPatientLink(
            doctor_id=doctor.id, profile_id=profile.id,
            status='active', consent_granted_at=datetime.now(timezone.utc),
            consent_type='in_person_exam'
        )
        db.add(link)
        db.flush()

        # Add critical readings (Stage 2 BP)
        _add_reading(db, profile.id, 1, "blood_pressure", 170, hours_ago=2) # 170/130

        last_7d = datetime.now(timezone.utc) - timedelta(days=7)
        summary = build_doctor_summary(db, doctor.id, last_7d)

        assert "Critical Patient" in summary["critical_patients"]
        assert "BP" in summary["patients"][0]["critical_metrics"]

    def _add_bp(self, db, pid, sys, dia, hours_ago=0):
        """BP reading with explicit systolic + diastolic. `_add_reading`
        hard-codes dia = sys-40, so anything above Stage-1 systolic also
        lands in Stage-2 diastolic — useless for testing the Stage-1
        boundary."""
        r = models.HealthReading(
            profile_id=pid, logged_by=1, reading_type="blood_pressure",
            systolic=sys, diastolic=dia,
            value_numeric=sys, unit_display="mmHg", status_flag="NORMAL",
            reading_timestamp=datetime.now(timezone.utc) - timedelta(hours=hours_ago),
        )
        db.add(r); db.flush()
        return r

    def test_sustained_stage1_bp_is_flagged_critical(self, db):
        """A patient with the whole week's BP averaging in Stage 1
        territory (132/87 daily) must surface as critical — the
        previous behavior (Stage 2 only) silently missed sustained mild
        hypertension, which is exactly the population the weekly digest
        is meant to escalate."""
        doctor = models.User(full_name="Dr. S1", role=models.UserRole.doctor, password_hash="...")
        db.add(doctor); db.flush()
        profile = models.Profile(name="Sustained S1 Patient")
        db.add(profile); db.flush()
        db.add(models.DoctorPatientLink(
            doctor_id=doctor.id, profile_id=profile.id, status='active',
            consent_granted_at=datetime.now(timezone.utc),
            consent_type='in_person_exam',
        )); db.flush()

        # 5 readings all clearly Stage 1, none Stage 2.
        # classify_bp: sys>131 OR dia>86 → STAGE 1; sys>140 OR dia>90 → STAGE 2.
        for hrs in (24, 48, 72, 96, 120):
            self._add_bp(db, profile.id, sys=135, dia=88, hours_ago=hrs)

        last_7d = datetime.now(timezone.utc) - timedelta(days=7)
        summary = build_doctor_summary(db, doctor.id, last_7d)
        assert "Sustained S1 Patient" in summary["critical_patients"], (
            "Sustained Stage-1 BP (avg 135/88 over 5 days) must be flagged "
            "critical. If this fails, the BP critical check has been "
            "narrowed back to Stage 2 only."
        )

    def test_single_stage1_bp_reading_is_NOT_flagged(self, db):
        """Conversely: ONE Stage-1 reading (a stress spike, anxiety,
        post-coffee) must NOT trigger a critical flag — would flood
        every weekly digest with non-actionable noise. The flag is for
        SUSTAINED elevation; we use the week's avg, not any single hit."""
        doctor = models.User(full_name="Dr. S1B", role=models.UserRole.doctor, password_hash="...")
        db.add(doctor); db.flush()
        profile = models.Profile(name="One-off Spike")
        db.add(profile); db.flush()
        db.add(models.DoctorPatientLink(
            doctor_id=doctor.id, profile_id=profile.id, status='active',
            consent_granted_at=datetime.now(timezone.utc),
            consent_type='in_person_exam',
        )); db.flush()

        # Mostly normal + ONE Stage-1 reading. Average lands in NORMAL.
        self._add_bp(db, profile.id, sys=118, dia=78, hours_ago=24)
        self._add_bp(db, profile.id, sys=120, dia=80, hours_ago=48)
        self._add_bp(db, profile.id, sys=135, dia=88, hours_ago=72)  # Stage 1 spike
        self._add_bp(db, profile.id, sys=115, dia=76, hours_ago=96)
        self._add_bp(db, profile.id, sys=119, dia=79, hours_ago=120)

        last_7d = datetime.now(timezone.utc) - timedelta(days=7)
        summary = build_doctor_summary(db, doctor.id, last_7d)
        assert "One-off Spike" not in summary["critical_patients"], (
            "A single Stage-1 reading must NOT critical-flag the patient. "
            "Sustained-only rule has regressed; doctors will get false-alarm "
            "alerts every week."
        )

    @patch("report_service.whatsapp_service")
    def test_doctor_profile_phone_decrypts_for_delivery(self, mock_whatsapp, db):
        """Reviewer M2 (companion to the Profile.name encryption test):
        the fallback phone path also goes through encrypted PII storage
        — DoctorProfile.phone_number_enc / whatsapp_number_enc. If the
        decrypt round-trip is broken there, send_doctor_weekly_reports
        would hand Twilio a base64 blob as the destination, every
        message would fail, and ops would see Twilio "invalid number"
        errors with no obvious cause.

        Sets the doctor's User.phone_number to NULL so the function
        is forced to consult DoctorProfile.whatsapp_number → exercises
        the decrypt path end-to-end."""
        with patch("report_service.settings") as mock_settings:
            mock_settings.TWILIO_DOCTOR_REPORT_CONTENT_SID = "HX123"
            mock_whatsapp.send_whatsapp_template.return_value = (True, "SM123", None)

            doctor = models.User(
                full_name="Dr. PhoneOnDP",
                # phone_number deliberately omitted → forces fallback
                role=models.UserRole.doctor,
                password_hash="...",
            )
            db.add(doctor); db.flush()
            dp = models.DoctorProfile(
                user_id=doctor.id,
                nmc_number="NMC-PHONE-001",
                doctor_code="DRPHN001",
                whatsapp_number="+919811112222",  # stored encrypted, decrypted on read
                is_verified=True,  # required for digest path (CRITICAL #1)
            )
            db.add(dp); db.flush()

            p = models.Profile(name="Phone Path Patient")
            db.add(p); db.flush()
            db.add(models.DoctorPatientLink(
                doctor_id=doctor.id, profile_id=p.id, status='active',
                consent_granted_at=datetime.now(timezone.utc),
                consent_type='in_person_exam',
            )); db.flush()
            _add_reading(db, p.id, 1, "glucose", 110)

            from report_service import send_doctor_weekly_reports
            send_doctor_weekly_reports(db, trigger_type=ReportTriggerType.MANUAL)

            # Twilio was handed the decrypted plaintext number, not the
            # ciphertext stored in whatsapp_number_enc.
            mock_whatsapp.send_whatsapp_template.assert_called_once()
            phone_arg = mock_whatsapp.send_whatsapp_template.call_args[0][0]
            # normalize_phone may strip the leading + or country code —
            # but the digits 9811112222 MUST be in there. A ciphertext
            # blob would not contain that exact substring.
            assert "9811112222" in phone_arg, (
                f"Twilio received {phone_arg!r} as the destination. "
                "Expected the decrypted plaintext containing 9811112222. "
                "DoctorProfile.whatsapp_number decrypt round-trip is broken."
            )

    @patch("report_service.whatsapp_service")
    @patch("report_service.settings")
    def test_send_doctor_weekly_reports(self, mock_settings, mock_whatsapp, db):
        mock_settings.TWILIO_DOCTOR_REPORT_CONTENT_SID = "HX123"
        mock_whatsapp.send_whatsapp_template.return_value = (True, "SM123", None)
        
        doctor = models.User(full_name="Dr. Smith", phone_number="+919999999999", role=models.UserRole.doctor, password_hash="...")
        db.add(doctor)
        db.flush()
        
        doc_profile = models.DoctorProfile(user_id=doctor.id, nmc_number="12345", doctor_code="DR123", specialty="Gen", is_verified=True)
        db.add(doc_profile)
        db.flush()
        
        profile = models.Profile(name="Patient A")
        db.add(profile)
        db.flush()
        
        link = models.DoctorPatientLink(
            doctor_id=doctor.id, profile_id=profile.id, 
            status='active', consent_granted_at=datetime.now(timezone.utc),
            consent_type='in_person_exam'
        )
        db.add(link)
        db.flush()
        
        _add_reading(db, profile.id, 1, "glucose", 100, hours_ago=2)
        
        results = send_doctor_weekly_reports(db, trigger_type=ReportTriggerType.MANUAL)
        
        assert results["total_doctors"] == 1
        assert results["successful_deliveries"] == 1
        mock_whatsapp.send_whatsapp_template.assert_called_once()
        
        # Verify log entry
        log = db.query(models.DoctorReportGenerationLog).filter_by(doctor_id=doctor.id).first()
        assert log is not None
        assert log.status == ReportGenerationStatus.SUCCESS

    @patch("report_service.whatsapp_service")
    @patch("report_service.settings")
    def test_critical_block_bounded_with_many_patients(self, mock_settings, mock_whatsapp, db):
        """C1: Verify that with many critical patients, the critical_block
        is bounded to ~333 chars and includes an omission notice."""
        mock_settings.TWILIO_DOCTOR_REPORT_CONTENT_SID = "HX123"
        mock_whatsapp.send_whatsapp_template.return_value = (True, "SM123", None)
        
        doctor = models.User(full_name="Dr. Busy", phone_number="+919999999999", role=models.UserRole.doctor, password_hash="...")
        db.add(doctor); db.flush()
        db.add(models.DoctorProfile(user_id=doctor.id, nmc_number="BUSY001", doctor_code="BUSY001", is_verified=True)); db.flush()
        
        # Create 50 patients with critical readings
        for i in range(50):
            p = models.Profile(name=f"Patient With Very Long Name {i}")
            db.add(p); db.flush()
            db.add(models.DoctorPatientLink(
                doctor_id=doctor.id, profile_id=p.id, status='active',
                consent_granted_at=datetime.now(timezone.utc),
                consent_type='in_person_exam',
            )); db.flush()
            # 350 mg/dL is critical
            _add_reading(db, p.id, 1, "glucose", 350)
            
        send_doctor_weekly_reports(db, trigger_type=ReportTriggerType.MANUAL)
        
        # Check the digest snippet passed to Twilio
        args = mock_whatsapp.send_whatsapp_template.call_args[0]
        template_vars = args[2]
        digest = template_vars[2]
        
        # Extract critical block (everything before the first " | 👤")
        # format: "🚨 CRITICAL: P1, P2 +N more | 👤 P1: ..."
        critical_section = digest.split(" | 👤")[0]
        
        assert "🚨 CRITICAL:" in critical_section
        assert "more" in critical_section
        # Tightened assertion: use the budget directly (333 chars)
        assert len(critical_section) <= 333 + len(" | "), (
            f"Critical section too long: {len(critical_section)} chars. "
            f"Content: {critical_section}"
        )

    @patch("report_service.whatsapp_service")
    @patch("report_service.settings")
    def test_digest_total_under_max_len(self, mock_settings, mock_whatsapp, db):
        """C1 load-bearing invariant: even with 100 critical and 100 regular
        patients, the final digest snippet passed to Twilio MUST NOT exceed
        _MAX_LEN (1000 chars)."""
        mock_settings.TWILIO_DOCTOR_REPORT_CONTENT_SID = "HX123"
        mock_whatsapp.send_whatsapp_template.return_value = (True, "SM-LOAD", None)
        
        doctor = models.User(full_name="Dr. LoadTest", phone_number="+919999999999", role=models.UserRole.doctor, password_hash="...")
        db.add(doctor); db.flush()
        db.add(models.DoctorProfile(user_id=doctor.id, nmc_number="LOAD001", doctor_code="LOAD001", is_verified=True)); db.flush()
        
        # 100 critical patients
        for i in range(100):
            p = models.Profile(name=f"Crit Patient {i}")
            db.add(p); db.flush()
            db.add(models.DoctorPatientLink(
                doctor_id=doctor.id, profile_id=p.id, status='active',
                consent_granted_at=datetime.now(timezone.utc),
                consent_type='in_person_exam',
            )); db.flush()
            _add_reading(db, p.id, 1, "glucose", 350)
            
        # 100 regular patients (total 200)
        for i in range(100):
            p = models.Profile(name=f"Reg Patient {i}")
            db.add(p); db.flush()
            db.add(models.DoctorPatientLink(
                doctor_id=doctor.id, profile_id=p.id, status='active',
                consent_granted_at=datetime.now(timezone.utc),
                consent_type='in_person_exam',
            )); db.flush()
            _add_reading(db, p.id, 1, "glucose", 110)
            
        send_doctor_weekly_reports(db, trigger_type=ReportTriggerType.MANUAL)
        
        args = mock_whatsapp.send_whatsapp_template.call_args[0]
        digest = args[2][2]
        
        assert len(digest) <= 1000, f"Digest exceeds 1000 chars: {len(digest)}"
        assert "omitted" in digest, "Expected omission notice in such a large panel"

    @patch("report_service.whatsapp_service")
    @patch("report_service.settings")
    def test_critical_block_omits_zero_suffix_when_all_fit(self, mock_settings, mock_whatsapp, db):
        """C1: Verify that when all critical patients fit, no suffix is shown."""
        mock_settings.TWILIO_DOCTOR_REPORT_CONTENT_SID = "HX123"
        mock_whatsapp.send_whatsapp_template.return_value = (True, "SM123", None)
        
        doctor = models.User(full_name="Dr. Calm", phone_number="+919999999999", role=models.UserRole.doctor, password_hash="...")
        db.add(doctor); db.flush()
        db.add(models.DoctorProfile(user_id=doctor.id, nmc_number="CALM001", doctor_code="CALM001", is_verified=True)); db.flush()
        
        # Only 2 critical patients
        for i in range(2):
            p = models.Profile(name=f"Patient {i}")
            db.add(p); db.flush()
            db.add(models.DoctorPatientLink(
                doctor_id=doctor.id, profile_id=p.id, status='active',
                consent_granted_at=datetime.now(timezone.utc),
                consent_type='in_person_exam',
            )); db.flush()
            _add_reading(db, p.id, 1, "glucose", 350)
            
        send_doctor_weekly_reports(db, trigger_type=ReportTriggerType.MANUAL)
        
        args = mock_whatsapp.send_whatsapp_template.call_args[0]
        digest = args[2][2]
        critical_section = digest.split(" | 👤")[0]
        
        assert "🚨 CRITICAL:" in critical_section
        assert "more" not in critical_section
        assert "Patient 0" in critical_section
        assert "Patient 1" in critical_section

    @patch("report_service.whatsapp_service")
    @patch("report_service.settings")
    def test_patient_with_only_non_aggregated_readings_skipped(self, mock_settings, mock_whatsapp, db):
        """M3 + M5: A patient with readings whose type the digest does
        NOT aggregate (e.g. weight) must not appear in the digest AND
        must not inflate patients_with_data_count. After the M5 fix in
        build_doctor_summary, the skip happens upstream — both audit
        row and rendered digest agree on the same patient list."""
        mock_settings.TWILIO_DOCTOR_REPORT_CONTENT_SID = "HX123"
        mock_whatsapp.send_whatsapp_template.return_value = (True, "SM-M3", None)

        doctor = models.User(
            full_name="Dr. M3", phone_number="+919999999999",
            role=models.UserRole.doctor, password_hash="...",
        )
        db.add(doctor); db.flush()
        db.add(models.DoctorProfile(
            user_id=doctor.id, nmc_number="M3001", doctor_code="M3001",
            is_verified=True,
        )); db.flush()

        # Patient WITH aggregated metric (glucose) — should appear
        good = models.Profile(name="Visible Patient")
        db.add(good); db.flush()
        db.add(models.DoctorPatientLink(
            doctor_id=doctor.id, profile_id=good.id, status='active',
            consent_granted_at=datetime.now(timezone.utc),
            consent_type='in_person_exam',
        )); db.flush()
        _add_reading(db, good.id, 1, "glucose", 110)

        # Patient with ONLY weight readings — should be skipped by
        # build_doctor_summary so audit count and digest agree.
        weight_only = models.Profile(name="Weight Only Patient")
        db.add(weight_only); db.flush()
        db.add(models.DoctorPatientLink(
            doctor_id=doctor.id, profile_id=weight_only.id, status='active',
            consent_granted_at=datetime.now(timezone.utc),
            consent_type='in_person_exam',
        )); db.flush()
        # 'weight' is not aggregated by build_doctor_summary — the
        # readings exist, but yield no glucose/bp/spo2/steps metric.
        _add_reading(db, weight_only.id, 1, "weight", 72)

        send_doctor_weekly_reports(db, trigger_type=ReportTriggerType.MANUAL)

        args = mock_whatsapp.send_whatsapp_template.call_args[0]
        digest = args[2][2]

        assert "Visible Patient" in digest, "Patient with glucose should be in digest"
        assert "Weight Only Patient" not in digest, (
            "Patient with only non-aggregated readings must be skipped — "
            f"otherwise the digest would contain '👤 Weight Only Patient: ' "
            f"(empty metrics). Got: {digest}"
        )
        # Sanity: no orphan "👤 <name>: " entries with no metrics.
        # Every "👤" should be followed by name + ": " + at least one metric.
        import re
        empty_lines = re.findall(r"👤 [^:]+: (?=\s*(?:\||$))", digest)
        assert empty_lines == [], (
            f"Found empty patient lines: {empty_lines}"
        )

    def test_build_doctor_summary_skips_empty_metric_patient(self, db):
        """M5: build_doctor_summary must not count or include patients
        whose readings produce no aggregated metric. The audit row's
        patients_with_data_count must match what the digest renders."""
        doctor = models.User(
            full_name="Dr. M5", role=models.UserRole.doctor, password_hash="...",
        )
        db.add(doctor); db.flush()

        # Patient A: glucose reading → included
        a = models.Profile(name="Has Glucose")
        db.add(a); db.flush()
        db.add(models.DoctorPatientLink(
            doctor_id=doctor.id, profile_id=a.id, status='active',
            consent_granted_at=datetime.now(timezone.utc),
            consent_type='in_person_exam',
        )); db.flush()
        _add_reading(db, a.id, 1, "glucose", 110)

        # Patient B: weight only → excluded
        b = models.Profile(name="Only Weight")
        db.add(b); db.flush()
        db.add(models.DoctorPatientLink(
            doctor_id=doctor.id, profile_id=b.id, status='active',
            consent_granted_at=datetime.now(timezone.utc),
            consent_type='in_person_exam',
        )); db.flush()
        _add_reading(db, b.id, 1, "weight", 72)

        last_7d = datetime.now(timezone.utc) - timedelta(days=7)
        summary = build_doctor_summary(db, doctor.id, last_7d)

        assert summary["patients_with_data_count"] == 1, (
            "Only the glucose patient should be counted; the weight-only "
            "patient produces no aggregated metric. Got "
            f"{summary['patients_with_data_count']}"
        )
        patient_names = [p["name"] for p in summary["patients"]]
        assert "Has Glucose" in patient_names
        assert "Only Weight" not in patient_names

    @patch("report_service.whatsapp_service")
    @patch("report_service.settings")
    def test_unverified_doctor_excluded_from_scheduled_report(self, mock_settings, mock_whatsapp, db):
        """CRITICAL #1: An unverified doctor (DoctorProfile.is_verified=False)
        must NEVER receive a PHI digest, even with active patient links.
        Bug: doctor_query joined on DoctorProfile without filtering on
        is_verified, so a doctor whose NMC verification was revoked
        AFTER linking would still get weekly reports."""
        mock_settings.TWILIO_DOCTOR_REPORT_CONTENT_SID = "HX123"
        mock_whatsapp.send_whatsapp_template.return_value = (True, "SM-UV", None)

        unverified = models.User(
            full_name="Dr. Unverified", phone_number="+919900000001",
            role=models.UserRole.doctor, password_hash="...",
        )
        db.add(unverified); db.flush()
        db.add(models.DoctorProfile(
            user_id=unverified.id, nmc_number="NMC-UV-001",
            doctor_code="DRUV0001",
            is_verified=False,  # explicit
        )); db.flush()

        # Active link + critical reading — would have triggered a send
        # under the buggy query.
        p = models.Profile(name="At Risk Patient")
        db.add(p); db.flush()
        db.add(models.DoctorPatientLink(
            doctor_id=unverified.id, profile_id=p.id, status='active',
            consent_granted_at=datetime.now(timezone.utc),
            consent_type='in_person_exam',
        )); db.flush()
        _add_reading(db, p.id, 1, "glucose", 350)  # critical

        results = send_doctor_weekly_reports(db, trigger_type=ReportTriggerType.SCHEDULED)

        assert results["total_doctors"] == 0, (
            "Unverified doctor must be filtered OUT of the query "
            f"entirely. Got {results['total_doctors']} doctor(s)."
        )
        assert results["successful_deliveries"] == 0
        # And crucially — Twilio must NEVER have been called with PHI.
        mock_whatsapp.send_whatsapp_template.assert_not_called()

    @patch("report_service.whatsapp_service")
    @patch("report_service.settings")
    def test_twilio_crash_triggers_failure_path(self, mock_settings, mock_whatsapp, db):
        """CRITICAL #2 (result-based): if Twilio raises mid-flight, the
        function MUST exercise the except handler — not crash the
        scheduler, AND record the failure in results so ops/audit can
        see it. The delivery_log row state (QUEUED → FAILED) cannot be
        asserted here because the test fixture's outer-transaction
        rollback semantics undo the in-function commit; the FAILED-row
        invariant is covered by integration tests against real
        Postgres."""
        mock_settings.TWILIO_DOCTOR_REPORT_CONTENT_SID = "HX123"
        mock_whatsapp.send_whatsapp_template.side_effect = RuntimeError(
            "twilio connection reset"
        )

        doctor = models.User(
            full_name="Dr. CrashTest", phone_number="+919900000099",
            role=models.UserRole.doctor, password_hash="...",
        )
        db.add(doctor); db.flush()
        db.add(models.DoctorProfile(
            user_id=doctor.id, nmc_number="NMC-CR-001", doctor_code="DRCR001",
            is_verified=True,
        )); db.flush()

        p = models.Profile(name="Crash Patient")
        db.add(p); db.flush()
        db.add(models.DoctorPatientLink(
            doctor_id=doctor.id, profile_id=p.id, status='active',
            consent_granted_at=datetime.now(timezone.utc),
            consent_type='in_person_exam',
        )); db.flush()
        _add_reading(db, p.id, 1, "glucose", 110)
        db.commit()  # persist test setup so the function's rollback
                     # does NOT nuke it under the test fixture's
                     # outer-transaction semantics.

        results = send_doctor_weekly_reports(db, trigger_type=ReportTriggerType.MANUAL)

        # The Twilio path was exercised — proves the except handler
        # ran (not a bypass via missing phone or unverified doctor).
        mock_whatsapp.send_whatsapp_template.assert_called_once()

        # Results report the failure cleanly — no unhandled crash.
        assert results["failed_deliveries"] == 1
        assert results["successful_deliveries"] == 0
        assert any("twilio connection reset" in err for err in results["errors"]), (
            f"Expected the Twilio error in results['errors'], got: {results['errors']}"
        )

    def test_steps_aggregation_uses_per_day_max_not_sum(self, db):
        """MEDIUM #2: Step counters are cumulative within a day — a
        single reading at 18:00 contains all steps walked since 00:00.
        Summing every reading double-counts (a patient who logs 3
        times a day for 7 days = 21 readings but only 7 days of
        steps). Aggregation must be MAX-per-day then sum across days,
        matching the patient dashboard fix in PR 267."""
        doctor = models.User(
            full_name="Dr. Step", role=models.UserRole.doctor, password_hash="...",
        )
        db.add(doctor); db.flush()

        p = models.Profile(name="Step Patient")
        db.add(p); db.flush()
        db.add(models.DoctorPatientLink(
            doctor_id=doctor.id, profile_id=p.id, status='active',
            consent_granted_at=datetime.now(timezone.utc),
            consent_type='in_person_exam',
        )); db.flush()

        # Use explicit timestamps anchored at midday on two distinct
        # calendar dates so the test is immune to wall-clock-relative
        # date-bucket flips (e.g. hours_ago=25 vs 26 can span midnight
        # depending on what time the test runs).
        now = datetime.now(timezone.utc)
        day1 = (now - timedelta(days=1)).replace(hour=12, minute=0, second=0, microsecond=0)
        day2 = (now - timedelta(days=2)).replace(hour=12, minute=0, second=0, microsecond=0)

        def _add_step_at(ts, val):
            r = models.HealthReading(
                profile_id=p.id, logged_by=1, reading_type="steps",
                steps_count=val, value_numeric=val, unit_display="steps",
                status_flag="NORMAL", reading_timestamp=ts,
            )
            db.add(r); db.flush()

        # Day 1 — two cumulative readings, max should win:
        _add_step_at(day1.replace(hour=6),  3500)   # morning
        _add_step_at(day1.replace(hour=18), 8000)   # evening (daily final)
        # Day 2 — two cumulative readings, max should win:
        _add_step_at(day2.replace(hour=8),  5000)
        _add_step_at(day2.replace(hour=20), 6500)   # daily final
        # Expected: 8000 + 6500 = 14500.
        # Buggy SUM gives 3500+8000+5000+6500 = 23000.

        last_7d = datetime.now(timezone.utc) - timedelta(days=7)
        summary = build_doctor_summary(db, doctor.id, last_7d)

        assert "steps" in summary["patients"][0]["metrics"]
        total = summary["patients"][0]["metrics"]["steps"]["total"]
        assert total == 14500, (
            f"Expected per-day MAX aggregation = 14500 (8000 + 6500), "
            f"got {total}. A value of 23000 means the buggy SUM-of-all-"
            f"readings logic is still in place — same bug PR 267 fixed "
            f"on the patient dashboard."
        )
