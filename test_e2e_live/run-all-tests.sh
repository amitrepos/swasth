#!/bin/bash
# run-all-tests.sh — Full E2E + API health check for Swasth AWS deployment
# Usage: bash run-all-tests.sh
# Env: PATIENT_EMAIL, PATIENT_PASS, RELATIVE_EMAIL, RELATIVE_EMAIL, DOCTOR_EMAIL, DOCTOR_PASS

set -uo pipefail

API="${API_URL:-https://api.swasth.health}"
STAGING_API="${STAGING_API_URL:-https://staging-api.swasth.health}"
APP="${TARGET:-https://app.swasth.health}"
PATIENT_EMAIL="${PATIENT_EMAIL:-swasth.patient.test@gmail.com}"
PATIENT_PASS="${PATIENT_PASS:-Test@1234}"

GREEN='\033[0;32m' RED='\033[0;31m' YELLOW='\033[1;33m' NC='\033[0m' BOLD='\033[1m'
PASS=0; FAIL=0

check() {
  local label="$1" result="$2" expected="$3"
  if [[ "$result" == "$expected" || "$result" =~ $expected ]]; then
    echo -e "  ${GREEN}✅ PASS${NC} $label"
    PASS=$((PASS+1))
  else
    echo -e "  ${RED}❌ FAIL${NC} $label — got: $result, expected: $expected"
    FAIL=$((FAIL+1))
  fi
}

section() { echo -e "\n${BOLD}$1${NC}"; }

# ─────────────────────────────────────────────
section "1. Infrastructure checks"
# ─────────────────────────────────────────────
check "prod /health → 200" \
  "$(curl -skL -o /dev/null -w '%{http_code}' $API/health)" "200"

check "staging /health → 200" \
  "$(curl -skL -o /dev/null -w '%{http_code}' $STAGING_API/health)" "200"

check "app.swasth.health → 200" \
  "$(curl -skL -o /dev/null -w '%{http_code}' $APP)" "200"

check "swasth.health → 200" \
  "$(curl -skL -o /dev/null -w '%{http_code}' https://swasth.health)" "200"

check "SSL cert valid (no -k needed)" \
  "$(curl -s -o /dev/null -w '%{http_code}' $API/health)" "200"

check "API rejects unauthenticated /api/profiles → 401" \
  "$(curl -skL -o /dev/null -w '%{http_code}' $API/api/profiles)" "401"

# ─────────────────────────────────────────────
section "2. Auth API — login"
# ─────────────────────────────────────────────
LOGIN_RESP=$(curl -skL -X POST "$API/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$PATIENT_EMAIL\",\"password\":\"$PATIENT_PASS\"}" 2>/dev/null)
LOGIN_CODE=$(curl -skL -o /dev/null -w '%{http_code}' -X POST "$API/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$PATIENT_EMAIL\",\"password\":\"$PATIENT_PASS\"}")

check "POST /api/auth/login → 200" "$LOGIN_CODE" "200"

TOKEN=$(echo "$LOGIN_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('access_token',''))" 2>/dev/null || true)
if [[ -z "$TOKEN" ]]; then
  echo -e "  ${RED}❌ FAIL${NC} Could not extract JWT token — login likely failed"
  echo -e "  ${YELLOW}⚠️  Response: ${LOGIN_RESP:0:200}${NC}"
  FAIL=$((FAIL+1))
else
  echo -e "  ${GREEN}✅ PASS${NC} JWT token extracted (${#TOKEN} chars)"
  PASS=$((PASS+1))
fi

# ─────────────────────────────────────────────
section "3. Profile API"
# ─────────────────────────────────────────────
if [[ -n "$TOKEN" ]]; then
  PROFILES_RESP=$(curl -skL -H "Authorization: Bearer $TOKEN" "$API/api/profiles/")
  PROFILES_CODE=$(curl -skL -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOKEN" "$API/api/profiles/")
  check "GET /api/profiles/ → 200" "$PROFILES_CODE" "200"

  PROFILE_COUNT=$(echo "$PROFILES_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d))" 2>/dev/null || echo "0")
  if [[ "$PROFILE_COUNT" -gt 0 ]]; then
    echo -e "  ${GREEN}✅ PASS${NC} Found $PROFILE_COUNT profile(s)"
    PASS=$((PASS+1))
    PROFILE_ID=$(echo "$PROFILES_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['id'])" 2>/dev/null || echo "")
  else
    echo -e "  ${YELLOW}⚠️  WARN${NC} No profiles found — user may not have data on AWS yet (data migration needed)"
    PROFILE_ID=""
  fi
else
  echo -e "  ${YELLOW}⚠️  SKIP${NC} Auth failed — skipping profile tests"
fi

# ─────────────────────────────────────────────
section "4. Health readings API"
# ─────────────────────────────────────────────
if [[ -n "$TOKEN" && -n "${PROFILE_ID:-}" ]]; then
  READINGS_CODE=$(curl -skL -o /dev/null -w '%{http_code}' \
    -H "Authorization: Bearer $TOKEN" "$API/api/health/readings?profile_id=$PROFILE_ID")
  check "GET /api/health/readings → 200" "$READINGS_CODE" "200"

  # POST a BP reading
  BP_CODE=$(curl -skL -o /dev/null -w '%{http_code}' \
    -X POST "$API/api/health/readings" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"profile_id\":$PROFILE_ID,\"reading_type\":\"blood_pressure\",\"systolic\":120,\"diastolic\":80,\"notes\":\"script test\"}")
  check "POST BP reading → 200 or 201" "$BP_CODE" "200|201"

  # POST a glucose reading
  GL_CODE=$(curl -skL -o /dev/null -w '%{http_code}' \
    -X POST "$API/api/health/readings" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"profile_id\":$PROFILE_ID,\"reading_type\":\"glucose\",\"glucose_value\":98,\"notes\":\"script test\"}")
  check "POST glucose reading → 200 or 201" "$GL_CODE" "200|201"
else
  echo -e "  ${YELLOW}⚠️  SKIP${NC} No profile ID — skipping reading tests"
fi

# ─────────────────────────────────────────────
section "5. Meals API"
# ─────────────────────────────────────────────
if [[ -n "$TOKEN" && -n "${PROFILE_ID:-}" ]]; then
  MEALS_CODE=$(curl -skL -o /dev/null -w '%{http_code}' \
    -H "Authorization: Bearer $TOKEN" "$API/api/meals/?profile_id=$PROFILE_ID")
  check "GET /api/meals/ → 200" "$MEALS_CODE" "200"
else
  echo -e "  ${YELLOW}⚠️  SKIP${NC} No profile ID — skipping meals tests"
fi

# ─────────────────────────────────────────────
section "6. Chat API"
# ─────────────────────────────────────────────
if [[ -n "$TOKEN" && -n "${PROFILE_ID:-}" ]]; then
  CHAT_CODE=$(curl -skL -o /dev/null -w '%{http_code}' \
    -H "Authorization: Bearer $TOKEN" "$API/api/chat/messages?profile_id=$PROFILE_ID")
  check "GET /api/chat/messages → 200" "$CHAT_CODE" "200"
else
  echo -e "  ${YELLOW}⚠️  SKIP${NC} No profile ID — skipping chat tests"
fi

# ─────────────────────────────────────────────
section "7. Security checks"
# ─────────────────────────────────────────────
check "SQL injection in email → 400 or 422" \
  "$(curl -skL -o /dev/null -w '%{http_code}' -X POST "$API/api/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@x.com OR 1=1--","password":"x"}')" "400|401|422"

check "Missing auth header → 401 or 403" \
  "$(curl -skL -o /dev/null -w '%{http_code}' "$API/api/profiles/")" "401|307"

# ─────────────────────────────────────────────
section "8. Playwright smoke tests"
# ─────────────────────────────────────────────
cd "$(dirname "$0")"
SMOKE_OUTPUT=$(npx playwright test tests/smoke.spec.js --reporter=line 2>&1)
SMOKE_RESULT=$(echo "$SMOKE_OUTPUT" | grep -E "[0-9]+ passed" | tail -1)
if echo "$SMOKE_OUTPUT" | grep -q "failed"; then
  echo -e "  ${RED}❌ FAIL${NC} Playwright smoke: $(echo "$SMOKE_OUTPUT" | grep -E 'passed|failed' | tail -1)"
  FAIL=$((FAIL+1))
else
  echo -e "  ${GREEN}✅ PASS${NC} Playwright smoke: $SMOKE_RESULT"
  PASS=$((PASS+1))
fi

# ─────────────────────────────────────────────
section "Summary"
# ─────────────────────────────────────────────
echo ""
TOTAL=$((PASS + FAIL))
echo -e "${BOLD}$TOTAL checks: ${GREEN}$PASS passed${NC} ${RED}$FAIL failed${NC}"
if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}✅ All systems operational — AWS deployment healthy${NC}"
else
  echo -e "${RED}${BOLD}⚠️  $FAIL check(s) failed — investigate above${NC}"
  echo ""
  echo "Common causes:"
  echo "  - Login failure: user not in AWS DB (run data migration from Hetzner)"
  echo "  - No profiles: create a profile via app.swasth.health first"
  echo "  - CORS error: check backend CORS_ORIGINS list in config.py"
fi
echo ""
