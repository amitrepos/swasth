---
name: security-audit
description: "OWASP Top 10 security scan on changed or specified files"
model: opus
---

# Security Audit

Perform a thorough security review on the changed or specified files.

## Scan Checklist (OWASP Top 10 + Health-Tech)

### A01: Broken Access Control
- [ ] All endpoints use `Depends(get_current_user)`
- [ ] Profile access checks (owner/editor/viewer) enforced
- [ ] No direct object references without authorization check
- [ ] No path traversal vulnerabilities

### A02: Cryptographic Failures
- [ ] Health data encrypted with AES-256-GCM
- [ ] No secrets in code (API keys, passwords, tokens)
- [ ] JWT tokens have reasonable expiry
- [ ] Passwords hashed with bcrypt (not MD5/SHA1)

### A03: Injection
- [ ] SQL injection: all queries use parameterized statements (SQLAlchemy ORM)
- [ ] XSS: all user input escaped in templates/responses
- [ ] Command injection: no `os.system()` or `subprocess` with user input
- [ ] LDAP/NoSQL injection: N/A for this project

### A04: Insecure Design
- [ ] Rate limiting on auth endpoints
- [ ] Account lockout after failed attempts
- [ ] No sensitive data in error messages
- [ ] Health data not logged in plaintext

### A05: Security Misconfiguration
- [ ] CORS properly configured (not `allow_origins=["*"]` in production)
- [ ] Debug mode off in production
- [ ] Default credentials removed
- [ ] `.env` file gitignored

### A06: Vulnerable Components
- [ ] Check for known CVEs in dependencies
- [ ] No outdated packages with security patches available

### A07: Authentication Failures
- [ ] Password complexity requirements enforced
- [ ] JWT secret is strong and not hardcoded
- [ ] Token refresh mechanism works correctly
- [ ] Logout invalidates tokens

### A08: Data Integrity Failures
- [ ] Input validation on all API boundaries
- [ ] Health readings validated (glucose: 20-600, BP: 40-300)
- [ ] File uploads validated (type, size)

### A09: Logging Failures
- [ ] Security events logged (login attempts, access violations)
- [ ] No sensitive data in logs (passwords, health data, tokens)
- [ ] AI insight calls logged to audit table

### A10: SSRF
- [ ] No user-controlled URLs in server-side requests
- [ ] External API calls use allowlists

### Health-Tech Specific
- [ ] DPDPA 2023 compliance: consent before data collection
- [ ] Health data access audit trail exists
- [ ] Data encryption at rest and in transit
- [ ] Right to deletion supported

## Instructions
1. Run `git diff --name-only` to identify changed files (or use files specified by user)
2. Read each changed file completely
3. Check every item on the checklist above
4. Report findings as: **CRITICAL** | **HIGH** | **MEDIUM** | **LOW**
5. For each finding: file:line, what's wrong, how to fix it
6. End with: PASS (no critical/high), CONDITIONAL PASS (medium only), or FAIL

$ARGUMENTS
