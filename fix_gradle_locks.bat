@echo off
REM This script fixes Gradle file lock issues on Windows
REM Run this when you get "Unable to delete directory" errors

echo ========================================
echo Gradle Clean and Reset Tool
echo ========================================
echo.

echo [1/6] Stopping Gradle daemon...
call gradlew --stop 2>nul
if %ERRORLEVEL% EQU 0 (
    echo   ✓ Gradle daemon stopped
) else (
    echo   ℹ Gradle daemon may not be running
)
echo.

echo [2/6] Cleaning Flutter project...
call flutter clean
if %ERRORLEVEL% EQU 0 (
    echo   ✓ Flutter clean completed
) else (
    echo   ✗ Flutter clean failed
)
echo.

echo [3/6] Cleaning Android Gradle cache...
if exist "android\.gradle" (
    rmdir /s /q "android\.gradle" 2>nul
    echo   ✓ Removed android/.gradle
) else (
    echo   ℹ android/.gradle not found
)
echo.

echo [4/6] Cleaning Android build directories...
if exist "android\app\build" (
    rmdir /s /q "android\app\build" 2>nul
    echo   ✓ Removed android/app/build
) else (
    echo   ℹ android/app/build not found
)

if exist "android\build" (
    rmdir /s /q "android\build" 2>nul
    echo   ✓ Removed android/build
) else (
    echo   ℹ android/build not found
)
echo.

echo [5/6] Cleaning Flutter SDK Gradle build (if accessible)...
REM Read Flutter SDK path from local.properties
set FLUTTER_SDK=
for /f "tokens=2 delims==" %%a in ('findstr "flutter.sdk" android\local.properties 2^>nul') do set FLUTTER_SDK=%%a

if defined FLUTTER_SDK (
    REM Remove double backslashes
    set FLUTTER_SDK=%FLUTTER_SDK:\\=\%

    if exist "%FLUTTER_SDK%\packages\flutter_tools\gradle\build" (
        echo   Attempting to clean Flutter SDK Gradle build...
        rmdir /s /q "%FLUTTER_SDK%\packages\flutter_tools\gradle\build" 2>nul
        if %ERRORLEVEL% EQU 0 (
            echo   ✓ Removed Flutter SDK Gradle build directory
        ) else (
            echo   ⚠ Could not remove - files may be locked
            echo   Please close all IDEs and try again
        )
    ) else (
        echo   ℹ Flutter SDK Gradle build directory not found
    )
) else (
    echo   ℹ Could not read Flutter SDK path from local.properties
)
echo.

echo [6/6] Getting Flutter packages...
call flutter pub get
if %ERRORLEVEL% EQU 0 (
    echo   ✓ Flutter pub get completed
) else (
    echo   ✗ Flutter pub get failed
)
echo.

echo ========================================
echo Cleanup Complete!
echo ========================================
echo.
echo Next steps:
echo   1. If you still see errors, close ALL these applications:
echo      - Android Studio
echo      - VS Code
echo      - IntelliJ IDEA
echo      - Any command prompts running Gradle
echo.
echo   2. Then run this script again
echo.
echo   3. Try running your app:
echo      flutter run
echo.

pause
