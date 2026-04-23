import re

def normalize_phone(phone: str | None) -> str:
    """Normalize phone to E.164 (+91...).
    
    Rules:
    - Return empty string if input is None or empty.
    - Remove all non-digits.
    - If resulting digits length < 10 or > 15, return empty string.
    - If 10 digits, prepend +91.
    - If 12 digits starting with 91, prepend +.
    - Otherwise, ensure it has a leading +.
    
    Examples:
        " 98765 43210 " -> +919876543210
        "919876543210" -> +919876543210
        "+919876543210" -> +919876543210
        "123" -> ""
        "invalid" -> ""
    """
    if not phone:
        return ""
    
    # Strip whitespace
    phone = phone.strip()
    
    # Remove all non-digits
    digits = re.sub(r"[^\d]", "", phone)
    
    # C4 & m1: Reject with "" when length not in [10..15]
    if not (10 <= len(digits) <= 15):
        return ""

    if len(digits) == 10:
        return f"+91{digits}"
    
    if len(digits) == 12 and digits.startswith("91"):
        return f"+{digits}"
    
    # If we don't know what it is but it's 10-15 digits, ensure it has a +
    # This covers international numbers or already-normalized numbers.
    return f"+{digits}"
