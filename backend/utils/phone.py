import re

def normalize_phone(phone: str | None) -> str:
    """Normalize phone to E.164 (+91...).
    
    Rules:
    - Remove all non-digits.
    - If 10 digits, prepend +91.
    - If 12 digits starting with 91, prepend +.
    - Otherwise, ensure it has a leading +.
    - Return empty string if input is None or invalid.
    
    Examples:
        " 98765 43210 " -> +919876543210
        "919876543210" -> +919876543210
        "+919876543210" -> +919876543210
        "invalid" -> ""
    """
    if not phone:
        return ""
    
    # Strip whitespace and capture leading + if present
    phone = phone.strip()
    has_leading_plus = phone.startswith("+")
    
    # Remove all non-digits
    digits = re.sub(r"[^\d]", "", phone)
    if not digits:
        return ""

    if len(digits) == 10:
        return f"+91{digits}"
    
    if len(digits) == 12 and digits.startswith("91"):
        return f"+{digits}"
    
    # If it already had a +, or we don't know what it is, ensure it has a +
    # This covers international numbers or already-normalized numbers.
    return f"+{digits}"
