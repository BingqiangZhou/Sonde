# ProGuard rules for Sonde
# Sonde 的混淆规则

# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Keep generic signature attributes (used by various libraries)
-keepattributes Signature
-keepattributes Exceptions
-keepattributes *Annotation*

# Audio service
-keep class com.ryanheise.audioservice.** { *; }

# Just Audio
-keep class com.ryanheise.just_audio.** { *; }

# SQLite
-keep class android.database.** { *; }

# XML StAX API (added as dependency in build.gradle.kts)
-keep class javax.xml.stream.** { *; }
-keep class org.apache.tika.** { *; }
-keep class com.fasterxml.woodstox.** { *; }
-keep class org.codehaus.stax2.** { *; }
-dontwarn aQute.bnd.annotation.**

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
