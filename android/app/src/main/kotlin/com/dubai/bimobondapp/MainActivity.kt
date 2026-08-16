package com.dubai.bimobondapp

import android.content.pm.PackageManager
import android.media.AudioManager
import android.media.ToneGenerator
import androidx.camera.lifecycle.ProcessCameraProvider
import com.dubai.bimobondapp.ar_camera.ArCameraBridge
import com.dubai.bimobondapp.ar_camera.ArCameraController
import com.dubai.bimobondapp.ar_camera.ArCameraOverlayPrefetcher
import com.dubai.bimobondapp.ar_camera.ArCameraPlatformViewFactory
import com.dubai.bimobondapp.ar_camera.ScreenOverlaySource
import com.dubai.bimobondapp.ar_camera.parseOverlayMediaType
import com.dubai.bimobondapp.ar_camera.FaceLandmarkerHolder
import com.dubai.bimobondapp.ar_camera.LiveBeautyAdjustments
import com.dubai.bimobondapp.ar_camera.LiveBeautyState
import com.dubai.bimobondapp.ar_camera.LiveRetouchAdjustments
import com.dubai.bimobondapp.ar_camera.LiveRetouchState
import com.dubai.bimobondapp.beauty.BeautyFilterProcessor
import com.dubai.bimobondapp.camera_engine.NativeCameraPlugin
import com.dubai.bimobondapp.camera_engine.TemplateExportPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {

    companion object {
        const val AR_CAMERA_CHANNEL = "com.dubai.bimobondapp/ar_camera"
        const val AR_CAMERA_VIEW_TYPE = "ar-camera-preview"
    }

    private var arCameraChannel: MethodChannel? = null
    private val arPipelineWarmupStarted = AtomicBoolean(false)

    private val beautyExecutor = Executors.newSingleThreadExecutor { r ->
        Thread(r, "beauty-filter").apply { isDaemon = true }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Load OpenCV early so first beauty apply is fast.
        beautyExecutor.execute { BeautyFilterProcessor.ensureOpenCv() }
        // Prefetch CameraX + MediaPipe before the user taps + (cuts open delay).
        warmArCameraPipeline()

        flutterEngine.platformViewsController.registry.registerViewFactory(
            AR_CAMERA_VIEW_TYPE,
            ArCameraPlatformViewFactory(this),
        )

        // Phase 1: CameraX → Flutter TextureRegistry (no effects / recording).
        NativeCameraPlugin.register(flutterEngine, this)
        // Template timeline → Media3 Transformer / MediaCodec export.
        TemplateExportPlugin.register(flutterEngine, this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AR_CAMERA_CHANNEL)
            .also { arCameraChannel = it }
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "warmup" -> {
                        warmArCameraPipeline()
                        result.success(null)
                    }
                    "applyBeauty" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("invalid_args", "path required", null)
                            return@setMethodCallHandler
                        }
                        fun argInt(key: String, default: Int = 0, min: Int = 0, max: Int = 100): Int =
                            when (val raw = call.argument<Any>(key)) {
                                is Int -> raw
                                is Long -> raw.toInt()
                                is Double -> raw.toInt()
                                else -> default
                            }.coerceIn(min, max)
                        val adjustments = BeautyFilterProcessor.Adjustments(
                            saturation = argInt("saturationLevel", 0, -100, 100),
                            brightness = argInt("brightnessLevel", 0, -100, 100),
                            contrast = argInt("contrastLevel", 0, -100, 100),
                            exposure = argInt("exposureLevel", 0, -100, 100),
                            whiteBalance = argInt("whiteBalanceLevel", 0, -100, 100),
                            highlights = argInt("highlightsLevel", 0, -100, 100),
                            shadows = argInt("shadowsLevel", 0, -100, 100),
                            nose = argInt("noseLevel", 0, -100, 100),
                        )
                        val maxEdge = when (val raw = call.argument<Any>("maxEdge")) {
                            is Int -> raw
                            is Long -> raw.toInt()
                            is Double -> raw.toInt()
                            else -> null
                        }
                        beautyExecutor.execute {
                            try {
                                val out = BeautyFilterProcessor.apply(
                                    context = this@MainActivity,
                                    inputPath = path,
                                    adjustments = adjustments,
                                    maxEdge = maxEdge,
                                )
                                runOnUiThread { result.success(out) }
                            } catch (t: Throwable) {
                                runOnUiThread {
                                    result.error("beauty_failed", t.message ?: "unknown", null)
                                }
                            }
                        }
                    }
                    "setFilter" -> {
                        val filter = call.argument<String>("filter") ?: "none"
                        val intensity = call.argument<Double>("intensity")?.toFloat()
                        // Present only for screen overlays — Dart looks the
                        // animation up in its (backend-driven) catalog and sends
                        // it along, since native has no overlay list of its own.
                        val overlayUrl = call.argument<String>("overlayUrl")
                        val overlayAsset = call.argument<String>("overlayAsset")
                        val overlayMediaType = call.argument<String>("overlayMediaType")
                        val overlay = if (!overlayUrl.isNullOrBlank() ||
                            !overlayAsset.isNullOrBlank()
                        ) {
                            ScreenOverlaySource(
                                id = filter,
                                url = overlayUrl,
                                assetName = overlayAsset,
                                loop = call.argument<Boolean>("overlayLoop") ?: true,
                                mediaType = parseOverlayMediaType(
                                    overlayMediaType,
                                    overlayUrl,
                                    overlayAsset,
                                ),
                            )
                        } else {
                            null
                        }
                        val is360 = call.argument<Boolean>("is360") ?: (filter == "static_360_test")
                        val video360Url = call.argument<String>("video360Url")
                        if (is360 || !video360Url.isNullOrBlank()) {
                            val targetUrl = if (!video360Url.isNullOrBlank()) video360Url else "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4"
                            ArCameraBridge.initialize360EffectEngine(this)
                            ArCameraBridge.load360Effect(targetUrl, null)
                        } else {
                            ArCameraBridge.remove360Effect()
                        }

                        ArCameraBridge.setFilter(filter, intensity, overlay)
                        result.success(null)
                    }
                    "prefetchOverlays" -> {
                        val lottieUrls = call.argument<List<String>>("urls").orEmpty()
                        val videoUrls = call.argument<List<String>>("videoUrls").orEmpty()
                        val assets = call.argument<List<String>>("assets").orEmpty()
                        ArCameraOverlayPrefetcher.prefetch(this, lottieUrls, videoUrls, assets)
                        result.success(null)
                    }
                    "setFilterIntensity" -> {
                        val intensity = call.argument<Double>("intensity")?.toFloat() ?: 1f
                        ArCameraBridge.updateFilterIntensity(intensity)
                        result.success(null)
                    }
                    "initializeEffectEngine" -> {
                        ArCameraBridge.initializeEffectEngine(this)
                        result.success(null)
                    }
                    "setOverlayEffect" -> {
                        val effect = parseEffectDefinition(call.arguments)
                        if (effect != null) {
                            ArCameraBridge.setOverlayEffect(effect)
                        }
                        result.success(null)
                    }
                    "removeOverlayEffect" -> {
                        ArCameraBridge.removeOverlayEffect()
                        result.success(null)
                    }
                    "setOverlayPosition" -> {
                        val x = call.argument<Double>("positionX")?.toFloat() ?: 0.5f
                        val y = call.argument<Double>("positionY")?.toFloat() ?: 0.5f
                        ArCameraBridge.setOverlayPosition(x, y)
                        result.success(null)
                    }
                    "setOverlayScale" -> {
                        val scale = call.argument<Double>("scale")?.toFloat() ?: 1.0f
                        ArCameraBridge.setOverlayScale(scale)
                        result.success(null)
                    }
                    "setOverlayOpacity" -> {
                        val opacity = call.argument<Double>("opacity")?.toFloat() ?: 1.0f
                        ArCameraBridge.setOverlayOpacity(opacity)
                        result.success(null)
                    }
                    "setOverlayLoop" -> {
                        val loop = call.argument<Boolean>("loop") ?: true
                        ArCameraBridge.setOverlayLoop(loop)
                        result.success(null)
                    }
                    "prepareShaderPipeline" -> {
                        ArCameraBridge.prepareShaderPipeline()
                        result.success(null)
                    }
                    "takePhoto" -> {
                        val top = call.argument<Int>("letterboxTopPx")
                        val bottom = call.argument<Int>("letterboxBottomPx")
                        if (top != null && bottom != null) {
                            ArCameraBridge.setPreviewLetterbox(top, bottom)
                        }
                        val replied = java.util.concurrent.atomic.AtomicBoolean(false)
                        ArCameraController.takePhoto { path, error ->
                            if (!replied.compareAndSet(false, true)) return@takePhoto
                            if (path != null) {
                                result.success(path)
                            } else {
                                result.error("photo_failed", error ?: "unknown", null)
                            }
                        }
                    }
                    "startRecording" -> {
                        val top = call.argument<Int>("letterboxTopPx")
                        val bottom = call.argument<Int>("letterboxBottomPx")
                        if (top != null && bottom != null) {
                            ArCameraBridge.setPreviewLetterbox(top, bottom)
                        }
                        val maxDurationMs = when (val raw = call.argument<Any>("maxDurationMs")) {
                            is Int -> raw.toLong()
                            is Long -> raw
                            is Double -> raw.toLong()
                            else -> 0L
                        }.coerceAtLeast(0L)
                        ArCameraController.startRecording(
                            onResult = { ok, error ->
                                if (ok) {
                                    result.success(null)
                                } else {
                                    result.error("record_start_failed", error ?: "unknown", null)
                                }
                            },
                            maxDurationMs = maxDurationMs,
                        )
                    }
                    "stopRecording" -> {
                        ArCameraController.stopRecording { path, error ->
                            if (path != null) {
                                result.success(path)
                            } else {
                                result.error("record_stop_failed", error ?: "unknown", null)
                            }
                        }
                    }
                    "mergeVideoSegments" -> {
                        val paths = call.argument<List<*>>("paths")
                            ?.mapNotNull { it?.toString() }
                            .orEmpty()
                        ArCameraController.mergeVideoSegments(paths) { path, error ->
                            if (path != null) {
                                result.success(path)
                            } else {
                                result.error("merge_failed", error ?: "unknown", null)
                            }
                        }
                    }
                    "trimVideoTail" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("invalid_args", "path required", null)
                            return@setMethodCallHandler
                        }
                        val trimMs = when (val raw = call.argument<Any>("trimMs")) {
                            is Int -> raw.toLong()
                            is Long -> raw
                            is Double -> raw.toLong()
                            else -> 120L
                        }.coerceIn(40L, 500L)
                        val maxDurationMs = when (val raw = call.argument<Any>("maxDurationMs")) {
                            is Int -> raw.toLong()
                            is Long -> raw
                            is Double -> raw.toLong()
                            else -> null
                        }
                        Executors.newSingleThreadExecutor { r ->
                            Thread(r, "ar-video-tail-trim").apply { isDaemon = true }
                        }.execute {
                            try {
                                val input = java.io.File(path)
                                val trimmed = if (maxDurationMs != null && maxDurationMs > 0L) {
                                    com.dubai.bimobondapp.ar_camera.ArVideoTailTrimmer.trimToDuration(
                                        input = input,
                                        maxDurationUs = maxDurationMs * 1000L,
                                    )
                                } else {
                                    com.dubai.bimobondapp.ar_camera.ArVideoTailTrimmer.trimEnd(
                                        input = input,
                                        trimUs = trimMs * 1000L,
                                    )
                                }
                                val finalPath = if (
                                    trimmed != null &&
                                    trimmed.absolutePath != input.absolutePath &&
                                    trimmed.exists()
                                ) {
                                    try {
                                        if (input.exists()) input.delete()
                                        if (trimmed.renameTo(input)) {
                                            input.absolutePath
                                        } else {
                                            trimmed.copyTo(input, overwrite = true)
                                            trimmed.delete()
                                            input.absolutePath
                                        }
                                    } catch (_: Exception) {
                                        trimmed.absolutePath
                                    }
                                } else {
                                    trimmed?.absolutePath ?: path
                                }
                                runOnUiThread { result.success(finalPath) }
                            } catch (t: Throwable) {
                                runOnUiThread {
                                    result.error("trim_failed", t.message ?: "unknown", null)
                                }
                            }
                        }
                    }
                    "flipCamera" -> {
                        ArCameraController.flipCamera { ok ->
                            if (ok) {
                                result.success(ArCameraBridge.isFrontCamera)
                            } else {
                                result.error("flip_failed", "cannot_flip", null)
                            }
                        }
                    }
                    "toggleTorch" -> {
                        ArCameraController.toggleTorch { enabled, error ->
                            if (error == null) {
                                result.success(enabled)
                            } else {
                                result.error("torch_failed", error, null)
                            }
                        }
                    }
                    // Called when the camera screen is covered by another route
                    // (media studio editor) and when it comes back — the host
                    // Activity isn't paused by a Flutter push, so the native
                    // camera has to be told explicitly.
                    "suspendPreview" -> {
                        ArCameraController.suspendPreview()
                        result.success(null)
                    }
                    "resumePreview" -> {
                        ArCameraController.resumePreview()
                        result.success(null)
                    }
                    // Fully tears the native camera down (camera unbound). Used
                    // before pushing a route that opens its own camera (live
                    // room) so the lens is never held twice at once.
                    "stopCamera" -> {
                        ArCameraController.stop()
                        result.success(null)
                    }
                    // Re-initialises the native camera after [stopCamera] when
                    // the camera screen becomes visible again.
                    "startCamera" -> {
                        val activity = ArCameraBridge.hostActivity
                        val lifecycleOwner = ArCameraBridge.lifecycleOwner
                        val previewView = ArCameraBridge.previewView
                        val faceOverlay = ArCameraBridge.faceOverlay
                        if (activity != null && lifecycleOwner != null &&
                            previewView != null && faceOverlay != null
                        ) {
                            ArCameraController.start(
                                activity,
                                lifecycleOwner,
                                previewView,
                                faceOverlay,
                            )
                        }
                        result.success(null)
                    }
                    "setPreviewLetterbox" -> {
                        val top = call.argument<Int>("topPx") ?: 0
                        val bottom = call.argument<Int>("bottomPx") ?: 0
                        ArCameraBridge.setPreviewLetterbox(top, bottom)
                        result.success(null)
                    }
                    "setRetouchAdjustments" -> {
                        fun level(key: String): Int =
                            when (val raw = call.argument<Any>(key)) {
                                is Int -> raw
                                is Long -> raw.toInt()
                                is Double -> raw.roundToInt()
                                is Float -> raw.toInt()
                                else -> 0
                            }.coerceIn(-100, 100)
                        LiveRetouchState.adjustments = LiveRetouchAdjustments.fromLevels(
                            saturation = level("saturationLevel"),
                            brightness = level("brightnessLevel"),
                            contrast = level("contrastLevel"),
                            exposure = level("exposureLevel"),
                            whiteBalance = level("whiteBalanceLevel"),
                            highlights = level("highlightsLevel"),
                            shadows = level("shadowsLevel"),
                            nose = level("noseLevel"),
                            shape = level("shapeLevel"),
                            eyes = level("eyesLevel"),
                            tooth = level("toothLevel"),
                            mouth = level("mouthLevel"),
                        )
                        ArCameraBridge.warpGlView?.requestRender()
                        result.success(null)
                    }
                    "clearRetouchAdjustments" -> {
                        LiveRetouchState.clear()
                        ArCameraBridge.warpGlView?.requestRender()
                        result.success(null)
                    }
                    "setBeautyFilter" -> {
                        fun level(key: String): Float =
                            when (val raw = call.argument<Any>(key)) {
                                is Double -> raw.toFloat()
                                is Int -> raw.toFloat()
                                is Long -> raw.toFloat()
                                is Float -> raw
                                else -> 0f
                            }.coerceIn(0f, 1f)
                        LiveBeautyState.apply(
                            smooth = level("smooth"),
                            whiten = level("whiten"),
                            brighten = level("brighten"),
                            blush = level("blush"),
                            lipTintHex = call.argument<String>("lipTint") ?: "#E8527A",
                            lipStrength = level("lipStrength"),
                            intensity = level("intensity"),
                        )
                        ArCameraBridge.warpGlView?.requestRender()
                        result.success(null)
                    }
                    "clearBeautyFilter" -> {
                        LiveBeautyState.clear()
                        ArCameraBridge.warpGlView?.requestRender()
                        result.success(null)
                    }
                    "setMagicEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val strength = when (val raw = call.argument<Any>("strength")) {
                            is Double -> raw.toFloat()
                            is Int -> raw.toFloat()
                            is Long -> raw.toFloat()
                            is Float -> raw
                            else -> null
                        }
                        LiveBeautyState.setMagic(enabled, strength)
                        android.util.Log.i(
                            "ArRetouchMagic",
                            "setMagicEnabled=$enabled strength=${LiveBeautyState.magicStrength} " +
                                "smooth=${LiveBeautyState.adjustments.smooth}",
                        )
                        ArCameraBridge.warpGlView?.requestRender()
                        result.success(null)
                    }
                    "setMagicStrength" -> {
                        val strength = when (val raw = call.argument<Any>("strength")) {
                            is Double -> raw.toFloat()
                            is Int -> raw.toFloat()
                            is Long -> raw.toFloat()
                            is Float -> raw
                            else -> LiveBeautyAdjustments.MAGIC_AUTO_STRENGTH
                        }
                        LiveBeautyState.applyMagicStrength(strength)
                        ArCameraBridge.warpGlView?.requestRender()
                        result.success(null)
                    }
                    "setZoom" -> {
                        val zoom = (call.argument<Double>("zoom") ?: 0.0).toFloat()
                        ArCameraController.setLinearZoom(zoom) { ok, error ->
                            if (ok) {
                                result.success(null)
                            } else {
                                result.error("zoom_failed", error ?: "unknown", null)
                            }
                        }
                    }
                    "playCountdownTick" -> {
                        val isFinal = call.argument<Boolean>("isFinal") ?: false
                        CountdownTonePlayer.play(isFinal)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        ArCameraController.onRecordingAutoStopped = { path ->
            runOnUiThread {
                arCameraChannel?.invokeMethod("onRecordingAutoStopped", path)
            }
        }
    }

    /** Prefetch CameraX provider + MediaPipe so + → camera isn't cold-starting. */
    private fun warmArCameraPipeline() {
        if (!arPipelineWarmupStarted.compareAndSet(false, true)) return
        FaceLandmarkerHolder.warmup(this)
        try {
            ProcessCameraProvider.getInstance(this)
        } catch (_: Throwable) {
        }
        // Warm H.264 encoder so the first record tap isn't cold.
        val executor = Executors.newSingleThreadExecutor { r ->
            Thread(r, "ar-encoder-warm").apply { isDaemon = true }
        }
        executor.execute {
            try {
                val codec = android.media.MediaCodec.createEncoderByType(
                    android.media.MediaFormat.MIMETYPE_VIDEO_AVC,
                )
                codec.release()
            } catch (_: Throwable) {
            } finally {
                executor.shutdown()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 100 &&
            grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        ) {
            ArCameraController.onPermissionGranted()
        }
        if (requestCode == 101) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            NativeCameraPlugin.onPermissionResult(requestCode, granted)
        }
    }

    override fun onDestroy() {
        ArCameraController.onRecordingAutoStopped = null
        NativeCameraPlugin.dispose()
        CountdownTonePlayer.release()
        super.onDestroy()
    }
}

private fun parseEffectDefinition(args: Any?): com.dubai.bimobondapp.ar_camera.EffectDefinition? {
    val map = args as? Map<*, *> ?: return null
    val id = map["id"]?.toString() ?: return null
    return com.dubai.bimobondapp.ar_camera.EffectDefinition(
        id = id,
        type = map["type"]?.toString() ?: "screen_overlay",
        assetUrl = map["assetUrl"]?.toString(),
        assetName = map["assetName"]?.toString(),
        durationMs = (map["durationMs"] as? Number)?.toLong() ?: 0L,
        loop = map["loop"] as? Boolean ?: true,
        startTimeMs = (map["startTimeMs"] as? Number)?.toLong() ?: 0L,
        endTimeMs = (map["endTimeMs"] as? Number)?.toLong() ?: 0L,
        opacity = (map["opacity"] as? Number)?.toFloat() ?: 1.0f,
        scale = (map["scale"] as? Number)?.toFloat() ?: 1.0f,
        positionX = (map["positionX"] as? Number)?.toFloat() ?: 0.5f,
        positionY = (map["positionY"] as? Number)?.toFloat() ?: 0.5f,
        rotation = (map["rotation"] as? Number)?.toFloat() ?: 0.0f,
        blendMode = map["blendMode"]?.toString() ?: "normal",
    )
}

/// Plays the TikTok-style countdown beeps natively via [ToneGenerator] on the
/// media stream, so they are audible even when system touch/key sounds are off.
private object CountdownTonePlayer {
    private var toneGenerator: ToneGenerator? = null

    @Synchronized
    fun play(isFinal: Boolean) {
        try {
            val generator = toneGenerator
                ?: ToneGenerator(AudioManager.STREAM_MUSIC, 90).also { toneGenerator = it }
            if (isFinal) {
                // Last second: a longer, sustained "tuunn" (continuous dial tone)
                // — clearly different from the short ticks, right before capture.
                generator.startTone(ToneGenerator.TONE_SUP_DIAL, 320)
            } else {
                // Each second: a short crisp "tik".
                generator.startTone(ToneGenerator.TONE_PROP_BEEP, 120)
            }
        } catch (t: Throwable) {
            // ToneGenerator can throw on some devices when the audio resource is
            // busy; drop it so the next tick recreates a fresh instance.
            try {
                toneGenerator?.release()
            } catch (_: Throwable) {
            }
            toneGenerator = null
        }
    }

    @Synchronized
    fun release() {
        try {
            toneGenerator?.release()
        } catch (_: Throwable) {
        }
        toneGenerator = null
    }
}