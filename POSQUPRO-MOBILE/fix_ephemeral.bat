@echo off
echo ============================================
echo   POSQUPRO MOBILE - Fix Ephemeral Files
echo ============================================
echo.

:: Stop running app
taskkill /f /im posqupro_mobile.exe >nul 2>&1
timeout /t 1 /nobreak >nul

:: Copy engine files from Flutter cache
set ENGINE_DIR=F:\Flutter\flutter\bin\cache\artifacts\engine\windows-x64\cpp_client_wrapper

echo Copying engine files from:
echo   %ENGINE_DIR%
echo.

if not exist "windows\flutter\ephemeral\cpp_client_wrapper" (
    mkdir "windows\flutter\ephemeral\cpp_client_wrapper"
)

copy "%ENGINE_DIR%\*.cc" "windows\flutter\ephemeral\cpp_client_wrapper\" 2>nul
copy "%ENGINE_DIR%\*.h" "windows\flutter\ephemeral\cpp_client_wrapper\" 2>nul
xcopy "%ENGINE_DIR%\include" "windows\flutter\ephemeral\cpp_client_wrapper\include\" /E /Y /Q 2>nul

echo.
echo Verifying files:
dir /b "windows\flutter\ephemeral\cpp_client_wrapper\*.cc" 2>nul
echo.

if exist "windows\flutter\ephemeral\cpp_client_wrapper\core_implementations.cc" (
    echo SUCCESS! Ephemeral files are now in place.
    echo You can now run: flutter run -d windows
) else (
    echo FAILED! Engine files not found.
    echo Check that Flutter is installed at: F:\Flutter\flutter
)

pause
