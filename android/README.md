# Android Build Configuration

## Setting Up Flutter SDK Path

If you encounter an error like:
```
Error resolving plugin [id: 'dev.flutter.flutter-plugin-loader', version: '1.0.0']
Included build 'C:\...\flutter\packages\flutter_tools\gradle' does not exist.
```

This means your `local.properties` file is missing or has an incorrect Flutter SDK path.

### Quick Fix

Run this command in the project root directory:
```bash
flutter pub get
```

This will automatically generate the `android/local.properties` file with the correct Flutter SDK path.

### Manual Setup

If the automatic method doesn't work:

1. **Find your Flutter SDK path:**
   ```bash
   flutter doctor -v
   ```
   Look for "Flutter version" line which shows the installation path.

2. **Create/Edit local.properties:**
   - Navigate to the `android/` directory
   - Copy `local.properties.example` to `local.properties`
   - Update the `flutter.sdk` path

   **Windows example:**
   ```properties
   flutter.sdk=C:\\Users\\YourUsername\\flutter
   ```

   **macOS/Linux example:**
   ```properties
   flutter.sdk=/Users/YourUsername/flutter
   ```

3. **Verify Flutter is installed:**
   ```bash
   flutter doctor
   ```

### Common Issues

- **Path contains spaces:** Use double backslashes on Windows: `C:\\Program Files\\flutter`
- **Moved Flutter SDK:** If you moved your Flutter installation, regenerate with `flutter pub get`
- **Multiple Flutter versions:** Ensure the path points to the Flutter version you want to use

### Note

The `local.properties` file is gitignored because it contains machine-specific paths. Each developer needs to set this up on their own machine.
