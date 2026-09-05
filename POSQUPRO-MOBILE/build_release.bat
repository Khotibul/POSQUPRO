@echo off
echo ========================================
echo   POSQUPRO MOBILE - Build Release
echo ========================================
echo.

echo [1/3] Cleaning build artifacts...
flutter clean
if %errorlevel% neq 0 (
    echo ERROR: flutter clean failed
    pause
    exit /b 1
)

echo.
echo [2/3] Getting dependencies...
flutter pub get
if %errorlevel% neq 0 (
    echo ERROR: flutter pub get failed
    pause
    exit /b 1
)

echo.
echo [3/3] Building release...
flutter build windows --release
if %errorlevel% neq 0 (
    echo ERROR: build failed
    pause
    exit /b 1
)

echo.
echo ========================================
echo   BUILD SUCCESS!
echo   Exe: build\windows\x64\runner\Release\posqupro_mobile.exe
echo ========================================
echo.

set /p run="Run app now? (y/n): "
if /i "%run%"=="y" (
    start "" "build\windows\x64\runner\Release\posqupro_mobile.exe"
)

pause
