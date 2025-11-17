# Flutter Build Troubleshooting Guide

Quick reference for common Flutter build errors on Windows.

## Error 1: Included build does not exist

**Full Error:**
```
Error resolving plugin [id: 'dev.flutter.flutter-plugin-loader', version: '1.0.0']
Included build 'C:\...\flutter\packages\flutter_tools\gradle' does not exist.
```

**Cause:** Your `android/local.properties` file has wrong or missing Flutter SDK path.

**Fix:**
```cmd
fix_flutter_path.bat
```

Or manually update `android/local.properties` with correct Flutter path.

**Details:** See [FLUTTER_SETUP_WINDOWS.md](FLUTTER_SETUP_WINDOWS.md)

---

## Error 2: Unable to delete directory

**Full Error:**
```
Unable to delete directory 'C:\Projects\Flutter\flutter\packages\flutter_tools\gradle\build\classes\kotlin\main'
Failed to delete some children. This might happen because a process has files open...
```

**Cause:** Gradle daemon or IDE has locked build files.

**Fix:**
1. Close Android Studio, VS Code, and all command prompts
2. Run:
   ```cmd
   fix_gradle_locks.bat
   ```
3. If still failing, restart your computer and run the script again

**Details:** See [FLUTTER_SETUP_WINDOWS.md](FLUTTER_SETUP_WINDOWS.md#gradle-file-lock-error-after-fixing-sdk-path)

---

## Error 3: flutter.sdk not set in local.properties

**Cause:** The `android/local.properties` file exists but is empty or doesn't have the Flutter SDK path.

**Fix:**
```cmd
flutter pub get
```

Or manually add to `android/local.properties`:
```properties
flutter.sdk=C:\\path\\to\\flutter
```

---

## Error 4: Gradle build fails with "Sync issues"

**Fix:**
1. Stop all processes:
   ```cmd
   cd android
   gradlew --stop
   ```

2. Clean everything:
   ```cmd
   cd ..
   flutter clean
   ```

3. Rebuild:
   ```cmd
   flutter pub get
   flutter run
   ```

---

## Quick Command Reference

### Find Flutter SDK Path
```cmd
where flutter
```
Output shows path like `C:\tools\flutter\bin\flutter.bat`
Your SDK path is `C:\tools\flutter`

### Check Flutter Installation
```cmd
flutter doctor -v
```

### Stop Gradle Daemon
```cmd
cd android
gradlew --stop
```

### Clean Project
```cmd
flutter clean
flutter pub get
```

### Remove Build Directories
```cmd
rmdir /s /q android\.gradle
rmdir /s /q android\build
rmdir /s /q android\app\build
```

---

## Automated Fix Scripts

This project includes two automated fix scripts:

1. **fix_flutter_path.bat** - Fixes Flutter SDK path issues
2. **fix_gradle_locks.bat** - Fixes file lock and build cache issues

Run them from the project root directory.

---

## When All Else Fails

### Option 1: Try Fix Scripts After Restart

1. Close **ALL** applications (Android Studio, VS Code, Command Prompts)
2. Restart your computer
3. Run both fix scripts:
   ```cmd
   fix_flutter_path.bat
   fix_gradle_locks.bat
   ```
4. Try again:
   ```cmd
   flutter run
   ```

### Option 2: Complete Project Reset (Nuclear Option)

If nothing works and build files are corrupted beyond repair, **start fresh**:

```cmd
reset_flutter_project.bat
```

This creates a clean Flutter project and copies only your source code (no build files).

**See:** [PROJECT_RESET_GUIDE.md](PROJECT_RESET_GUIDE.md) for detailed instructions.

**Why this works:**
- Removes all corrupted build caches
- Gets fresh Flutter tooling
- Keeps your source code and configs
- Automatically sets correct Flutter SDK path

---

## Getting Help

If none of these fixes work, please provide:
1. Output of `where flutter`
2. Output of `flutter doctor -v`
3. Content of `android/local.properties`
4. Full error message from the build

See detailed guides:
- [FLUTTER_SETUP_WINDOWS.md](FLUTTER_SETUP_WINDOWS.md) - Complete Windows setup guide
- [android/README.md](android/README.md) - Android build configuration
