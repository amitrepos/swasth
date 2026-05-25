import pytest
from fastapi import HTTPException, Request
from backend.dependencies import verify_india_location
import unittest.mock as mock

class MockGeoIPResponse:
    def __init__(self, iso_code):
        self.country = mock.Mock()
        self.country.iso_code = iso_code

def test_verify_india_location_missing_db():
    # When DB is missing, it should allow the request (fail-open for dev)
    request = mock.Mock(spec=Request)
    request.headers = {}
    request.client = mock.Mock()
    request.client.host = "8.8.8.8"
    
    with mock.patch("backend.dependencies._get_geoip_reader", return_value=None):
        # Should not raise any exception
        verify_india_location(request)

def test_verify_india_location_allowed_ip():
    request = mock.Mock(spec=Request)
    request.headers = {}
    request.client = mock.Mock()
    request.client.host = "14.139.1.1" # Indian IP
    
    mock_reader = mock.Mock()
    mock_reader.country.return_value = MockGeoIPResponse("IN")
    
    with mock.patch("backend.dependencies._get_geoip_reader", return_value=mock_reader):
        # Should not raise
        verify_india_location(request)

def test_verify_india_location_blocked_ip():
    request = mock.Mock(spec=Request)
    request.headers = {}
    request.client = mock.Mock()
    request.client.host = "8.8.8.8" # US IP
    
    mock_reader = mock.Mock()
    mock_reader.country.return_value = MockGeoIPResponse("US")
    
    with mock.patch("backend.dependencies._get_geoip_reader", return_value=mock_reader):
        with pytest.raises(HTTPException) as exc:
            verify_india_location(request)
        assert exc.value.status_code == 403
        assert exc.value.detail == "REGION_RESTRICTED"

def test_verify_india_location_x_forwarded_for():
    request = mock.Mock(spec=Request)
    # First IP is the real client
    request.headers = {"X-Forwarded-For": "14.139.1.1, 10.0.0.1"}
    request.client = mock.Mock()
    request.client.host = "10.0.0.1" # Proxy IP
    
    mock_reader = mock.Mock()
    mock_reader.country.return_value = MockGeoIPResponse("IN")
    
    with mock.patch("backend.dependencies._get_geoip_reader", return_value=mock_reader):
        # Should check 14.139.1.1 and allow
        verify_india_location(request)
        mock_reader.country.assert_called_once_with("14.139.1.1")

def test_verify_india_location_bypass():
    request = mock.Mock(spec=Request)
    request.headers = {}
    request.client = mock.Mock()
    request.client.host = "8.8.8.8"
    
    with mock.patch.dict("os.environ", {"BYPASS_GEO_RESTRICTION": "true"}):
        # Should bypass check even if IP is foreign
        verify_india_location(request)
