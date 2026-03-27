@echo off
setlocal enabledelayedexpansion

echo ========================================
echo  Swasth Health App - Flutter Startup
echo ========================================
echo.

REM ── Check Flutter ─────────────────────────────────────────────────────────
flutter --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Flutter not found in PATH.
    echo Install from: https://docs.flutter.dev/get-started/install
    pause & exit /b 1
)
echo [OK] Flutter found.

REM ── Check ADB ─────────────────────────────────────────────────────────────
adb version >nul 2>&1
if errorlevel 1 (
    set "PATH=%PATH%;%LOCALAPPDATA%\Android\Sdk\platform-tools"
    adb version >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] ADB not found. Add platform-tools to PATH.
        pause & exit /b 1
    )
)
echo [OK] ADB found.
echo.

REM ── Flutter pub get ───────────────────────────────────────────────────────
echo Step 1: Installing Flutter dependencies...
flutter pub get
if errorlevel 1 (
    echo [ERROR] flutter pub get failed.
    pause & exit /b 1
)
echo [OK] Dependencies installed.
echo.

REM ── Android wireless pairing ──────────────────────────────────────────────
set /p pair="Pair a new Android device wirelessly? (y/n, default=n): "
if /i "%pair%"=="y" (
    echo.
    echo On your phone: Settings ^> Developer Options ^> Wireless Debugging
    echo Tap 'Pair device with pairing code' and note the IP:PORT and 6-digit code.
    echo.
    set /p pairAddr="Enter pairing IP:PORT shown on phone (e.g. 10.0.0.136:40649): "
    adb pair !pairAddr!
    if not errorlevel 1 (
        echo [OK] Paired!
        echo.
        set /p connAddr="Enter connect IP:PORT from main Wireless Debugging screen: "
        adb connect !connAddr!
        if not errorlevel 1 (
            echo [OK] Connected!
        )
    )
    timeout /t 3 /nobreak >nul
)
echo.

REM ── Server host ───────────────────────────────────────────────────────────
:ask_host
set serverHost=
set /p serverHost="Enter backend server IP:PORT (e.g. 10.0.0.189:8000): "
if "!serverHost!"=="" (
    echo [ERROR] Server host cannot be empty.
    goto ask_host
)

REM ── Run Flutter app on Android ────────────────────────────────────────────
echo.
echo Starting Flutter app...
flutter run --dart-define="SERVER_HOST=http://!serverHost!"

pause