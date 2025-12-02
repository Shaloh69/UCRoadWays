plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.flutter_application_1"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.flutter_application_1"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
             // Keep your signing config (or set your real release signing here)
            signingConfig = signingConfigs.getByName("debug")

            // If you are using R8/proguard for release, keep the proguard file reference:
            // If you prefer to disable minification for now, set isMinifyEnabled = false
            // (temporary workaround).
            // Recommended: keep minification and add keep rules (we'll add them below).
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
// Add dependencies here (Kotlin DSL)
dependencies {
    // Add Play Core so R8 can resolve SplitCompat / SplitInstall / Tasks used by Flutter
    implementation("com.google.android.play:core:1.10.3")
    // optionally if you want Kotlin extensions:
    // implementation("com.google.android.play:core-ktx:1.8.1")
}