Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  POSQUPRO MOBILE - Clean & Run (Windows)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Stop running app
Write-Host "[0/4] Stopping running app..." -ForegroundColor Yellow
Get-Process -Name posqupro_mobile -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

# Full clean + regenerate
Write-Host "[1/4] Full clean + regenerate..." -ForegroundColor Yellow
$dirs = @("build", ".dart_tool", "windows\flutter\ephemeral")
foreach ($d in $dirs) {
    if (Test-Path $d) { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue }
}
flutter create --platforms=windows . 2>&1 | Out-Null
flutter pub get
if ($LASTEXITCODE -ne 0) { Write-Host "ERROR: flutter pub get failed" -ForegroundColor Red; pause; exit 1 }

# Analyze
Write-Host ""
Write-Host "[2/4] Analyzing code..." -ForegroundColor Yellow
flutter analyze
Write-Host ""

# Build
Write-Host "[3/4] Building release..." -ForegroundColor Yellow
flutter build windows --release
if ($LASTEXITCODE -ne 0) { Write-Host "BUILD FAILED" -ForegroundColor Red; pause; exit 1 }

# Run
Write-Host ""
Write-Host "[4/4] Starting app..." -ForegroundColor Green
Start-Process "build\windows\x64\runner\Release\posqupro_mobile.exe"
Write-Host "App started!" -ForegroundColor Green
