package com.dubai.bimobondapp

import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Registers Flutter plugins one-by-one so a single failing plugin (notably FFmpegKit
 * on 16 KB page-size devices) does not abort registration for Firebase and others.
 *
 * Update this list when [io.flutter.plugins.GeneratedPluginRegistrant] changes
 * after `flutter pub get`.
 */
object SafePluginRegistrant {
    private const val TAG = "SafePluginRegistrant"

    fun registerWith(flutterEngine: FlutterEngine) {
        safeAdd(flutterEngine, "camerawesome") {
            com.apparence.camerawesome.cameraX.CameraAwesomeX()
        }
        safeAdd(flutterEngine, "cloud_firestore") {
            io.flutter.plugins.firebase.firestore.FlutterFirebaseFirestorePlugin()
        }
        safeAdd(flutterEngine, "cloud_functions") {
            io.flutter.plugins.firebase.functions.FlutterFirebaseFunctionsPlugin()
        }
        safeAdd(flutterEngine, "device_info_plus") {
            dev.fluttercommunity.plus.device_info.DeviceInfoPlusPlugin()
        }
        safeAdd(flutterEngine, "ffmpeg_kit_flutter_new") {
            com.antonkarpenko.ffmpegkit.FFmpegKitFlutterPlugin()
        }
        safeAdd(flutterEngine, "flutter_image_compress_common") {
            com.fluttercandies.flutter_image_compress.ImageCompressPlugin()
        }
        safeAdd(flutterEngine, "video_thumbnail") {
            xyz.justsoft.video_thumbnail.VideoThumbnailPlugin()
        }
        safeAdd(flutterEngine, "file_selector_android") {
            dev.flutter.packages.file_selector_android.FileSelectorAndroidPlugin()
        }
        safeAdd(flutterEngine, "firebase_auth") {
            io.flutter.plugins.firebase.auth.FlutterFirebaseAuthPlugin()
        }
        safeAdd(flutterEngine, "firebase_core") {
            io.flutter.plugins.firebase.core.FlutterFirebaseCorePlugin()
        }
        safeAdd(flutterEngine, "firebase_messaging") {
            io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingPlugin()
        }
        safeAdd(flutterEngine, "flutter_contacts") {
            co.quis.flutter_contacts.FlutterContactsPlugin()
        }
        safeAdd(flutterEngine, "flutter_facebook_auth") {
            app.meedu.flutter_facebook_auth.FlutterFacebookAuthPlugin()
        }
        safeAdd(flutterEngine, "flutter_local_notifications") {
            com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin()
        }
        safeAdd(flutterEngine, "flutter_plugin_android_lifecycle") {
            io.flutter.plugins.flutter_plugin_android_lifecycle.FlutterAndroidLifecyclePlugin()
        }
        safeAdd(flutterEngine, "geocoding_android") {
            com.baseflow.geocoding.GeocodingPlugin()
        }
        safeAdd(flutterEngine, "geolocator_android") {
            com.baseflow.geolocator.GeolocatorPlugin()
        }
        safeAdd(flutterEngine, "google_mlkit_commons") {
            com.google_mlkit_commons.GoogleMlKitCommonsPlugin()
        }
        safeAdd(flutterEngine, "google_mlkit_face_detection") {
            com.google_mlkit_face_detection.GoogleMlKitFaceDetectionPlugin()
        }
        safeAdd(flutterEngine, "google_sign_in_android") {
            io.flutter.plugins.googlesignin.GoogleSignInPlugin()
        }
        safeAdd(flutterEngine, "image_picker_android") {
            io.flutter.plugins.imagepicker.ImagePickerPlugin()
        }
        safeAdd(flutterEngine, "jni") {
            com.github.dart_lang.jni.JniPlugin()
        }
        safeAdd(flutterEngine, "jni_flutter") {
            com.github.dart_lang.jni_flutter.JniFlutterPlugin()
        }
        safeAdd(flutterEngine, "package_info_plus") {
            dev.fluttercommunity.plus.packageinfo.PackageInfoPlugin()
        }
        safeAdd(flutterEngine, "permission_handler_android") {
            com.baseflow.permissionhandler.PermissionHandlerPlugin()
        }
        safeAdd(flutterEngine, "record_android") {
            com.llfbandit.record.RecordPlugin()
        }
        safeAdd(flutterEngine, "share_plus") {
            dev.fluttercommunity.plus.share.SharePlusPlugin()
        }
        safeAdd(flutterEngine, "shared_preferences_android") {
            io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin()
        }
        safeAdd(flutterEngine, "sqflite_android") {
            com.tekartik.sqflite.SqflitePlugin()
        }
        safeAdd(flutterEngine, "url_launcher_android") {
            io.flutter.plugins.urllauncher.UrlLauncherPlugin()
        }
        safeAdd(flutterEngine, "video_player_android") {
            io.flutter.plugins.videoplayer.VideoPlayerPlugin()
        }
    }

    private inline fun safeAdd(
        flutterEngine: FlutterEngine,
        name: String,
        factory: () -> FlutterPlugin,
    ) {
        try {
            flutterEngine.plugins.add(factory())
        } catch (t: Throwable) {
            Log.e(TAG, "Error registering plugin $name", t)
        }
    }
}
