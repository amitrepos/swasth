import os
from slowapi import Limiter
from slowapi.util import get_remote_address

# Shared rate limiter instance. 
# Reused across main.py and individual route modules to ensure consistent
# exception handling (preventing 500s on limit hits) and global state.
_rate_limit_enabled = os.getenv("TESTING", "").lower() != "true"
limiter = Limiter(key_func=get_remote_address, enabled=_rate_limit_enabled)
