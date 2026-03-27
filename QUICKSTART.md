# Quick Start Guide - Swasth Health App

Get up and running in 5 minutes!

## Prerequisites

- ✅ Python 3.8+ installed
- ✅ PostgreSQL installed
- ✅ Flutter SDK installed
- ✅ Git (optional)

---

## Step 1: Set Up Backend (2 minutes)

### 1.1 Install Python Dependencies

```bash
cd backend
pip install -r requirements.txt
```

### 1.2 Create PostgreSQL Database

Open pgAdmin or PostgreSQL command line:

```sql
CREATE DATABASE swasth_db;
```

### 1.3 Configure Environment

```bash
# Copy example env file
copy .env.example .env

# Edit .env and update:
# - DATABASE_URL with your postgres password
# - SECRET_KEY with any random 32+ character string
```

Example `.env`:
```env
DATABASE_URL=postgresql://postgres:your_password@localhost:5432/swasth_db
SECRET_KEY=super-secret-key-change-this-to-something-random-and-long
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
```

### 1.4 Initialize Database

```bash
python init_db.py
```

Expected output:
```
Creating database tables...
✓ Database tables created successfully!

Tables created:
- users

You can now start the backend server with: python main.py
```

### 1.5 Start Backend Server

```bash
python main.py
```

✅ Backend running at: http://localhost:8000
📚 API Docs at: http://localhost:8000/docs

---

## Step 2: Set Up Flutter App (2 minutes)

### 2.1 Install Flutter Dependencies

Open a new terminal:

```bash
cd d:\nuofintech\BLE_APP\swasth_app
flutter pub get
```

### 2.2 Configure Backend URL (if needed)

If you're using:
- **Android Emulator**: Update `lib/services/api_service.dart` to use `http://10.0.2.2:8000`
- **iOS Simulator**: Use `http://localhost:8000`
- **Physical Device**: Use your computer's IP address

### 2.3 Run Flutter App

```bash
flutter run
```

✅ App should launch on your device/emulator

---

## Step 3: Test the Application (1 minute)

### Option A: Test via Swagger UI (Recommended for quick test)

1. Open http://localhost:8000/docs
2. Click on `POST /api/auth/register`
3. Click "Try it out"
4. Fill in the form with test data:
```json
{
  "email": "test@example.com",
  "password": "SecurePass123!",
  "confirm_password": "SecurePass123!",
  "full_name": "Test User",
  "phone_number": "1234567890",
  "age": 25,
  "gender": "Male",
  "height": 170.0,
  "weight": 65.0,
  "blood_group": "O+",
  "medical_conditions": ["None"]
}
```
5. Click "Execute"
6. You should see status code 201

### Option B: Test via Flutter App

1. Open the Flutter app
2. Tap "Register" link
3. Fill in all fields
4. Watch real-time password validation
5. Tap "Register" button
6. Should navigate to home screen

---

## Common Issues & Solutions

### ❌ Database Connection Error

**Error:** `could not connect to server`

**Solution:**
1. Check if PostgreSQL is running
2. Verify DATABASE_URL in `.env` has correct password
3. Ensure database `swasth_db` exists

### ❌ Port Already in Use

**Error:** `Address already in use`

**Solution:** Change port in `backend/main.py`:
```python
uvicorn.run(app, host="0.0.0.0", port=8001)  # Changed from 8000 to 8001
```

### ❌ Connection Refused (Flutter)

**Error:** `Connection refused` or `Network request failed`

**Solutions:**
- **Android Emulator**: Change API URL to `http://10.0.2.2:8000`
- **Physical Device**: 
  - Make sure computer and device are on same WiFi
  - Use your computer's IP: `http://192.168.x.x:8000`
  - May need to allow through Windows Firewall

### ❌ Password Validation Errors

**Requirements:**
- Minimum 8 characters ✓
- At least 1 uppercase letter ✓
- At least 1 lowercase letter ✓
- At least 1 number ✓
- At least 1 special character (!@#$%^&* etc.) ✓

**Example valid password:** `SecurePass123!`

---

## Project Overview

```
┌─────────────┐         ┌──────────────┐
│  Flutter    │◄───────►│   FastAPI    │
│  Mobile App │  HTTP   │   Backend    │
│             │  JSON   │              │
└─────────────┘         └──────┬───────┘
                               │
                               ▼
                        ┌──────────────┐
                        │  PostgreSQL  │
                        │   Database   │
                        └──────────────┘
```

### Features Implemented

✅ **User Registration** with comprehensive health profile
✅ **Login** with JWT authentication  
✅ **Real-time Password Validation** with visual feedback
✅ **Medical Conditions** multi-select with "Other" option
✅ **Form Validation** (frontend & backend)
✅ **Password Hashing** with bcrypt
✅ **Email Uniqueness** check
✅ **Material Design 3** UI

---

## What's Next?

After getting the app running:

1. **Explore the API** at http://localhost:8000/docs
2. **Customize the UI** colors in `lib/main.dart`
3. **Add token storage** using flutter_secure_storage
4. **Implement profile editing** functionality
5. **Connect BLE features** with user profiles

---

## File Structure Quick Reference

### Backend
```
backend/
├── main.py           # FastAPI app entry point
├── config.py         # Configuration
├── database.py       # DB connection
├── models.py         # Database models (User table)
├── schemas.py        # Request/Response schemas
├── auth.py           # Password hashing & JWT
├── routes.py         # API endpoints
└── .env              # Environment variables (create this)
```

### Frontend
```
lib/
├── main.dart                    # Flutter app entry
├── screens/
│   ├── login_screen.dart       # Login UI
│   ├── registration_screen.dart # Registration UI
│   └── home_screen.dart        # Home after login
├── services/
│   └── api_service.dart        # API calls
└── models/
    └── user_model.dart         # User data model
```

---

## Support

Having issues? Check:
- 📖 `SETUP_GUIDE.md` - Detailed setup instructions
- 📡 `API_DOCUMENTATION.md` - Complete API reference
- 🔍 http://localhost:8000/docs - Interactive API docs

---

**Happy Coding! 🚀**
