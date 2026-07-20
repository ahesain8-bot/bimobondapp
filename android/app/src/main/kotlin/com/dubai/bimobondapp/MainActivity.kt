package com.dubai.bimobondapp

import android.content.pm.PackageManager
import android.media.AudioManager
import android.media.ToneGenerator
import com.dubai.bimobondapp.ar_camera.ArCameraBridge
import com.dubai.bimobondapp.ar_camera.ArCameraController
import com.dubai.bimobondapp.ar_camera.ArCameraPlatformViewFactory
import com.dubai.bimobondapp.ar_camera.ArColorGradeBaker
import com.dubai.bimobondapp.ar_camera.FaceLandmarkerHolder
import com.dubai.bimobondapp.beauty.BeautyFilterProcessor
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    companion object {
        const val AR_CAMERA_CHANNEL = "com.dubai.bimobondapp/ar_camera"
        const val AR_CAMERA_VIEW_TYPE = "ar-camera-preview"
    }

    private val beautyExecutor = Executors.newSingleThreadExecutor { r ->
        Thread(r, "beauty-filter").apply { isDaemon = true }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Load OpenCV early so first beauty apply is fast.
        beautyExecutor.execute { BeautyFilterProcessor.ensureOpenCv() }

        flutterEngine.platformViewsController.registry.registerViewFactory(
            AR_CAMERA_VIEW_TYPE,
            ArCameraPlatformViewFactory(this),
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AR_CAMERA_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "warmup" -> {
                        FaceLandmarkerHolder.warmup(this)
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
                        ArCameraController.startRecording { ok, error ->
                            if (ok) {
                                result.success(null)
                            } else {
                                result.error("record_start_failed", error ?: "unknown", null)
                            }
                        }
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
