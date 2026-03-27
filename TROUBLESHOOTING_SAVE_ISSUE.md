# Troubleshooting: Readings Not Storing in Database

## Current Status
✅ Database table exists  
✅ Backend API endpoint works (returns 401 without token)  
❌ Readings not being saved when scanning devices  

---

## Step-by-Step Debugging

### Step 1: Check Console Output

When you scan a glucose meter, you should see these console messages:

```
=== Starting save process ===
Token retrieved: YES
Converting reading to HealthReading format...
Created HealthReading: glucose, value: 95.5
Calling API to save reading...
SUCCESS: Reading saved with ID: 123
```

**If you DON'T see these messages:**
- The `_saveReadingToDatabase()` method is not being called
- Check if `onReading` callback is being triggered

---

### Step 2: Check Token Storage

The most common issue is **missing or invalid JWT token**.

#### Test in Flutter Console:
Add this temporary debug code in your dashboard:

```dart
// Add this at the start of _fetchReadings()
final debugToken = await StorageService().getToken();
print('=== DEBUG TOKEN CHECK ===');
print('Token exists: ${debugToken != null}');
if (debugToken != null) {
  print('Token length: ${debugToken.length}');
  print('Token preview: ${debugToken.substring(0, 20)}...');
} else {
  print('NO TOKEN FOUND - User needs to login!');
}
print('========================');
```

#### Possible Outputs:

**✅ Good Token:**
```
Token exists: true
Token length: 245
Token preview: eyJhbGciOiJIUzI1NiIs...
```

**❌ No Token:**
```
Token exists: false
NO TOKEN FOUND - User needs to login!
```

**Solution if no token:**
1. Logout completely
2. Clear app data/cache
3. Login again
4. Verify token is saved

---

### Step 3: Check Backend Logs

In your **backend terminal**, you should see:

```
INFO:     192.168.29.66:12345 - "POST /api/readings HTTP/1.1" 201 Created
```

**Possible Responses:**

| Status | Meaning | Solution |
|--------|---------|----------|
| **201 Created** | ✅ Success! Reading saved | Nothing - it's working |
| **401 Unauthorized** | ❌ Invalid/missing token | Re-login to get new token |
| **422 Unprocessable Entity** | ❌ Invalid data format | Check payload structure |
| **500 Internal Server Error** | ❌ Backend error | Check backend logs for details |
| **No log at all** | ❌ Request not reaching backend | Network/firewall issue |

---

### Step 4: Verify Database Save

After scanning, run this to check if reading was saved:

```bash
cd backend
python check_db.py
```

Expected output:
```
health_readings table exists: True
Total readings in database: 1

Recent readings:
  ID: 1, Type: glucose, Value: 95.5 mg/dL, Status: NORMAL, Time: 2025-03-26 14:30:00
```

---

## Common Issues & Solutions

### Issue 1: Token Not Being Saved

**Symptoms:**
- Console shows: "Token retrieved: NO"
- Backend shows: 401 Unauthorized

**Causes:**
1. User not logged in properly
2. Token storage failed
3. Using wrong storage service

**Solution:**
```dart
// In login_screen.dart, after successful login:
await StorageService().saveToken(response.token);
await StorageService().saveUserData({
  'id': user.id,
  'email': user.email,
});
```

---

### Issue 2: API Base URL Wrong

**Symptoms:**
- Console shows error connecting
- Backend shows no requests

**Check:**
```dart
// In health_reading_service.dart
print('API Base URL: $baseUrl');
// Should print: http://192.168.29.12:8000/api
```

**Fix if wrong:**
```dart
static String baseUrl = '${AppConfig.serverHost}/api';
```

---

### Issue 3: Device Type Not Recognized

**Symptoms:**
- Console shows: "Unknown device type: Blood Pressure"
- Exception thrown

**Cause:** Factory method doesn't recognize device type string

**Fix:**
```dart
// In HealthReading.fromGlucoseOrBP()
if (deviceType.toLowerCase().contains('glucose') || 
    deviceType == 'Glucose') {
  // Handle glucose
} else if (deviceType.toLowerCase().contains('blood') || 
           deviceType == 'Blood Pressure') {
  // Handle BP
}
```

---

### Issue 4: onReading Callback Not Triggered

**Symptoms:**
- Reading appears on device screen
- Dashboard shows "Connected" but no readings
- Console shows no "Received reading" message

**Causes:**
1. BLE subscription not set up
2. Device not sending notifications
3. Wrong service UUID

**Debug:**
```dart
// In dashboard, add more logging
print('Found glucose service: ${glucoseService.uuid}');
print('Subscribing to measurements...');

await GlucoseService.requestAllRecords(
  service: glucoseService,
  onReading: (reading) {
    print('*** READING RECEIVED: ${reading.mgdl} ***');
    // ... rest of code
  },
);
```

---

### Issue 5: Duplicate Sequence Numbers

**Symptoms:**
- Multiple readings taken but only 1 saved
- Console shows same sequence number

**Cause:** Glucometer reusing sequence numbers

**Current Code Handles This:**
```dart
_allReadings.removeWhere((r) => r.sequenceNumber == reading.sequenceNumber);
_allReadings.add(reading);
```

But database might reject duplicates. Check backend for unique constraints.

---

## Quick Test Checklist

Run through these steps:

- [ ] **1. Login to app**
  - Enter credentials
  - Click login
  - Check console: token should be saved

- [ ] **2. Verify token exists**
  ```dart
  final token = await StorageService().getToken();
  print('Token: ${token != null ? "EXISTS" : "MISSING"}');
  ```

- [ ] **3. Connect glucometer**
  - Tap "Glucometer" icon
  - Turn on device
  - Wait for connection

- [ ] **4. Take measurement**
  - Apply blood sample
  - Wait for reading
  - Device should beep/show result

- [ ] **5. Check console output**
  ```
  === Starting save process ===
  Token retrieved: YES
  Created HealthReading: glucose, value: 95.5
  SUCCESS: Reading saved with ID: 123
  ```

- [ ] **6. Check backend logs**
  ```
  INFO: POST /api/readings HTTP/1.1" 201 Created
  ```

- [ ] **7. Check database**
  ```bash
  python check_db.py
  ```
  Should show: "Total readings in database: 1"

- [ ] **8. Check history screen**
  - Navigate to History
  - Reading should appear in list

---

## Expected Full Flow

### Frontend (Flutter Console):
```
Dashboard: Glucose service found! Fetching records...
Dashboard: Received reading - 95 mg/dL (Seq: #5)
=== Starting save process ===
Token retrieved: YES
Converting reading to HealthReading format...
Created HealthReading: glucose, value: 95.5
Calling API to save reading...
SUCCESS: Reading saved with ID: 42
```

### Backend (Python Terminal):
```
INFO:     192.168.29.66:54321 - "POST /api/readings HTTP/1.1" 201 Created
```

### Database:
```sql
SELECT * FROM health_readings ORDER BY created_at DESC LIMIT 1;
-- Returns: id=42, reading_type=glucose, glucose_value=95.5, ...
```

---

## Emergency Fallback: Manual Save Test

If automatic save still doesn't work, test manually:

### Create test endpoint call:

```dart
// Add this button to dashboard for testing
ElevatedButton(
  onPressed: () async {
    // Simulate a reading
    final testReading = HealthReading(
      id: 0,
      userId: 0,
      readingType: 'glucose',
      glucoseValue: 100.0,
      glucoseUnit: 'mg/dL',
      sampleType: 'Capillary whole blood',
      valueNumeric: 100.0,
      unitDisplay: 'mg/dL',
      statusFlag: 'NORMAL',
      notes: null,
      readingTimestamp: DateTime.now(),
      createdAt: DateTime.now(),
    );
    
    final token = await StorageService().getToken();
    if (token == null) {
      print('No token!');
      return;
    }
    
    try {
      final saved = await HealthReadingService().saveReading(testReading, token);
      print('Manual save successful! ID: ${saved.id}');
    } catch (e) {
      print('Manual save failed: $e');
    }
  },
  child: Text('TEST SAVE'),
)
```

---

## Summary

**Most Likely Causes:**
1. ❌ No token (user not logged in properly)
2. ❌ Wrong API URL (network unreachable)
3. ❌ Exception in fromGlucoseOrBP()
4. ❌ onReading callback not triggered

**Debug Priority:**
1. Check console for "Token retrieved: YES/NO"
2. Check backend logs for POST request
3. Check database with `python check_db.py`
4. Verify onReading is being called

**Next Steps:**
1. Hot restart Flutter app
2. Watch console output while scanning
3. Share the exact console output you see
4. We can pinpoint where it's failing

---

## Contact Info

Share these outputs for help:
1. Flutter console output (full log)
2. Backend terminal output
3. Result of `python check_db.py`
4. Screenshot of error (if any)
