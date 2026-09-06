@echo off
echo ============================================
echo   POSQUPRO MOBILE - Quick Windows Test
echo ============================================
echo.

:: Stop running app
taskkill /f /im posqupro_mobile.exe >nul 2>&1
timeout /t 1 /nobreak >nul

:: Check if ephemeral exists
if not exist "windows\flutter\ephemeral\cpp_client_wrapper" (
    echo Ephemeral files missing! Running full setup...
    flutter clean
    flutter create --platforms=windows .
    flutter pub get
)

:: Quick analyze
echo [1/2] Analyzing...
flutter analyze
echo.

:: Build release
echo [2/2] Building release...
flutter build windows --release
if %errorlevel% neq 0 (
    echo BUILD FAILED - Run audit_windows.bat for full repair
    pause
    exit /b 1
)

echo.
echo BUILD SUCCESS!
set /p run="Run app? (y/n): "
if /i "%run%"=="y" (
    start "" "build\windows\x64\runner\Release\posqupro_mobile.exe"
)
