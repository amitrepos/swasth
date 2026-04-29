# AI Insights JSON Display - Diagnostic Guide

## Problem
When scanning food, JSON data (foods array with name, weight_grams, etc.) is appearing in the AI Insights section on the home screen instead of formatted, human-readable text.

## What We've Fixed

### Backend (ai_service.py)
1. Added `_clean_ai_response()` function that automatically detects and formats JSON responses
2. **FIXED: Markdown code block stripping** - AI models often wrap JSON in ```json ... ``` which breaks parsing
3. Nutrition JSON is now converted to readable format:
   ```
   Meal Score: 6/10 - Good balance of protein and fiber
   Nutrition: 845 cal, 44.4g protein, 118.2g carbs, 21.9g fat
   Carb Level: HIGH
   Sugar Level: MEDIUM
   Diet: Gluten-free, High-protein
   Foods: Rice, Dal, Chicken
   ```

3. Added extensive logging to track what's happening

### Frontend (ai_insight_card.dart)
1. Removed quotes around insight text
2. Removed italic styling for better readability

## How to Test & Diagnose

### Step 1: Check Backend Logs
When you scan food or view AI insights, check the backend logs:

```bash
# In the backend terminal, you should see:
Raw AI response (first 300 chars): {...}
Detected JSON response, keys: ['total_calories', 'meal_score', ...]
Formatted nutrition JSON to: Meal Score: 6/10...
```

### Step 2: Check Flutter Console
In the Flutter app console (VS Code Debug Console or terminal), look for:

```
DEBUG: AI Insight received: Meal Score: 6/10 - Good balance...
```

### Step 3: Verify the Display
The AI Insights card on the home screen should now show:
- ✅ Formatted text with line breaks
- ✅ No raw JSON brackets `{}`
- ✅ Readable nutrition information
- ✅ Meal score with reason

## What to Look For

### If you STILL see JSON like this:
```
{"foods": [{"name": "Rice", "weight_grams": 200}, ...], "total_calories": 845, ...}
```

Then check:

1. **Backend logs** - Is the `_clean_ai_response` function being called?
   - Look for: "Raw AI response" log message
   - Look for: "Formatted nutrition JSON" log message

2. **Which endpoint is returning this?**
   - `/api/readings/ai-insight` - Home screen AI insight
   - `/api/meals/analyze-nutrition` - Food scan nutrition result (THIS SHOULD BE JSON)

### IMPORTANT: Two Different Endpoints

1. **`/api/meals/analyze-nutrition`** (Food Scan)
   - ✅ SHOULD return JSON with foods array
   - ✅ Parsed by `NutritionResultScreen` in Flutter
   - ✅ Displays formatted nutrition cards

2. **`/api/readings/ai-insight`** (Home Screen Insight)
   - ✅ Should return human-readable TEXT
   - ✅ JSON is automatically cleaned by `_clean_ai_response()`
   - ✅ Displayed in `AiInsightCard` on home screen

## Common Issues & Solutions

### Issue: JSON showing in home screen AI insights
**Cause**: The AI model is returning JSON instead of text
**Solution**: Already fixed - `_clean_ai_response()` will format it

### Issue: Food scan showing JSON
**Cause**: This is CORRECT behavior - nutrition result screen parses the JSON
**Solution**: No fix needed - the NutritionResultScreen properly displays the data

### Issue: Cleanup function not being called
**Check**: 
- Is `generate_health_insight()` being called? 
- Are the logs showing "Raw AI response"?
- Is there an error in the logs?

## Testing Commands

### Test the cleanup function directly:
```bash
cd backend
python -c "from ai_service import _clean_ai_response; print(_clean_ai_response('{\"total_calories\": 845, \"meal_score\": 6}'))"
```

Expected output:
```
Meal Score: 6/10
Nutrition: 845 cal
```

### Run the AI service tests:
```bash
cd backend
python -m pytest tests/test_ai_service.py -v
```

## Next Steps

1. **Restart the backend server** to load the new code:
   ```bash
   cd backend
   python main.py
   ```

2. **Hot reload the Flutter app** (press `r` in the Flutter terminal)

3. **Scan a food item** and check:
   - Backend logs for "Raw AI response"
   - Flutter console for "DEBUG: AI Insight received"
   - Home screen AI Insights card display

4. **Report back** with:
   - What you see in the backend logs
   - What you see in the Flutter console
   - Screenshot of what's displayed on screen

## Files Modified

- `backend/ai_service.py` - Added JSON cleanup and logging
- `backend/routes_health.py` - Added response logging
- `lib/widgets/home/ai_insight_card.dart` - Improved text display
- `lib/services/health_reading_service.dart` - Added debug logging
- `backend/tests/test_ai_service.py` - Added cleanup tests
