# Flutter ProGuard Rules for UCRoadWays

# Keep Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep JSON annotations (for models.dart serialization)
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses

# Keep JSON serializable models
-keep class com.example.flutter_application_1.** { *; }
-keepclassmembers class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Keep all model classes (prevents JSON serialization issues)
-keep class * implements com.google.gson.JsonSerializer { *; }
-keep class * implements com.google.gson.JsonDeserializer { *; }

# Geolocator plugin
-keep class com.baseflow.geolocator.** { *; }

# Permission handler
-keep class com.baseflow.permissionhandler.** { *; }

# SQLite (for offline maps)
-keep class org.sqlite.** { *; }
-keep class net.sqlcipher.** { *; }

# HTTP/Dio networking
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
