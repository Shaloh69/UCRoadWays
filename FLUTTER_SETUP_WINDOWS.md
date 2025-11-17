# Fixing Flutter SDK Path Error on Windows

## The Problem

You moved your Flutter project and now get this error:
```
Included build 'C:\Users\Shaloh\OneDrive\Desktop\Projects\Flutter\flutter\packages\flutter_tools\gradle' does not exist.
```

This happens because `android/local.properties` still points to the old Flutter SDK location.

## Quick Fix (Automatic)

1. Open Command Prompt in your project directory:
   ```cmd
   cd C:\Projects\Thesis\UCWays_RoadMaker\ucroadways
   ```

2. Run the fix script:
   ```cmd
   fix_flutter_path.bat
   ```

This will automatically find your Flutter SDK and update `android/local.properties`.

## Manual Fix (If Automatic Doesn't Work)

### Step 1: Find Your Flutter SDK Path

Open Command Prompt and run:
```cmd
where flutter
```

**Example output:**
```
C:\tools\flutter\bin\flutter.bat
```

Your Flutter SDK path is the part **before** `\bin\flutter.bat`:
- If output is: `C:\tools\flutter\bin\flutter.bat`
- Then SDK path is: `C:\tools\flutter`

### Step 2: Update local.properties

Navigate to your project's android folder:
```cmd
cd C:\Projects\Thesis\UCWays_RoadMaker\ucroadways\android
```

Create or edit `local.properties` file with this content:
```properties
flutter.sdk=C:\\tools\\flutter
sdk.dir=C:\\Users\\Shaloh\\AppData\\Local\\Android\\sdk
```

**IMPORTANT:** Use double backslashes (`\\`) in the paths!

Replace `C:\\tools\\flutter` with your actual Flutter SDK path from Step 1.

### Step 3: Verify

Go back to project root and test:
```cmd
cd C:\Projects\Thesis\UCWays_RoadMaker\ucroadways
flutter pub get
flutter run
```

## Common Flutter SDK Locations

Your Flutter might be in one of these locations:
- `C:\flutter`
- `C:\src\flutter`
- `C:\tools\flutter`
- `%USERPROFILE%\flutter` (e.g., `C:\Users\Shaloh\flutter`)
- `%LOCALAPPDATA%\flutter` (e.g., `C:\Users\Shaloh\AppData\Local\flutter`)

## If Flutter Isn't Installed

If `where flutter` returns "INFO: Could not find files", you need to install Flutter:

1. Download Flutter SDK from: https://docs.flutter.dev/get-started/install/windows
2. Extract to a location (e.g., `C:\tools\flutter`)
3. Add `C:\tools\flutter\bin` to your PATH environment variable
4. Run `flutter doctor` to complete setup

## Gradle File Lock Error (After Fixing SDK Path)

If you fixed the SDK path but now get this error:
```
Unable to delete directory 'C:\Projects\Flutter\flutter\packages\flutter_tools\gradle\build\classes\kotlin\main'
Failed to delete some children. This might happen because a process has files open...
```

This is a **Windows file locking issue**. Files are locked by Gradle daemon, IDE, or antivirus.

### Quick Fix for File Locks

1. **Close all these applications:**
   - Android Studio
   - VS Code
   - IntelliJ IDEA
   - Any Command Prompt windows running Gradle

2. **Run the cleanup script:**
   ```cmd
   fix_gradle_locks.bat
   ```

   This script will:
   - Stop the Gradle daemon
   - Clean all build directories
   - Remove cached files
   - Regenerate packages

3. **Try again:**
   ```cmd
   flutter run
   ```

### Manual Fix for File Locks

If the script doesn't work:

1. **Stop Gradle daemon:**
   ```cmd
   cd C:\Projects\Thesis\UCWays_RoadMaker\ucroadways\android
   gradlew --stop
   ```

2. **Clean Flutter project:**
   ```cmd
   cd ..
   flutter clean
   ```

3. **Delete build directories manually:**
   ```cmd
   rmdir /s /q android\.gradle
   rmdir /s /q android\app\build
   rmdir /s /q android\build
   ```

4. **Clean Flutter SDK Gradle build (if possible):**
   ```cmd
   REM Replace with your actual Flutter path
   rmdir /s /q C:\Projects\Flutter\flutter\packages\flutter_tools\gradle\build
   ```

   **Note:** If this fails, restart your computer and try again.

5. **Regenerate:**
   ```cmd
   flutter pub get
   flutter run
   ```

### If Nothing Works - Restart Computer

Sometimes Windows locks files so tightly that only a restart helps:
1. Close all applications
2. Restart your computer
3. Run `fix_gradle_locks.bat`
4. Try `flutter run`

## Still Having Issues?

### Check PATH Environment Variable

1. Open System Properties → Advanced → Environment Variables
2. Check if Flutter's `bin` directory is in your PATH:
   - User variables: Look for `Path` variable
   - Should contain something like: `C:\tools\flutter\bin`

### Regenerate Flutter Configuration

Delete these files and regenerate:
```cmd
cd C:\Projects\Thesis\UCWays_RoadMaker\ucroadways
del android\local.properties
flutter clean
flutter pub get
```

### Verify Flutter Installation

```cmd
flutter doctor -v
```

This shows:
- Flutter version and installation path
- Android toolchain status
- Connected devices

Look for the line that starts with "Flutter version" - it shows your SDK path.

## Example local.properties

Here's what a correct `android/local.properties` should look like:

```properties
# Flutter SDK path (use double backslashes on Windows)
flutter.sdk=C:\\tools\\flutter

# Android SDK path (optional, usually auto-detected)
sdk.dir=C:\\Users\\Shaloh\\AppData\\Local\\Android\\sdk
```

## Need More Help?

If you're still stuck, provide:
1. Output of `where flutter`
2. Output of `flutter doctor -v`
3. Content of `android/local.properties` (if it exists)
