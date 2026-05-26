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
        assert p0["name"] == "John's Profile"
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

    @patch("report_service.whatsapp_service")
    @patch("report_service.settings")
    def test_send_doctor_weekly_reports(self, mock_settings, mock_whatsapp, db):
        mock_settings.TWILIO_DOCTOR_REPORT_CONTENT_SID = "HX123"
        mock_whatsapp.send_whatsapp_template.return_value = (True, "SM123", None)
        
        doctor = models.User(full_name="Dr. Smith", phone_number="+919999999999", role=models.UserRole.doctor, password_hash="...")
        db.add(doctor)
        db.flush()
        
        doc_profile = models.DoctorProfile(user_id=doctor.id, nmc_number="12345", doctor_code="DR123", specialty="Gen")
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
