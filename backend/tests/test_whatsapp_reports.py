import pytest
from unittest.mock import patch, MagicMock, ANY
from datetime import datetime, timedelta
import pytz
from models import User, Profile, HealthReading, ProfileAccess
from report_service import send_daily_reports

# 1. Test Phone Normalization Logic
@patch("report_service.whatsapp_service")
def test_send_daily_reports_phone_normalization(mock_whatsapp, db):
    """Verify that different phone formats are normalized to +91 E.164."""
    user = User(
        email="norm@test.com",
        full_name="Norm Tester",
        password_hash="dummy_hash",
        phone_number="8700151250",  # Raw 10 digits
        timezone="Asia/Kolkata"
    )
    db.add(user)
    db.flush()
    
    mock_whatsapp.send_whatsapp.return_value = (True, "SMxxx", None)
    
    profile = Profile(name="Self")
    db.add(profile)
    db.flush()
    db.add(ProfileAccess(user_id=user.id, profile_id=profile.id, access_level="owner"))
    
    db.add(HealthReading(
        profile_id=profile.id,
        reading_type="glucose",
        glucose_value=120,
        value_numeric=120,
        unit_display="mg/dL",
        reading_timestamp=datetime.now(pytz.utc)
    ))
    db.commit()
    
    # Execute passing the test DB session
    send_daily_reports(db=db)
    
    # Assert: Twilio should receive +918700151250
    mock_whatsapp.send_whatsapp.assert_called_with("+918700151250", ANY)

# 2. Test Multi-Profile Aggregation
@patch("report_service.whatsapp_service")
def test_send_daily_reports_multi_profile(mock_whatsapp, db):
    """Verify that multiple profiles owned by the user are combined into one message."""
    user = User(
        email="multi@test.com", 
        full_name="Multi Owner", 
        phone_number="+919999999999",
        password_hash="dummy_hash"
    )
    db.add(user)
    db.flush()
    
    mock_whatsapp.send_whatsapp.return_value = (True, "SMxxx", None)
    
    p1 = Profile(name="Deepak")
    p2 = Profile(name="Papa")
    db.add_all([p1, p2])
    db.flush()
    
    db.add(ProfileAccess(user_id=user.id, profile_id=p1.id, access_level="owner"))
    db.add(ProfileAccess(user_id=user.id, profile_id=p2.id, access_level="owner"))
    
    now = datetime.now(pytz.utc)
    db.add(HealthReading(
        profile_id=p1.id, reading_type="glucose", glucose_value=110, value_numeric=110, unit_display="mg/dL", reading_timestamp=now
    ))
    db.add(HealthReading(
        profile_id=p2.id, reading_type="glucose", glucose_value=180, value_numeric=180, unit_display="mg/dL", reading_timestamp=now
    ))
    db.commit()
    
    send_daily_reports(db=db)
    
    args, kwargs = mock_whatsapp.send_whatsapp.call_args
    message = args[1]
    assert "Deepak" in message
    assert "Papa" in message
    assert "110 mg/dL" in message
    assert "180 mg/dL" in message
    assert "Normal ✅" in message
    assert "High ⚠️" in message

# 3. Test Shared Access Scoping
@patch("report_service.whatsapp_service")
def test_send_daily_reports_excludes_viewed_profiles(mock_whatsapp, db):
    """Verify that reports only include profiles where user is 'owner', not just 'viewer'."""
    user_a = User(email="owner@test.com", phone_number="+911111111111", password_hash="hash_a", full_name="Owner A")
    user_b = User(email="viewer@test.com", phone_number="+912222222222", password_hash="hash_b", full_name="Viewer B")
    db.add_all([user_a, user_b])
    db.flush()
    
    mock_whatsapp.send_whatsapp.return_value = (True, "SMxxx", None)
    
    shared_profile = Profile(name="Shared Profile")
    db.add(shared_profile)
    db.flush()
    
    db.add(ProfileAccess(user_id=user_a.id, profile_id=shared_profile.id, access_level="owner"))
    db.add(ProfileAccess(user_id=user_b.id, profile_id=shared_profile.id, access_level="viewer"))
    
    db.add(HealthReading(
        profile_id=shared_profile.id, reading_type="glucose", glucose_value=120, value_numeric=120, unit_display="mg/dL", reading_timestamp=datetime.now(pytz.utc)
    ))
    db.commit()
    
    send_daily_reports(db=db)
    
    calls = mock_whatsapp.send_whatsapp.call_args_list
    recipient_numbers = [call[0][0] for call in calls]
    
    assert "+911111111111" in recipient_numbers
    assert "+912222222222" not in recipient_numbers

# 4. Test No Readings
@patch("report_service.whatsapp_service")
def test_send_daily_reports_no_recent_data(mock_whatsapp, db):
    """Verify that no WhatsApp is sent if there are no readings in the last 24h."""
    user = User(email="empty@test.com", phone_number="+910000000000", password_hash="dummy_hash", full_name="Empty User")
    db.add(user)
    db.flush()
    profile = Profile(name="Legacy Profile")
    db.add(profile)
    db.flush()
    db.add(ProfileAccess(user_id=user.id, profile_id=profile.id, access_level="owner"))
    
    db.add(HealthReading(
        profile_id=profile.id, reading_type="glucose", glucose_value=120, value_numeric=120, unit_display="mg/dL", 
        reading_timestamp=datetime.now(pytz.utc) - timedelta(days=2)
    ))
    db.commit()
    
    send_daily_reports(db=db)
    mock_whatsapp.send_whatsapp.assert_not_called()
