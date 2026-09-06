Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  POSQUPRO MOBILE - Windows Audit & Test" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Continue"
$hasError = $false

function Write-Step($step, $total, $msg) {
    Write-Host "[$step/$total] $msg" -ForegroundColor Yellow
}

function Write-OK($msg) {
    Write-Host "       $msg" -ForegroundColor Green
}

function Write-Fail($msg) {
    Write-Host "       $msg" -ForegroundColor Red
    $script:hasError = $true
}

# Step 1: Stop running app
Write-Step 1 8 "Stopping running app..."
Get-Process -Name posqupro_mobile -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
Write-OK "OK"

# Step 2: Check Flutter
Write-Step 2 8 "Checking Flutter installation..."
try {
    $ver = flutter --version 2>&1 | Select-String "Flutter" | Select-Object -First 1
    Write-OK "Found: $ver"
} catch {
    Write-Fail "Flutter not found in PATH"
    pause; exit 1
}

# Step 3: Check Windows build tools
Write-Step 3 8 "Checking Windows build tools..."
$cmake = Get-Command cmake -ErrorAction SilentlyContinue
$cl = Get-Command cl -ErrorAction SilentlyContinue
if ($cmake) { Write-OK "cmake: $($cmake.Source)" } else { Write-Host "       WARNING: cmake not found" -ForegroundColor Yellow }
if ($cl) { Write-OK "cl.exe: $($cl.Source)" } else { Write-Host "       WARNING: MSVC cl.exe not found (may use Ninja)" -ForegroundColor Yellow }

# Step 4: Clean build
Write-Step 4 8 "Cleaning build artifacts..."
$dirs = @("build", ".dart_tool", "windows\flutter\ephemeral", ".flutter-plugins-dependencies")
foreach ($d in $dirs) {
    if (Test-Path $d) {
        Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue
    }
}
Write-OK "Cleaned"

# Step 5: Regenerate Windows platform
Write-Step 5 8 "Regenerating Windows platform..."
$output = flutter create --platforms=windows . 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Fail "flutter create failed: $output"
    pause; exit 1
}
Write-OK "OK"

# Step 6: Get dependencies
Write-Step 6 8 "Getting dependencies..."
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Fail "flutter pub get failed"
    pause; exit 1
}
Write-OK "OK"

# Step 7: Analyze code
Write-Step 7 8 "Analyzing code..."
flutter analyze
Write-Host ""

# Step 8: Build release
Write-Step 8 8 "Building Windows release..."
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Fail "BUILD FAILED!"
    Write-Host "       Try: flutter clean; flutter create --platforms=windows .; flutter pub get" -ForegroundColor Yellow
    pause; exit 1
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  BUILD SUCCESS!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Exe: build\windows\x64\runner\Release\posqupro_mobile.exe" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

$run = Read-Host "Run app now? (y/n)"
if ($run -eq "y" -or $run -eq "Y") {
    Start-Process "build\windows\x64\runner\Release\posqupro_mobile.exe"
}

pause
