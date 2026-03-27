# Swasth Health App

A comprehensive health monitoring mobile application built with Flutter and FastAPI backend, featuring user authentication, health profile management, and Bluetooth Low Energy (BLE) device integration.

![Flutter](https://img.shields.io/badge/Flutter-3.11+-blue?logo=flutter)
![FastAPI](https://img.shields.io/badge/FastAPI-0.104+-green?logo=fastapi)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-14+-blue?logo=postgresql)
![Python](https://img.shields.io/badge/Python-3.8+-blue?logo=python)

## 🌟 Features

### User Authentication & Profile Management
- ✅ **User Registration** with comprehensive health profile
- ✅ **Login** with JWT token authentication
- ✅ **Real-time Password Validation** with visual feedback indicators
- ✅ **Email Uniqueness** verification
- ✅ **Secure Password Hashing** using bcrypt

### Health Profile Fields
- 📧 Email & Password (with validation)
- 👤 Full Name
- 📱 Phone Number
- 🎂 Age
- ⚧ Gender (Male / Female / Other)
- 📏 Height (cm)
- ⚖️ Weight (kg)
- 🩸 Blood Group (A+, A-, B+, B-, O+, O-, AB+, AB-)
- 💊 Current Medications (comma-separated list)
- 🏥 Medical Conditions (Multi-select):
  - Diabetes T1
  - Diabetes T2
  - Hypertension
  - Heart Disease
  - None
  - Other (with text field for details)

### Password Security Requirements
- Minimum 8 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one number
- At least one special character (!@#$%^&* etc.)

### Mobile App Features
- 🎨 Material Design 3 UI
- 📝 Comprehensive form validation
- 🔄 Real-time password strength indicators
- ✅ Conditional form fields (e.g., "Other" medical condition)
- 📱 Responsive design
- 🔒 Secure authentication flow
- 💙 Bluetooth Low Energy (BLE) ready for device integration

## 🏗️ Architecture

```
┌─────────────────┐
│   Flutter       │
│   Mobile App    │
│  (Frontend)     │
└────────┬────────┘
         │ HTTP/JSON
         │ REST API
         ▼
┌─────────────────┐
│   FastAPI       │
│   Backend       │
│  (API Server)   │
└────────┬────────┘
         │ SQLAlchemy
         ▼
┌─────────────────┐
│   PostgreSQL    │
│   Database      │
└─────────────────┘
```

## 📋 Prerequisites

### Backend
- Python 3.8 or higher
- PostgreSQL 14 or higher
- pip (Python package manager)

### Frontend
- Flutter SDK 3.11 or higher
- Dart SDK 3.11 or higher
- Android Studio / VS Code
- Android Emulator or Physical Device

## 🚀 Quick Start

Get up and running in 5 minutes! See [QUICKSTART.md](QUICKSTART.md)

### Backend Setup (Summary)
```bash
cd backend
pip install -r requirements.txt
# Create PostgreSQL database: swasth_db
# Copy .env.example to .env and update credentials
python init_db.py
python main.py
```

### Frontend Setup (Summary)
```bash
flutter pub get
# Update API URL in lib/services/api_service.dart if needed
flutter run
```

## 📚 Documentation

- **[Quick Start Guide](QUICKSTART.md)** - Get started in 5 minutes
- **[Setup Guide](SETUP_GUIDE.md)** - Detailed setup instructions
- **[API Documentation](API_DOCUMENTATION.md)** - Complete API reference

## 🗂️ Project Structure

```
swasth_app/
├── backend/                    # FastAPI Backend
│   ├── main.py                # Application entry point
│   ├── config.py              # Configuration settings
│   ├── database.py            # Database connection
│   ├── models.py              # SQLAlchemy models
│   ├── schemas.py             # Pydantic schemas
│   ├── auth.py                # Authentication utilities
│   ├── routes.py              # API routes
│   ├── init_db.py             # Database initialization
│   ├── requirements.txt       # Python dependencies
│   └── .env.example           # Environment template
│
├── lib/                       # Flutter Frontend
│   ├── main.dart              # App entry point
│   ├── screens/
│   │   ├── login_screen.dart
│   │   ├── registration_screen.dart
│   │   ├── home_screen.dart
│   │   └── dashboard_screen.dart
│   ├── services/
│   │   └── api_service.dart   # API integration
│   └── models/
│       └── user_model.dart    # Data models
│
├── test/                      # Test files
├── QUICKSTART.md              # Quick start guide
├── SETUP_GUIDE.md             # Detailed setup
├── API_DOCUMENTATION.md       # API docs
└── README.md                  # This file
```

## 🔌 API Endpoints

### Authentication

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Register new user |
| POST | `/api/auth/login` | Login user |
| GET | `/api/auth/me` | Get current user (protected) |

### Health Check

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Check API status |

**Interactive API Documentation:** http://localhost:8000/docs

## 🛠️ Technology Stack

### Backend
- **Framework:** FastAPI
- **Database:** PostgreSQL
- **ORM:** SQLAlchemy
- **Validation:** Pydantic
- **Authentication:** JWT (python-jose)
- **Password Hashing:** bcrypt (passlib)
- **Server:** Uvicorn

### Frontend
- **Framework:** Flutter
- **State Management:** Provider (can be extended with Riverpod)
- **HTTP Client:** http package
- **UI Components:** Material Design 3
- **Storage:** flutter_secure_storage (for tokens)

## 🧪 Testing

### Test Backend API

Using Swagger UI at http://localhost:8000/docs or cURL:

```bash
# Register
curl -X POST "http://localhost:8000/api/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "SecurePass123!",
    "full_name": "Test User",
    "phone_number": "1234567890",
    "age": 25,
    "gender": "Male",
    "height": 170.0,
    "weight": 65.0,
    "blood_group": "O+",
    "medical_conditions": ["None"]
  }'

# Login
curl -X POST "http://localhost:8000/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "SecurePass123!"
  }'
```

### Test Flutter App

```bash
# Run tests
flutter test

# Run on device
flutter run
```

## 🔐 Security Features

- ✅ Password hashing with bcrypt
- ✅ JWT token authentication
- ✅ Email uniqueness validation
- ✅ Input validation (frontend + backend)
- ✅ CORS configuration
- ✅ SQL injection protection (SQLAlchemy ORM)
- 🔒 Token storage (recommended: flutter_secure_storage)
- 🔒 HTTPS (production deployment)

## 📱 Mobile App Screenshots

The app includes:
1. **Login Screen** - Clean, simple login with email/password
2. **Registration Screen** - Comprehensive health profile form
3. **Home Screen** - Dashboard after successful login

Features:
- Real-time password validation with visual indicators
- Dropdown selections for gender and blood group
- Multi-select checkboxes for medical conditions
- Conditional text field for "Other" medical condition
- Loading states and error handling
- Material Design 3 theming

## 🚧 Future Enhancements

- [ ] Token refresh mechanism
- [ ] Password reset functionality
- [ ] Email verification
- [ ] Profile editing
- [ ] BLE device integration
- [ ] Health data visualization
- [ ] Offline mode
- [ ] Push notifications
- [ ] Multi-language support
- [ ] Dark mode

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is proprietary software. All rights reserved.

## 👥 Support

For issues and questions:
- Check documentation files
- Review API docs at http://localhost:8000/docs
- Open an issue on GitHub

## 🎯 Key Highlights

✨ **Comprehensive Health Profile**: Captures detailed user health information
✨ **Real-time Validation**: Instant feedback on password requirements
✨ **Modern UI**: Material Design 3 with smooth animations
✨ **Secure Backend**: Industry-standard security practices
✨ **Well Documented**: Extensive documentation for easy setup
✨ **Production Ready**: Robust error handling and validation

---

**Built with ❤️ using Flutter and FastAPI**
