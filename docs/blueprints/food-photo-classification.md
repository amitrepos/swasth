# Blueprint: Food Photo Classification (Carb Level Detection)

## Objective
Patient photographs their meal → Gemini classifies carb level → app shows health tip → stores for glucose correlation over time.

## Architecture Fit
- Backend: new `routes_meals.py` (mirrors `routes_health.py` pattern)
- Model: new `MealLog` table in `models.py` (mirrors `HealthReading`)
- AI: reuse existing `ai_service.generate_vision_insight()` with food-specific prompt
- Frontend: new screens in `lib/screens/` (mirrors photo_scan_screen pattern)
- Spec says Firestore → we use PostgreSQL (adapt)
- Spec says `lib/features/meal_logging/` → we follow existing flat `lib/screens/` pattern

## Steps

### Step 1: Backend — MealLog model + schemas + migration
**Context brief:** Add a `meal_logs` table to PostgreSQL. The project uses SQLAlchemy declarative models in `backend/models.py` and Pydantic schemas in `backend/schemas.py`. Follow the `HealthReading` model pattern exactly. No Firestore — we use PostgreSQL. Table auto-creates via `Base.metadata.create_all(bind=engine)` in `main.py`.
**Files:**
- Modify: `backend/models.py` — add `MealLog` class
- Modify: `backend/schemas.py` — add `MealLogCreate`, `MealLogResponse`, `FoodClassificationResponse`
**Changes:**
- `MealLog` model with columns: id, profile_id, logged_by, timestamp, category (HIGH_CARB etc), glucose_impact, tip_en, tip_hi, meal_type, photo_path, input_method (PHOTO_GEMINI/QUICK_SELECT), confidence, user_confirmed, user_corrected_category, created_at
- Pydantic schemas for create/response
- Category and meal_type as string enums in schemas
**Tests:**
- Unit test: MealLog model instantiation
- Unit test: schema validation (valid/invalid categories, boundary values)
**Done when:** `MealLog` table creates on app startup, schemas validate correctly
**Blocks:** Step 2, Step 3

### Step 2: Backend — Meal API routes (CRUD + parse-image)
**Context brief:** Create `backend/routes_meals.py` mirroring `routes_health.py` structure. Register in `main.py` with `prefix="/api"`. All endpoints require auth via `Depends(get_current_user)`. Rate limit 20/min. The `/meals/parse-image` endpoint reuses `ai_service.generate_vision_insight()` with a food-specific prompt. NEVER return food names — only carb category.
**Files:**
- Create: `backend/routes_meals.py`
- Modify: `backend/main.py` — import and register router
**Changes:**
- `POST /meals` — save a meal log (from photo result or quick select)
- `GET /meals` — list meals for a profile (with date range filter)
- `GET /meals/today` — today's meals for dashboard summary
- `POST /meals/parse-image` — accept food photo, call Gemini Vision with carb classification prompt, return `FoodClassificationResponse`
- `DELETE /meals/{id}` — delete a meal log
- Photo saved to `uploads/meals/{profile_id}/{meal_id}.jpg`
**Tests:**
- Test: parse-image endpoint with mock Gemini response
- Test: CRUD operations (create, list, get today, delete)
- Test: auth required on all endpoints
- Test: profile access control (can't access other user's meals)
- Test: rate limiting
**Done when:** All endpoints work, tests pass, registered in main.py
**Blocked by:** Step 1

### Step 3: Backend — Food AI insight rules
**Context brief:** Add food-specific rules to the AI insight engine. The existing insight engine is in `routes_health.py` (`GET /api/readings/ai-insight`). Add 5 new rules that cross-reference meal logs with glucose readings. Rules are in-app only — no WhatsApp.
**Files:**
- Modify: `backend/routes_health.py` — add food rules to ai-insight endpoint
- Modify: `backend/health_utils.py` — add meal correlation helpers
**Changes:**
- Rule: high_carb_dinner_warning (immediate tip when HIGH_CARB/SWEETS dinner logged)
- Rule: carb_glucose_correlation (7+ days: compare fasting glucose after high vs low carb dinners)
- Rule: sweet_alert (immediate tip when SWEETS logged)
- Rule: good_food_choice (positive reinforcement for LOW_CARB/HIGH_PROTEIN)
- Rule: weekly_food_pattern (weekly summary of carb distribution)
**Tests:**
- Test each rule with mock meal + reading data
- Test correlation calculation with 7+ days of data
- Test rules don't fire with insufficient data
**Done when:** AI insight endpoint includes food-aware tips when meal data exists
**Blocked by:** Step 1

### Step 4: Frontend — Food photo capture screen
**Context brief:** Create `lib/screens/food_photo_screen.dart` by adapting `photo_scan_screen.dart`. Same camera pattern (camera package v0.12.0+1, back camera, medium resolution). Overlay says "Point at your plate and tap to capture" in Hindi/English. After capture, calls `POST /meals/parse-image`. On success, navigates to meal result screen. On failure, falls back to quick select. All strings via AppLocalizations, all colors via AppColors.
**Files:**
- Create: `lib/screens/food_photo_screen.dart`
- Create: `lib/screens/meal_result_screen.dart`
- Modify: `lib/l10n/app_en.arb` — add food-related strings
- Modify: `lib/l10n/app_hi.arb` — add Hindi translations
**Changes:**
- Camera capture with overlay hint text
- Loading state while Gemini processes
- Navigate to meal_result_screen on success
- Fall back to quick_select on failure/timeout
- meal_result_screen: show carb badge (color-coded), tip in user's language, meal type auto-detected by time, "Not correct? Change" dropdown, Save button
- NEVER show food name — only carb level badge
**Tests:**
- Widget test: food_photo_screen renders camera overlay
- Widget test: meal_result_screen renders badge + tip
- Widget test: correction dropdown works
**Done when:** Photo capture → Gemini → result screen → save works end-to-end
**Blocked by:** Step 2

### Step 5: Frontend — Quick select screen + meal log service
**Context brief:** Create quick select fallback screen with 5 large buttons (HIGH_CARB, LOW_CARB, HIGH_PROTEIN, SWEETS, MODERATE_CARB). Hindi/English labels. Also create `lib/services/meal_service.dart` mirroring `health_reading_service.dart` — handles API calls to /meals endpoints.
**Files:**
- Create: `lib/screens/quick_select_screen.dart`
- Create: `lib/services/meal_service.dart`
- Create: `lib/models/meal_log.dart`
**Changes:**
- 5 large tap buttons in a grid (icons + bilingual labels)
- Tap → auto-detect meal type by time → save immediately
- meal_service.dart: parseImageWithFood(), saveMeal(), getMeals(), getTodayMeals()
- meal_log.dart: MealLog data class matching backend schema
**Tests:**
- Widget test: all 5 buttons render
- Widget test: tap saves with correct category
- Unit test: meal type auto-detection by time of day
**Done when:** Quick select saves meals, meal service communicates with backend
**Blocked by:** Step 2

### Step 6: Frontend — Dashboard integration + meal entry point
**Context brief:** Add "Log Meal" button to dashboard and meal summary card showing today's meals. Entry point shows two options: "Photograph your meal" and "Quick select". Add meal summary card to home screen after health score card. Profile selector for "log for someone else" — reuse existing select_profile_screen pattern.
**Files:**
- Modify: `lib/screens/home_screen.dart` — add meal summary card + log meal button
- Modify: `lib/screens/dashboard_screen.dart` — add meal entry point
- Create: `lib/widgets/meal_summary_card.dart`
**Changes:**
- Floating action button or bottom sheet with Photo/Quick Select options
- Meal summary card: today's meals with carb badges (no food names)
- "Not logged yet → Log now" prompts for missing meals
- Profile selector before camera for multi-profile users
**Tests:**
- Widget test: meal summary card renders today's meals
- Widget test: empty state shows "Log your meals" prompt
- Widget test: FAB opens photo/quick select choice
**Done when:** Meal logging accessible from dashboard, today's summary visible
**Blocked by:** Step 4, Step 5

## Dependency Graph
```
Step 1 (model + schemas)
  ├── Step 2 (API routes) ──── Step 4 (photo screen) ──┐
  ├── Step 3 (AI rules)                                  ├── Step 6 (dashboard)
  └──────────────────────── Step 5 (quick select) ──────┘
```

## Parallel Opportunities
- Steps 2 and 3 can run in parallel (different files, both depend only on Step 1)
- Steps 4 and 5 can run in parallel (different screens, both depend on Step 2)

## Risks
- **Gemini food classification accuracy:** Mitigation — Quick Select fallback always available. Low confidence (<0.5) asks user to confirm.
- **Photo storage disk space:** Mitigation — save to server filesystem with cleanup policy. Consider S3 later.
- **iOS camera bug:** Mitigation — existing photo_scan_screen handles this. Reuse same workarounds.
- **Hindi translations for food tips:** Mitigation — Gemini generates tip_hi in the prompt. Validate with native speaker.
- **Spec says Firestore, we use PostgreSQL:** Mitigation — MealLog table in PostgreSQL, same as HealthReading. No architecture conflict.

## Estimated Steps: 6 | Critical Path: Steps 1 → 2 → 4 → 6
