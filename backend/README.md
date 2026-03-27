# Swasth Health App - Backend

FastAPI backend for user authentication and registration with PostgreSQL database.

## Setup Instructions

### 1. Install Python Dependencies

```bash
cd backend
pip install -r requirements.txt
```

### 2. Set Up PostgreSQL Database

1. Install PostgreSQL from https://www.postgresql.org/download/
2. Create a database:
```sql
CREATE DATABASE swasth_db;
```

3. Update the `.env` file with your database credentials:
```bash
cp .env.example .env
```

Edit `.env` and update:
- `DATABASE_URL` with your PostgreSQL credentials
- `SECRET_KEY` with a secure random string (at least 32 characters)

### 3. Run the Backend Server

```bash
python main.py
```

The API will be available at `http://localhost:8000`

## API Endpoints

### Authentication

- **POST** `/api/auth/register` - Register a new user
- **POST** `/api/auth/login` - Login user
- **GET** `/api/auth/me` - Get current user info (requires authentication)

### Health Check

- **GET** `/health` - Check API health status

## API Documentation

Once the server is running, visit:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Example Usage

### Register a User

```bash
curl -X POST "http://localhost:8000/api/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "SecurePass123!",
    "confirm_password": "SecurePass123!",
    "full_name": "John Doe",
    "phone_number": "1234567890",
    "age": 30,
    "gender": "Male",
    "height": 175.5,
    "weight": 70.5,
    "blood_group": "O+",
    "medical_conditions": ["None"]
  }'
```

### Login

```bash
curl -X POST "http://localhost:8000/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "SecurePass123!"
  }'
```
