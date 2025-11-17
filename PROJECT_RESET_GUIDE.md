# Complete Flutter Project Reset Guide

When build files get corrupted and nothing else works, starting fresh is the best solution. This guide shows you how to safely reset your Flutter project.

## Option 1: Automated Reset (Easiest)

**Use the automated script:**
```cmd
cd C:\Projects\Thesis\UCWays_RoadMaker\ucroadways
reset_flutter_project.bat
```

This script will:
- Create a fresh Flutter project in a new folder (`ucroadways_fresh`)
- Copy ONLY your source code and configs (no build files)
- Install dependencies in the new project
- Keep your original project intact for comparison

**Then test it:**
```cmd
cd ucroadways_fresh
flutter run
```

**If it works:**
```cmd
cd ..
rmdir /s /q ucroadways
rename ucroadways_fresh ucroadways
```

---

## Option 2: Manual Reset

### Step 1: Create Fresh Flutter Project

```cmd
cd C:\Projects\Thesis\UCWays_RoadMaker
flutter create ucroadways_new
```

### Step 2: Copy These Files (KEEP)

**✓ COPY these - Your actual code and configs:**

```
ucroadways/
├── lib/                          ← ALL your source code
│   ├── main.dart
│   ├── models/
│   ├── screens/
│   └── ...
│
├── assets/                       ← Images, fonts, data files
│   └── ...
│
├── pubspec.yaml                  ← Dependencies and project config
├── analysis_options.yaml         ← Linting rules (if you have it)
├── README.md                     ← Documentation
├── .gitignore                    ← Git config
│
├── android/app/src/main/AndroidManifest.xml  ← Android permissions
├── android/app/build.gradle      ← Android build config
├── android/build.gradle          ← Android project config
├── android/gradle.properties     ← Gradle settings
│
├── ios/Runner/Info.plist         ← iOS permissions (if using iOS)
└── web/index.html                ← Web config (if using web)
```

**Copy commands:**
```cmd
cd C:\Projects\Thesis\UCWays_RoadMaker

REM Copy source code
xcopy /E /I /Y ucroadways\lib ucroadways_new\lib

REM Copy assets
xcopy /E /I /Y ucroadways\assets ucroadways_new\assets

REM Copy config files
copy /Y ucroadways\pubspec.yaml ucroadways_new\pubspec.yaml
copy /Y ucroadways\analysis_options.yaml ucroadways_new\analysis_options.yaml
copy /Y ucroadways\README.md ucroadways_new\README.md

REM Copy Android configs
copy /Y ucroadways\android\app\src\main\AndroidManifest.xml ucroadways_new\android\app\src\main\AndroidManifest.xml
copy /Y ucroadways\android\app\build.gradle ucroadways_new\android\app\build.gradle
copy /Y ucroadways\android\build.gradle ucroadways_new\android\build.gradle
copy /Y ucroadways\android\gradle.properties ucroadways_new\android\gradle.properties
```

### Step 3: DO NOT Copy These (SKIP)

**✗ NEVER copy these - Build artifacts and caches:**

```
ucroadways/
├── .dart_tool/                   ← Build cache (regenerated)
├── .flutter-plugins              ← Plugin list (regenerated)
├── .flutter-plugins-dependencies ← Plugin deps (regenerated)
├── .packages                     ← Package list (regenerated)
├── pubspec.lock                  ← Lock file (regenerated)
├── build/                        ← Build output (regenerated)
│
├── android/.gradle/              ← Gradle cache (corrupted!)
├── android/app/build/            ← Android build output
├── android/build/                ← Android build cache
├── android/local.properties      ← Machine-specific (regenerated)
├── android/gradlew               ← Gradle wrapper (fresh version better)
├── android/gradlew.bat           ← Gradle wrapper (fresh version better)
│
├── ios/Pods/                     ← iOS dependencies (regenerated)
├── ios/build/                    ← iOS build output
├── ios/.symlinks/                ← iOS symlinks (regenerated)
│
└── .idea/                        ← IDE settings (IDE-specific)
```

**These are the corrupted files causing your issues!**

### Step 4: Install Dependencies

```cmd
cd ucroadways_new
flutter pub get
```

### Step 5: Test the New Project

```cmd
flutter run
```

### Step 6: Replace Old Project (If It Works)

```cmd
cd ..

REM Backup old project (optional)
rename ucroadways ucroadways_old_backup

REM Use new project
rename ucroadways_new ucroadways

REM Later, delete backup when confident
REM rmdir /s /q ucroadways_old_backup
```

---

## What Gets Regenerated Automatically

When you run `flutter pub get` in the fresh project, Flutter automatically creates:

1. **`.dart_tool/`** - Dart build system cache
2. **`.flutter-plugins`** - List of Flutter plugins used
3. **`.flutter-plugins-dependencies`** - Plugin dependency tree
4. **`.packages`** - Package resolution info
5. **`pubspec.lock`** - Locked dependency versions
6. **`android/local.properties`** - Flutter SDK path (correct path!)
7. **`android/.gradle/`** - Fresh Gradle cache (no locks!)

These files are **machine-specific and auto-generated** - never commit them to git!

---

## Why This Works

Your current project has:
- Corrupted Gradle cache in `android/.gradle/`
- Locked build files in `android/build/`
- Stale Flutter SDK paths in `android/local.properties`
- File locks from previous build attempts

A fresh project has:
- Clean Gradle cache
- Correct Flutter SDK path (from current Flutter installation)
- No locked files
- Latest Flutter tooling

By copying ONLY your source code (`lib/`), assets, and configs - you get a clean slate with working build tools.

---

## After Reset - Initial Setup

Once your fresh project works:

1. **Verify Flutter is working:**
   ```cmd
   cd ucroadways_new
   flutter doctor
   flutter pub get
   flutter run
   ```

2. **Test on your device/emulator:**
   - Make sure app launches
   - Check all features work
   - Verify assets load correctly

3. **Commit to git:**
   ```cmd
   git add .
   git commit -m "Reset project with clean build files"
   git push
   ```

4. **Set up Android local.properties (automatically done):**
   After `flutter pub get`, check `android/local.properties` has correct path:
   ```properties
   flutter.sdk=C:\\Projects\\Flutter\\flutter
   sdk.dir=C:\\Users\\Shaloh\\AppData\\Local\\Android\\sdk
   ```

---

## Troubleshooting After Reset

### If dependencies fail to install:
```cmd
flutter clean
flutter pub cache repair
flutter pub get
```

### If Android still has issues:
```cmd
cd android
gradlew clean
cd ..
flutter clean
flutter pub get
```

### If you need to update Flutter:
```cmd
flutter upgrade
flutter doctor
```

---

## Files Summary Table

| Path | Copy? | Why |
|------|-------|-----|
| `lib/` | ✓ YES | Your actual source code |
| `assets/` | ✓ YES | Images, fonts, data files |
| `pubspec.yaml` | ✓ YES | Dependencies and metadata |
| `android/app/build.gradle` | ✓ YES | Android build configuration |
| `android/gradle.properties` | ✓ YES | Gradle settings |
| `AndroidManifest.xml` | ✓ YES | Android permissions |
| `build/` | ✗ NO | Build output (regenerated) |
| `.dart_tool/` | ✗ NO | Build cache (regenerated) |
| `android/.gradle/` | ✗ NO | Gradle cache (corrupted!) |
| `android/build/` | ✗ NO | Build output (regenerated) |
| `android/local.properties` | ✗ NO | Machine-specific (regenerated) |
| `.packages` | ✗ NO | Package list (regenerated) |
| `pubspec.lock` | ✓ MAYBE | Lock versions (usually regenerated) |

---

## Quick Command Reference

**Create fresh project:**
```cmd
flutter create project_name
```

**Copy source code:**
```cmd
xcopy /E /I /Y old_project\lib new_project\lib
```

**Copy assets:**
```cmd
xcopy /E /I /Y old_project\assets new_project\assets
```

**Install dependencies:**
```cmd
cd new_project
flutter pub get
```

**Test:**
```cmd
flutter run
```

**Replace old project:**
```cmd
rename old_project old_project_backup
rename new_project old_project
```

---

## Need Help?

If the reset doesn't work:
1. Run `flutter doctor -v` - ensure Flutter is properly installed
2. Check `where flutter` - verify Flutter SDK location
3. Try `flutter clean && flutter pub get` in the new project
4. Make sure NO IDE is open (Android Studio, VS Code)

See also:
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- [FLUTTER_SETUP_WINDOWS.md](FLUTTER_SETUP_WINDOWS.md)
