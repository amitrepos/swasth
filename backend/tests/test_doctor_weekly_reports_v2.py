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

            # Verify message snapshot contains critical emoji
            log = db.query(models.WhatsAppMessageLog).filter_by(user_id=doctor.id).first()
            assert log is not None, (
                "WhatsAppMessageLog row missing — send_doctor_weekly_reports "
                "skipped this doctor. Check DoctorProfile setup and "
                "settings.TWILIO_DOCTOR_REPORT_CONTENT_SID mock."
            )
            assert "🚨 CRITICAL: Hyper Patient" in log.message_snapshot

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
