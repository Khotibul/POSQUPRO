@echo off
echo ============================================
echo   POSQUPRO MOBILE - Windows Audit ^& Test
echo ============================================
echo.

setlocal enabledelayedexpansion

:: Step 1: Stop running app
echo [1/8] Stopping running app...
taskkill /f /im posqupro_mobile.exe >nul 2>&1
timeout /t 2 /nobreak >nul
echo       OK

:: Step 2: Check Flutter
echo [2/8] Checking Flutter installation...
flutter --version >nul 2>&1
if %errorlevel% neq 0 (
    echo       ERROR: Flutter not found in PATH
    pause
    exit /b 1
)
for /f "tokens=2" %%v in ('flutter --version 2^>nul ^| findstr /r "Flutter [0-9]"') do set FLUTTER_VER=%%v
echo       Flutter found: %FLUTTER_VER%

:: Step 3: Check Windows build tools
echo [3/8] Checking Windows build tools...
where cmake >nul 2>&1
if %errorlevel% neq 0 (
    echo       WARNING: cmake not found
)
where cl >nul 2>&1
if %errorlevel% neq 0 (
    echo       WARNING: MSVC cl.exe not found
)

:: Step 4: Clean build
echo [4/8] Cleaning build artifacts...
if exist "build" (
    rmdir /s /q "build" 2>nul
)
if exist ".dart_tool" (
    rmdir /s /q ".dart_tool" 2>nul
)
if exist "windows\flutter\ephemeral" (
    rmdir /s /q "windows\flutter\ephemeral" 2>nul
)
if exist ".flutter-plugins-dependencies" (
    del /f ".flutter-plugins-dependencies" 2>nul
)
echo       Cleaned

:: Step 5: Regenerate Windows platform
echo [5/8] Regenerating Windows platform...
flutter create --platforms=windows . >nul 2>&1
if %errorlevel% neq 0 (
    echo       ERROR: flutter create failed
    pause
    exit /b 1
)

:: Step 6: Get dependencies
echo [6/8] Getting dependencies...
flutter pub get
if %errorlevel% neq 0 (
    echo       ERROR: flutter pub get failed
    pause
    exit /b 1
)

:: Step 7: Analyze code
echo [7/8] Analyzing code...
flutter analyze
set ANALYZE_RESULT=%errorlevel%
echo.

:: Step 8: Build and run
echo [8/8] Building Windows release...
flutter build windows --release
if %errorlevel% neq 0 (
    echo.
    echo       BUILD FAILED!
    echo       Try: flutter clean ^&^& flutter create --platforms=windows . ^&^& flutter pub get
    pause
    exit /b 1
)

echo.
echo ============================================
echo   BUILD SUCCESS!
echo ============================================
echo   Exe: build\windows\x64\runner\Release\posqupro_mobile.exe
echo ============================================
echo.

set /p run="Run app now? (y/n): "
if /i "%run%"=="y" (
    start "" "build\windows\x64\runner\Release\posqupro_mobile.exe"
)

pause
