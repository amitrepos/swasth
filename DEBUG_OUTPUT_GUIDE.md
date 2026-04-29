# AI Insights - Debug Output Guide

## What You'll See Now

### In Backend Terminal (Python/FastAPI):

When the home screen requests AI insights, you'll see:

```
================================================================================
🔵 BACKEND AI INSIGHT RESPONSE:
================================================================================
Your glucose levels are stable and within normal range. Consider maintaining your current diet and exercise routine.

Dinner was high carb - a 15-minute walk after eating may help keep sugar levels stable.
================================================================================
```

### In Flutter Console (VS Code Debug Console or Terminal):

Immediately after, you'll see:

```
================================================================================
🟡 FRONTEND AI INSIGHT RECEIVED:
================================================================================
Your glucose levels are stable and within normal range. Consider maintaining your current diet and exercise routine.

Dinner was high carb - a 15-minute walk after eating may help keep sugar levels stable.
================================================================================
```

## How to Test

1. **Restart backend:**
   ```bash
   cd backend
   # Ctrl+C to stop current server
   python main.py
   ```

2. **Hot reload Flutter app:**
   - In Flutter terminal, press `r`

3. **Open the app and go to home screen**
   - The AI Insights card will load
   - Check both terminals for the output

4. **What to look for:**

   ✅ **GOOD OUTPUT** (formatted text):
   ```
   Your glucose levels are stable...
   Dinner was high carb...
   ```

   ❌ **BAD OUTPUT** (raw JSON - this should NOT appear anymore):
   ```
   {"foods": [{"name": "Idli", ...}], "total_calories": 255, ...}
   ```

## Where the Output Appears

### Backend Terminal:
- Look for: `🔵 BACKEND AI INSIGHT RESPONSE:`
- This shows what the backend is sending to the app

### Flutter Console:
- **VS Code:** Debug Console tab (bottom panel)
- **Terminal:** Where you ran `flutter run`
- Look for: `🟡 FRONTEND AI INSIGHT RECEIVED:`
- This shows what the app actually received

## If You Still See JSON

If the output shows JSON instead of formatted text:

1. **Check backend logs for:**
   ```
   INFO:ai_service:Stripped markdown code blocks
   INFO:ai_service:Detected JSON response, keys: [...]
   INFO:ai_service:Formatted nutrition JSON to: ...
   ```

2. **If you DON'T see these logs**, the cleanup function isn't being called.

3. **Take a screenshot** of both terminal outputs and share it.

## Quick Test Command

You can also test the AI insight endpoint directly:

```bash
# Replace YOUR_TOKEN with actual token
curl -H "Authorization: Bearer YOUR_TOKEN" \
  "http://localhost:8000/api/readings/ai-insight?profile_id=1"
```

This will show the raw JSON response from the backend.
