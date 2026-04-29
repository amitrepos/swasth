# AI Insights JSON Fix - Summary

## Root Cause Identified

The AI model (Gemini) was returning JSON wrapped in **markdown code blocks**:

```
```json
{
  "foods": [
    {"name": "Idli", "weight_grams": 150, ...}
  ],
  "total_calories": 255,
  "meal_score": 7,
  ...
}
```
```

The JSON parser was failing because it encountered ````json` instead of `{`, causing this error:
```
INFO:ai_service:JSON parse failed (Expecting value: line 1 column 1 (char 0)), returning as-is
```

So the raw markdown-wrapped JSON was being returned to the app and displayed as-is.

## Solution Implemented

### Updated `backend/ai_service.py`

Added markdown code block stripping before JSON parsing:

```python
# Strip markdown code blocks if present
cleaned_text = response_text.strip()
if cleaned_text.startswith('```'):
    # Remove opening ```json or ```
    first_newline = cleaned_text.find('\n')
    if first_newline != -1:
        cleaned_text = cleaned_text[first_newline:].strip()
    # Remove closing ```
    if cleaned_text.endswith('```'):
        cleaned_text = cleaned_text[:-3].strip()
    logger.info(f"Stripped markdown code blocks")
```

Now the flow is:
1. Receive response: ````json\n{...}\n```
2. Strip markdown: `{...}`
3. Parse JSON successfully
4. Format to human-readable text

## Result

### Before Fix:
```
```json
{
  "foods": [{"name": "Idli", "weight_grams": 150, ...}],
  "total_calories": 255,
  "meal_score": 7
}
```
```
(Displayed as raw JSON with markdown in the app)

### After Fix:
```
Meal Score: 7/10 - Balanced meal with good fiber content
Nutrition: 255 cal, 9g protein, 51g carbs, 1.5g fat, 6g fiber
Carb Level: MEDIUM
Sugar Level: LOW
Diet: Vegan, Vegetarian, Gluten-free
Foods: Idli, Sambar
```
(Displayed as formatted, human-readable text)

## Testing

✅ All 13 tests pass (including new markdown test)
✅ Manual test with actual Idli/Sambar JSON works perfectly
✅ Backend logs now show:
```
INFO:ai_service:Stripped markdown code blocks
INFO:ai_service:Detected JSON response, keys: ['foods', 'total_calories', ...]
INFO:ai_service:Formatted nutrition JSON to: Meal Score: 7/10...
```

## Next Steps

1. **Restart backend server** to load the fix:
   ```bash
   cd backend
   # Stop current server (Ctrl+C)
   python main.py
   ```

2. **Hot reload Flutter app** (press `r` in Flutter terminal)

3. **Scan food again** - you should now see formatted text instead of JSON

4. **Check backend logs** - should show:
   - "Stripped markdown code blocks"
   - "Formatted nutrition JSON to: Meal Score:..."

## Files Modified

- ✅ `backend/ai_service.py` - Added markdown stripping logic
- ✅ `backend/tests/test_ai_service.py` - Added test for markdown JSON
- ✅ `lib/widgets/home/ai_insight_card.dart` - Improved text display
- ✅ `lib/services/health_reading_service.dart` - Added debug logging
- ✅ `backend/routes_health.py` - Added response logging

## Why This Happened

AI models (especially Gemini and GPT) are trained to format code examples in markdown. When prompted to return JSON, they often wrap it in ````json` code blocks for "proper formatting". This is helpful for documentation but breaks programmatic JSON parsing.

This is a common issue with LLM APIs and the fix (stripping markdown) is the standard solution used in production systems.
