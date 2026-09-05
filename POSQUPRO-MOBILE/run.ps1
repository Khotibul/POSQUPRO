Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  POSQUPRO MOBILE - Clean & Run" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[0/4] Stopping running app..." -ForegroundColor Yellow
Get-Process -Name posqupro_mobile -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

Write-Host "[1/4] Cleaning build artifacts..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) { Write-Host "ERROR: flutter clean failed" -ForegroundColor Red; pause; exit 1 }

Write-Host ""
Write-Host "[2/4] Getting dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) { Write-Host "ERROR: flutter pub get failed" -ForegroundColor Red; pause; exit 1 }

Write-Host ""
Write-Host "[3/4] Analyzing code..." -ForegroundColor Yellow
flutter analyze
Write-Host ""

Write-Host "[4/4] Running app..." -ForegroundColor Green
flutter run -d windows

pause
