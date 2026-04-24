"""Tests for manual report generation via send_weekly_reports and trigger_single_profile_report."""
import sys
import os
from unittest.mock import patch

# Ensure backend path is in sys.path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from datetime import datetime, timedelta, timezone
from sqlalchemy.orm import Session
import models
from models import User, Profile, ProfileAccess, ReportTriggerType, ReportGenerationLog, WhatsAppMessageLog, HealthReading
from report_service import send_weekly_reports, trigger_single_profile_report
from auth import get_password_hash


class TestManualReportGeneration:
    """Test manual report triggering for users."""

    @patch("report_service.settings")
    @patch("report_service.whatsapp_service")
    @patch("report_service.ai_report_service")
    def test_trigger_report_for_user_with_data(self, mock_ai, mock_whatsapp, mock_settings, db, test_user):
        """Test that a report can be triggered for a user with health data."""
        mock_settings.TWILIO_REPORT_CONTENT_SID = "HXmock"
        mock_whatsapp.send_whatsapp_template.return_value = (True, "SMxxx", None)
        mock_ai.get_weekly_ai_insight.return_value = "Test AI Insight"
        
        # Get the user's profile
        access = db.query(ProfileAccess).filter_by(
            user_id=test_user.id, access_level="owner"
        ).first()
        
        # Add some health data
        reading = HealthReading(
            profile_id=access.profile_id,
            logged_by=test_user.id,
            reading_type="glucose",
            glucose_value=120,
            value_numeric=120,
            unit_display="mg/dL",
            status_flag="NORMAL",
            reading_timestamp=datetime.now(timezone.utc) - timedelta(days=1),
        )
        db.add(reading)
        db.flush()

        # Trigger the report for this specific user
        send_weekly_reports(db=db, trigger_type=ReportTriggerType.MANUAL, user_id=test_user.id)

        # Verify generation log was created
        gen_log = db.query(ReportGenerationLog).filter_by(
            user_id=test_user.id
        ).order_by(ReportGenerationLog.generated_at.desc()).first()
        
        assert gen_log is not None, "ReportGenerationLog should be created"

    @patch("report_service.settings")
    @patch("report_service.whatsapp_service")
    @patch("report_service.ai_report_service")
    def test_trigger_report_for_user_without_data(self, mock_ai, mock_whatsapp, mock_settings, db, test_user):
        """Test report triggering for a user with no health data."""
        mock_settings.TWILIO_REPORT_CONTENT_SID = "HXmock"
        
        # Trigger the report without any health data
        send_weekly_reports(db=db, trigger_type=ReportTriggerType.MANUAL, user_id=test_user.id)

        # The report may not be sent if there's no data, but the function should complete without error
        # No assertion needed - just verifying it doesn't crash

    def test_trigger_single_profile_report_success(self, db, test_user):
        """Test trigger_single_profile_report for a profile with data."""
        # Get the user's profile
        access = db.query(ProfileAccess).filter_by(
            user_id=test_user.id, access_level="owner"
        ).first()
        profile = db.query(Profile).filter_by(id=access.profile_id).first()
        
        # Add some health data
        reading = HealthReading(
            profile_id=profile.id,
            logged_by=test_user.id,
            reading_type="glucose",
            glucose_value=120,
            value_numeric=120,
            unit_display="mg/dL",
            status_flag="NORMAL",
            reading_timestamp=datetime.now(timezone.utc) - timedelta(days=1),
        )
        db.add(reading)
        db.flush()

        # Trigger the report for this profile
        result = trigger_single_profile_report(db, profile, trigger_type=ReportTriggerType.MANUAL, owner=test_user)

        # Should return data dict (not None) when there's data
        assert result is not None, "Should return report data for profile with readings"
        assert result.get("status") is not None

    def test_trigger_single_profile_report_no_data(self, db, test_user):
        """Test trigger_single_profile_report for a profile without data."""
        # Get the user's profile
        access = db.query(ProfileAccess).filter_by(
            user_id=test_user.id, access_level="owner"
        ).first()
        profile = db.query(Profile).filter_by(id=access.profile_id).first()

        # Trigger the report without any health data
        result = trigger_single_profile_report(db, profile, trigger_type=ReportTriggerType.MANUAL, owner=test_user)

        # Should return None when there's no data
        assert result is None, "Should return None for profile without readings"

    @patch("report_service.settings")
    @patch("report_service.whatsapp_service")
    @patch("report_service.ai_report_service")
    def test_trigger_report_multiple_times(self, mock_ai, mock_whatsapp, mock_settings, db, test_user):
        """Test that multiple reports can be triggered for the same user."""
        mock_settings.TWILIO_REPORT_CONTENT_SID = "HXmock"
        mock_whatsapp.send_whatsapp_template.return_value = (True, "SMxxx", None)
        mock_ai.get_weekly_ai_insight.return_value = "Test AI Insight"
        
        # Trigger first report
        send_weekly_reports(db=db, trigger_type=ReportTriggerType.MANUAL, user_id=test_user.id)
        
        # Trigger second report
        send_weekly_reports(db=db, trigger_type=ReportTriggerType.MANUAL, user_id=test_user.id)

        # Both should complete without error (function doesn't return count, so just verify no exception)
