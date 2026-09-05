plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Add the Google services Gradle plugin
    id("com.google.gms.google-services")
}

android {
    namespace = "com.dubai.bimobondapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.dubai.bimobondapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Leave abiFilters empty so `flutter build apk --split-per-abi` can
        // emit armeabi-v7a / arm64-v8a / x86_64 outputs without conflict.
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    packaging {
        jniLibs {
            // Keep MediaPipe .so extractable on devices where compressed JNI fails.
            useLegacyPackaging = true
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // FlutterFire plugins supply Firebase SDK versions.
    implementation("com.google.android.gms:play-services-auth:21.5.1")
    implementation("com.google.android.gms:play-services-maps:19.2.0")

    // filters camera dependencies
    implementation("androidx.camera:camera-core:1.4.1")
    implementation("androidx.camera:camera-camera2:1.4.1")
    implementation("androidx.camera:camera-lifecycle:1.4.1")
    implementation("androidx.camera:camera-view:1.4.1")
    implementation("androidx.camera:camera-video:1.4.1")
    implementation("androidx.camera:camera-effects:1.4.1")
    // MediaPipe Face Landmarker (468-point mesh)
    // 0.10.29+ restores missing ABI / 16KB page native libs (fixes
    // UnsatisfiedLinkError: libmediapipe_tasks_vision_jni.so not found).
    implementation("com.google.mediapipe:tasks-vision:0.10.29")

    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("com.google.guava:guava:33.3.1-android")

    // WebRTC — the live beauty shader runs on the frames LiveKit publishes,
    // so it needs org.webrtc's GL helpers and frame types. flutter_webrtc
    // declares this same artifact as `implementation`, which keeps it off our
    // compile classpath; compileOnly at the identical version lets us build
    // against it while the plugin still supplies the one copy at runtime.
    compileOnly("io.github.webrtc-sdk:android:144.7559.09")

    // Lottie — confetti overlay animation on the AR camera preview.
    implementation("com.airbnb.android:lottie:6.6.2")

    // MP4/WebM screen overlays on the AR camera preview.
    implementation("androidx.media3:media3-exoplayer:1.5.1")
    implementation("androidx.media3:media3-datasource:1.5.1")

    // Media3 Transformer — Phase 11 camera_engine export / compression (HW encode).
    implementation("androidx.media3:media3-transformer:1.5.1")
    implementation("androidx.media3:media3-effect:1.5.1")
    implementation("androidx.media3:media3-common:1.5.1")

    // OpenCV Android SDK (Maven Central) — still-image beauty pipeline
    implementation("org.opencv:opencv:4.9.0")

    // Same WebRTC as flutter_webrtc / livekit — needed so app Kotlin can
    // implement VideoCapturer for FaceWarp → LiveKit beauty publish.
    implementation("io.github.webrtc-sdk:android:144.7559.09")
}
