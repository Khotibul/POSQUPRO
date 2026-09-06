@echo off
echo ============================================
echo   POSQUPRO MOBILE - Run Windows
echo ============================================
echo.

:: Stop running app
taskkill /f /im posqupro_mobile.exe >nul 2>&1
timeout /t 2 /nobreak >nul

:: Check if ephemeral engine files exist
if not exist "windows\flutter\ephemeral\cpp_client_wrapper\core_implementations.cc" (
    echo Ephemeral engine files missing! Copying from Flutter cache...
    
    :: Create directory
    if not exist "windows\flutter\ephemeral\cpp_client_wrapper" (
        mkdir "windows\flutter\ephemeral\cpp_client_wrapper"
    )
    
    :: Copy from Flutter engine cache
    set ENGINE_DIR=%FLUTTER_ROOT%\bin\cache\artifacts\engine\windows-x64\cpp_client_wrapper
    if not defined ENGINE_DIR set ENGINE_DIR=F:\Flutter\flutter\bin\cache\artifacts\engine\windows-x64\cpp_client_wrapper
    
    if exist "%ENGINE_DIR%" (
        copy "%ENGINE_DIR%\*.cc" "windows\flutter\ephemeral\cpp_client_wrapper\" >nul 2>&1
        copy "%ENGINE_DIR%\*.h" "windows\flutter\ephemeral\cpp_client_wrapper\" >nul 2>&1
        xcopy "%ENGINE_DIR%\include" "windows\flutter\ephemeral\cpp_client_wrapper\include\" /E /Y /Q >nul 2>&1
        echo Engine files copied!
    ) else (
        echo WARNING: Engine cache not found at %ENGINE_DIR%
    )
)

:: Build
echo.
echo Building...
flutter build windows --release
if %errorlevel% neq 0 (
    echo.
    echo BUILD FAILED
    pause
    exit /b 1
)

:: Run
echo.
echo Starting app...
start "" "build\windows\x64\runner\Release\posqupro_mobile.exe"
echo Done!
