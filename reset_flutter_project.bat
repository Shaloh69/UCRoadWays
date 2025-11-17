@echo off
REM This script helps you reset your Flutter project by creating a fresh one
REM and copying over only your source code and configuration files

echo ========================================
echo Flutter Project Reset Tool
echo ========================================
echo.
echo This script will:
echo   1. Create a fresh Flutter project
echo   2. Copy your source code and configs
echo   3. Skip all build/cache files
echo.
echo WARNING: This creates a NEW project directory.
echo Your original project will NOT be deleted.
echo.

set /p CONFIRM="Continue? (Y/N): "
if /i not "%CONFIRM%"=="Y" (
    echo Cancelled.
    pause
    exit /b
)
echo.

REM Get current directory name (project name)
for %%I in (.) do set CURRENT_DIR=%%~nxI
set PROJECT_NAME=%CURRENT_DIR%
set NEW_PROJECT=%PROJECT_NAME%_fresh

echo [1/7] Creating fresh Flutter project: %NEW_PROJECT%
echo.
flutter create %NEW_PROJECT%
if %ERRORLEVEL% NEQ 0 (
    echo ✗ Failed to create Flutter project
    pause
    exit /b 1
)
echo   ✓ Fresh project created
echo.

echo [2/7] Copying pubspec.yaml...
copy /Y pubspec.yaml %NEW_PROJECT%\pubspec.yaml >nul
echo   ✓ Copied pubspec.yaml
echo.

echo [3/7] Copying lib folder (your source code)...
xcopy /E /I /Y lib %NEW_PROJECT%\lib >nul
echo   ✓ Copied lib/
echo.

echo [4/7] Copying assets (if they exist)...
if exist "assets" (
    xcopy /E /I /Y assets %NEW_PROJECT%\assets >nul
    echo   ✓ Copied assets/
) else (
    echo   ℹ No assets folder found
)
echo.

echo [5/7] Copying configuration files...
if exist "analysis_options.yaml" (
    copy /Y analysis_options.yaml %NEW_PROJECT%\analysis_options.yaml >nul
    echo   ✓ Copied analysis_options.yaml
)
if exist ".gitignore" (
    copy /Y .gitignore %NEW_PROJECT%\.gitignore >nul
    echo   ✓ Copied .gitignore
)
if exist "README.md" (
    copy /Y README.md %NEW_PROJECT%\README.md >nul
    echo   ✓ Copied README.md
)
echo.

echo [6/7] Copying platform-specific configurations...

REM Copy Android config (but not build files)
if exist "android\app\src\main\AndroidManifest.xml" (
    copy /Y android\app\src\main\AndroidManifest.xml %NEW_PROJECT%\android\app\src\main\AndroidManifest.xml >nul
    echo   ✓ Copied AndroidManifest.xml
)
if exist "android\app\build.gradle" (
    copy /Y android\app\build.gradle %NEW_PROJECT%\android\app\build.gradle >nul
    echo   ✓ Copied android/app/build.gradle
)
if exist "android\build.gradle" (
    copy /Y android\build.gradle %NEW_PROJECT%\android\build.gradle >nul
    echo   ✓ Copied android/build.gradle
)
if exist "android\gradle.properties" (
    copy /Y android\gradle.properties %NEW_PROJECT%\android\gradle.properties >nul
    echo   ✓ Copied gradle.properties
)

REM Copy iOS config if exists
if exist "ios\Runner\Info.plist" (
    copy /Y ios\Runner\Info.plist %NEW_PROJECT%\ios\Runner\Info.plist >nul
    echo   ✓ Copied Info.plist
)

REM Copy web config if exists
if exist "web\index.html" (
    copy /Y web\index.html %NEW_PROJECT%\web\index.html >nul
    echo   ✓ Copied web/index.html
)
echo.

echo [7/7] Installing dependencies in new project...
cd %NEW_PROJECT%
call flutter pub get
if %ERRORLEVEL% EQU 0 (
    echo   ✓ Dependencies installed
) else (
    echo   ✗ Failed to get dependencies
    cd ..
    pause
    exit /b 1
)
cd ..
echo.

echo ========================================
echo Reset Complete!
echo ========================================
echo.
echo Your fresh project is in: %NEW_PROJECT%\
echo.
echo Next steps:
echo   1. Test the new project:
echo      cd %NEW_PROJECT%
echo      flutter run
echo.
echo   2. If it works, you can:
echo      - Delete the old project folder
echo      - Rename %NEW_PROJECT% to %PROJECT_NAME%
echo.
echo   3. Or keep both and compare:
echo      - Old project: %CD%
echo      - New project: %CD%\%NEW_PROJECT%
echo.
echo Your original project is still intact in the current directory.
echo.

pause
