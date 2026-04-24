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

def test_normalize_phone_whitespace_only():
    assert normalize_phone("   ") == ""
    assert normalize_phone("\t\n") == ""

def test_normalize_phone_all_zeros():
    # 10 zeros pass the length check and get a +91 prefix — semantically invalid
    # but normalize_phone is a format function, not a number registry validator.
    assert normalize_phone("0000000000") == "+910000000000"

def test_normalize_phone_11_digit_non_india():
    # 11 digits that don't start with 91 are treated as generic international
    # (e.g., a US number: 1 + 10 digits). No +91 prepended.
    assert normalize_phone("12345678901") == "+12345678901"

def test_normalize_phone_13_14_15_digits():
    # 13-, 14-, 15-digit numbers are within the E.164 max — passed through with +
    assert normalize_phone("4915123456789") == "+4915123456789"   # German mobile (13 digits)
    assert normalize_phone("85212345678901") == "+85212345678901"  # 14 digits
    assert normalize_phone("999999999999999") == "+999999999999999"  # 15 digits (max)
