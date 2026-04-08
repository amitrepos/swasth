# Blueprint: Food Photo Classification (Carb Level Detection)

## Objective
Patient photographs their meal → Gemini classifies carb level → app shows health tip → stores for glucose correlation over time.

## Stage 3 Validation — Dr. Rajesh Feedback (2026-04-08)

**Overall score: 6.2/10. Approved with Must Fix items below.**

### Must Fix (incorporated into steps below)
1. **Quick Select is DEFAULT entry point**, Photo is secondary. Patients won't photograph food.
2. **3 buttons for patients** (Heavy/Light/Sweets), not 5. Keep 5 categories internally for AI.
3. **Soften ALL tip language** — "may help", "consider", never "do this". Add disclaimer.
4. **Photo privacy** — shared-profile viewers see meal logs (category+time) but NOT photos.
5. **Add disclaimer** — "Tips are for general wellness, not medical advice."

### Should Fix
6. **Reduce Gemini timeout to 3-5 seconds** (Bihar patients assume it's broken after 3s).
7. **Doctor dashboard** — add meal-glucose correlation tab to admin panel.

### Noted (defer to post-pilot)
8. **Medication interaction** — correlation may be misleading if patient takes metformin. Document as limitation.

## Architecture Fit
- Backend: new `routes_meals.py` (mirrors `routes_health.py` pattern)
- Model: `MealLog` table in `models.py` ✅ DONE (Step 1 complete)
- AI: reuse existing `ai_service.generate_vision_insight()` with food-specific prompt
- Frontend: new screens in `lib/screens/` (mirrors photo_scan_screen pattern)
- Spec says Firestore → we use PostgreSQL (adapted)
- Quick Select is PRIMARY path, Photo is secondary (Rajesh feedback)

## Steps

### Step 1: Backend — MealLog model + schemas ✅ DONE
- `MealLog` class added to `backend/models.py`
- `MealLogCreate`, `MealLogResponse`, `FoodClassificationResponse` added to `backend/schemas.py`
- 11 tests in `backend/tests/test_meals.py` — all passing
- 355 total backend tests pass

### Step 2: Backend — Meal API routes (CRUD + parse-image)
**Context brief:** Create `backend/routes_meals.py` mirroring `routes_health.py` structure. Register in `main.py` with `prefix="/api"`. All endpoints require auth via `Depends(get_current_user)`. Rate limit 20/min. The `/meals/parse-image` endpoint reuses `ai_service.generate_vision_insight()` with a food-specific prompt. NEVER return food names — only carb category. Gemini timeout must be 5 seconds max (Rajesh: Bihar users).
**Files:**
- Create: `backend/routes_meals.py`
- Modify: `backend/main.py` — import and register router
**Changes:**
- `POST /meals` — save a meal log (from photo result or quick select)
- `GET /meals` — list meals for a profile (with date range filter)
- `GET /meals/today` — today's meals for dashboard summary
- `POST /meals/parse-image` — accept food photo, call Gemini Vision with carb classification prompt, return `FoodClassificationResponse`. **Timeout: 5 seconds.**
- `DELETE /meals/{id}` — delete a meal log
- Photo saved to `uploads/meals/{profile_id}/{meal_id}.jpg`
- **Photo access control:** only profile owners can view photos. Viewers see logs only (Rajesh #4).
- **Prompt must include:** suggestive language only — "may help", "consider" (Rajesh #3)
- **Prompt must include:** disclaimer text for tip_en and tip_hi (Rajesh #5)
**Tests:**
- Test: parse-image endpoint with mock Gemini response
- Test: CRUD operations (create, list, get today, delete)
- Test: auth required on all endpoints
- Test: profile access control (can't access other user's meals)
- Test: photo_path NOT returned for viewer-level access
- Test: tip language contains "may" or "consider" (no commanding language)
**Done when:** All endpoints work, tests pass, registered in main.py
**Blocked by:** Step 1 ✅

### Step 3: Backend — Food AI insight rules
**Context brief:** Add food-specific rules to the AI insight engine. Rules are in-app only — no WhatsApp. ALL tip language must be suggestive (Rajesh #3). Add correlation disclaimer (Rajesh #8).
**Files:**
- Modify: `backend/routes_health.py` — add food rules to ai-insight endpoint
- Modify: `backend/health_utils.py` — add meal correlation helpers
**Changes:**
- Rule: high_carb_dinner_warning — suggestive: "A short walk after meals may help keep sugar stable."
- Rule: carb_glucose_correlation (7+ days) — with disclaimer: "These patterns are for awareness. Always follow your doctor's diet advice."
- Rule: sweet_alert — suggestive: "You had sweets today. Consider checking sugar in 2 hours."
- Rule: good_food_choice — positive reinforcement (no changes needed)
- Rule: weekly_food_pattern — weekly summary with disclaimer
**Tests:**
- Test each rule with mock meal + reading data
- Test correlation calculation with 7+ days of data
- Test ALL tip strings contain suggestive language (no "must", "should", "do this")
- Test correlation disclaimer is present
**Done when:** AI insight endpoint includes food-aware tips with safe language
**Blocked by:** Step 1 ✅

### Step 4: Frontend — Food photo capture screen
**Context brief:** Create photo capture screen as SECONDARY option (not primary — Rajesh #1). Gemini timeout 5 seconds (Rajesh #6). On failure/timeout, fall back to quick select INSTANTLY — no waiting. All strings via AppLocalizations, all colors via AppColors. Tip display must include disclaimer.
**Files:**
- Create: `lib/screens/food_photo_screen.dart`
- Create: `lib/screens/meal_result_screen.dart`
- Modify: `lib/l10n/app_en.arb` — add food-related strings
- Modify: `lib/l10n/app_hi.arb` — add Hindi translations
**Changes:**
- Camera capture with overlay hint: "Point at your plate" (Hindi/English)
- Loading state — max 5 seconds, then auto-fallback to quick select
- meal_result_screen: carb badge (color-coded), tip in user's language
- **Disclaimer at bottom:** "For general wellness, not medical advice"
- Meal type auto-detected by time, editable
- "Not correct? Change" → opens quick select for override
- NEVER show food name — only carb level badge
**Tests:**
- Widget test: food_photo_screen renders camera overlay
- Widget test: meal_result_screen renders badge + tip + disclaimer
- Widget test: correction dropdown works
**Done when:** Photo capture → Gemini → result screen → save works end-to-end
**Blocked by:** Step 2

### Step 5: Frontend — Quick select screen + meal log service
**Context brief:** Quick Select is the PRIMARY entry point (Rajesh #1). Show 3 LARGE buttons to patient (Rajesh #2), not 5. Internally map to 5 categories. Hindi/English labels. Two taps max to log a meal.
**Files:**
- Create: `lib/screens/quick_select_screen.dart`
- Create: `lib/services/meal_service.dart`
- Create: `lib/models/meal_log.dart`
**Changes:**
- **3 large buttons (patient-facing):**
  - 🍚 "Heavy — Rice / Roti" → maps to HIGH_CARB internally
  - 🥗 "Light — Sabzi / Dal" → maps to LOW_CARB internally
  - 🍬 "Sweets / Meetha" → maps to SWEETS internally
- Small link below: "More options" → expands to show HIGH_PROTEIN and MODERATE_CARB
- Tap → auto-detect meal type by time → save immediately (2 taps total)
- meal_service.dart: parseImageWithFood(), saveMeal(), getMeals(), getTodayMeals()
- meal_log.dart: MealLog data class matching backend schema
**Tests:**
- Widget test: 3 primary buttons render with Hindi/English
- Widget test: "More options" expands to show 2 additional buttons
- Widget test: tap saves with correct internal category
- Unit test: meal type auto-detection by time of day
**Done when:** Quick select saves meals in 2 taps, meal service communicates with backend
**Blocked by:** Step 2

### Step 6: Frontend — Dashboard integration + meal entry point
**Context brief:** Add "Log Meal" entry to dashboard. Quick Select is the default (Rajesh #1). Photo is a secondary option. Meal summary card shows today's meals with carb badges. Photo thumbnails visible ONLY to profile owners (Rajesh #4).
**Files:**
- Modify: `lib/screens/home_screen.dart` — add meal summary card + log meal button
- Modify: `lib/screens/dashboard_screen.dart` — add meal entry point
- Create: `lib/widgets/meal_summary_card.dart`
**Changes:**
- Entry point opens Quick Select by default, with "Want more accuracy? Take a photo" link
- Meal summary card: today's meals with color badges (🔴🟢🟡), no food names
- "Not logged yet → Log now" prompts for missing meals
- Photo thumbnails: show only if current user is profile owner
- Profile selector for "log for someone else" — reuse existing pattern
**Tests:**
- Widget test: meal summary card renders today's meals
- Widget test: empty state shows "Log your meals" prompt
- Widget test: entry point shows Quick Select as primary
**Done when:** Meal logging accessible from dashboard, today's summary visible
**Blocked by:** Step 4, Step 5

## Dependency Graph
```
Step 1 (model + schemas) ✅ DONE
  ├── Step 2 (API routes) ──── Step 4 (photo screen) ──┐
  ├── Step 3 (AI rules)                                  ├── Step 6 (dashboard)
  └──────────────────────── Step 5 (quick select) ──────┘
```

## Parallel Opportunities
- Steps 2 and 3 can run in parallel (different files, both depend only on Step 1)
- Steps 4 and 5 can run in parallel (different screens, both depend on Step 2)

## Risks
- **Gemini food classification accuracy:** Mitigation — Quick Select is primary path. Photo is secondary.
- **Commanding tip language (NMC liability):** Mitigation — all tips use "may help", "consider". Disclaimer on every screen. (Rajesh #3, #5)
- **Photo privacy:** Mitigation — viewers see logs, not photos. Only owners see photos. (Rajesh #4)
- **Bihar connectivity:** Mitigation — 5s Gemini timeout, instant fallback to Quick Select. (Rajesh #6)
- **Medication confound:** Mitigation — documented as limitation. Correlation disclaimer added. (Rajesh #8)
- **iOS camera bug:** Mitigation — existing photo_scan_screen handles this. Reuse same workarounds.

## Estimated Steps: 6 | Critical Path: Steps 1 → 2 → 5 → 6
## Step 1: ✅ Complete | Next: Step 2
