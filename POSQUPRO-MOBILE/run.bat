@echo off
echo ========================================
echo   POSQUPRO MOBILE - Clean ^& Run
echo ========================================
echo.

echo [0/4] Stopping running app...
taskkill /f /im posqupro_mobile.exe >nul 2>&1
timeout /t 2 /nobreak >nul

echo [1/4] Cleaning build artifacts...
flutter clean
if %errorlevel% neq 0 (
    echo ERROR: flutter clean failed
    pause
    exit /b 1
)

echo.
echo [2/4] Getting dependencies...
flutter pub get
if %errorlevel% neq 0 (
    echo ERROR: flutter pub get failed
    pause
    exit /b 1
)

echo.
echo [3/4] Analyzing code...
flutter analyze
echo.

echo [4/4] Running app (press q to quit)...
flutter run -d windows
