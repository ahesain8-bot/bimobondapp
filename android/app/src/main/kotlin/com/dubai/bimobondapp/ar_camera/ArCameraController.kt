package com.dubai.bimobondapp.ar_camera

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import android.util.Size
import android.view.Surface
import android.view.View
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import androidx.camera.core.Camera

object ArCameraController {
    private const val ANALYSIS_WIDTH = 1080
    private const val ANALYSIS_HEIGHT = 1440
    private const val DETECT_MAX_DIMENSION = 384
    private const val GL_MAX_EDGE = 1280
    private const val CAPTURE_MAX_EDGE = 1920
    private const val RECORD_PROCESS_EDGE = ArFilteredVideoRecorder.MAX_EDGE
    private const val PHOTO_TARGET_WIDTH = 2160
    private const val PHOTO_TARGET_HEIGHT = 2880
    private const val RECORD_FRAME_INTERVAL_MS = 33L // ~30 fps production gate (matches pump)

    // Consecutive face-detection misses before we clear overlays/stickers. A small
    // grace avoids flicker on a single dropped detection while still removing the
    // sticker quickly once the face actually leaves the frame.
    private const val NO_FACE_CLEAR_THRESHOLD = 2

    private var faceLandmarker: FaceLandmarkerHelper? = null
    private var started = false
    private var analysisExecutor: ExecutorService? = null
    private var recordOfferExecutor: ExecutorService? = null
    private var recordPumpExecutor: ScheduledExecutorService? = null
    private var recordPumpFuture: ScheduledFuture<*>? = null
    private val recordFrameLock = Any()
    private var latestRecordFrame: Bitmap? = null
    private var pumpCurrentFrame: Bitmap? = null
    private val convertingFrame = AtomicBoolean(false)
    private var frameCounter = 0
    private val mainHandler = Handler(Looper.getMainLooper())
    private val videoRecorder = ArFilteredVideoRecorder()
    private val captureBusy = AtomicBoolean(false)
    private val recordingPixelCopyBusy = AtomicBoolean(false)

    @Volatile
    private var imageCapture: ImageCapture? = null

    @Volatile
    private var imageAnalysis: ImageAnalysis? = null

    // True while a camera flip is rebinding. Frames are dropped so the analysis
    // thread releases the camera and the new lens can open (fixes flip freeze
    // when a face filter is active).
    @Volatile
    private var switchingCamera = false

    // Consecutive frames with no detected face (used to clear stale stickers).
    private var noFaceStreak = 0

    // True when the camera Preview is bound straight to the GL OES SurfaceTexture
    // (the zero-CPU color-grade path). False = classic PreviewView binding used by
    // NONE / PNG stickers / distortion (bitmap) filters.
    @Volatile
    private var boundToOes = false

    @Volatile
    private var camera: Camera? = null

    @Volatile
    private var torchEnabled = false

    private var previousBrightness = Float.NaN

    @Volatile
    private var cachedWarpParams: FaceWarpParams = FaceWarpParams.INACTIVE

    @Volatile
    private var cachedSnapshot: FaceLandmarkSnapshot? = null

    @Volatile
    private var lastCaptureBitmap: Bitmap? = null

    @Volatile
    private var recording = false

    fun start(
        activity: Activity,
        lifecycleOwner: LifecycleOwner,
        previewView: PreviewView,
        faceOverlay: FaceOverlayView,
    ) {
        if (started) return
        started = true

        previewView.implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        previewView.scaleType = PreviewView.ScaleType.FILL_CENTER

        FaceLandmarkerHolder.warmup(activity)
        faceLandmarker = FaceLandmarkerHolder.get()
        analysisExecutor = Executors.newSingleThreadExecutor()
        recordOfferExecutor = Executors.newSingleThreadExecutor { r ->
            Thread(r, "ar-video-offer").apply { priority = Thread.NORM_PRIORITY }
        }

        if (!hasCameraPermission(activity)) {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(
                    Manifest.permission.CAMERA,
                    Manifest.permission.RECORD_AUDIO,
                ),
                100,
            )
            return
        }

        if (!hasMicPermission(activity)) {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.RECORD_AUDIO),
                101,
            )
        }

        previewView.post {
            if (started) {
                bindCamera(lifecycleOwner, previewView, faceOverlay)
            }
        }
    }

    fun onPermissionGranted() {
        val lifecycleOwner = ArCameraBridge.lifecycleOwner ?: return
        val previewView = ArCameraBridge.previewView ?: return
        val faceOverlay = ArCameraBridge.faceOverlay ?: return
        if (hasCameraPermission(ArCameraBridge.hostActivity ?: return)) {
            bindCamera(lifecycleOwner, previewView, faceOverlay)
        }
    }

    fun flipCamera(onResult: ((Boolean) -> Unit)? = null) {
        if (recording || videoRecorder.isRecording()) {
            onResult?.invoke(false)
            return
        }
        val activity = ArCameraBridge.hostActivity
        val lifecycleOwner = ArCameraBridge.lifecycleOwner
        val previewView = ArCameraBridge.previewView
        val faceOverlay = ArCameraBridge.faceOverlay
        if (activity == null || lifecycleOwner == null || previewView == null || faceOverlay == null) {
            onResult?.invoke(false)
            return
        }

        // Pause frame processing so the analysis thread stops holding the camera;
        // otherwise the old lens never releases and the new one fails to open,
        // freezing the preview (only reproduces when a face filter is active).
        switchingCamera = true
        imageAnalysis?.clearAnalyzer()

        ArCameraBridge.isFrontCamera = !ArCameraBridge.isFrontCamera
        frameCounter = 0
        cachedWarpParams = FaceWarpParams.INACTIVE
        cachedSnapshot = null
        FaceLandmarkSmoother.reset()
        convertingFrame.set(false)
        faceOverlay.resetForNonPngFilter()

        activity.runOnUiThread {
            bindCamera(lifecycleOwner, previewView, faceOverlay)
            ArCameraBridge.applyCurrentFilter()
            onResult?.invoke(true)
        }
    }

    fun toggleTorch(onResult: (Boolean, String?) -> Unit) {
        val next = !torchEnabled
        if (ArCameraBridge.isFrontCamera) {
            try {
                camera?.cameraControl?.enableTorch(false)
            } catch (_: Exception) {
            }
            torchEnabled = next
            applyScreenFlash(next)
            onResult(torchEnabled, null)
            return
        }

        applyScreenFlash(false)
        val cam = camera
        if (cam == null) {
            onResult(false, "no_camera")
            return
        }
        if (!cam.cameraInfo.hasFlashUnit()) {
            onResult(false, "no_flash")
            return
        }
        try {
            cam.cameraControl.enableTorch(next)
            torchEnabled = next
            onResult(torchEnabled, null)
        } catch (e: Exception) {
            onResult(false, e.message ?: "torch_failed")
        }
    }

    fun setLinearZoom(zoom: Float, onResult: (Boolean, String?) -> Unit) {
        val cam = camera
        if (cam == null) {
            onResult(false, "no_camera")
            return
        }
        try {
            val clamped = zoom.coerceIn(0f, 1f)
            cam.cameraControl.setLinearZoom(clamped)
            onResult(true, null)
        } catch (e: Exception) {
            onResult(false, e.message ?: "zoom_failed")
        }
    }

    private fun applyScreenFlash(enabled: Boolean) {
        val activity = ArCameraBridge.hostActivity ?: return
        activity.runOnUiThread {
            val window = activity.window
            val attrs = window.attributes
            if (enabled) {
                if (previousBrightness.isNaN()) {
                    previousBrightness = attrs.screenBrightness
                }
                attrs.screenBrightness = 1f
            } else if (!previousBrightness.isNaN()) {
                attrs.screenBrightness = previousBrightness
                previousBrightness = Float.NaN
            } else {
                attrs.screenBrightness =
                    android.view.WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
            }
            window.attributes = attrs
        }
    }

    fun onFilterChanged() {
        frameCounter = 0
        cachedWarpParams = FaceWarpParams.INACTIVE
        // Unstick analysis if a previous conversion hung mid-switch.
        convertingFrame.set(false)
        if (!ArCameraBridge.currentFilter.isPngOverlay() &&
            !ArCameraBridge.currentFilter.isDistortion() &&
            !ArCameraBridge.currentFilter.isBeauty()
        ) {
            cachedSnapshot = null
            FaceLandmarkSmoother.reset()
        }
    }

    fun stop() {
        abortCapture()
        started = false
        boundToOes = false
        rebindPosted = false
        convertingFrame.set(false)
        frameCounter = 0
        cachedWarpParams = FaceWarpParams.INACTIVE
        cachedSnapshot = null
        FaceLandmarkSmoother.reset()
        faceLandmarker = null
        analysisExecutor?.shutdownNow()
        analysisExecutor = null
        recordOfferExecutor?.shutdownNow()
        recordOfferExecutor = null
        imageCapture = null
        camera = null
        torchEnabled = false
        applyScreenFlash(false)
        lastCaptureBitmap?.recycle()
        lastCaptureBitmap = null
        ArCameraBridge.faceOverlay?.clearUnderlay()
        unbindCamera()
    }

    fun abortCapture() {
        recording = false
        videoRecorder.abort()
        stopRecordFramePump()
        captureBusy.set(false)
        recordingPixelCopyBusy.set(false)
    }

    fun takePhoto(onResult: (String?, String?) -> Unit) {
        if (!captureBusy.compareAndSet(false, true)) {
            onResult(null, "busy")
            return
        }

        val delivered = AtomicBoolean(false)
        fun deliver(path: String?, error: String?) {
            if (!delivered.compareAndSet(false, true)) return
            captureBusy.set(false)
            val activity = ArCameraBridge.hostActivity
            if (activity != null) {
                activity.runOnUiThread { onResult(path, error) }
            } else {
                onResult(path, error)
            }
        }

        mainHandler.postDelayed({
            deliver(null, "photo_timeout")
        }, 8_000L)

        fun saveBaked(bitmap: Bitmap): Boolean {
            val activity = ArCameraBridge.hostActivity ?: return false
            var toSave = bitmap
            var owned: Bitmap? = null
            // Compose exact on-screen letterbox (black bars + mid FOV) so editor
            // matches camera preview — mid-only crop looks zoomed when shown full-bleed.
            if (ArCameraBridge.isPreviewLetterboxed()) {
                val root = ArCameraBridge.platformRootSize()
                if (root != null) {
                    owned = ImageProxyBitmapUtils.composeLetterboxedCapture(
                        bitmap,
                        root.first,
                        root.second,
                        ArCameraBridge.letterboxTopPx(),
                        ArCameraBridge.letterboxBottomPx(),
                    )
                    toSave = owned
                }
            }
            return try {
                val file = File(
                    activity.cacheDir,
                    "ar_photo_${System.currentTimeMillis()}.jpg",
                )
                FileOutputStream(file).use { fos ->
                    java.io.BufferedOutputStream(fos, 64 * 1024).use { out ->
                        toSave.compress(Bitmap.CompressFormat.JPEG, 95, out)
                        out.flush()
                    }
                }
                if (file.exists() && file.length() > 0L) {
                    deliver(file.absolutePath, null)
                    true
                } else {
                    false
                }
            } catch (_: Exception) {
                false
            } finally {
                if (owned != null && owned !== bitmap && !owned.isRecycled) {
                    owned.recycle()
                }
                if (bitmap !== lastCaptureBitmap) {
                    try {
                        bitmap.recycle()
                    } catch (_: Exception) {
                    }
                }
            }
        }

        // OES GPU path: still MUST come from the same GL framebuffer as the live
        // preview. ImageCapture is a different stream and was saving left↔right
        // flipped vs what the user saw on screen.
        if (boundToOes) {
            takePhotoFromGl(::deliver, ::saveBaked)
            return
        }

        // High-res ImageCapture only when full-screen (no ratio letterbox).
        // Letterboxed mode must bake from the live preview stream so FOV matches.
        val filter = ArCameraBridge.currentFilter
        if (filter == FilterType.NONE && !ArCameraBridge.isPreviewLetterboxed()) {
            takePhotoWithImageCapture(::deliver)
            return
        }

        fun tryBaked(remaining: Int) {
            snapshotVisibleFrame(preferImmediate = true) { bitmap ->
                if (bitmap != null && !isMostlyEmpty(bitmap) && saveBaked(bitmap)) {
                    return@snapshotVisibleFrame
                }
                if (bitmap != null && bitmap !== lastCaptureBitmap) {
                    try {
                        bitmap.recycle()
                    } catch (_: Exception) {
                    }
                }
                if (remaining > 0) {
                    mainHandler.postDelayed({ tryBaked(remaining - 1) }, 16)
                } else {
                    takePhotoWithImageCapture(::deliver)
                }
            }
        }

        val retries = if (filter.isDistortion()) 2 else 1
        tryBaked(retries)
    }

    /**
     * Grabs the exact on-screen OES/GL frame (same pixels the user sees — same
     * mirror, crop, LUT). Falls back to ImageCapture only if GL readback fails.
     */
    private fun takePhotoFromGl(
        onResult: (String?, String?) -> Unit,
        saveBaked: (Bitmap) -> Boolean,
    ) {
        val gl = ArCameraBridge.warpGlView
        if (gl == null || !gl.isGlInitialized()) {
            takePhotoWithImageCapture(onResult)
            return
        }
        gl.setCaptureMaxEdge(CAPTURE_MAX_EDGE)
        gl.requestCaptureNow()
        fun tryRead(remaining: Int) {
            val gpu = try {
                gl.copyLastFilteredFrame()
            } catch (_: Exception) {
                null
            }
            if (gpu != null && !isMostlyEmpty(gpu) && saveBaked(gpu)) {
                if (!recording) gl.setCaptureEnabled(false)
                return
            }
            gpu?.recycle()
            if (remaining > 0) {
                gl.requestCaptureNow()
                mainHandler.postDelayed({ tryRead(remaining - 1) }, 33)
            } else {
                if (!recording) gl.setCaptureEnabled(false)
                takePhotoWithImageCapture(onResult)
            }
        }
        mainHandler.postDelayed({ tryRead(3) }, 50)
    }

    private fun takePhotoWithImageCapture(onResult: (String?, String?) -> Unit) {
        val activity = ArCameraBridge.hostActivity
        if (activity == null) {
            onResult(null, "no_activity")
            return
        }
        val capture = imageCapture
        if (capture == null) {
            onResult(null, "no_image_capture")
            return
        }

        val file = File(activity.cacheDir, "ar_photo_${System.currentTimeMillis()}.jpg")
        val executor = analysisExecutor ?: ContextCompat.getMainExecutor(activity)

        try {
            // Bake rotation + front-camera mirror into pixels. EXIF-only
            // isReversedHorizontal often saves photos upside-down on Android.
            capture.takePicture(
                executor,
                object : ImageCapture.OnImageCapturedCallback() {
                    override fun onCaptureSuccess(image: ImageProxy) {
                        try {
                            var selfie = ImageProxyBitmapUtils.toUprightCapture(
                                image,
                                mirrorFront = false,
                            )
                            if (selfie == null) {
                                onResult(null, "decode_failed")
                                return
                            }
                            val front = ArCameraBridge.isFrontCamera
                            if (front &&
                                (ArCameraBridge.currentFilter.isPngOverlay() ||
                                    ArCameraBridge.currentFilter.isColorGrade() ||
                                    ArCameraBridge.currentFilter.useShader())
                            ) {
                                // Filters bake in mirrored (preview) space — keep mirrored.
                                val mirrored = ImageProxyBitmapUtils.mirrorHorizontally(selfie)
                                if (mirrored !== selfie) selfie.recycle()
                                selfie = bakeFilterOntoBitmap(mirrored)
                            } else {
                                selfie = bakeFilterOntoBitmap(selfie)
                                if (front) {
                                    val mirrored =
                                        ImageProxyBitmapUtils.mirrorHorizontally(selfie)
                                    if (mirrored !== selfie) selfie.recycle()
                                    selfie = mirrored
                                }
                            }
                            if (ArCameraBridge.isPreviewLetterboxed()) {
                                val root = ArCameraBridge.platformRootSize()
                                if (root != null) {
                                    val composed = ImageProxyBitmapUtils.composeLetterboxedCapture(
                                        selfie,
                                        root.first,
                                        root.second,
                                        ArCameraBridge.letterboxTopPx(),
                                        ArCameraBridge.letterboxBottomPx(),
                                    )
                                    if (composed !== selfie) {
                                        selfie.recycle()
                                        selfie = composed
                                    }
                                }
                            }
                            FileOutputStream(file).use { fos ->
                                java.io.BufferedOutputStream(fos, 64 * 1024).use { out ->
                                    selfie.compress(Bitmap.CompressFormat.JPEG, 95, out)
                                    out.flush()
                                }
                            }
                            selfie.recycle()
                            if (file.exists() && file.length() > 0L) {
                                onResult(file.absolutePath, null)
                            } else {
                                onResult(null, "empty_photo")
                            }
                        } catch (e: Exception) {
                            onResult(null, e.message ?: "photo_failed")
                        } finally {
                            image.close()
                        }
                    }

                    override fun onError(exception: ImageCaptureException) {
                        onResult(null, exception.message ?: "photo_failed")
                    }
                },
            )
        } catch (e: Exception) {
            onResult(null, e.message ?: "photo_failed")
        }
    }

    fun startRecording(onResult: (Boolean, String?) -> Unit) {
        if (recording || videoRecorder.isRecording()) {
            onResult(false, "already_recording")
            return
        }
        val activity = ArCameraBridge.hostActivity
        if (activity == null) {
            onResult(false, "no_activity")
            return
        }

        val file = File(activity.cacheDir, "ar_video_${System.currentTimeMillis()}.mp4")
        try {
            if (!hasMicPermission(activity)) {
                ActivityCompat.requestPermissions(
                    activity,
                    arrayOf(Manifest.permission.RECORD_AUDIO),
                    101,
                )
            }
            videoRecorder.arm(file)
            recording = true
            lastRecordCopyMs = 0L
            startRecordFramePump()
            // Enable GL front-buffer capture whenever the frame is rendered on the
            // GPU (OES path: NONE + color grades, OR a shader distortion) so recorded
            // frames come from the already-rendered GPU output instead of a per-frame
            // CPU pass.
            if (boundToOes || ArCameraBridge.currentFilter.useShader()) {
                ArCameraBridge.warpGlView?.setCaptureEnabled(true)
            }
            onResult(true, null)
        } catch (e: Exception) {
            recording = false
            onResult(false, e.message ?: "record_start_failed")
        }
    }

    fun stopRecording(onResult: (String?, String?) -> Unit) {
        if (!recording && !videoRecorder.isRecording()) {
            onResult(null, "not_recording")
            return
        }
        recording = false
        stopRecordFramePump()
        try {
            ArCameraBridge.warpGlView?.setCaptureEnabled(
                ArCameraBridge.currentFilter.isDistortion(),
            )
            // OES color-grade capture is recording-only; leave it off after stop.
            val file = videoRecorder.stop()
            if (file != null && file.exists() && file.length() > 0L) {
                onResult(file.absolutePath, null)
            } else {
                onResult(null, "empty_video")
            }
        } catch (e: Exception) {
            onResult(null, e.message ?: "record_stop_failed")
        }
    }

    fun mergeVideoSegments(paths: List<String>, onResult: (String?, String?) -> Unit) {
        val activity = ArCameraBridge.hostActivity
        if (activity == null) {
            onResult(null, "no_activity")
            return
        }
        val inputs = paths.mapNotNull { path ->
            File(path).takeIf { it.exists() && it.length() > 0L }
        }
        if (inputs.isEmpty()) {
            onResult(null, "no_segments")
            return
        }
        try {
            val out = File(activity.cacheDir, "ar_video_merged_${System.currentTimeMillis()}.mp4")
            val merged = ArVideoSegmentMerger.merge(inputs, out)
            if (merged != null) {
                onResult(merged.absolutePath, null)
            } else {
                onResult(null, "merge_failed")
            }
        } catch (e: Exception) {
            onResult(null, e.message ?: "merge_failed")
        }
    }

    private fun snapshotVisibleFrame(
        preferImmediate: Boolean = false,
        onDone: (Bitmap?) -> Unit,
    ) {
        val filter = ArCameraBridge.currentFilter
        val intensity = ArCameraBridge.filterIntensity

        fun bakeAnalysisFrame(): Bitmap? {
            val base = safeCopyBitmap(lastCaptureBitmap) ?: return null
            return try {
                when {
                    filter.isPngOverlay() -> {
                        ArCameraBridge.faceOverlay?.composeOnto(base) ?: base
                    }
                    filter.isColorGrade() -> {
                        val baked = ArColorGradeBaker.apply(base, filter, intensity)
                        if (baked !== base) base.recycle()
                        baked
                    }
                    else -> base
                }
            } catch (_: Exception) {
                base
            }
        }

        if (!filter.isDistortion()) {
            mainHandler.post { onDone(bakeAnalysisFrame()) }
            return
        }

        val gl = ArCameraBridge.warpGlView
        if (gl != null && gl.visibility == View.VISIBLE && gl.isGlInitialized()) {
            gl.setCaptureEnabled(true)
            fun readGpu() {
                val gpu = try {
                    gl.copyLastFilteredFrame()
                } catch (_: Exception) {
                    null
                }
                if (gpu != null && !isMostlyEmpty(gpu)) {
                    val edge = if (recording) RECORD_PROCESS_EDGE else CAPTURE_MAX_EDGE
                    val scaled = try {
                        ImageProxyBitmapUtils.scaleToMaxDimension(
                            gpu,
                            edge,
                            filter = true,
                        )
                    } catch (_: Exception) {
                        gpu
                    }
                    if (scaled !== gpu) gpu.recycle()
                    onDone(scaled)
                } else {
                    gpu?.recycle()
                    onDone(bakeAnalysisFrame())
                }
            }
            if (preferImmediate) {
                mainHandler.post { readGpu() }
            } else {
                mainHandler.postDelayed({ readGpu() }, 40)
            }
            return
        }

        mainHandler.post { onDone(bakeAnalysisFrame()) }
    }

    private fun maybeCaptureRecordingFrame() {
        if (!recording || !videoRecorder.isRecording()) return
        val now = android.os.SystemClock.elapsedRealtime()
        if (now - lastRecordCopyMs < RECORD_FRAME_INTERVAL_MS) return
        if (!recordingPixelCopyBusy.compareAndSet(false, true)) return
        lastRecordCopyMs = now

        val filter = ArCameraBridge.currentFilter
        // Anything on the GPU (OES path: NONE + color grades, OR a shader distortion)
        // is already rendered. Pull the finished frame straight from GL instead of
        // re-applying the grade on the CPU (LutStore.apply is a per-pixel trilinear
        // pass over the whole frame — running it on EVERY recorded frame was the main
        // cause of the recording/preview lag). The GPU output already has the exact
        // same result baked in, so this is both correct and far cheaper.
        if (boundToOes || filter.useShader()) {
            val gl = ArCameraBridge.warpGlView
            // take() — no Bitmap.copy. Skip isMostlyEmpty (full getPixel loop) on the
            // hot recording path; empty frames are rare once GL is streaming.
            val gpu = try {
                gl?.takeLastFilteredFrame()
            } catch (_: Exception) {
                null
            }
            if (gpu != null) {
                offerRecordingFrameAsync(gpu, recycleSourceAlways = true)
                return
            }
        }

        snapshotVisibleFrame { bitmap ->
            if (bitmap == null) {
                recordingPixelCopyBusy.set(false)
                return@snapshotVisibleFrame
            }
            offerRecordingFrameAsync(
                bitmap,
                recycleSourceAlways = bitmap !== lastCaptureBitmap,
            )
        }
    }

    /**
     * Recording-only fast path for color-grade/none filters. [displayBmp] here is a
     * freshly rotated/mirrored frame that isn't aliased with [lastCaptureBitmap]
     * ([retainCaptureFrame] always makes its own copy), so it can be baked and handed
     * straight to the encoder without the extra defensive copy [snapshotVisibleFrame]
     * needs for the async take-photo path. That removes a redundant full-frame copy
     * from every single recorded frame, which was a real source of the video judder.
     * Returns true if [displayBmp] was consumed (caller must not recycle it further).
     */
    private fun maybeCaptureRecordingFrameDirect(displayBmp: Bitmap, filter: FilterType): Boolean {
        if (!videoRecorder.isRecording()) return false
        val now = android.os.SystemClock.elapsedRealtime()
        if (now - lastRecordCopyMs < RECORD_FRAME_INTERVAL_MS) return false
        if (!recordingPixelCopyBusy.compareAndSet(false, true)) return false
        lastRecordCopyMs = now

        val baked = try {
            if (filter.isColorGrade()) {
                ArColorGradeBaker.apply(displayBmp, filter, ArCameraBridge.filterIntensity)
            } else {
                displayBmp
            }
        } catch (_: Exception) {
            displayBmp
        }
        if (baked !== displayBmp && !displayBmp.isRecycled) {
            displayBmp.recycle()
        }
        offerRecordingFrameAsync(baked, recycleSourceAlways = true)
        return true
    }

    /**
     * Recording-only fast path for shader-rendered color-grade filters. Takes a
     * standalone copy of [source] synchronously (cheap, since [source] is about to be
     * handed off to the GL renderer and recycled asynchronously), then bakes the
     * color grade and hands off to the encoder on a background thread. This skips
     * [snapshotVisibleFrame]'s mainHandler hop, which added queueing latency (racing
     * against Flutter/UI-thread work) on top of an extra defensive copy.
     */
    private fun maybeCaptureRecordingFrameFromSource(source: Bitmap, filter: FilterType): Boolean {
        if (!videoRecorder.isRecording() || source.isRecycled) return false
        val now = android.os.SystemClock.elapsedRealtime()
        if (now - lastRecordCopyMs < RECORD_FRAME_INTERVAL_MS) return false
        if (!recordingPixelCopyBusy.compareAndSet(false, true)) return false
        lastRecordCopyMs = now

        val copy = try {
            source.copy(Bitmap.Config.ARGB_8888, false)
        } catch (_: Exception) {
            null
        }
        if (copy == null) {
            recordingPixelCopyBusy.set(false)
            return false
        }

        fun bakeAndOffer() {
            val baked = try {
                if (filter.isColorGrade()) {
                    val b = ArColorGradeBaker.apply(copy, filter, ArCameraBridge.filterIntensity)
                    if (b !== copy && !copy.isRecycled) copy.recycle()
                    b
                } else {
                    copy
                }
            } catch (_: Exception) {
                copy
            }
            offerRecordingFrameAsync(baked, recycleSourceAlways = true)
        }

        val executor = recordOfferExecutor
        if (executor == null) bakeAndOffer() else executor.execute { bakeAndOffer() }
        return true
    }

    /**
     * Feeds the encoder at a fixed [ArFilteredVideoRecorder.FRAME_RATE] cadence,
     * repeating the last frame when the pipeline hasn't produced a new one yet.
     * This decouples encoder timing from analysis/filter throughput so playback
     * stays evenly paced (no stutter) even when a filter or compose step is slow.
     *
     * Two things are critical for smoothness and were the previous cause of the lag:
     *  - Uses [ScheduledExecutorService.scheduleAtFixedRate] (constant wall-clock
     *    cadence) instead of `scheduleWithFixedDelay` (whose real period was
     *    draw-time + delay, so effective fps sagged and jittered).
     *  - The encoder Surface derives each frame's timestamp from the moment it is
     *    posted, so [offerFrame] must run OUTSIDE [recordFrameLock]; the pump only
     *    holds the lock long enough to swap in a newly produced frame.
     */
    private fun startRecordFramePump() {
        stopRecordFramePump()
        val executor = Executors.newSingleThreadScheduledExecutor { r ->
            Thread(r, "ar-video-pump").apply { priority = Thread.NORM_PRIORITY }
        }
        recordPumpExecutor = executor
        val periodMs = (1000L / ArFilteredVideoRecorder.FRAME_RATE).coerceAtLeast(1L)
        recordPumpFuture = executor.scheduleAtFixedRate(
            { pumpRecordFrame() },
            0L,
            periodMs,
            TimeUnit.MILLISECONDS,
        )
    }

    private fun pumpRecordFrame() {
        if (!recording || !videoRecorder.isRecording()) return
        // Adopt a freshly produced frame (if any) under the lock, then draw the
        // pump-owned frame without holding the lock so the canvas post — and thus
        // the frame's presentation timestamp — lands on the fixed-rate tick.
        synchronized(recordFrameLock) {
            val pending = latestRecordFrame
            if (pending != null && !pending.isRecycled) {
                pumpCurrentFrame?.takeIf { it !== pending && !it.isRecycled }?.recycle()
                pumpCurrentFrame = pending
                latestRecordFrame = null
            }
        }
        val frame = pumpCurrentFrame ?: return
        if (frame.isRecycled) return
        try {
            videoRecorder.offerFrame(frame)
        } catch (_: Exception) {
        }
    }

    private fun stopRecordFramePump() {
        recordPumpFuture?.cancel(false)
        recordPumpFuture = null
        val executor = recordPumpExecutor
        recordPumpExecutor = null
        if (executor != null) {
            executor.shutdown()
            // Wait for any in-flight offerFrame() to finish before recycling the
            // frame it may still be drawing, otherwise we could recycle a bitmap
            // mid-draw and crash the encoder canvas.
            try {
                if (!executor.awaitTermination(300, TimeUnit.MILLISECONDS)) {
                    executor.shutdownNow()
                }
            } catch (_: InterruptedException) {
                executor.shutdownNow()
            }
        }
        synchronized(recordFrameLock) {
            latestRecordFrame?.takeIf { !it.isRecycled }?.recycle()
            latestRecordFrame = null
        }
        pumpCurrentFrame?.takeIf { !it.isRecycled }?.recycle()
        pumpCurrentFrame = null
    }

    private fun offerRecordingFrameAsync(source: Bitmap, recycleSourceAlways: Boolean) {
        fun process() {
            var framed: Bitmap? = null
            try {
                if (recording && videoRecorder.isRecording()) {
                    framed = frameForRecording(source)
                    synchronized(recordFrameLock) {
                        // Only ever recycle the value we replace here; the pump owns
                        // [pumpCurrentFrame] separately and never lives in this slot.
                        val old = latestRecordFrame
                        latestRecordFrame = framed
                        if (old != null && old !== framed && old !== source && !old.isRecycled) {
                            old.recycle()
                        }
                    }
                }
            } finally {
                if (recycleSourceAlways && framed !== source && !source.isRecycled) {
                    source.recycle()
                }
                recordingPixelCopyBusy.set(false)
            }
        }
        val executor = recordOfferExecutor
        if (executor == null) process() else executor.execute { process() }
    }

    /** Scales to encode size; letterbox composes at encode resolution (not full screen). */
    private fun frameForRecording(source: Bitmap): Bitmap {
        val maxEdge = RECORD_PROCESS_EDGE
        val scaled = try {
            ImageProxyBitmapUtils.scaleToMaxDimension(source, maxEdge, filter = true)
        } catch (_: Exception) {
            source
        }

        if (!ArCameraBridge.isPreviewLetterboxed()) {
            return scaled
        }

        val root = ArCameraBridge.platformRootSize()
        if (root == null || root.first <= 0 || root.second <= 0) {
            return scaled
        }

        val rootW = root.first
        val rootH = root.second
        val fit = kotlin.math.min(1f, maxEdge.toFloat() / kotlin.math.max(rootW, rootH))
        val outW = ((rootW * fit).toInt() and 1.inv()).coerceAtLeast(2)
        val outH = ((rootH * fit).toInt() and 1.inv()).coerceAtLeast(2)
        val top = (ArCameraBridge.letterboxTopPx() * fit).toInt().coerceAtLeast(0)
        val bottom = (ArCameraBridge.letterboxBottomPx() * fit).toInt().coerceAtLeast(0)

        val composed = try {
            ImageProxyBitmapUtils.composeLetterboxedCapture(
                scaled,
                outW,
                outH,
                top,
                bottom,
            )
        } catch (_: Exception) {
            return scaled
        }

        if (scaled !== source && scaled !== composed && !scaled.isRecycled) {
            scaled.recycle()
        }
        return composed
    }

    private fun bakeFilterOntoBitmap(source: Bitmap): Bitmap {
        val filter = ArCameraBridge.currentFilter
        if (filter == FilterType.NONE || source.isRecycled) return source
        return try {
            when {
                filter.isPngOverlay() -> {
                    ArCameraBridge.faceOverlay?.composeOnto(source) ?: source
                }
                filter.isColorGrade() -> {
                    val baked = ArColorGradeBaker.apply(
                        source,
                        filter,
                        ArCameraBridge.filterIntensity,
                    )
                    if (baked !== source) source.recycle()
                    baked
                }
                else -> source
            }
        } catch (_: Exception) {
            source
        }
    }

    /** PixelCopy sometimes "succeeds" with an empty / green garbage buffer. */
    private fun isMostlyEmpty(bitmap: Bitmap): Boolean {
        if (bitmap.width <= 0 || bitmap.height <= 0) return true
        val stepX = (bitmap.width / 8).coerceAtLeast(1)
        val stepY = (bitmap.height / 8).coerceAtLeast(1)
        var samples = 0
        var nearBlack = 0
        var y = stepY / 2
        while (y < bitmap.height) {
            var x = stepX / 2
            while (x < bitmap.width) {
                val c = bitmap.getPixel(x, y)
                val r = (c shr 16) and 0xFF
                val g = (c shr 8) and 0xFF
                val b = c and 0xFF
                samples++
                // Classic CameraX/GL garbage: pure green or near-black empty.
                if ((r < 8 && b < 8 && g > 180) || (r + g + b) < 24) {
                    nearBlack++
                }
                x += stepX
            }
            y += stepY
        }
        return samples > 0 && nearBlack * 2 >= samples
    }

    private fun safeCopyBitmap(source: Bitmap?): Bitmap? {
        if (source == null || source.isRecycled) return null
        return try {
            source.copy(Bitmap.Config.ARGB_8888, false)
        } catch (_: Exception) {
            null
        }
    }

    private fun retainCaptureFrame(source: Bitmap) {
        if (source.isRecycled) return
        val maxEdge = if (recording) RECORD_PROCESS_EDGE else CAPTURE_MAX_EDGE
        val copy = try {
            ImageProxyBitmapUtils.scaleToMaxDimension(source, maxEdge, filter = true)
                .let { scaled ->
                    if (scaled !== source) {
                        scaled
                    } else if (!source.isRecycled) {
                        source.copy(Bitmap.Config.ARGB_8888, false)
                    } else {
                        null
                    }
                }
        } catch (_: Exception) {
            null
        } ?: return

        val previous = lastCaptureBitmap
        lastCaptureBitmap = copy
        if (previous != null && previous !== copy && !previous.isRecycled) {
            previous.recycle()
        }
    }

    private var lastRecordCopyMs = 0L

    private fun unbindCamera() {
        val activity = ArCameraBridge.hostActivity ?: return
        try {
            ProcessCameraProvider.getInstance(activity).get().unbindAll()
        } catch (_: Exception) {
        }
    }

    private fun hasCameraPermission(activity: Activity): Boolean {
        return ContextCompat.checkSelfPermission(activity, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun hasMicPermission(activity: Activity): Boolean {
        return ContextCompat.checkSelfPermission(activity, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
    }

    /**
     * Feeds the camera frames straight into the GL renderer's OES SurfaceTexture.
     * CameraX writes directly to the GPU — no ImageAnalysis → Bitmap → upload, which
     * is what caused the color-filter preview/record lag. Rotation + front mirror are
     * applied in the OES shader (see [FaceWarpRenderer]).
     */
    private fun bindPreviewToOes(preview: Preview, glView: FaceWarpGlView, activity: Activity) {
        val executor = ContextCompat.getMainExecutor(activity)
        preview.setSurfaceProvider(executor) { request ->
            val st = glView.cameraSurfaceTexture()
            if (st == null) {
                request.willNotProvideSurface()
                return@setSurfaceProvider
            }
            val res = request.resolution
            // Cap the OES buffer — back cameras often negotiate huge streams and that
            // alone adds GPU fill + lag. 1280 max edge stays sharp on phone screens.
            val maxBuf = 1280
            val bufScale = minOf(1f, maxBuf.toFloat() / maxOf(res.width, res.height))
            val bufW = ((res.width * bufScale).toInt() and 1.inv()).coerceAtLeast(2)
            val bufH = ((res.height * bufScale).toInt() and 1.inv()).coerceAtLeast(2)
            st.setDefaultBufferSize(bufW, bufH)
            // Never apply selfie X-mirror — natural left/right (turn right → right).
            glView.setCameraTransform(0, frontMirror = false, bufW, bufH)
            request.setTransformationInfoListener(executor) { info ->
                glView.setCameraTransform(
                    info.rotationDegrees,
                    frontMirror = false,
                    bufW,
                    bufH,
                )
            }
            val surface = Surface(st)
            request.provideSurface(surface, executor) { surface.release() }
        }
    }

    /** Called (GL thread) after each OES frame — drives preview swap + recording. */
    private fun onOesFramePresented() {
        ArCameraBridge.onGlFramePresented()
        if (recording) maybeCaptureRecordingFrame()
    }

    fun isBoundToOes(): Boolean = boundToOes

    /**
     * App minimized — pause the GLSurfaceView so EGL can be torn down cleanly.
     * Without this, resume leaves a dead SurfaceTexture and a permanent black preview.
     */
    fun onHostPause() {
        if (!started) return
        try {
            ArCameraBridge.warpGlView?.onPause()
        } catch (_: Throwable) {
        }
    }

    /**
     * App restored from recents/minimize — restart GL + force a camera rebind onto
     * the new OES SurfaceTexture. CameraX alone is not enough after GL context loss.
     */
    fun onHostResume() {
        if (!started) return
        if (recording || videoRecorder.isRecording()) return
        val activity = ArCameraBridge.hostActivity ?: return
        val gl = ArCameraBridge.warpGlView
        try {
            gl?.onResume()
        } catch (_: Throwable) {
        }
        // Old OES surface is invalid after GL pause; require a fresh bind.
        boundToOes = false
        rebindPosted = false
        switchingCamera = false
        convertingFrame.set(false)
        activity.runOnUiThread {
            ArCameraBridge.syncPreviewNaturalOrientation()
            gl?.ensureGlInitialized()
            ArCameraBridge.applyCurrentFilter()
            val wantsOes = ArCameraBridge.currentFilter.usesGpuPreview()
            if (wantsOes) {
                gl?.setOesEnabled(true)
                if (gl?.cameraSurfaceTexture() != null) {
                    requestPreviewRebind()
                } else {
                    gl?.onCameraSurfaceReady = {
                        gl.onCameraSurfaceReady = null
                        requestPreviewRebind()
                    }
                    gl?.requestRender()
                }
            } else {
                requestPreviewRebind()
            }
        }
    }

    /** Bridge asks to route the live preview through the OES GPU path (color grade). */
    fun ensureOesPreviewBound() {
        if (boundToOes) return
        if (recording || videoRecorder.isRecording()) return
        val gl = ArCameraBridge.warpGlView ?: return
        gl.setOesEnabled(true)
        if (gl.cameraSurfaceTexture() != null) {
            requestPreviewRebind()
        } else {
            // GL surface not created yet — bind as soon as the OES texture exists.
            gl.onCameraSurfaceReady = {
                gl.onCameraSurfaceReady = null
                if (!boundToOes) requestPreviewRebind()
            }
        }
    }

    /** Bridge asks to route the live preview back through the classic PreviewView. */
    fun ensurePreviewViewBound() {
        if (!boundToOes) return
        if (recording || videoRecorder.isRecording()) return
        requestPreviewRebind()
    }

    @Volatile
    private var rebindPosted = false

    private fun requestPreviewRebind() {
        val activity = ArCameraBridge.hostActivity ?: return
        val lifecycleOwner = ArCameraBridge.lifecycleOwner ?: return
        val previewView = ArCameraBridge.previewView ?: return
        val faceOverlay = ArCameraBridge.faceOverlay ?: return
        // Coalesce rapid rebind requests (filter spam / startup race) into ONE
        // camera session change — each rebind was flashing black + adding lag.
        if (rebindPosted) return
        rebindPosted = true
        // Pause analysis so the current lens releases cleanly before rebinding.
        switchingCamera = true
        imageAnalysis?.clearAnalyzer()
        convertingFrame.set(false)
        activity.runOnUiThread {
            rebindPosted = false
            bindCamera(lifecycleOwner, previewView, faceOverlay)
        }
    }

    private fun bindCamera(
        lifecycleOwner: LifecycleOwner,
        previewView: PreviewView,
        faceOverlay: FaceOverlayView,
    ) {
        val activity = ArCameraBridge.hostActivity ?: run {
            switchingCamera = false
            return
        }
        val executor = analysisExecutor ?: run {
            switchingCamera = false
            return
        }
        val cameraProviderFuture = ProcessCameraProvider.getInstance(activity)
        cameraProviderFuture.addListener({
            val cameraProvider = cameraProviderFuture.get()
            val displayRotation = activity.windowManager.defaultDisplay.rotation
            val target = Size(ANALYSIS_WIDTH, ANALYSIS_HEIGHT)

            // Same target size for Preview + Analysis so FILL_CENTER crops match.
            // Different aspect ratios cause glasses/dog to sit off the nose/eyes.
            val preview = Preview.Builder()
                .setTargetResolution(target)
                .setTargetRotation(displayRotation)
                .build()

            // Color grades render straight from the camera into a GL OES texture
            // (no per-frame Bitmap → stock-camera-smooth). Everything else keeps the
            // proven PreviewView binding so face filters/stickers are untouched.
            val glView = ArCameraBridge.warpGlView
            val useOes = ArCameraBridge.currentFilter.usesGpuPreview() &&
                glView != null &&
                glView.cameraSurfaceTexture() != null
            boundToOes = useOes
            if (useOes && glView != null) {
                glView.setOesEnabled(true)
                glView.setOnFramePresented { onOesFramePresented() }
                bindPreviewToOes(preview, glView, activity)
            } else {
                glView?.setOesEnabled(false)
                preview.surfaceProvider = previewView.surfaceProvider
            }

            val analysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                .setTargetResolution(target)
                .setTargetRotation(displayRotation)
                .build()

            analysis.setAnalyzer(executor) { imageProxy ->
                processImage(imageProxy, faceOverlay, activity)
            }

            val capture = ImageCapture.Builder()
                .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
                .setTargetResolution(Size(PHOTO_TARGET_WIDTH, PHOTO_TARGET_HEIGHT))
                .setTargetRotation(displayRotation)
                .build()
            imageCapture = capture

            // Detach the previous analyzer + fully release the old lens before
            // rebinding, so a flip doesn't fail to open the new camera.
            imageAnalysis?.clearAnalyzer()
            cameraProvider.unbindAll()
            imageAnalysis = analysis
            val selector = if (ArCameraBridge.isFrontCamera) {
                CameraSelector.DEFAULT_FRONT_CAMERA
            } else {
                CameraSelector.DEFAULT_BACK_CAMERA
            }
            fun applyTorchAfterBind(bound: Camera?) {
                camera = bound
                if (bound == null) return
                if (ArCameraBridge.isFrontCamera) {
                    try {
                        bound.cameraControl.enableTorch(false)
                    } catch (_: Exception) {
                    }
                    applyScreenFlash(torchEnabled)
                } else {
                    applyScreenFlash(false)
                    if (torchEnabled && bound.cameraInfo.hasFlashUnit()) {
                        try {
                            bound.cameraControl.enableTorch(true)
                        } catch (_: Exception) {
                        }
                    }
                }
            }
            try {
                applyTorchAfterBind(
                    cameraProvider.bindToLifecycle(
                        lifecycleOwner,
                        selector,
                        preview,
                        analysis,
                        capture,
                    ),
                )
            } catch (_: Exception) {
                try {
                    cameraProvider.unbindAll()
                    applyTorchAfterBind(
                        cameraProvider.bindToLifecycle(
                            lifecycleOwner,
                            selector,
                            preview,
                            capture,
                        ),
                    )
                    imageCapture = capture
                } catch (_: Exception) {
                    try {
                        cameraProvider.unbindAll()
                        applyTorchAfterBind(
                            cameraProvider.bindToLifecycle(
                                lifecycleOwner,
                                selector,
                                preview,
                                analysis,
                            ),
                        )
                    } catch (_: Exception) {
                        camera = null
                    }
                    imageCapture = null
                }
            } finally {
                // Resume frame processing now that the new lens is bound.
                switchingCamera = false
            }
        }, ContextCompat.getMainExecutor(activity))
    }

    private fun processImage(
        imageProxy: ImageProxy,
        faceOverlay: FaceOverlayView,
        activity: Activity,
    ) {
        // Drop frames while a camera flip is in progress so the analysis thread
        // releases the current lens promptly and the new one can bind.
        if (switchingCamera) {
            imageProxy.close()
            return
        }
        if (!convertingFrame.compareAndSet(false, true)) {
            imageProxy.close()
            return
        }

        var oriented: Bitmap? = null
        var display: Bitmap? = null
        try {
            val rotation = imageProxy.imageInfo.rotationDegrees
            val filter = ArCameraBridge.currentFilter
            frameCounter++

            // OES GPU path (NONE + non-beauty color grades): the camera renders
            // straight into GL, so the analysis frame has no consumer (recording is
            // driven from the GL thread). Drop it — this is what removes the per-frame
            // CPU cost/lag. If OES isn't bound yet, fall through to the bitmap path
            // (fallback) so the preview is never black during the switch.
            if (boundToOes && filter.usesGpuPreview()) {
                imageProxy.close()
                return
            }

            // Original filter: PreviewView shows the live feed. Skip heavy
            // bitmap conversion — stills use CameraX ImageCapture instead.
            if (filter == FilterType.NONE && !recording) {
                imageProxy.close()
                return
            }

            // No-filter recording: the analysis frame's ONLY consumer is the video
            // encoder. If the record gate hasn't elapsed yet, skip the whole
            // rotate/mirror conversion — the frame pump repeats the last frame at a
            // fixed cadence, so nothing is lost and the analysis thread stays free.
            if (filter == FilterType.NONE && recording) {
                val now = android.os.SystemClock.elapsedRealtime()
                if (now - lastRecordCopyMs < RECORD_FRAME_INTERVAL_MS) {
                    imageProxy.close()
                    return
                }
            }

            val rawBitmap = ImageProxyBitmapUtils.toBitmap(imageProxy)
            imageProxy.close()

            if (rawBitmap == null) {
                convertingFrame.set(false)
                return
            }

            val needsFace =
                filter.isDistortion() || filter.isBeauty() || filter.isPngOverlay()
            val detectEvery = if (needsFace) 3 else 4
            val runDetection =
                needsFace && (frameCounter % detectEvery == 0 || cachedSnapshot == null)

            // Face detection needs the UN-mirrored upright frame, so for those filters
            // we rotate only and mirror later. For non-face filters (color-grade /
            // none) we never read the un-mirrored frame, so fold rotate + front-camera
            // mirror into ONE matrix pass here — saving a full-frame copy per frame.
            val front = ArCameraBridge.isFrontCamera
            val mirrorInOrient = front && !needsFace
            val needMirrorInBranch = front && needsFace

            oriented = if (needsFace) {
                // Face filters need the full-res un-mirrored upright frame for detection.
                ImageProxyBitmapUtils.orient(rawBitmap, rotation, mirrorInOrient)
            } else {
                // Color-grade / none: no detection, so rotate + mirror + downscale to
                // the encode/GL size in ONE pass. The later scaleToMaxDimension then
                // becomes a no-op, so we allocate a single bitmap per frame instead of
                // three — far less GC churn, smoother preview + steadier encode timing.
                ImageProxyBitmapUtils.orientScaled(rawBitmap, rotation, mirrorInOrient, GL_MAX_EDGE)
            }
            if (oriented !== rawBitmap) rawBitmap.recycle()

            // Note: do NOT downscale `oriented` here while recording. The preview /
            // GL path and the still-capture buffer both read from it, so shrinking it
            // up front made the live camera look low-res during recording. The encoder
            // frame is scaled separately (frameForRecording), so quality is preserved.

            if (runDetection) {
                val landmarker = faceLandmarker ?: FaceLandmarkerHolder.get().also { faceLandmarker = it }
                if (landmarker != null) {
                    val detectBitmap = ImageProxyBitmapUtils.scaleToMaxDimension(
                        oriented,
                        DETECT_MAX_DIMENSION,
                        filter = false,
                    )
                    val result = landmarker.detect(detectBitmap)
                    val raw = result?.let {
                        val mapped = FaceLandmarkMapper.fromResult(
                            it,
                            detectBitmap.width,
                            detectBitmap.height,
                        )
                        if (mapped != null && detectBitmap !== oriented) {
                            FaceLandmarkMapper.scaleSnapshot(mapped, oriented.width, oriented.height)
                        } else {
                            mapped
                        }
                    }
                    if (detectBitmap !== oriented) detectBitmap.recycle()
                    if (raw != null) {
                        noFaceStreak = 0
                        cachedSnapshot = FaceLandmarkSmoother.smooth(raw)
                    } else {
                        // No face: clear the cached landmarks so stickers/overlays
                        // (glasses, dog, big eyes, lips, distortion) disappear instead
                        // of freezing the last pose on screen.
                        noFaceStreak++
                        if (noFaceStreak >= NO_FACE_CLEAR_THRESHOLD) {
                            cachedSnapshot = null
                            cachedWarpParams = FaceWarpParams.INACTIVE
                            FaceLandmarkSmoother.reset()
                        }
                    }
                }
            }

            val activeSnapshot = cachedSnapshot

            when {
                filter.useShader() -> {
                    // Front camera: mirror the bitmap so GL matches CameraX PreviewView
                    // (stickers path). Without this, big-eyes/lips/nose look flipped vs glasses.
                    display = if (needMirrorInBranch) {
                        ImageProxyBitmapUtils.mirrorHorizontally(oriented)
                    } else {
                        oriented
                    }
                    if (display !== oriented) {
                        oriented.recycle()
                        oriented = null
                    }

                    val glView = ArCameraBridge.warpGlView
                    if (glView == null) {
                        display.recycle()
                        display = null
                        return
                    }

                    val glInput = ImageProxyBitmapUtils.scaleToMaxDimension(
                        display,
                        GL_MAX_EDGE,
                        filter = true,
                    )
                    val snapshotForGl = if (
                        glInput !== display && activeSnapshot != null
                    ) {
                        FaceLandmarkMapper.scaleSnapshot(
                            activeSnapshot,
                            glInput.width,
                            glInput.height,
                        )
                    } else {
                        activeSnapshot
                    }
                    if (glInput !== display) {
                        display.recycle()
                        display = glInput
                    }

                    val viewWidth = ArCameraBridge.warpViewWidth
                        .takeIf { it > 0 } ?: glView.width.coerceAtLeast(1)
                    val viewHeight = ArCameraBridge.warpViewHeight
                        .takeIf { it > 0 } ?: glView.height.coerceAtLeast(1)

                    val params = FaceWarpParamsBuilder.build(
                        snapshotForGl,
                        filter,
                        display.width,
                        display.height,
                        viewWidth,
                        viewHeight,
                    ).also { cachedWarpParams = it }

                    // Still-capture buffer isn't needed mid-recording for shader
                    // filters (record frames come straight from `display`/GL), so
                    // skip the per-frame copy+scale to keep the analysis thread free.
                    if (!recording) retainCaptureFrame(display)
                    val handledDirect = recording && !filter.isDistortion() &&
                        maybeCaptureRecordingFrameFromSource(display, filter)
                    glView.submitFrameWithParams(display, params)
                    display = null
                    ArCameraBridge.onGlFramePresented()
                    if (!handledDirect) {
                        maybeCaptureRecordingFrame()
                    }
                }

                else -> {
                    val retainThisFrame = recording || (frameCounter % 2 == 0)

                    if (filter.isPngOverlay()) {
                        // Live camera is shown by the (visible) PreviewView; faceOverlay
                        // draws ONLY the stickers. Previously we also drew a full-res
                        // mirrored camera "underlay" on the overlay every frame — with
                        // PreviewView now visible that meant TWO camera layers rendering
                        // plus a per-frame scale copy, which caused the lag. Dropping the
                        // underlay leaves PreviewView as the single (hardware) camera layer.
                        val frame = oriented
                        val snapshots = activeSnapshot?.let { listOf(it) } ?: emptyList()
                        val landmarkW = activeSnapshot?.imageWidth ?: frame.width
                        val landmarkH = activeSnapshot?.imageHeight ?: frame.height
                        val expectedFilter = filter
                        val expectedFront = front
                        activity.runOnUiThread {
                            if (ArCameraBridge.currentFilter != expectedFilter) return@runOnUiThread
                            faceOverlay.setLandmarks(
                                snapshots,
                                landmarkW,
                                landmarkH,
                                isFrontCamera = expectedFront,
                            )
                        }

                        // The mirrored full-res frame is only needed to bake the sticker
                        // into a photo (on-demand) or a recording (every frame). Skip the
                        // mirror + copy on the other frames to keep the preview smooth.
                        if (retainThisFrame) {
                            val captureSrc = if (needMirrorInBranch) {
                                ImageProxyBitmapUtils.mirrorHorizontally(frame).also { frame.recycle() }
                            } else {
                                frame
                            }
                            oriented = null
                            retainCaptureFrame(captureSrc)
                            if (captureSrc !== lastCaptureBitmap) {
                                captureSrc.recycle()
                            }
                        } else {
                            frame.recycle()
                            oriented = null
                        }
                        maybeCaptureRecordingFrame()
                    } else {
                        // NONE while recording: the frame is fed straight to the encoder.
                        val displayBmp = if (needMirrorInBranch) {
                            ImageProxyBitmapUtils.mirrorHorizontally(oriented)
                        } else {
                            oriented
                        }
                        if (displayBmp !== oriented) {
                            oriented.recycle()
                            oriented = null
                        }
                        if (recording && maybeCaptureRecordingFrameDirect(displayBmp, filter)) {
                            // Ownership transferred to the recording pipeline above.
                        } else if (displayBmp !== lastCaptureBitmap) {
                            displayBmp.recycle()
                        }
                    }
                }
            }
        } catch (_: Throwable) {
            oriented?.recycle()
            display?.recycle()
        } finally {
            convertingFrame.set(false)
        }
    }
}
