# Swasth Health App - Flutter App Startup Script (PowerShell)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Swasth Health App - Flutter Startup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ── Check Flutter ─────────────────────────────────────────────────────────
try {
    flutter --version | Out-Null
    Write-Host "[OK] Flutter found." -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Flutter not found in PATH." -ForegroundColor Red
    Write-Host "Install from: https://docs.flutter.dev/get-started/install"
    pause; exit 1
}

# ── Check ADB ─────────────────────────────────────────────────────────────
$adbPath = "$env:LOCALAPPDATA\Android\Sdk\platform-tools"
if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    $env:PATH += ";$adbPath"
}
if (Get-Command adb -ErrorAction SilentlyContinue) {
    Write-Host "[OK] ADB found." -ForegroundColor Green
} else {
    Write-Host "[ERROR] ADB not found. Add platform-tools to PATH." -ForegroundColor Red
    pause; exit 1
}

Write-Host ""

# ── Flutter pub get ───────────────────────────────────────────────────────
Write-Host "Step 1: Installing Flutter dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] flutter pub get failed." -ForegroundColor Red
    pause; exit 1
}
Write-Host "[OK] Dependencies installed." -ForegroundColor Green
Write-Host ""


$pair = Read-Host "Pair a new Android device wirelessly? (y/n, default=n)"
if ($pair -eq "y") {
    Write-Host ""
    Write-Host "On your phone: Settings > Developer Options > Wireless Debugging"
    Write-Host "Tap 'Pair device with pairing code' and note the IP:PORT and 6-digit code."
    Write-Host ""
    $pairAddr = Read-Host "Enter pairing IP:PORT shown on phone (e.g. 10.0.0.136:40649)"
    adb pair $pairAddr
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Paired!" -ForegroundColor Green
        $connAddr = Read-Host "Enter connect IP:PORT from main Wireless Debugging screen"
        adb connect $connAddr
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Connected!" -ForegroundColor Green
        }
    }
    Start-Sleep -Seconds 3
}



# ── Server host ───────────────────────────────────────────────────────────
$serverHost = ""
while ($serverHost -eq "") {
    $serverHost = Read-Host "Enter backend server IP:PORT (e.g. 10.0.0.189:8000)"
    if ($serverHost -eq "") {
        Write-Host "[ERROR] Server host cannot be empty." -ForegroundColor Red
    }
}

flutter run --dart-define="SERVER_HOST=http://$serverHost"
