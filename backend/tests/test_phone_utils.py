import pytest
from utils.phone import normalize_phone

def test_normalize_phone_basic_10_digit():
    assert normalize_phone("9876543210") == "+919876543210"

def test_normalize_phone_with_whitespace():
    assert normalize_phone(" 98765 43210 ") == "+919876543210"

def test_normalize_phone_12_digit_with_91():
    assert normalize_phone("919876543210") == "+919876543210"

def test_normalize_phone_already_normalized():
    assert normalize_phone("+919876543210") == "+919876543210"

def test_normalize_phone_with_hyphens():
    assert normalize_phone("91-98765-43210") == "+919876543210"

def test_normalize_phone_country_code_with_hyphens():
    assert normalize_phone("+91-9876543210") == "+919876543210"

def test_normalize_phone_international():
    # Should just ensure it has a +
    assert normalize_phone("14155238886") == "+14155238886"

def test_normalize_phone_invalid():
    assert normalize_phone("invalid") == ""
    assert normalize_phone("") == ""
    assert normalize_phone(None) == ""
    # Too short (9 digits)
    assert normalize_phone("123456789") == ""
    # Too long (16 digits)
    assert normalize_phone("1234567890123456") == ""
    # 10 digits with letters
    assert normalize_phone("98765abc10") == ""
