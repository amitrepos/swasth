# Swasth App - Project Structure & Context

## 🎯 Project Overview
Swasth App is a Flutter-based health management system with a FastAPI (Python) backend. 
It supports multi-profile management, health data scanning, and access sharing.

## 📂 Directory Map

### 📱 Frontend (Flutter) - /lib
- **/models**: Data schemas (e.g., `profile_model.dart`, `invite_model.dart`).
- **/screens**: UI Layers. Key logic for multi-profile is in `select_profile_screen.dart` and `manage_access_screen.dart`.
- **/services**: API wrappers and local persistence (e.g., `profile_service.dart`, `storage_service.dart`).

### ⚙️ Backend (FastAPI) - /backend
- **main.py**: Application entry point and middleware.
- **routes.py**: Core logic for user authentication and general features.
- **routes_health.py**: Specialized logic for processing health metrics and scans.

### 📄 Documentation & State
- **AUDIT.md**: Tracks security and code quality checks.
- **TASK_A2_MULTI_PROFILE.md**: Current feature roadmap and requirements.
- **Updates.md**: Recent changelog for AI context.

## 🔗 Key Data Flow
1. User logs in via `login_screen.dart`.
2. App fetches profiles via `profile_service.dart` from `backend/routes.py`.
3. Health data is sent to `backend/routes_health.py` for processing.
