@echo off
REM This script helps fix the Flutter SDK path in local.properties
REM Run this from the project root directory

echo ========================================
echo Flutter SDK Path Fixer
echo ========================================
echo.

REM Try to find Flutter SDK
echo Searching for Flutter SDK...
echo.

REM Check common locations
set FLUTTER_PATH=
if exist "C:\flutter\bin\flutter.bat" set FLUTTER_PATH=C:\flutter
if exist "C:\src\flutter\bin\flutter.bat" set FLUTTER_PATH=C:\src\flutter
if exist "C:\tools\flutter\bin\flutter.bat" set FLUTTER_PATH=C:\tools\flutter
if exist "%USERPROFILE%\flutter\bin\flutter.bat" set FLUTTER_PATH=%USERPROFILE%\flutter
if exist "%USERPROFILE%\AppData\Local\flutter\bin\flutter.bat" set FLUTTER_PATH=%USERPROFILE%\AppData\Local\flutter
if exist "%LOCALAPPDATA%\flutter\bin\flutter.bat" set FLUTTER_PATH=%LOCALAPPDATA%\flutter

if defined FLUTTER_PATH (
    echo Found Flutter at: %FLUTTER_PATH%
    echo.

    REM Create local.properties with correct path
    echo Creating android\local.properties...
    echo flutter.sdk=%FLUTTER_PATH:\=\\%> android\local.properties
    echo sdk.dir=%LOCALAPPDATA%\Android\sdk>> android\local.properties
    echo.
    echo ✓ Success! local.properties has been updated.
    echo.
    echo The following has been written to android\local.properties:
    type android\local.properties
    echo.
) else (
    echo ✗ Flutter SDK not found in common locations.
    echo.
    echo Please manually create android\local.properties with:
    echo   flutter.sdk=YOUR_FLUTTER_SDK_PATH
    echo.
    echo To find your Flutter SDK path:
    echo   1. Open Command Prompt
    echo   2. Run: where flutter
    echo   3. The path shown minus '\bin\flutter.bat' is your SDK path
    echo.
    echo Example:
    echo   If 'where flutter' shows: C:\tools\flutter\bin\flutter.bat
    echo   Then use: flutter.sdk=C:\\tools\\flutter
    echo.
)

pause
