pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            val localPropertiesFile = file("local.properties")

            if (!localPropertiesFile.exists()) {
                throw GradleException(
                    """
                    |
                    |ERROR: local.properties file not found!
                    |
                    |Please run 'flutter pub get' in the project root directory to generate this file.
                    |Alternatively, create android/local.properties with:
                    |  flutter.sdk=<path-to-your-flutter-sdk>
                    |
                    """.trimMargin()
                )
            }

            localPropertiesFile.inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")

            if (flutterSdkPath == null) {
                throw GradleException(
                    """
                    |
                    |ERROR: flutter.sdk not set in local.properties!
                    |
                    |Please add the following line to android/local.properties:
                    |  flutter.sdk=<path-to-your-flutter-sdk>
                    |
                    |Or run 'flutter pub get' in the project root to regenerate this file.
                    |
                    """.trimMargin()
                )
            }

            val flutterSdkDir = file(flutterSdkPath)
            if (!flutterSdkDir.exists()) {
                throw GradleException(
                    """
                    |
                    |ERROR: Flutter SDK not found at: $flutterSdkPath
                    |
                    |The path in android/local.properties points to a non-existent location.
                    |
                    |To fix this:
                    |1. Run 'flutter pub get' in the project root to regenerate local.properties
                    |2. Or update android/local.properties with the correct Flutter SDK path
                    |3. Verify Flutter is installed by running 'flutter doctor'
                    |
                    |Current value in local.properties: $flutterSdkPath
                    |
                    """.trimMargin()
                )
            }

            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
