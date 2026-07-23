# Flutter / Play Core
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter references Play Core deferred-component APIs that we do not use.
# Suppress R8 missing-class errors (from missing_rules.txt).
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Google Maps / Play Services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Media / camera
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# TFLite
-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**

-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# MediaPipe + TFLite + protobuf (release face landmarks / glasses / dog / etc.)
# R8 must not rename these — createFromOptions fails silently otherwise.
-keepattributes Signature, InnerClasses, EnclosingMethod, *Annotation*, Exceptions

-keepclasseswithmembernames class * {
    native <methods>;
}

-keep class com.google.mediapipe.** { *; }
-keepclassmembers class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**

-keep class com.google.protobuf.** { *; }
-keepclassmembers class com.google.protobuf.** { *; }
-keep class * extends com.google.protobuf.GeneratedMessageLite { *; }
-keepclassmembers class * extends com.google.protobuf.GeneratedMessageLite {
    <fields>;
    <methods>;
}
-dontwarn com.google.protobuf.**

-keep class com.google.flatbuffers.** { *; }
-dontwarn com.google.flatbuffers.**

-keep class com.google.auto.value.** { *; }
-dontwarn com.google.auto.value.**

-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**

-keep class com.google.android.gms.tflite.** { *; }
-dontwarn com.google.android.gms.tflite.**

# OpenCV
-keep class org.opencv.** { *; }
-dontwarn org.opencv.**
