package com.dubai.bimobondapp.ar_camera

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.media.MediaCodec
import android.media.MediaFormat
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
import androidx.camera.core.MirrorMode
import androidx.camera.core.Preview
import androidx.camera.core.UseCaseGroup
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.FallbackStrategy
import androidx.camera.video.Quality
import androidx.camera.video.QualitySelector
import androidx.camera.video.Recorder
import androidx.camera.video.VideoCapture
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
import android.util.Log

object ArCameraController {
    private const val ANALYSIS_WIDTH = 1080
    private const val ANALYSIS_HEIGHT = 1440
    /** Analysis while PNG stickers active. Photos use ImageCapture (unchanged). */
    private const val PNG_ANALYSIS_WIDTH = 480
    private const val PNG_ANALYSIS_HEIGHT = 640
    private const val DETECT_MAX_DIMENSION = 384
    /** Sticker video encode edge — keep modest so preview stays responsive while recording. */
    private const val PNG_RECORD_EDGE = 640
    private const val PNG_RECORD_INTERVAL_MS = 66L
    private const val GL_MAX_EDGE = 1280
    private const val CAPTURE_MAX_EDGE = 1920
    /** Fast preview JPEG for instant Flutter navigation (hi-res upgrades in background). */
    private const val INSTANT_CAPTURE_EDGE = 1080
    private const val INSTANT_JPEG_QUALITY = 85
    private const val INSTANT_GL_POLL_MS = 96L
    private const val INSTANT_GL_COLD_POLL_MS = 400L
    private const val OES_PHOTO_WARM_INTERVAL_MS = 80L
    private const val RECORD_PROCESS_EDGE = ArFilteredVideoRecorder.MAX_EDGE

    private const val RECORD_GL_EDGE = 720
    private const val PHOTO_TARGET_WIDTH = 2160
    private const val PHOTO_TARGET_HEIGHT = 2880
    private const val RECORD_FRAME_INTERVAL_MS = 33L

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
    private val simpleHardwareRecorder = ArSimpleHardwareRecorder()
    private val captureBusy = AtomicBoolean(false)
    private val recordingPixelCopyBusy = AtomicBoolean(false)

    @Volatile
    private var imageCapture: ImageCapture? = null

    @Volatile
    private var imageAnalysis: ImageAnalysis? = null

    @Volatile
    private var videoCapture: VideoCapture<Recorder>? = null

    @Volatile
    private var hardwareRecording = false

    @Volatile
    private var glSurfaceRecording = false

    @Volatile
    private var switchingCamera = false

    private var noFaceStreak = 0

    @Volatile
    private var boundToOes = false

    /** OES preview has produced at least one non-black frame (cold-open guard). */
    @Volatile
    private var oesPhotoReady = false

    private var lastOesPhotoWarmMs = 0L

    @Volatile
    private var preferOesBinding = false

    /** True when ImageAnalysis last bound at PNG sticker resolution. */
    @Volatile
    private var pngFastAnalysisBound = false

    /** Hardware VideoCapture sticker bake (PNG only) — same lag profile as normal record. */
    private var stickerCameraOverlay: StickerCameraOverlay? = null

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

    /** Cap for the current take (layout cell). 0 = no cap. */
    @Volatile
    private var maxRecordDurationMs: Long = 0L

    private var maxRecordStopRunnable: Runnable? = null

    /**
     * Path from a max-duration auto-stop, returned if Flutter's stop races
     * after Kotlin already finalized the file.
     */
    @Volatile
    private var lastStoppedPath: String? = null

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
        previewView.visibility = View.VISIBLE

        FaceLandmarkerHolder.warmup(activity)
        faceLandmarker = FaceLandmarkerHolder.get()
        analysisExecutor = Executors.newSingleThreadExecutor()
        recordOfferExecutor = Executors.newSingleThreadExecutor { r ->
            Thread(r, "ar-video-offer").apply { priority = Thread.NORM_PRIORITY }
        }
        stickerCameraOverlay = StickerCameraOverlay(activity.applicationContext)

        warmVideoEncoder()

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

        if (previewView.width > 0 && previewView.height > 0) {
            bindCamera(lifecycleOwner, previewView, faceOverlay)
        } else {
            previewView.post {
                if (started) {
                    bindCamera(lifecycleOwner, previewView, faceOverlay)
                }
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
        if (isRecordingActive()) {
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

        convertingFrame.set(false)
        // Drop graded GL / analysis snapshots so clear-filter cannot re-use them.
        try {
            ArCameraBridge.warpGlView?.clearLastCapturedFrame()
        } catch (_: Exception) {
        }
        lastCaptureBitmap?.recycle()
        lastCaptureBitmap = null
        val filter = ArCameraBridge.currentFilter
        if (!filter.isPngOverlay() &&
            !filter.isDistortion()
        ) {
            cachedSnapshot = null
            FaceLandmarkSmoother.reset()
        }
        if (filter.isPngOverlay()) {
            StickerPoseSmoother.reset()
        } else {
            stickerCameraOverlay?.clear()
        }
        // Rebind analysis at sticker resolution when entering/leaving PNG (Preview stays sharp).
        val wantPngFast = filter.isPngOverlay()
        if (started &&
            !isRecordingActive() &&
            !boundToOes &&
            wantPngFast != pngFastAnalysisBound &&
            canRebindCamera()
        ) {
            requestPreviewRebind()
        }
    }

    fun stop() {
        abortCapture()
        started = false
        boundToOes = false
        preferOesBinding = false
        pngFastAnalysisBound = false
        rebindPosted = false
        convertingFrame.set(false)
        frameCounter = 0
        cachedWarpParams = FaceWarpParams.INACTIVE
        cachedSnapshot = null
        FaceLandmarkSmoother.reset()
        StickerPoseSmoother.reset()
        faceLandmarker = null
        analysisExecutor?.shutdownNow()
        analysisExecutor = null
        recordOfferExecutor?.shutdownNow()
        recordOfferExecutor = null
        try {
            stickerCameraOverlay?.release()
        } catch (_: Exception) {
        }
        stickerCameraOverlay = null
        imageCapture = null
        videoCapture = null
        simpleHardwareRecorder.attach(null)
        camera = null
        torchEnabled = false
        applyScreenFlash(false)
        lastCaptureBitmap?.recycle()
        lastCaptureBitmap = null
        resetOesPhotoReady()
        ArCameraBridge.faceOverlay?.clearUnderlay()
        unbindCamera()
    }

    fun abortCapture() {
        recording = false
        hardwareRecording = false
        glSurfaceRecording = false
        try {
            ArCameraBridge.warpGlView?.clearEncoderSurface(null)
        } catch (_: Exception) {
        }
        simpleHardwareRecorder.abort()
        videoRecorder.abort()
        stopRecordFramePump()
        captureBusy.set(false)
        recordingPixelCopyBusy.set(false)
    }

    private fun isRecordingActive(): Boolean =
        recording || hardwareRecording || videoRecorder.isRecording() ||
            simpleHardwareRecorder.isRecording()

    fun isRecordingNow(): Boolean = isRecordingActive()

    private fun resetOesPhotoReady() {
        oesPhotoReady = false
        lastOesPhotoWarmMs = 0L
    }

    private fun warmOesPhotoCaptureIfNeeded() {
        if (!boundToOes || recording) return
        val gl = ArCameraBridge.warpGlView ?: return
        if (!gl.isGlInitialized() || gl.visibility != View.VISIBLE) return

        val now = android.os.SystemClock.elapsedRealtime()
        val interval = if (oesPhotoReady) 250L else OES_PHOTO_WARM_INTERVAL_MS
        if (now - lastOesPhotoWarmMs < interval) return
        lastOesPhotoWarmMs = now

        val cached = try {
            gl.copyLastFilteredFrame()
        } catch (_: Exception) {
            null
        }
        if (cached != null && !isMostlyEmpty(cached)) {
            oesPhotoReady = true
            cached.recycle()
            // Keep captureEnabled so the buffer stays warm for the next shutter.
            return
        }
        cached?.recycle()

        gl.setCaptureMaxEdge(INSTANT_CAPTURE_EDGE)
        gl.setCaptureEnabled(true)
        gl.requestCaptureNow()
    }

    private fun scheduleOesPhotoWarmup(glView: FaceWarpGlView) {
        glView.setCaptureMaxEdge(INSTANT_CAPTURE_EDGE)
        repeat(6) { index ->
            mainHandler.postDelayed({
                if (!boundToOes || recording) return@postDelayed
                glView.setCaptureEnabled(true)
                glView.requestCaptureNow()
                warmOesPhotoCaptureIfNeeded()
            }, index * 45L)
        }
    }

    private fun savePhotoBitmapToFile(
        bitmap: Bitmap,
        file: File,
        quality: Int,
        maxEdge: Int,
    ): Boolean {
        var working = bitmap
        val toRecycle = mutableListOf<Bitmap>()
        try {
            if (maxEdge > 0) {
                val scaled = try {
                    ImageProxyBitmapUtils.scaleToMaxDimension(bitmap, maxEdge, filter = true)
                } catch (_: Exception) {
                    bitmap
                }
                if (scaled !== bitmap) {
                    toRecycle.add(scaled)
                    working = scaled
                }
            }
            var toSave = working
            if (ArCameraBridge.isPreviewLetterboxed()) {
                val root = ArCameraBridge.platformRootSize()
                if (root != null) {
                    val composed = ImageProxyBitmapUtils.composeLetterboxedCapture(
                        working,
                        root.first,
                        root.second,
                        ArCameraBridge.letterboxTopPx(),
                        ArCameraBridge.letterboxBottomPx(),
                    )
                    if (composed !== working) {
                        toRecycle.add(composed)
                        toSave = composed
                    }
                }
            }
            FileOutputStream(file).use { fos ->
                java.io.BufferedOutputStream(fos, 64 * 1024).use { out ->
                    toSave.compress(Bitmap.CompressFormat.JPEG, quality, out)
                    out.flush()
                }
            }
            return file.exists() && file.length() > 0L
        } catch (_: Exception) {
            return false
        } finally {
            for (b in toRecycle) {
                if (b !== bitmap && b !== lastCaptureBitmap && !b.isRecycled) {
                    try {
                        b.recycle()
                    } catch (_: Exception) {
                    }
                }
            }
        }
    }

    private fun snapshotGlFrameForPhoto(maxEdge: Int): Bitmap? {
        val gl = ArCameraBridge.warpGlView ?: return null
        if (gl.visibility != View.VISIBLE || !gl.isGlInitialized()) return null

        fun readFrame(): Bitmap? {
            val gpu = try {
                gl.copyLastFilteredFrame()
            } catch (_: Exception) {
                null
            } ?: return null
            if (isMostlyEmpty(gpu)) {
                gpu.recycle()
                return null
            }
            return try {
                ImageProxyBitmapUtils.scaleToMaxDimension(gpu, maxEdge, filter = true).also {
                    if (it !== gpu) gpu.recycle()
                }
            } catch (_: Exception) {
                gpu
            }
        }

        readFrame()?.let { return it }

        gl.setCaptureMaxEdge(maxEdge)
        gl.setCaptureEnabled(true)
        gl.requestCaptureNow()
        val pollMs = if (oesPhotoReady) INSTANT_GL_POLL_MS else INSTANT_GL_COLD_POLL_MS
        val deadline = android.os.SystemClock.elapsedRealtime() + pollMs
        while (android.os.SystemClock.elapsedRealtime() < deadline) {
            readFrame()?.let {
                oesPhotoReady = true
                return it
            }
            gl.requestCaptureNow()
            try {
                Thread.sleep(8)
            } catch (_: InterruptedException) {
                break
            }
        }
        if (!recording) {
            gl.setCaptureEnabled(false)
        }
        return null
    }

    private fun bakeCapturedImageProxy(image: ImageProxy): Bitmap? {
        var selfie = ImageProxyBitmapUtils.toUprightCapture(
            image,
            mirrorFront = false,
        ) ?: return null
        val front = ArCameraBridge.isFrontCamera
        if (front &&
            (ArCameraBridge.currentFilter.isPngOverlay() ||
                ArCameraBridge.currentFilter.useShader())
        ) {
            val mirrored = ImageProxyBitmapUtils.mirrorHorizontally(selfie)
            if (mirrored !== selfie) selfie.recycle()
            selfie = bakeFilterOntoBitmap(mirrored)
        } else {
            selfie = bakeFilterOntoBitmap(selfie)
            if (front) {
                val mirrored = ImageProxyBitmapUtils.mirrorHorizontally(selfie)
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
        return selfie
    }

    private fun takePhotoWithImageCaptureToFile(
        file: File,
        jpegQuality: Int = 95,
        onComplete: (Boolean) -> Unit,
    ) {
        val activity = ArCameraBridge.hostActivity
        if (activity == null) {
            onComplete(false)
            return
        }
        val capture = imageCapture
        if (capture == null) {
            onComplete(false)
            return
        }

        val executor = analysisExecutor ?: ContextCompat.getMainExecutor(activity)
        try {
            capture.takePicture(
                executor,
                object : ImageCapture.OnImageCapturedCallback() {
                    override fun onCaptureSuccess(image: ImageProxy) {
                        try {
                            val selfie = bakeCapturedImageProxy(image)
                            if (selfie == null || isMostlyEmpty(selfie)) {
                                selfie?.recycle()
                                onComplete(false)
                                return
                            }
                            FileOutputStream(file).use { fos ->
                                java.io.BufferedOutputStream(fos, 64 * 1024).use { out ->
                                    selfie.compress(Bitmap.CompressFormat.JPEG, jpegQuality, out)
                                    out.flush()
                                }
                            }
                            selfie.recycle()
                            onComplete(file.exists() && file.length() > 0L)
                        } catch (_: Exception) {
                            onComplete(false)
                        } finally {
                            image.close()
                        }
                    }

                    override fun onError(exception: ImageCaptureException) {
                        onComplete(false)
                    }
                },
            )
        } catch (_: Exception) {
            onComplete(false)
        }
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

        val activity = ArCameraBridge.hostActivity
        if (activity == null) {
            deliver(null, "no_activity")
            return
        }
        val outputFile = File(
            activity.cacheDir,
            "ar_photo_${System.currentTimeMillis()}.jpg",
        )
        val outputPath = outputFile.absolutePath

        fun saveBaked(
            bitmap: Bitmap,
            quality: Int = INSTANT_JPEG_QUALITY,
            maxEdge: Int = INSTANT_CAPTURE_EDGE,
        ): Boolean {
            return try {
                if (savePhotoBitmapToFile(bitmap, outputFile, quality, maxEdge)) {
                    oesPhotoReady = true
                    deliver(outputPath, null)
                    true
                } else {
                    false
                }
            } catch (_: Exception) {
                false
            } finally {
                if (bitmap !== lastCaptureBitmap) {
                    try {
                        bitmap.recycle()
                    } catch (_: Exception) {
                    }
                }
            }
        }

        fun photoExecutor() =
            analysisExecutor
                ?: ArCameraBridge.hostActivity?.let {
                    ContextCompat.getMainExecutor(it)
                }

        fun enqueueSaveBaked(bitmap: Bitmap, onFailure: () -> Unit) {
            val exec = photoExecutor()
            if (exec == null) {
                if (!saveBaked(bitmap) && !delivered.get()) onFailure()
                return
            }
            exec.execute {
                if (!saveBaked(bitmap) && !delivered.get()) {
                    mainHandler.post(onFailure)
                }
            }
        }

        fun bakePreviewFrame(): Bitmap? {
            val filter = ArCameraBridge.currentFilter
            val base = safeCopyBitmap(lastCaptureBitmap) ?: return null
            return try {
                when {
                    filter.isPngOverlay() -> {
                        ArCameraBridge.faceOverlay?.composeOnto(base) ?: base
                    }
                    else -> base
                }
            } catch (_: Exception) {
                base
            }
        }

        val filter = ArCameraBridge.currentFilter

        // First-open / no-filter: use retained analysis frame so editor isn't black.
        // Never use this path for active filters (must bake live GL / ImageCapture).
        if (filter == FilterType.NONE && !boundToOes) {
            val frame = bakePreviewFrame()
            if (frame != null && !isMostlyEmpty(frame)) {
                enqueueSaveBaked(frame) {
                    if (!delivered.get()) takePhotoWithImageCapture(::deliver)
                }
                return
            }
            if (frame != null && frame !== lastCaptureBitmap) {
                try {
                    frame.recycle()
                } catch (_: Exception) {
                }
            }
        }

        // OES preview path (legacy): grab a fresh GL frame when still bound to OES.
        if (boundToOes) {
            takePhotoFromGl(::deliver, ::saveBaked)
            return
        }

        // Stickers: always use hardware ImageCapture (hi-res) then bake overlay —
        // analysis frames are intentionally small for tracking and look soft if used.
        if (filter.isPngOverlay() ||
            (filter == FilterType.NONE && !ArCameraBridge.isPreviewLetterboxed())
        ) {
            takePhotoWithImageCapture(::deliver)
            return
        }

        fun tryBaked(remaining: Int) {
            snapshotVisibleFrame(preferImmediate = true) { bitmap ->
                if (bitmap != null && !isMostlyEmpty(bitmap)) {
                    enqueueSaveBaked(bitmap) {
                        if (bitmap !== lastCaptureBitmap) {
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

    private fun takePhotoFromGl(
        onResult: (String?, String?) -> Unit,
        saveBaked: (Bitmap) -> Boolean,
    ) {
        val gl = ArCameraBridge.warpGlView
        if (gl == null || !gl.isGlInitialized()) {
            takePhotoWithImageCapture(onResult)
            return
        }

        fun finishGlKeepWarm() {
            // Leave capture enabled while OES preview is live so the next tap is instant.
            gl.setCaptureMaxEdge(INSTANT_CAPTURE_EDGE)
            if (boundToOes && !recording) {
                gl.setCaptureEnabled(true)
            } else if (!recording) {
                gl.setCaptureEnabled(false)
            }
        }

        fun saveOnExecutor(gpu: Bitmap, remaining: Int, onMiss: () -> Unit) {
            val exec = analysisExecutor
                ?: ArCameraBridge.hostActivity?.let {
                    ContextCompat.getMainExecutor(it)
                }
            val work = Runnable {
                val ok = saveBaked(gpu)
                mainHandler.post {
                    if (ok) {
                        finishGlKeepWarm()
                        gl.requestCaptureNow()
                    } else if (remaining > 0) {
                        onMiss()
                    } else {
                        finishGlKeepWarm()
                        takePhotoWithImageCapture(onResult)
                    }
                }
            }
            if (exec != null) exec.execute(work) else work.run()
        }

        // Instant path: save the already-warm live preview frame.
        val immediate = try {
            gl.copyLastFilteredFrame()
        } catch (_: Exception) {
            null
        }
        if (immediate != null && !isMostlyEmpty(immediate)) {
            saveOnExecutor(immediate, 0) {
                takePhotoWithImageCapture(onResult)
            }
            return
        }
        immediate?.recycle()

        // Cold path: force one new frame, then save (short poll).
        gl.setCaptureMaxEdge(INSTANT_CAPTURE_EDGE)
        gl.setCaptureEnabled(true)
        gl.requestCaptureNow()

        fun tryRead(remaining: Int) {
            val gpu = try {
                gl.copyLastFilteredFrame()
            } catch (_: Exception) {
                null
            }
            if (gpu != null && !isMostlyEmpty(gpu)) {
                saveOnExecutor(gpu, remaining) {
                    gl.requestCaptureNow()
                    mainHandler.postDelayed({ tryRead(remaining - 1) }, 16)
                }
                return
            }
            gpu?.recycle()
            if (remaining > 0) {
                gl.requestCaptureNow()
                mainHandler.postDelayed({ tryRead(remaining - 1) }, 16)
            } else {
                finishGlKeepWarm()
                takePhotoWithImageCapture(onResult)
            }
        }

        mainHandler.postDelayed({ tryRead(4) }, 24)
    }

    private fun takePhotoWithImageCapture(onResult: (String?, String?) -> Unit) {
        val activity = ArCameraBridge.hostActivity
        if (activity == null) {
            onResult(null, "no_activity")
            return
        }
        val file = File(activity.cacheDir, "ar_photo_${System.currentTimeMillis()}.jpg")
        takePhotoWithImageCaptureToFile(file) { ok ->
            if (ok) {
                onResult(file.absolutePath, null)
            } else {
                onResult(null, "photo_failed")
            }
        }
    }

    fun startRecording(
        onResult: (Boolean, String?) -> Unit,
        maxDurationMs: Long = 0L,
    ) {
        if (isRecordingActive()) {
            onResult(false, "already_recording")
            return
        }
        val activity = ArCameraBridge.hostActivity
        if (activity == null) {
            onResult(false, "no_activity")
            return
        }

        cancelMaxDurationStop()
        lastStoppedPath = null
        maxRecordDurationMs = maxDurationMs.coerceAtLeast(0L)

        val file = File(activity.cacheDir, "ar_video_${System.currentTimeMillis()}.mp4")
        try {
            if (!hasMicPermission(activity)) {
                ActivityCompat.requestPermissions(
                    activity,
                    arrayOf(Manifest.permission.RECORD_AUDIO),
                    101,
                )
            }

            if ((ArCameraBridge.currentFilter == FilterType.NONE ||
                    ArCameraBridge.currentFilter.isPngOverlay()) &&
                !ArCameraBridge.isPreviewLetterboxed() &&
                !boundToOes &&
                simpleHardwareRecorder.isAvailable()
            ) {
                simpleHardwareRecorder.start(activity, file) { ok, err ->
                    if (ok) {
                        recording = true
                        hardwareRecording = true
                        glSurfaceRecording = false
                        scheduleMaxDurationStop()
                        onResult(true, null)
                    } else {

                        startBitmapRecording(file, onResult)
                    }
                }
                return
            }

            if (ArCameraBridge.currentFilter.useShader() || boundToOes) {
                startGlSurfaceRecording(file, onResult)
                return
            }

            startBitmapRecording(file, onResult)
        } catch (e: Exception) {
            recording = false
            hardwareRecording = false
            glSurfaceRecording = false
            cancelMaxDurationStop()
            onResult(false, e.message ?: "record_start_failed")
        }
    }

    @Volatile
    var onRecordingAutoStopped: ((String) -> Unit)? = null

    private fun scheduleMaxDurationStop() {
        maxRecordStopRunnable?.let { mainHandler.removeCallbacks(it) }
        maxRecordStopRunnable = null
        val maxMs = maxRecordDurationMs
        if (maxMs <= 0L) return
        val runnable = Runnable {
            maxRecordStopRunnable = null
            if (!isRecordingActive()) return@Runnable
            Log.i("ArCameraController", "layout max-duration reached (${maxMs}ms) — auto stop")
            stopRecording { path, err ->
                if (path != null) {
                    lastStoppedPath = path
                    onRecordingAutoStopped?.invoke(path)
                } else {
                    Log.w("ArCameraController", "max-duration auto-stop failed: $err")
                }
            }
        }
        maxRecordStopRunnable = runnable
        mainHandler.postDelayed(runnable, maxMs)
    }

    private fun cancelMaxDurationStop() {
        maxRecordStopRunnable?.let { mainHandler.removeCallbacks(it) }
        maxRecordStopRunnable = null
        maxRecordDurationMs = 0L
    }

    private fun startGlSurfaceRecording(file: File, onResult: (Boolean, String?) -> Unit) {
        val gl = ArCameraBridge.warpGlView
        if (gl == null || !gl.isGlInitialized()) {
            startBitmapRecording(file, onResult)
            return
        }
        val vw = ArCameraBridge.warpViewWidth.takeIf { it > 0 }
            ?: gl.width.coerceAtLeast(1)
        val vh = ArCameraBridge.warpViewHeight.takeIf { it > 0 }
            ?: gl.height.coerceAtLeast(1)
        val maxEdge = RECORD_GL_EDGE
        val scale = minOf(1f, maxEdge.toFloat() / maxOf(vw, vh))
        val encW = ((vw * scale).toInt() and 1.inv()).coerceAtLeast(2)
        val encH = ((vh * scale).toInt() and 1.inv()).coerceAtLeast(2)

        val surface = try {
            videoRecorder.startSurfaceSession(file, encW, encH)
        } catch (_: Exception) {
            null
        }
        if (surface == null) {
            startBitmapRecording(file, onResult)
            return
        }

        try {
            recording = true
            hardwareRecording = false
            glSurfaceRecording = true
            lastRecordCopyMs = 0L

            gl.setCaptureEnabled(false)
            gl.setOnFramePresented(null)
            gl.setEncoderSurface(surface, encW, encH)
            scheduleMaxDurationStop()
            onResult(true, null)
        } catch (e: Exception) {
            glSurfaceRecording = false
            recording = false
            try {
                gl.clearEncoderSurface(null)
            } catch (_: Exception) {
            }
            videoRecorder.abort()
            startBitmapRecording(file, onResult)
        }
    }

    private fun startBitmapRecording(file: File, onResult: (Boolean, String?) -> Unit) {
        try {
            videoRecorder.arm(file)
            recording = true
            hardwareRecording = false
            glSurfaceRecording = false
            lastRecordCopyMs = 0L
            startRecordFramePump()

            val gl = ArCameraBridge.warpGlView
            if (boundToOes || ArCameraBridge.currentFilter.useShader()) {
                gl?.setCaptureEnabled(true)
                gl?.setCaptureMaxEdge(RECORD_GL_EDGE)

                gl?.setOnFramePresented { onOesFramePresented() }
            }
            scheduleMaxDurationStop()
            onResult(true, null)
        } catch (e: Exception) {
            recording = false
            hardwareRecording = false
            glSurfaceRecording = false
            cancelMaxDurationStop()
            onResult(false, e.message ?: "record_start_failed")
        }
    }

    fun stopRecording(onResult: (String?, String?) -> Unit) {
        cancelMaxDurationStop()
        if (!isRecordingActive()) {
            val cached = lastStoppedPath
            lastStoppedPath = null
            if (cached != null) {
                onResult(cached, null)
            } else {
                onResult(null, "not_recording")
            }
            return
        }
        lastStoppedPath = null

        if (hardwareRecording || simpleHardwareRecorder.isRecording()) {
            recording = false
            hardwareRecording = false
            glSurfaceRecording = false
            simpleHardwareRecorder.stop { file, err ->
                if (file != null) {
                    lastStoppedPath = file.absolutePath
                    onResult(file.absolutePath, null)
                } else {
                    onResult(null, err ?: "empty_video")
                }
            }
            return
        }

        if (glSurfaceRecording || videoRecorder.isSurfaceSession()) {
            recording = false
            glSurfaceRecording = false
            val gl = ArCameraBridge.warpGlView

            fun finishStop() {
                try {
                    val file = videoRecorder.stop()
                    if (file != null && file.exists() && file.length() > 0L) {
                        lastStoppedPath = file.absolutePath
                        onResult(file.absolutePath, null)
                    } else {
                        onResult(null, "empty_video")
                    }
                } catch (e: Exception) {
                    onResult(null, e.message ?: "record_stop_failed")
                }
            }
            if (gl != null) {
                // Stop the encoder first; clearing the encoder surface afterward
                // avoids encoding an extra black frame as the clip's last sample.
                finishStop()
                gl.clearEncoderSurface(null)
            } else {
                finishStop()
            }
            return
        }

        recording = false
        stopRecordFramePump()
        try {
            val gl = ArCameraBridge.warpGlView
            gl?.setCaptureEnabled(
                ArCameraBridge.currentFilter.isDistortion(),
            )
            gl?.setCaptureMaxEdge(CAPTURE_MAX_EDGE)

            if (!boundToOes) {
                gl?.setOnFramePresented(null)
            }

            val file = videoRecorder.stop()
            if (file != null && file.exists() && file.length() > 0L) {
                lastStoppedPath = file.absolutePath
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

        fun bakeAnalysisFrame(): Bitmap? {
            val base = safeCopyBitmap(lastCaptureBitmap) ?: return null
            return try {
                when {
                    filter.isPngOverlay() -> {
                        ArCameraBridge.faceOverlay?.composeOnto(base) ?: base
                    }
                    else -> base
                }
            } catch (_: Exception) {
                base
            }
        }

        if (!filter.isDistortion()) {
            onDone(bakeAnalysisFrame())
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
        if (!recording || glSurfaceRecording || !videoRecorder.isRecording()) return
        if (videoRecorder.isSurfaceSession()) return
        val now = android.os.SystemClock.elapsedRealtime()
        if (now - lastRecordCopyMs < RECORD_FRAME_INTERVAL_MS) return
        if (!recordingPixelCopyBusy.compareAndSet(false, true)) return
        lastRecordCopyMs = now

        val filter = ArCameraBridge.currentFilter

        if (boundToOes || filter.useShader()) {
            val gl = ArCameraBridge.warpGlView

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

    private fun maybeCaptureRecordingFrameDirect(displayBmp: Bitmap, filter: FilterType): Boolean {
        if (glSurfaceRecording || videoRecorder.isSurfaceSession()) return false
        if (!videoRecorder.isRecording()) return false
        val now = android.os.SystemClock.elapsedRealtime()
        if (now - lastRecordCopyMs < RECORD_FRAME_INTERVAL_MS) return false
        if (!recordingPixelCopyBusy.compareAndSet(false, true)) return false
        lastRecordCopyMs = now

        val baked = displayBmp
        if (baked !== displayBmp && !displayBmp.isRecycled) {
            displayBmp.recycle()
        }
        offerRecordingFrameAsync(baked, recycleSourceAlways = true)
        return true
    }

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

        val pngOverlay = ArCameraBridge.currentFilter.isPngOverlay()
        var hasNewFrame = false
        synchronized(recordFrameLock) {
            val pending = latestRecordFrame
            if (pending != null && !pending.isRecycled) {
                pumpCurrentFrame?.takeIf { it !== pending && !it.isRecycled }?.recycle()
                pumpCurrentFrame = pending
                latestRecordFrame = null
                hasNewFrame = true
            }
        }
        // Stickers: only blit when a new baked frame arrives — re-drawing the same
        // bitmap at 30fps was starving the live preview while recording.
        if (pngOverlay && !hasNewFrame) return
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
                else -> source
            }
        } catch (_: Exception) {
            source
        }
    }

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

    private fun warmVideoEncoder() {
        val executor = recordOfferExecutor ?: return
        executor.execute {
            try {
                val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
                codec.release()
                Log.i("ArCameraController", "video encoder warmed")
            } catch (t: Throwable) {
                Log.w("ArCameraController", "video encoder warm failed", t)
            }
        }
    }

    private fun buildImageCapture(displayRotation: Int): ImageCapture {
        return ImageCapture.Builder()
            .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
            .setTargetResolution(Size(PHOTO_TARGET_WIDTH, PHOTO_TARGET_HEIGHT))
            .setTargetRotation(displayRotation)
            .build()
            .also { it.flashMode = ImageCapture.FLASH_MODE_OFF }
    }

    private fun bindPreviewToOes(preview: Preview, glView: FaceWarpGlView, activity: Activity) {
        val executor = ContextCompat.getMainExecutor(activity)
        preview.setSurfaceProvider(executor) { request ->
            val st = glView.cameraSurfaceTexture()
            if (st == null) {
                request.willNotProvideSurface()
                return@setSurfaceProvider
            }
            val res = request.resolution
            // Keep camera buffer aspect (e.g. 1440x1080 → 960x720). Do NOT force
            // phone screen aspect — that stretched/squashed faces.
            val maxBuf = 960
            val bufScale = minOf(1f, maxBuf.toFloat() / maxOf(res.width, res.height))
            val bufW = ((res.width * bufScale).toInt() and 1.inv()).coerceAtLeast(2)
            val bufH = ((res.height * bufScale).toInt() and 1.inv()).coerceAtLeast(2)
            st.setDefaultBufferSize(bufW, bufH)
            android.util.Log.i(
                "ArCameraOES",
                "bindPreviewToOes cam=${res.width}x${res.height} " +
                    "view=${glView.width}x${glView.height} buf=${bufW}x${bufH} " +
                    "+${ArCameraBridge.oesDiagElapsedMs()}ms",
            )

            glView.setCameraTransform(0, frontMirror = false, bufW, bufH)
            request.setTransformationInfoListener(executor) { info ->
                android.util.Log.i(
                    "ArCameraOES",
                    "transform rot=${info.rotationDegrees} buf=${bufW}x${bufH} " +
                        "+${ArCameraBridge.oesDiagElapsedMs()}ms",
                )
                glView.setCameraTransform(
                    info.rotationDegrees,
                    frontMirror = false,
                    bufW,
                    bufH,
                )
            }
            val surface = Surface(st)
            request.provideSurface(surface, executor) { surface.release() }
            android.util.Log.i(
                "ArCameraOES",
                "bindPreviewToOes: surfaceProvided +${ArCameraBridge.oesDiagElapsedMs()}ms",
            )
            ArCameraBridge.onOesSurfaceProvided()
        }
    }

    private fun onOesFramePresented() {
        ArCameraBridge.onGlFramePresented()
        warmOesPhotoCaptureIfNeeded()

        if (recording && !hardwareRecording && !glSurfaceRecording) {
            maybeCaptureRecordingFrame()
        }
    }

    fun isBoundToOes(): Boolean = boundToOes

    fun setPreferOesBinding(prefer: Boolean) {
        preferOesBinding = prefer
    }

    fun canRebindCamera(): Boolean = started && !isRecordingActive()

    fun onHostPause() {
        if (!started) return
        try {
            ArCameraBridge.warpGlView?.onPause()
        } catch (_: Throwable) {
        }
    }

    fun onHostResume() {
        if (!started) return
        if (isRecordingActive()) return
        val activity = ArCameraBridge.hostActivity ?: return
        val gl = ArCameraBridge.warpGlView
        try {
            gl?.onResume()
        } catch (_: Throwable) {
        }

        boundToOes = false
        rebindPosted = false
        switchingCamera = false
        convertingFrame.set(false)
        activity.runOnUiThread {
            ArCameraBridge.syncPreviewNaturalOrientation()
            gl?.ensureGlInitialized()
            preferOesBinding = false
            boundToOes = false
            ArCameraBridge.applyCurrentFilter()

            // Color-grade OES path removed; always rebind PreviewView after camera switch.
            requestPreviewRebind()
        }
    }

    fun ensureOesPreviewBound() {
        if (boundToOes) {
            android.util.Log.i(
                "ArCameraOES",
                "ensureOes: alreadyBound +${ArCameraBridge.oesDiagElapsedMs()}ms",
            )
            return
        }
        if (isRecordingActive()) {
            android.util.Log.w(
                "ArCameraOES",
                "ensureOes: recording — skip +${ArCameraBridge.oesDiagElapsedMs()}ms",
            )
            return
        }
        preferOesBinding = true
        val gl = ArCameraBridge.warpGlView ?: run {
            android.util.Log.e("ArCameraOES", "ensureOes: gl null")
            return
        }
        gl.setOesEnabled(true)
        val stReady = gl.cameraSurfaceTexture() != null
        android.util.Log.i(
            "ArCameraOES",
            "ensureOes: requestRebind stReady=$stReady +${ArCameraBridge.oesDiagElapsedMs()}ms",
        )
        if (stReady) {
            requestPreviewRebind()
        } else {

            gl.onCameraSurfaceReady = {
                gl.onCameraSurfaceReady = null
                android.util.Log.i(
                    "ArCameraOES",
                    "ensureOes: surfaceReady → rebind +${ArCameraBridge.oesDiagElapsedMs()}ms",
                )
                if (!boundToOes) requestPreviewRebind()
            }
        }
    }

    fun ensurePreviewViewBound() {
        preferOesBinding = false
        if (!boundToOes) return
        if (isRecordingActive()) return
        requestPreviewRebind()
    }

    fun forcePreviewViewRebind() {
        if (isRecordingActive()) return
        preferOesBinding = false
        boundToOes = false
        requestPreviewRebind()
    }

    @Volatile
    private var rebindPosted = false

    private fun requestPreviewRebind() {
        val activity = ArCameraBridge.hostActivity ?: return
        val lifecycleOwner = ArCameraBridge.lifecycleOwner ?: return
        val previewView = ArCameraBridge.previewView ?: return
        val faceOverlay = ArCameraBridge.faceOverlay ?: return

        if (rebindPosted) {
            android.util.Log.i(
                "ArCameraOES",
                "rebind: alreadyPosted +${ArCameraBridge.oesDiagElapsedMs()}ms",
            )
            return
        }
        rebindPosted = true

        switchingCamera = true
        imageAnalysis?.clearAnalyzer()
        convertingFrame.set(false)
        android.util.Log.i(
            "ArCameraOES",
            "rebind: posted preferOes=$preferOesBinding +${ArCameraBridge.oesDiagElapsedMs()}ms",
        )
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
            val bindStart = android.os.SystemClock.elapsedRealtime()
            val cameraProvider = cameraProviderFuture.get()
            val displayRotation = activity.windowManager.defaultDisplay.rotation
            val previewTarget = Size(ANALYSIS_WIDTH, ANALYSIS_HEIGHT)
            val pngFast = ArCameraBridge.currentFilter.isPngOverlay()
            pngFastAnalysisBound = pngFast
            val analysisTarget = if (pngFast) {
                Size(PNG_ANALYSIS_WIDTH, PNG_ANALYSIS_HEIGHT)
            } else {
                Size(ANALYSIS_WIDTH, ANALYSIS_HEIGHT)
            }

            val preview = Preview.Builder()
                .setTargetResolution(previewTarget)
                .setTargetRotation(displayRotation)
                .build()

            val glView = ArCameraBridge.warpGlView
            val useOes = preferOesBinding &&
                glView != null &&
                glView.cameraSurfaceTexture() != null

            android.util.Log.i(
                "ArCameraOES",
                "bindCamera: START useOes=$useOes preferOes=$preferOesBinding " +
                    "stReady=${glView?.cameraSurfaceTexture() != null} " +
                    "+${ArCameraBridge.oesDiagElapsedMs()}ms",
            )

            imageAnalysis?.clearAnalyzer()
            android.util.Log.i(
                "ArCameraOES",
                "bindCamera: unbindAll BEFORE +${ArCameraBridge.oesDiagElapsedMs()}ms",
            )
            cameraProvider.unbindAll()
            android.util.Log.i(
                "ArCameraOES",
                "bindCamera: unbindAll AFTER +${ArCameraBridge.oesDiagElapsedMs()}ms",
            )
            imageAnalysis = null
            videoCapture = null
            simpleHardwareRecorder.attach(null)

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

            if (useOes && glView != null) {
                resetOesPhotoReady()
                boundToOes = true
                glView.setOesEnabled(true)
                glView.setOnFramePresented { onOesFramePresented() }
                bindPreviewToOes(preview, glView, activity)
                val capture = buildImageCapture(displayRotation)
                imageCapture = capture
                try {
                    applyTorchAfterBind(
                        cameraProvider.bindToLifecycle(
                            lifecycleOwner,
                            selector,
                            preview,
                            capture,
                        ),
                    )
                    android.util.Log.i(
                        "ArCameraOES",
                        "bindCamera: OES bind OK cost=${android.os.SystemClock.elapsedRealtime() - bindStart}ms " +
                            "+${ArCameraBridge.oesDiagElapsedMs()}ms",
                    )
                    scheduleOesPhotoWarmup(glView)
                } catch (_: Exception) {
                    try {
                        cameraProvider.unbindAll()
                        applyTorchAfterBind(
                            cameraProvider.bindToLifecycle(
                                lifecycleOwner,
                                selector,
                                preview,
                            ),
                        )
                        imageCapture = null
                        android.util.Log.w(
                            "ArCameraOES",
                            "bindCamera: OES bind fallback preview-only " +
                                "+${ArCameraBridge.oesDiagElapsedMs()}ms",
                        )
                    } catch (_: Exception) {
                        camera = null
                        boundToOes = false
                        imageCapture = null
                        android.util.Log.e(
                            "ArCameraOES",
                            "bindCamera: OES bind FAILED +${ArCameraBridge.oesDiagElapsedMs()}ms",
                        )
                    }
                }
                switchingCamera = false
                return@addListener
            }

            boundToOes = false
            glView?.setOesEnabled(false)
            preview.surfaceProvider = previewView.surfaceProvider

            val analysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                .setTargetResolution(analysisTarget)
                .setTargetRotation(displayRotation)
                .build()

            analysis.setAnalyzer(executor) { imageProxy ->
                processImage(imageProxy, faceOverlay, activity)
            }

            val capture = buildImageCapture(displayRotation)
            imageCapture = capture

            val recorder = Recorder.Builder()
                .setQualitySelector(
                    QualitySelector.fromOrderedList(
                        listOf(Quality.HD, Quality.SD, Quality.LOWEST),
                        FallbackStrategy.lowerQualityOrHigherThan(Quality.SD),
                    ),
                )
                .build()
            val hwVideo = VideoCapture.Builder(recorder)
                .setMirrorMode(MirrorMode.MIRROR_MODE_ON_FRONT_ONLY)
                .build()
            hwVideo.targetRotation = displayRotation

            imageAnalysis = analysis
            fun bindWithVideo(): Boolean {
                return try {
                    if (pngFast) {
                        val overlay = stickerCameraOverlay ?: StickerCameraOverlay(
                            activity.applicationContext,
                        ).also { stickerCameraOverlay = it }
                        val effect = overlay.ensureEffect()
                        val viewPort = try {
                            previewView.getViewPort(displayRotation)
                        } catch (_: Exception) {
                            null
                        }
                        val groupBuilder = UseCaseGroup.Builder()
                            .addUseCase(preview)
                            .addUseCase(analysis)
                            .addUseCase(capture)
                            .addUseCase(hwVideo)
                            .addEffect(effect)
                        if (viewPort != null) {
                            groupBuilder.setViewPort(viewPort)
                        }
                        applyTorchAfterBind(
                            cameraProvider.bindToLifecycle(
                                lifecycleOwner,
                                selector,
                                groupBuilder.build(),
                            ),
                        )
                    } else {
                        applyTorchAfterBind(
                            cameraProvider.bindToLifecycle(
                                lifecycleOwner,
                                selector,
                                preview,
                                analysis,
                                capture,
                                hwVideo,
                            ),
                        )
                    }
                    videoCapture = hwVideo
                    simpleHardwareRecorder.attach(hwVideo)
                    true
                } catch (_: Exception) {
                    false
                }
            }
            try {
                if (!bindWithVideo()) {
                    cameraProvider.unbindAll()
                    // Fallback without OverlayEffect (software record path if PNG hw fails later).
                    applyTorchAfterBind(
                        cameraProvider.bindToLifecycle(
                            lifecycleOwner,
                            selector,
                            preview,
                            analysis,
                            capture,
                            hwVideo,
                        ),
                    )
                    videoCapture = hwVideo
                    simpleHardwareRecorder.attach(hwVideo)
                }
            } catch (_: Exception) {
                try {
                    cameraProvider.unbindAll()
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
                }
            } finally {
                switchingCamera = false
            }
        }, ContextCompat.getMainExecutor(activity))
    }

    private fun processImage(
        imageProxy: ImageProxy,
        faceOverlay: FaceOverlayView,
        activity: Activity,
    ) {

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

            // OES color-grade path removed — analysis always processes when not hardware-recording.

            if (hardwareRecording) {
                // Normal/hardware path: drop frames (zero CPU).
                // PNG: keep lightweight landmark updates so live overlay + OverlayEffect stay sticky.
                if (!filter.isPngOverlay()) {
                    imageProxy.close()
                    return
                }
            }

            if (filter == FilterType.NONE && !recording) {
                // Keep a throttled snapshot so first shutter (no filter) is instant.
                if (frameCounter % 3 == 0) {
                    val raw = ImageProxyBitmapUtils.toBitmap(imageProxy)
                    imageProxy.close()
                    if (raw != null) {
                        try {
                            val orientedBmp = ImageProxyBitmapUtils.orientScaled(
                                raw,
                                rotation,
                                ArCameraBridge.isFrontCamera,
                                INSTANT_CAPTURE_EDGE,
                            )
                            if (orientedBmp !== raw && !raw.isRecycled) raw.recycle()
                            retainCaptureFrame(orientedBmp)
                            if (orientedBmp !== lastCaptureBitmap && !orientedBmp.isRecycled) {
                                orientedBmp.recycle()
                            }
                        } catch (_: Exception) {
                            if (!raw.isRecycled) raw.recycle()
                        }
                    }
                } else {
                    imageProxy.close()
                }
                return
            }

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
                filter.isDistortion() || filter.isPngOverlay()
            // Stickers/glasses: detect every frame so overlays stick like TikTok (no catch-up lag).
            // Beauty/distortion keep throttling to protect GPU warp path FPS.
            val detectEvery = when {
                // Stickers: every other frame — enough stickiness, much less MediaPipe load.
                filter.isPngOverlay() -> 2
                needsFace -> 3
                else -> 4
            }
            val runDetection =
                needsFace && (frameCounter % detectEvery == 0 || cachedSnapshot == null)

            val front = ArCameraBridge.isFrontCamera
            val mirrorInOrient = front && !needsFace
            val needMirrorInBranch = front && needsFace

            oriented = when {
                filter.isPngOverlay() -> {
                    // Tiny bitmap for MediaPipe only — keeps live tracking light.
                    ImageProxyBitmapUtils.orientScaled(
                        rawBitmap,
                        rotation,
                        mirrorInOrient,
                        DETECT_MAX_DIMENSION,
                    )
                }
                needsFace -> {
                    ImageProxyBitmapUtils.orient(rawBitmap, rotation, mirrorInOrient)
                }
                else -> {
                    val edge = GL_MAX_EDGE
                    ImageProxyBitmapUtils.orientScaled(rawBitmap, rotation, mirrorInOrient, edge)
                }
            }
            // Keep rawBitmap for PNG hi-res record frames; recycle after PNG branch.
            if (oriented !== rawBitmap && !filter.isPngOverlay()) rawBitmap.recycle()

            if (runDetection) {
                val landmarker = faceLandmarker ?: FaceLandmarkerHolder.get().also { faceLandmarker = it }
                if (landmarker != null) {
                    val detectBitmap = if (filter.isPngOverlay()) {
                        oriented
                    } else {
                        ImageProxyBitmapUtils.scaleToMaxDimension(
                            oriented,
                            DETECT_MAX_DIMENSION,
                            filter = false,
                        )
                    }
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
                        if (filter.isPngOverlay()) {
                            cachedSnapshot = raw
                        } else {
                            cachedSnapshot = FaceLandmarkSmoother.smooth(raw)
                        }
                    } else {

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
            if (!LiveRetouchState.adjustments.isNoop && activeSnapshot != null) {
                LiveRetouchState.updateNoseLandmarks(
                    activeSnapshot,
                    oriented.width,
                    oriented.height,
                )
            }

            when {
                filter.useShader() -> {

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

                    if (!recording) retainCaptureFrame(display)

                    if (recording && !glSurfaceRecording) {
                        glView.setCaptureEnabled(true)
                        glView.setCaptureMaxEdge(RECORD_GL_EDGE)
                    }
                    glView.submitFrameWithParams(display, params)
                    display = null
                    ArCameraBridge.onGlFramePresented()
                }

                else -> {
                    if (filter.isPngOverlay()) {
                        val landmarkW = activeSnapshot?.imageWidth ?: oriented.width
                        val landmarkH = activeSnapshot?.imageHeight ?: oriented.height
                        val snapshots = activeSnapshot?.let { listOf(it) } ?: emptyList()
                        val expectedFilter = filter
                        val expectedFront = front
                        // Regular post (not front-of-queue) so sticker updates don't starve UI.
                        mainHandler.post {
                            if (ArCameraBridge.currentFilter != expectedFilter) return@post
                            faceOverlay.setLandmarks(
                                snapshots,
                                landmarkW,
                                landmarkH,
                                isFrontCamera = expectedFront,
                            )
                        }
                        stickerCameraOverlay?.updateLandmarks(
                            expectedFilter,
                            snapshots,
                            landmarkW,
                            landmarkH,
                            expectedFront,
                        )

                        // Preferred path: hardware VideoCapture + OverlayEffect (zero encode lag).
                        // Fallback only when HW recorder isn't active (rare bind failure).
                        if (recording && !hardwareRecording) {
                            val now = android.os.SystemClock.elapsedRealtime()
                            if (now - lastRecordCopyMs >= PNG_RECORD_INTERVAL_MS &&
                                recordingPixelCopyBusy.compareAndSet(false, true)
                            ) {
                                lastRecordCopyMs = now
                                val hiRes = ImageProxyBitmapUtils.orientScaled(
                                    rawBitmap,
                                    rotation,
                                    false,
                                    PNG_RECORD_EDGE,
                                )
                                val captureSrc = if (needMirrorInBranch) {
                                    ImageProxyBitmapUtils.mirrorHorizontally(hiRes).also {
                                        if (it !== hiRes && !hiRes.isRecycled) hiRes.recycle()
                                    }
                                } else {
                                    hiRes
                                }
                                val exec = recordOfferExecutor
                                if (exec != null) {
                                    exec.execute {
                                        try {
                                            val baked = try {
                                                ArCameraBridge.faceOverlay?.composeOnto(captureSrc)
                                                    ?: captureSrc
                                            } catch (_: Exception) {
                                                captureSrc
                                            }
                                            if (recording && videoRecorder.isRecording()) {
                                                synchronized(recordFrameLock) {
                                                    val old = latestRecordFrame
                                                    latestRecordFrame = baked
                                                    if (old != null &&
                                                        old !== baked &&
                                                        !old.isRecycled
                                                    ) {
                                                        old.recycle()
                                                    }
                                                }
                                                if (baked !== captureSrc && !captureSrc.isRecycled) {
                                                    captureSrc.recycle()
                                                }
                                            } else {
                                                if (baked !== captureSrc && !baked.isRecycled) {
                                                    baked.recycle()
                                                }
                                                if (!captureSrc.isRecycled) captureSrc.recycle()
                                            }
                                        } finally {
                                            recordingPixelCopyBusy.set(false)
                                        }
                                    }
                                } else {
                                    recordingPixelCopyBusy.set(false)
                                    if (!captureSrc.isRecycled) captureSrc.recycle()
                                }
                            }
                        }

                        if (oriented !== rawBitmap && !oriented.isRecycled) oriented.recycle()
                        oriented = null
                        if (!rawBitmap.isRecycled) rawBitmap.recycle()
                    } else {

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
