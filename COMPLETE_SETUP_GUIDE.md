# Complete Setup Guide - Swasth Health App

This comprehensive guide will walk you through setting up the Swasth Health App from scratch. Follow each step carefully to get your development environment ready.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Step 1: Install Development Tools](#step-1-install-development-tools)
3. [Step 2: Clone/Download the Project](#step-2-clonedownload-the-project)
4. [Step 3: Backend Setup (FastAPI + PostgreSQL)](#step-3-backend-setup-fastapi--postgresql)
5. [Step 4: Frontend Setup (Flutter)](#step-4-frontend-setup-flutter)
6. [Step 5: Running the Application](#step-5-running-the-application)
7. [Step 6: Testing & Verification](#step-6-testing--verification)
8. [Troubleshooting](#troubleshooting)
9. [Next Steps](#next-steps)

---

## Prerequisites

Before starting, ensure you have:
- Windows 10/11 operating system
- Administrator access to install software
- Stable internet connection
- At least 5GB of free disk space
- Basic knowledge of terminal/command prompt

---

## Step 1: Install Development Tools

### 1.1 Install Python (3.8 or higher)

**Why:** The backend is built with FastAPI, which requires Python.

**Steps:**

1. **Download Python:**
   - Visit https://www.python.org/downloads/
   - Download the latest Python version (3.8+)

2. **Install Python:**
   - Run the installer
   - ✅ **IMPORTANT:** Check "Add Python to PATH" during installation
   - Click "Install Now"

3. **Verify Installation:**
   ```bash
   python --version
   # Should show: Python 3.8.x or higher
   ```

### 1.2 Install PostgreSQL (14 or higher)

**Why:** The database that stores user information.

**Steps:**

1. **Download PostgreSQL:**
   - Visit https://www.postgresql.org/download/windows/
   - Download the installer (version 14+)

2. **Install PostgreSQL:**
   - Run the installer
   - Set a **strong password** for the `postgres` superuser (remember this!)
   - Keep default port: 5432
   - Install pgAdmin 4 (included)

3. **Verify Installation:**
   ```bash
   psql --version
   # Should show: psql (PostgreSQL) 14.x.x
   ```

### 1.3 Install Flutter SDK (3.11 or higher)

**Why:** The mobile app framework.

**Steps:**

1. **Download Flutter:**
   - Visit https://docs.flutter.dev/get-started/install/windows
   - Download the Flutter SDK

2. **Extract Flutter:**
   - Extract to a folder (e.g., `C:\src\flutter`)
   - Avoid folders with spaces in the path

3. **Add Flutter to PATH:**
   - Press `Win + R`, type `sysdm.cpl`, press Enter
   - Click "Advanced" → "Environment Variables"
   - Under "User variables", find `Path`, click "Edit"
   - Click "New" and add: `C:\src\flutter\bin` (or your Flutter path)
   - Click "OK" to save

4. **Verify Installation:**
   ```bash
   flutter doctor
   # This will check your setup and show any issues
   ```

5. **Accept Android Licenses:**
   ```bash
   flutter doctor --android-licenses
   # Accept all licenses by typing 'y'
   ```

### 1.4 Install VS Code (Recommended IDE)

**Why:** A lightweight code editor with great Flutter/Python support.

**Steps:**

1. **Download VS Code:**
   - Visit https://code.visualstudio.com/
   - Download and install

2. **Install Extensions:**
   - Open VS Code
   - Go to Extensions (Ctrl+Shift+X)
   - Install these extensions:
     - Flutter
     - Dart
     - Python
     - Pylance
     - PostgreSQL Viewer (optional)

---

## Step 2: Clone/Download the Project

### Option A: Using Git (Recommended)

1. **Install Git (if not already installed):**
   - Visit https://git-scm.com/download/win
   - Download and install with default settings

2. **Clone the Repository:**
   ```bash
   # Navigate to where you want to store the project
   cd C:\Users\YourUsername\Documents
   
   # Clone the repository
   git clone <your-repository-url> swasth_app
   
   # Navigate into the project
   cd swasth_app
   ```

### Option B: Manual Download

1. **Download ZIP:**
   - Download the project ZIP file
   - Extract to a folder (e.g., `C:\Users\YourUsername\Documents\swasth_app`)

2. **Open Folder:**
   ```bash
   cd C:\Users\YourUsername\Documents\swasth_app
   ```

---

## Step 3: Backend Setup (FastAPI + PostgreSQL)

### 3.1 Create PostgreSQL Database

**Method 1: Using pgAdmin (GUI)**

1. Open pgAdmin 4 from Start Menu
2. Connect to PostgreSQL (use password you set during installation)
3. Right-click on "Databases" → "Create" → "Database"
4. Name: `swasth_db`
5. Owner: `postgres`
6. Click "Save"

**Method 2: Using Command Line**

```bash
# Open PowerShell or Command Prompt as Administrator
psql -U postgres

# Inside psql, run:
CREATE DATABASE swasth_db;
\q
```

### 3.2 Install Python Dependencies

```bash
# Navigate to backend folder
cd backend

# Create virtual environment (recommended)
python -m venv venv

# Activate virtual environment
# For PowerShell:
.\venv\Scripts\Activate.ps1

# For Command Prompt:
.\venv\Scripts\activate.bat

# You should see (venv) at the beginning of your prompt now

# Install dependencies
pip install -r requirements.txt
```

**Expected Output:**
```
Collecting fastapi>=0.104.0
  Downloading fastapi...
Successfully installed fastapi-0.104.1 uvicorn-0.24.0 ...
```

### 3.3 Configure Environment Variables

```bash
# Still in backend folder
copy .env.example .env
```

Now edit the `.env` file with your actual values:

```env
# Database Configuration
DATABASE_URL=postgresql://postgres:YOUR_PASSWORD@localhost:5432/swasth_db

# Security Settings
SECRET_KEY=your-super-secret-key-min-32-characters-long-random-string
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# Brevo SMTP Configuration (optional - for sending emails)
BREVO_SMTP_SERVER=smtp-relay.brevo.com
BREVO_SMTP_PORT=587
BREVO_SENDER_EMAIL=your-brevo-email
BREVO_SMTP_PASSWORD=your-brevo-password
BREVO_SENDER_NAME=Swasth Health App

# OTP Settings
OTP_EXPIRE_MINUTES=10

# Application Settings
PROJECT_NAME=Swasth Health App API
VERSION=1.0.0
```

**Important Notes:**
- Replace `YOUR_PASSWORD` with your actual PostgreSQL password
- Generate a random SECRET_KEY (use at least 32 characters)
- Example SECRET_KEY: `a8f5f167f44f4964e6c998dee827110c3b2b3b91f1234567890abcdef`

### 3.4 Initialize Database Tables

```bash
# Make sure you're in the backend folder
python init_db.py
```

**Expected Output:**
```
Creating database tables...
✓ Database tables created successfully!

Tables created:
- users

You can now start the backend server with: python main.py
```

### 3.5 Verify Backend Setup

```bash
# Start the backend server
python main.py
```

**Expected Output:**
```
==================================================
Swasth Health App API Server
==================================================
Host: 0.0.0.0
Port: 8000
Local URL: http://localhost:8000
Mobile URL: http://0.0.0.0:8000
API Docs: http://localhost:8000/docs
==================================================

INFO:     Started server process [12345]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
```

✅ **Success!** Your backend is running at http://localhost:8000

Open your browser and visit:
- **API Home:** http://localhost:8000
- **Interactive API Docs:** http://localhost:8000/docs
- **Health Check:** http://localhost:8000/health

**Stop the server** by pressing `Ctrl+C` in the terminal.

---

## Step 4: Frontend Setup (Flutter)

### 4.1 Install Flutter Dependencies

Open a **NEW terminal** (keep the backend terminal separate):

```bash
# Navigate to the project root
cd C:\Users\YourUsername\Documents\swasth_app

# Get Flutter dependencies
flutter pub get
```

**Expected Output:**
```
Running "flutter pub get" in swasth_app...
Resolving dependencies...
Got dependencies!
```

### 4.2 Configure Environment Variables (Optional)

```bash
# Copy example env file
copy .env.example .env
```

Edit `.env` if needed:

```env
# Backend Server Configuration
SERVER_HOST=http://YOUR_IP_ADDRESS:8000
# Example: SERVER_HOST=http://192.168.1.100:8000
```

**Finding Your IP Address:**
```bash
# In PowerShell or Command Prompt
ipconfig
# Look for "IPv4 Address" under your network adapter
```

**When to Update SERVER_HOST:**
- **Android Emulator:** Use `http://10.0.2.2:8000`
- **iOS Simulator:** Use `http://localhost:8000`
- **Physical Device:** Use your computer's IP (e.g., `http://192.168.1.100:8000`)

### 4.3 Check Connected Devices

```bash
# List available devices
flutter devices
```

**Expected Output:**
```
1 connected device:
Chrome (web) • chrome • web-javascript • Google Chrome 120.0.6099.200
```

**For Android Device:**
- Enable USB Debugging on your Android phone
- Connect via USB
- Authorize the computer on your phone

**For Android Emulator:**
- Open Android Studio
- Go to AVD Manager
- Create/Start an emulator

### 4.4 Run Flutter App

```bash
# Make sure you're in the project root
flutter run
```

**If you have multiple devices:**
```bash
# Choose a specific device
flutter run -d chrome
# or
flutter run -d <device-id>
```

**Expected Output:**
```
Launching lib\main.dart on Chrome in debug mode...
Waiting for connection from debug service on Chrome...
Syncing files to device Chrome...
Compiled 1,234,567 bytes

Flutter Web Bootstrap
  Loading entrypoint...
  Done loading

Application finished.
```

The app should launch automatically in your browser/emulator/device.

✅ **Success!** Your Flutter app is running!

---

## Step 5: Running the Application

### Starting Both Services

You need **TWO terminals** running simultaneously:

**Terminal 1 - Backend:**
```bash
cd backend
.\venv\Scripts\Activate.ps1  # Activate Python virtual environment
python main.py
```

**Terminal 2 - Frontend:**
```bash
flutter pub get  # Only needed first time or if dependencies change
flutter run
```

### Alternative: Using Batch Files

The project includes convenience scripts:

**Start Backend:**
```bash
cd backend
start_backend.bat
```

**Start Flutter:**
```bash
start_flutter_app.bat
```

---

## Step 6: Testing & Verification

### 6.1 Test Backend API (Swagger UI)

1. Open http://localhost:8000/docs
2. Expand `POST /api/auth/register`
3. Click "Try it out"
4. Fill in test data:

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
6. Look for status code **201** (Created)

### 6.2 Test Login

1. In Swagger UI, expand `POST /api/auth/login`
2. Click "Try it out"
3. Enter credentials:

```json
{
  "email": "test@example.com",
  "password": "SecurePass123!"
}
```

4. Click "Execute"
5. You should receive a JWT token

### 6.3 Test Flutter App

1. Launch the app
2. Tap "Register" link
3. Fill in the registration form
4. Watch real-time password validation
5. Submit the form
6. Should navigate to home screen

---

## Troubleshooting

### Backend Issues

#### ❌ Database Connection Error

**Error:** `could not connect to server: Connection refused`

**Solutions:**
1. Verify PostgreSQL is running:
   ```bash
   # Check if PostgreSQL service is running
   Get-Service postgresql*
   ```

2. Check DATABASE_URL in `.env`:
   - Ensure password is correct
   - Ensure database name is `swasth_db`
   - Ensure port is 5432

3. Restart PostgreSQL service:
   ```bash
   Restart-Service postgresql-x64-14
   ```

#### ❌ Port Already in Use

**Error:** `Address already in use`

**Solution:** Change the port in `backend/main.py`:

```python
uvicorn.run(app, host="0.0.0.0", port=8001)  # Changed from 8000 to 8001
```

Also update Flutter app's API URL accordingly.

#### ❌ Module Not Found Error

**Error:** `ModuleNotFoundError: No module named 'fastapi'`

**Solution:**
```bash
# Make sure virtual environment is activated
cd backend
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### Frontend Issues

#### ❌ Connection Refused

**Error:** `Connection refused` or `Network request failed`

**Solutions:**

**For Android Emulator:**
- Update API URL in `lib/services/api_service.dart`:
  ```dart
  static const String baseUrl = 'http://10.0.2.2:8000';
  ```

**For Physical Device:**
1. Ensure both computer and phone are on the same WiFi network
2. Use your computer's IP address:
   ```bash
   ipconfig
   # Use IPv4 Address
   ```
3. Update `.env`:
   ```env
   SERVER_HOST=http://192.168.1.100:8000
   ```
4. Allow through Windows Firewall if needed

#### ❌ Flutter Doctor Shows Issues

**Run:**
```bash
flutter doctor
```

Follow the recommendations shown. Common fixes:

```bash
# Accept Android licenses
flutter doctor --android-licenses

# Update Flutter
flutter upgrade

# Check for Flutter issues
flutter doctor -v
```

#### ❌ Gradle Build Failed

**Solution:**
```bash
# Navigate to android folder
cd android

# Clean build
./gradlew clean

# Go back and rebuild
cd ..
flutter clean
flutter pub get
flutter run
```

### General Issues

#### ❌ Password Validation Errors

**Requirements:**
- ✅ Minimum 8 characters
- ✅ At least 1 uppercase letter
- ✅ At least 1 lowercase letter
- ✅ At least 1 number
- ✅ At least 1 special character (!@#$%^&*)

**Example valid password:** `SecurePass123!`

#### ❌ Email Already Exists

**Error:** "Email already registered"

**Solution:** Use a different email or delete the existing user from database:

```sql
-- In pgAdmin or psql
DELETE FROM users WHERE email = 'test@example.com';
```

---

## Next Steps

After successful setup:

### 1. Explore the Codebase

**Backend:**
- `backend/models.py` - Database schema
- `backend/schemas.py` - Request/response validation
- `backend/routes.py` - API endpoints
- `backend/auth.py` - Authentication logic

**Frontend:**
- `lib/screens/` - UI screens
- `lib/services/` - API integration
- `lib/models/` - Data models
- `lib/widgets/` - Reusable components

### 2. Customize the App

- Change app theme colors in `lib/main.dart`
- Modify API endpoints in `lib/services/api_service.dart`
- Add new features to the backend
- Extend the database schema

### 3. Learn More

- **Interactive API Docs:** http://localhost:8000/docs
- **Flutter Documentation:** https://docs.flutter.dev
- **FastAPI Documentation:** https://fastapi.tiangolo.com
- **PostgreSQL Documentation:** https://www.postgresql.org/docs/

### 4. Development Workflow

1. Make changes to backend or frontend code
2. Hot reload Flutter app (`r` in terminal or Ctrl+S)
3. Backend auto-reloads on save (if using uvicorn with reload)
4. Test changes immediately

### 5. Deploy to Production

When ready to deploy:
- Set up production database (PostgreSQL on cloud)
- Configure environment variables securely
- Use HTTPS for API communication
- Implement proper CORS settings
- Set up monitoring and logging

---

## Additional Resources

### Useful Commands

**Backend:**
```bash
# Activate virtual environment
cd backend
.\venv\Scripts\Activate.ps1

# Run backend server
python main.py

# Install new package
pip install package-name

# View installed packages
pip list
```

**Frontend:**
```bash
# Get dependencies
flutter pub get

# Run app
flutter run

# Build APK
flutter build apk

# Build for web
flutter build web

# Clean build artifacts
flutter clean

# Check for Flutter updates
flutter upgrade
```

### File Structure Reference

```
swasth_app/
├── backend/                    # FastAPI Backend
│   ├── main.py                # Entry point
│   ├── config.py              # Configuration
│   ├── database.py            # DB connection
│   ├── models.py              # SQLAlchemy models
│   ├── schemas.py             # Pydantic schemas
│   ├── auth.py                # Auth utilities
│   ├── routes.py              # API routes
│   ├── init_db.py             # DB initialization
│   ├── requirements.txt       # Python deps
│   └── .env                   # Environment vars
│
├── lib/                       # Flutter Frontend
│   ├── main.dart              # Entry point
│   ├── screens/               # UI screens
│   ├── services/              # API calls
│   ├── models/                # Data models
│   ├── widgets/               # Reusable widgets
│   ├── ble/                   # Bluetooth LE
│   └── config/                # App config
│
├── android/                   # Android-specific
├── ios/                       # iOS-specific
├── web/                       # Web build files
├── test/                      # Test files
├── .env                       # Root env vars
├── pubspec.yaml               # Flutter deps
└── README.md                  # Project info
```

---

## Support

If you encounter issues:

1. Check this guide thoroughly
2. Review error messages carefully
3. Check the interactive API docs at http://localhost:8000/docs
4. Review the README.md file
5. Search for similar issues online

**Common Resources:**
- Stack Overflow
- Flutter Discord
- FastAPI GitHub Discussions
- PostgreSQL Documentation

---

**Congratulations! 🎉**

You've successfully set up the Swasth Health App! You now have a fully functional health monitoring application with user authentication, profile management, and BLE capabilities.

Happy coding! 🚀
