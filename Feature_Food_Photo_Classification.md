# FEATURE SPEC: Food Photo Classification (Carb Level Detection)
## For implementation in existing Flutter app using Gemini Vision API

**Context:** This is a connected health app for diabetic/hypertensive patients in India. The app already uses Gemini API for other features. We need to add a food photo feature that classifies meals by carb level to predict next-morning glucose impact.

**Goal:** Patient photographs their meal → Gemini classifies carb level → app stores result → AI correlates with next-morning glucose reading over time.

---

## WHAT TO BUILD

### 1. Food Photo Capture Screen

A new screen accessible from the dashboard via a "Log Meal" button (floating action button or bottom nav action).

**UI Flow:**
```
Dashboard → Tap "Log Meal" → Two options appear:

  [📸 Photograph your meal]    [🍚 Quick select]
```

**Option A: Photo Capture**
- Opens camera with a simple overlay hint: "Point at your plate and tap to capture"
- After capture, show the photo with a loading indicator while Gemini processes
- Show result: classification badge + one-line Hindi/English explanation
- Confirm button to save

**Option B: Quick Select (fallback / no camera situations)**
- Show 5 large tap buttons in a grid:

```
┌─────────────────┐  ┌─────────────────┐
│    🍚            │  │    🥗            │
│  Rice / Roti     │  │  Sabzi / Dal     │
│  heavy           │  │  heavy           │
│  (High Carb)     │  │  (Low Carb)      │
└─────────────────┘  └─────────────────┘
┌─────────────────┐  ┌─────────────────┐
│    🍗            │  │    🍬            │
│  Protein         │  │  Sweets /        │
│  heavy           │  │  Dessert         │
│  (Low Carb)      │  │  (Very High)     │
└─────────────────┘  └─────────────────┘
┌─────────────────────────────────────┐
│    🍽️  Balanced / Mixed meal        │
│         (Moderate Carb)             │
└─────────────────────────────────────┘
```

- Labels should be in Hindi and English based on language setting
- Tap one → saved immediately with timestamp

### 2. Gemini Vision API Integration

**Use the existing Gemini API client in the codebase.** Do not create a new integration.

**API Call — send the food photo with this prompt:**

```
You are a nutrition classifier for diabetic patients in India.

Look at this food photo and classify the OVERALL meal into exactly one category:
- HIGH_CARB (rice, roti, paratha, biryani, poha, noodles, bread, pasta, potatoes dominate)
- MODERATE_CARB (balanced meal — mix of carbs, protein, vegetables)
- LOW_CARB (mostly vegetables, sabzi, salad, dal without rice, sprouts)
- HIGH_PROTEIN (mostly eggs, chicken, fish, paneer, dal without carbs)
- SWEETS (mithai, desserts, gulab jamun, halwa, sugary drinks, chai with sugar)

IMPORTANT: Do NOT try to name or identify the specific food. 
Only classify the carb level. We want category accuracy, not food naming.

Respond ONLY in this exact JSON format, nothing else:
{
  "category": "HIGH_CARB",
  "glucose_impact": "HIGH",
  "tip_en": "High carb meal. Walk 15 minutes after eating to reduce sugar spike.",
  "tip_hi": "ज़्यादा कार्ब वाला खाना। खाने के बाद 15 मिनट टहलें, शुगर कम रहेगी।",
  "confidence": 0.9
}
```

**WHY WE DON'T NAME THE FOOD:** If Gemini says "aloo gobi" but it's actually "gobi manchurian," the patient loses trust in ALL AI recommendations — including the glucose ones that matter. Just saying "High carb meal" is always correct and never damages trust.

**Parse the JSON response.** If parsing fails or confidence < 0.5, fall back to the Quick Select screen and ask user to classify manually.

**Error handling:**
- Network error → show Quick Select as fallback
- Gemini API timeout (set 10 second timeout) → show Quick Select
- Unrecognizable image (not food) → show message "This doesn't look like food. Try again or use Quick Select."
- Low confidence (<0.5) → show result but ask "Is this correct?" with option to change category

### 3. Data Model

**Add to existing reading/measurement data model:**

```dart
class MealLog {
  String id;                    // Unique ID
  String profileId;             // Which patient profile this belongs to
  String loggedBy;              // User ID of who logged it (could be family member)
  DateTime timestamp;           // When the meal was logged
  
  // Classification (NO food naming — only carb level)
  String category;              // HIGH_CARB, MODERATE_CARB, LOW_CARB, HIGH_PROTEIN, SWEETS
  String glucoseImpact;         // HIGH, MODERATE, LOW, VERY_HIGH
  
  // Health tip (from Gemini)
  String? tipEn;                // Health tip in English
  String? tipHi;                // Health tip in Hindi
  
  // Meal context
  String mealType;              // BREAKFAST, LUNCH, DINNER, SNACK
  
  // Photo storage (CRITICAL: store every photo for future AI training)
  String? photoUrl;             // Cloud storage URL of the food photo (nullable - no photo for Quick Select)
  String? photoLocalPath;       // Local path for offline access
  
  // Metadata
  String inputMethod;           // PHOTO_GEMINI, QUICK_SELECT
  double? confidence;           // Gemini confidence score (nullable for Quick Select)
  bool userConfirmed;           // Did user confirm/edit the classification?
  String? userCorrectedCategory; // If user changed the category, store what they changed it to
}
```

**Store in Firestore** under the patient's profile, same collection structure as glucose/BP readings.

**IMPORTANT: Store the original photo in cloud storage (Firebase Storage or equivalent) even if you only use the classification now.** These photos + classifications + next-morning glucose readings = future training data for a custom food-glucose AI model. This data is a strategic asset.

### 4. Meal Type Auto-Detection

Based on time of day, auto-suggest meal type:
- 6:00 AM - 10:00 AM → BREAKFAST
- 11:00 AM - 2:00 PM → LUNCH
- 3:00 PM - 5:00 PM → SNACK
- 6:00 PM - 10:00 PM → DINNER

Show as pre-selected but allow user to change.

### 5. Result Display Screen (after classification)

```
┌─────────────────────────────────────┐
│                                     │
│        [Food Photo Thumbnail]       │
│                                     │
│   ┌─────────────────────────────┐   │
│   │  🔴 HIGH CARB               │   │
│   │  ज़्यादा कार्ब वाला खाना    │   │
│   │  High carb meal             │   │
│   └─────────────────────────────┘   │
│                                     │
│   💡 खाने के बाद 15 मिनट टहलें,   │
│      शुगर कम रहेगी।               │
│                                     │
│   Dinner · 8:32 PM                  │
│                                     │
│   [Not correct? Change ▼]           │
│                                     │
│   [    ✅ Save    ]                  │
│                                     │
└─────────────────────────────────────┘
```

**NOTE: We deliberately do NOT show the food name.** Only the carb level category and the health tip. This prevents trust-breaking misidentification (e.g., calling "gobi manchurian" as "aloo gobi").

**Color coding for the category badge:**
- HIGH_CARB → Red (🔴)
- MODERATE_CARB → Yellow (🟡)
- LOW_CARB → Green (🟢)
- HIGH_PROTEIN → Green (🟢)
- SWEETS → Dark Red (🔴🔴)

**"Not correct? Change" dropdown:** Opens the Quick Select grid so user can override the Gemini classification. If user changes it, store both `category` (Gemini's answer) and `userCorrectedCategory` (user's correction). This correction data is gold for future model training.

### 6. Dashboard Integration

**Add to Today's Summary Card:**

After the existing glucose/BP/steps cards, add a meal summary:

```
🍽️ Today's meals:
   Breakfast: 🟢 Low Carb
   Lunch: 🟡 Moderate Carb
   Dinner: not logged yet → [Log now]
```

If no meals logged today, show a gentle prompt:
```
🍽️ Log your meals to get better sugar predictions
   [Log Breakfast] [Log Lunch] [Log Dinner]
```

### 7. AI Insights Integration

**Add these rules to the existing AI insights engine:**

```
RULE: high_carb_dinner_warning
  TRIGGER: meal logged as HIGH_CARB or SWEETS AND mealType == DINNER
  → IMMEDIATE in-app tip: "High carb dinner tonight. A 15-minute walk 
     before bed can reduce your fasting sugar by 10-20 mg/dL."

RULE: carb_glucose_correlation (needs 7+ days of data)
  IF avg_fasting_glucose on mornings_after_high_carb_dinner > 
     avg_fasting_glucose on mornings_after_low_carb_dinner
  AND difference > 10 mg/dL
  → "When you eat high-carb dinners, your morning sugar averages {X}. 
     After low-carb dinners, it's {Y}. That's a {difference} mg/dL difference."

RULE: sweet_alert
  TRIGGER: meal logged as SWEETS
  → "You had sweets today. Your sugar will likely spike. 
     Walk 20 minutes and check your sugar in 2 hours."

RULE: good_food_choice
  TRIGGER: meal logged as LOW_CARB or HIGH_PROTEIN
  → "Great food choice! Low carb meals help keep your sugar stable."

RULE: no_dinner_logged
  TRIGGER: time > 9:30 PM AND no DINNER meal logged today
  → In-app reminder: "You haven't logged dinner yet. 
     A quick log helps predict your morning sugar."

RULE: weekly_food_pattern
  TRIGGER: weekly summary generation (every Monday)
  → "This week you had {X} high-carb meals and {Y} low-carb meals. 
     Your sugar was best on low-carb days."
```

**NOTE:** All these insights are shown IN-APP only in this feature. WhatsApp delivery of meal insights will be built as a separate feature (see Feature_WhatsApp_Integration.md).

### 8. WhatsApp Integration — SEPARATE FEATURE

**WhatsApp notifications for meal data (daily summaries, alerts, meal reminders) will be built as a separate feature.**

This includes:
- WhatsApp Business API setup and Meta template approvals
- Daily/weekly summary messages including meal data
- Immediate high-carb dinner alerts to family
- Meal logging reminders via WhatsApp
- Per-profile notification preferences

See separate spec: **Feature_WhatsApp_Integration.md** (to be created)

**For this feature, all insights and reminders are IN-APP ONLY:**
- In-app tip cards on the dashboard
- Local push notifications for meal reminders (as interim until WhatsApp feature is built)

### 9. "Log for Someone Else" Support

Same as glucose/BP photo capture — if user has access to multiple profiles, show profile selector before camera:

```
Logging meal for:
[Papa's profile]  [Mummy's profile]  [My profile]
```

This allows the daughter visiting her parents to photograph their dinner and log it to their profile.

---

## FILE STRUCTURE (suggested)

```
lib/
  features/
    meal_logging/
      screens/
        meal_log_screen.dart        // Main screen with Photo/Quick Select options
        food_photo_screen.dart      // Camera capture screen
        meal_result_screen.dart     // Show classification result + confirm
        quick_select_screen.dart    // Manual 5-button grid selection
      models/
        meal_log.dart               // MealLog data class
      services/
        gemini_food_classifier.dart // Gemini API call + response parsing
        meal_repository.dart        // Firestore CRUD for meal logs
      widgets/
        meal_summary_card.dart      // Dashboard widget showing today's meals
        carb_level_badge.dart       // Colored badge (HIGH_CARB = red, etc.)
        meal_type_selector.dart     // Breakfast/Lunch/Dinner/Snack selector
```

---

## TESTING CHECKLIST

### Gemini Carb Classification Accuracy
Test with photos of these common Indian foods. The test ONLY checks if carb level is correct — NOT if the food is correctly named.

**HIGH_CARB (should classify as HIGH_CARB):**
- [ ] Plate of plain white rice
- [ ] Stack of roti/chapati
- [ ] Paratha (aloo paratha, gobi paratha, any)
- [ ] Biryani (any variety)
- [ ] Poha
- [ ] Idli (plate of 3-4)
- [ ] Dosa (plain or masala)
- [ ] Plate of noodles/chowmein
- [ ] Bread/toast
- [ ] Chole bhature

**MODERATE_CARB (should classify as MODERATE_CARB):**
- [ ] Full thali with roti, dal, sabzi, rice (balanced)
- [ ] Dal chawal with moderate rice portion
- [ ] Rajma chawal (mixed — carb + protein)
- [ ] Roti with paneer sabzi (some carb, some protein)

**LOW_CARB (should classify as LOW_CARB):**
- [ ] Bowl of sabzi/vegetable dish only (no rice/roti visible)
- [ ] Salad
- [ ] Dal/sambar without rice (soup-like)
- [ ] Sprouts
- [ ] Green vegetables (palak, bhindi, etc.)

**HIGH_PROTEIN (should classify as HIGH_PROTEIN):**
- [ ] Eggs/omelette (without bread)
- [ ] Chicken dish without rice/roti
- [ ] Fish dish without rice/roti
- [ ] Paneer dish without rice/roti

**SWEETS (should classify as SWEETS):**
- [ ] Gulab jamun
- [ ] Mithai/barfi assortment
- [ ] Halwa
- [ ] Jalebi
- [ ] Cake/pastry

### Edge Cases
- [ ] Blurry photo → should fall back to Quick Select
- [ ] Photo of non-food item (table, person, etc.) → "This doesn't look like food" message
- [ ] No network → should fall back to Quick Select immediately
- [ ] Gemini timeout (>10 seconds) → should fall back to Quick Select
- [ ] Multiple dishes on one plate → should classify OVERALL carb level of the meal
- [ ] Photo in low light → test with flash on/off
- [ ] Very close-up photo of one item → should still classify carb level
- [ ] Photo with hand/utensils/table visible → should still work
- [ ] Gemini returns low confidence (<0.5) → should show result but ask user to confirm
- [ ] Photo of packaged food (biscuit packet, chips) → should classify (likely HIGH_CARB or SWEETS)
- [ ] Photo of drink (chai, lassi, juice) → should classify appropriately
- [ ] Empty plate → should show "no food detected" or fall back to Quick Select

### Functional Tests
- [ ] Photo capture → Gemini call → result displays correctly with ONLY carb level badge (no food name)
- [ ] Tip displays in correct language (Hindi or English based on setting)
- [ ] User can correct classification → both original and corrected values stored
- [ ] Quick Select saves correctly with all 5 categories
- [ ] Meal type auto-detects based on time of day
- [ ] Meal type can be manually changed
- [ ] "Log for someone else" works — meal saved to correct profile
- [ ] Photo stored in cloud storage with correct path/reference
- [ ] Dashboard shows today's meal summary with carb level badges only (no food names)
- [ ] AI insight triggers in-app on HIGH_CARB dinner (immediate tip card)
- [ ] Hindi/English toggle works for all meal-related screens
- [ ] Works offline — Quick Select saves locally, syncs when online
- [ ] Photo upload queues when offline, uploads when back online
- [ ] Confidence score stored correctly
- [ ] User correction stored separately from original classification

---

## ESTIMATED EFFORT

| Task | Days |
|------|------|
| Meal log data model + Firestore setup | 0.5 |
| Quick Select screen (5 buttons) | 0.5 |
| Camera/photo capture screen | 0.5 (reuse existing camera code) |
| Gemini food classifier service (prompt + JSON parsing + error handling) | 1 |
| Result display screen with correction flow (carb badge only, no food name) | 1 |
| Meal type auto-detection | 0.5 |
| Profile selector ("log for someone else") | 0.5 (reuse existing) |
| Dashboard meal summary card | 0.5 |
| Cloud photo storage | 0.5 |
| AI insight rules — in-app only (5 food-related rules) | 1 |
| Local push notification for meal reminders (interim until WhatsApp feature) | 0.5 |
| Hindi translations | 0.5 |
| Testing + bug fixes | 2 |
| **Total** | **~9 days** |

Can be done by 1 developer in ~2 weeks, or 2 developers in 1 week if parallelized (one on UI screens, one on Gemini + AI rules).

**WhatsApp integration (daily summaries, alerts, meal reminders via WhatsApp) is a SEPARATE feature** with its own spec, timeline, and pre-work (API setup, Meta template approvals, notification preference system). Do not mix into this feature.

---

## IMPORTANT NOTES

- **NEVER display food names to the user.** Only show carb level classification (HIGH_CARB, LOW_CARB, etc.) and the health tip. Incorrect food naming destroys user trust in the entire AI system. "High carb meal" is always correct. "Aloo gobi" when it's actually "gobi manchurian" breaks trust permanently.
- **Store EVERY food photo permanently** — even if classification is wrong. These photos + user corrections + next-morning glucose values = proprietary training dataset for future custom AI model. This data is a strategic moat.
- **Gemini response should NOT include food_name fields.** The prompt explicitly tells Gemini not to name the food. If Gemini returns a food name anyway, DO NOT display it to the user.
- **WhatsApp integration is a SEPARATE feature.** This feature is IN-APP ONLY. Do not build any WhatsApp sending logic here. Use local push notifications as interim for meal reminders.
- **Gemini classification is NOT medical advice** — it's a lifestyle suggestion. Don't use medical language like "you must" or "dangerous." Use language like "this may help" or "consider."
- **Privacy** — food photos may contain personal/location info. Store securely. Don't share between patients. Follow same privacy rules as health data.
- **Don't over-design the UI** — big buttons, big text, simple flow. Target user is a 55+ year old in Bihar. Two taps maximum to log a meal.
