package com.dubai.bimobondapp

import android.content.pm.PackageManager
import android.media.AudioManager
import android.media.ToneGenerator
import androidx.camera.lifecycle.ProcessCameraProvider
import com.dubai.bimobondapp.ar_camera.ArCameraBridge
import com.dubai.bimobondapp.ar_camera.ArCameraController
import com.dubai.bimobondapp.ar_camera.ArCameraPlatformViewFactory
import com.dubai.bimobondapp.ar_camera.ArColorGradeBaker
import com.dubai.bimobondapp.ar_camera.FaceLandmarkerHolder
import com.dubai.bimobondapp.ar_camera.LiveRetouchAdjustments
import com.dubai.bimobondapp.ar_camera.LiveRetouchState
import com.dubai.bimobondapp.beauty.BeautyFilterProcessor
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {

    companion object {
        const val AR_CAMERA_CHANNEL = "com.dubai.bimobondapp/ar_camera"
        const val AR_CAMERA_VIEW_TYPE = "ar-camera-preview"
    }

    private var arCameraChannel: MethodChannel? = null

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
                    "applyColorLut" -> {
                        val path = call.argument<String>("path")
                        val filterId = call.argument<String>("filter") ?: "none"
                        if (path.isNullOrBlank()) {
                            result.error("invalid_args", "path required", null)
                            return@setMethodCallHandler
                        }
                        val intensity =
                            (call.argument<Any>("intensity") as? Number)?.toFloat() ?: 1f
                        val maxEdge = when (val raw = call.argument<Any>("maxEdge")) {
                            is Int -> raw
                            is Long -> raw.toInt()
                            is Double -> raw.toInt()
                            else -> null
                        }
                        beautyExecutor.execute {
                            try {
                                val out = ArColorGradeBaker.applyToFile(
                                    context = this@MainActivity.applicationContext,
                                    inputPath = path,
                                    filterId = filterId,
                                    intensity = intensity,
                                    maxEdge = maxEdge,
                                )
                                runOnUiThread { result.success(out) }
                            } catch (t: Throwable) {
                                runOnUiThread {
                                    result.error("lut_failed", t.message ?: "unknown", null)
                                }
                            }
                        }
                    }
                    "setFilter" -> {
                        val filter = call.argument<String>("filter") ?: "none"
                        val intensity = call.argument<Double>("intensity")?.toFloat()
                        ArCameraBridge.setFilter(filter, intensity)
                        result.success(null)
                    }
                    "setFilterIntensity" -> {
                        val intensity = call.argument<Double>("intensity")?.toFloat() ?: 1f
                        ArCameraBridge.updateFilterIntensity(intensity)
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
                        )
                        ArCameraBridge.warpGlView?.requestRender()
                        result.success(null)
                    }
                    "clearRetouchAdjustments" -> {
                        LiveRetouchState.clear()
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
        FaceLandmarkerHolder.warmup(this)
        try {
            ProcessCameraProvider.getInstance(this)
        } catch (_: Throwable) {
        }
        // Warm H.264 encoder so the first record tap isn't cold.
        Executors.newSingleThreadExecutor { r ->
            Thread(r, "ar-encoder-warm").apply { isDaemon = true }
        }.execute {
            try {
                val codec = android.media.MediaCodec.createEncoderByType(
                    android.media.MediaFormat.MIMETYPE_VIDEO_AVC,
                )
                codec.release()
            } catch (_: Throwable) {
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
    }

    override fun onDestroy() {
        ArCameraController.onRecordingAutoStopped = null
        CountdownTonePlayer.release()
        super.onDestroy()
    }
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
