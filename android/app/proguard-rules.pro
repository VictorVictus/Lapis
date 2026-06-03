# Flutter specific
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase / Firestore
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep model classes used by Firestore serialization
-keep class com.example.to_do_app.** { *; }
-keep class app.lapis.todo.** { *; }

# Keep Kotlin metadata
-keep class kotlin.Metadata { *; }

# Keep notification receiver
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# General Android rules
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Keep enum classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
