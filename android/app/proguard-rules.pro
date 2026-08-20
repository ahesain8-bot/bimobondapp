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

# MediaPipe Face Landmarker
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**

# MediaPipe parses its .task graph config via protobuf-lite, which relies on
# field/class names at runtime. R8 obfuscation breaks this → createFromOptions
# fails silently and ALL face effects (dog, glasses, big eyes, lips, nose, jaw)
# stop working in release. Keep protobuf + generated messages intact.
-keep class com.google.protobuf.** { *; }
-keep class * extends com.google.protobuf.GeneratedMessageLite { *; }
-keepclassmembers class * extends com.google.protobuf.GeneratedMessageLite {
    <fields>;
}
-dontwarn com.google.protobuf.**

# AutoValue-generated classes used by MediaPipe tasks options/results.
-keep class com.google.auto.value.** { *; }
-dontwarn com.google.auto.value.**

# FlatBuffers (TFLite model container inside the .task bundle).
-keep class com.google.flatbuffers.** { *; }
-dontwarn com.google.flatbuffers.**

# OpenCV
-keep class org.opencv.** { *; }
-dontwarn org.opencv.**

# AndroidX Media3 (ExoPlayer + Transformer)
#
# Used for video playback and, via pro_video_editor, for the export that runs
# when a post is submitted. Media3 guards its newer-platform code with API level
# checks; R8 was merging and inlining across those guards, which put an
# API-31-only type (android.media.metrics.LogSessionId) on a path that executes
# on older devices. On a Galaxy Note 9 (API 29) that crashed the app the moment
# Post was tapped:
#
#   java.lang.NoClassDefFoundError:
#       Failed resolution of: Landroid/media/metrics/LogSessionId;
#     at androidx.media3.transformer.Transformer.start
#     at ch.waio.pro_video_editor...RenderVideo
#
# Keeping these classes intact leaves the guards where the library put them.
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**

# Platform classes that only exist on newer API levels and are referenced from
# behind those guards.
-dontwarn android.media.metrics.**

# Video/media Flutter plugins that drive the above.
-keep class ch.waio.pro_video_editor.** { *; }
-dontwarn ch.waio.pro_video_editor.**

# LiveKit / Flutter WebRTC (JNI + reflection + native libwebrtc bridge)
-keep class com.cloudwebrtc.webrtc.** { *; }
-dontwarn com.cloudwebrtc.webrtc.**
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**
-keep class io.livekit.android.** { *; }
-dontwarn io.livekit.android.**

# Socket.IO / Engine.IO Java client (okhttp3 + okio)
-keep class io.socket.** { *; }
-dontwarn io.socket.**
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**
-keep class okio.** { *; }
-dontwarn okio.**

# Just Audio (media session + ExoPlayer bridge)
-keep class com.ryanheise.** { *; }
-dontwarn com.ryanheise.**

# Record Android plugin (microphone / NDK audio)
-keep class com.llfbandit.record.** { *; }
-dontwarn com.llfbandit.record.**

# Location plugin (GMS FusedLocation + GMS common)
-keep class com.lyokone.location.** { *; }
-dontwarn com.lyokone.location.**

# flutter_local_notifications (schedules alarms via AndroidX core)
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# flutter_callkit_incoming (telecom / VoIP service + reflection)
-keep class co.huntie.flutter_callkit_incoming.** { *; }
-dontwarn co.huntie.flutter_callkit_incoming.**
-keep class com.timwoj.flutter_callkit_incoming.** { *; }
-dontwarn com.timwoj.flutter_callkit_incoming.**

# Permission Handler + Wakelock Plus (Activity binding + reflection)
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**
-keep class creativemaybeno.wakelock_plus.** { *; }
-dontwarn creativemaybeno.wakelock_plus.**

# AndroidX / Guava / WorkManager classes that are referenced only
# behind compile-time guards (library declares them @RequiresApi, or
# Flavio classes shadow across versions). R8 treats missing refs as errors
# unless explicitly silenced.
-dontwarn androidx.window.**
-dontwarn androidx.concurrent.**
-dontwarn androidx.work.**
-dontwarn com.google.common.util.concurrent.**
-dontwarn com.squareup.moshi.**
