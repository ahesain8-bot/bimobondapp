package com.dubai.bimobondapp.ar_camera

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CaptureRequest
import android.media.MediaCodec
import android.media.MediaFormat
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.util.Range
import android.util.Size
import android.view.PixelCopy
import android.view.Surface
import android.view.SurfaceView
import android.view.View
import androidx.annotation.OptIn
import androidx.camera.camera2.interop.Camera2CameraControl
import androidx.camera.camera2.interop.Camera2CameraInfo
import androidx.camera.camera2.interop.Camera2Interop
import androidx.camera.camera2.interop.CaptureRequestOptions
import androidx.camera.camera2.interop.ExperimentalCamera2Interop
import androidx.camera.core.AspectRatio
import androidx.camera.core.CameraInfo
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.ImageProxy
import androidx.camera.core.MirrorMode
import androidx.camera.core.Preview
import androidx.camera.core.UseCaseGroup
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
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
import com.airbnb.lottie.LottieAnimationView
import com.dubai.bimobondapp.beauty.BeautyFilterProcessor
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
    /** High live Preview target (4:3 portrait). Prefer ≥1080p long edge. */
    private const val PREVIEW_TARGET_WIDTH = 1440
    private const val PREVIEW_TARGET_HEIGHT = 1920

    /** Landmarks / distortion only — keep low so Preview stream stays sharp. */
    private const val ANALYSIS_WIDTH = 640
    private const val ANALYSIS_HEIGHT = 480
    /** Analysis while PNG stickers active. Photos use ImageCapture (unchanged). */
    private const val PNG_ANALYSIS_WIDTH = 480
    private const val PNG_ANALYSIS_HEIGHT = 640

    /** Fallback raw EV index used only for the pre-bind builder (device step unknown yet). */
    private const val PREVIEW_EXPOSURE_BIAS = 2

    /**
     * Target EV bias for the live preview once the real device step size is known
     * (applied in [applyPreviewLook]). +0.7 EV brightens the viewfinder like stock
     * camera apps without blowing out highlights, regardless of whether the device's
     * exposureCompensationStep is 1/3, 1/2, or a full stop.
     */
    private const val PREVIEW_EXPOSURE_EV_STOPS = 0.7f

    /**
     * Front-camera zoom ratio applied on bind. Selfie lenses/HAL 1.0x defaults are
     * often pre-cropped tighter than the sensor's true FOV; pulling slightly under
     * 1.0 backs the frame out without the heavy edge distortion a full zoom-to-min
     * would introduce. Clamped to the device's actual supported range in
     * [applyFrontZoomOut] — devices whose minimum is already 1.0 (most single-lens
     * front cameras) are simply left untouched.
     */
    private const val FRONT_ZOOM_OUT_RATIO = 0.85f

    /**
     * Bilateral-filter smoothing strength baked into captured photos and recorded
     * video frames (see [BeautyFilterProcessor.smoothSkin]). Kept light — this
     * stacks on top of the HAL's own still-capture noise reduction (now correctly
     * STILL_CAPTURE-intent quality processing, not leaked-in preview settings — see
     * [buildLivePreview]), so it only needs to nudge things further, not do the
     * heavy lifting itself. Live viewfinder preview is untouched; this only bakes
     * into saved media.
     */
    private const val CAPTURE_SMOOTH_STRENGTH = 0.18f

    private const val PREVIEW_QUALITY_TAG = "ArPreviewQuality"
    private const val DETECT_MAX_DIMENSION = 384

    /** Skin-mask analysis/rasterize edge — small is fine, it's a soft gating mask. */
    private const val SKIN_MASK_ANALYSIS_EDGE = 256

    /** Run landmark detect + mask rasterize every Nth analysis frame — mask
     *  changes slowly, so a soft gating mask doesn't need every-frame updates. */
    private const val SKIN_MASK_DETECT_EVERY = 6
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

    // Matches CAPTURE_MAX_EDGE — Normal Mode video now records from the same
    // full-res OES pipeline the live preview and photos use (Stage 1), so it no
    // longer needs a lower cap than those.
    private const val RECORD_GL_EDGE = CAPTURE_MAX_EDGE
    private const val PHOTO_TARGET_WIDTH = 2160
    private const val PHOTO_TARGET_HEIGHT = 2880
    private const val RECORD_FRAME_INTERVAL_MS = 33L

    // Screen-overlay filters (Confetti/Keywords/Matrix/Space Rocket) capture via
    // PreviewView.getBitmap(), which does a full-view pixel readback — Android's
    // own docs warn against calling it every frame. Polling it at 30fps (same as
    // RECORD_FRAME_INTERVAL_MS) was the source of the heavy recording lag; this
    // slower interval (~10fps content updates) cuts that readback cost by ~3x.
    // The encoder itself still writes at full frame rate — pumpRecordFrame keeps
    // re-submitting the last captured composite between updates — so the saved
    // video doesn't drop frames, only how often the overlay content refreshes,
    // which is imperceptible for a decorative animation like this.
    private const val CONFETTI_RECORD_INTERVAL_MS = 100L

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
    private var skinMaskFrameCounter = 0
    private val skinMaskBusy = AtomicBoolean(false)
    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * Dedicated background thread for [PixelCopy] callbacks used by the
     * screen-overlay (Confetti/Keywords/Matrix/Space Rocket) recording capture
     * — see [requestConfettiFrame]. Keeps that readback fully off the main
     * thread without adding another concurrent camera stream (which was tried
     * and reverted — see project history — because it degraded overall camera
     * quality). Started in [start], torn down in [stop].
     */
    private var pixelCopyHandlerThread: HandlerThread? = null
    private var pixelCopyHandler: Handler? = null
    private val confettiPixelCopyBusy = AtomicBoolean(false)

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

    /** Last bind included ImageAnalysis (landmarks / distortion / stickers). */
    @Volatile
    private var analysisUseCaseBound = false

    /** Last bind included VideoCapture. */
    @Volatile
    private var videoUseCaseBound = false

    /**
     * When true, next [bindCamera] includes VideoCapture (record start).
     * Idle / normal preview keeps this false for max stream quality.
     */
    @Volatile
    private var preferVideoBinding = false

    /**
     * When true, next bind includes ImageCapture (shutter). Idle Normal Mode keeps
     * Preview-only so CameraX can pick the highest-quality preview stream.
     */
    @Volatile
    private var preferCaptureBinding = false

    private var pendingPhotoFile: File? = null
    private var pendingPhotoCb: ((Boolean) -> Unit)? = null

    /** Rebind-then-start for hardware record when VideoCapture was not bound. */
    private var pendingHardwareRecordFile: File? = null
    private var pendingHardwareRecordCb: ((Boolean, String?) -> Unit)? = null

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

        // SurfaceView path — sharper live preview than TextureView (COMPATIBLE).
        previewView.implementationMode = PreviewView.ImplementationMode.PERFORMANCE
        previewView.scaleType = PreviewView.ScaleType.FILL_CENTER
        previewView.visibility = View.VISIBLE

        FaceLandmarkerHolder.warmup(activity)
        faceLandmarker = FaceLandmarkerHolder.get()
        analysisExecutor = Executors.newSingleThreadExecutor()
        recordOfferExecutor = Executors.newSingleThreadExecutor { r ->
            Thread(r, "ar-video-offer").apply { priority = Thread.NORM_PRIORITY }
        }
        pixelCopyHandlerThread = HandlerThread("ar-confetti-pixelcopy").apply { start() }
        pixelCopyHandler = pixelCopyHandlerThread?.looper?.let { Handler(it) }
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
        // Rebind when Analysis need changes (NONE = no Analysis → sharper Preview stream).
        val wantAnalysis = needsAnalysisUseCase(filter)
        val wantPngFast = filter.isPngOverlay()
        if (started &&
            !isRecordingActive() &&
            !boundToOes &&
            canRebindCamera() &&
            (wantAnalysis != analysisUseCaseBound ||
                (wantAnalysis && wantPngFast != pngFastAnalysisBound))
        ) {
            requestPreviewRebind()
        }
    }

    private fun needsAnalysisUseCase(filter: FilterType): Boolean =
        filter.isDistortion() || filter.isPngOverlay()

    fun stop() {
        abortCapture()
        started = false
        boundToOes = false
        preferOesBinding = false
        preferVideoBinding = false
        preferCaptureBinding = false
        pendingHardwareRecordFile = null
        pendingHardwareRecordCb = null
        pendingPhotoFile = null
        pendingPhotoCb = null
        pngFastAnalysisBound = false
        analysisUseCaseBound = false
        videoUseCaseBound = false
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
        pixelCopyHandler = null
        pixelCopyHandlerThread?.quitSafely()
        pixelCopyHandlerThread = null
        confettiPixelCopyBusy.set(false)
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
        stopConfettiFramePump()
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
        skipSmoothing: Boolean = false,
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
            // Frames from the OES/GPU pipeline already have skin-smoothing + temporal
            // denoise baked in (FaceWarpRenderer, Stage 2/3) — running this CPU
            // bilateral filter on top of that double-smoothed and looked soft/blotchy.
            if (!skipSmoothing) {
                val smoothed = try {
                    BeautyFilterProcessor.smoothSkin(working, CAPTURE_SMOOTH_STRENGTH)
                } catch (t: Throwable) {
                    working
                }
                if (smoothed !== working) {
                    toRecycle.add(smoothed)
                    working = smoothed
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
        selfie = applyCaptureSmoothing(selfie)
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
            if (!canRebindCamera()) {
                onComplete(false)
                return
            }
            preferCaptureBinding = true
            pendingPhotoFile = file
            pendingPhotoCb = onComplete
            requestPreviewRebind()
            return
        }

        takePictureWithBoundCapture(capture, file, jpegQuality) { ok ->
            onComplete(ok)
            if (ArCameraBridge.currentFilter == FilterType.NONE &&
                !preferVideoBinding &&
                canRebindCamera()
            ) {
                preferCaptureBinding = false
                requestPreviewRebind()
            }
        }
    }

    /**
     * Snapshots the screen-overlay Lottie view's currently-rendered frame
     * (Confetti/Keywords/Matrix/Space Rocket) as a bitmap, so it can be
     * composited into a saved photo/video frame. Must run on the main thread
     * (View drawing) — call this BEFORE handing off to a background executor,
     * never from inside one.
     */
    private fun captureConfettiOverlayFrame(): Bitmap? {
        if (!ArCameraBridge.currentFilter.isScreenOverlay()) return null
        val overlay = ArCameraBridge.confettiOverlay ?: return null
        if (overlay.visibility != View.VISIBLE) return null
        val w = overlay.width
        val h = overlay.height
        if (w <= 0 || h <= 0) return null
        return try {
            val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            overlay.draw(Canvas(bmp))
            bmp
        } catch (_: Exception) {
            null
        }
    }

    /** Draws [confettiFrame] over [base] (scaled to fit), recycling confettiFrame. */
    private fun compositeConfettiOnto(base: Bitmap, confettiFrame: Bitmap?): Bitmap {
        if (confettiFrame == null || confettiFrame.isRecycled) return base
        try {
            val target = if (base.isMutable && base.config == Bitmap.Config.ARGB_8888) {
                base
            } else {
                val copy = base.copy(Bitmap.Config.ARGB_8888, true) ?: return base
                if (copy !== base) base.recycle()
                copy
            }
            val canvas = Canvas(target)
            val dst = RectF(0f, 0f, target.width.toFloat(), target.height.toFloat())
            canvas.drawBitmap(
                confettiFrame,
                null,
                dst,
                Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG),
            )
            return target
        } catch (_: Exception) {
            return base
        } finally {
            if (!confettiFrame.isRecycled) confettiFrame.recycle()
        }
    }

    private fun takePictureWithBoundCapture(
        capture: ImageCapture,
        file: File,
        jpegQuality: Int,
        onComplete: (Boolean) -> Unit,
    ) {
        val activity = ArCameraBridge.hostActivity
        if (activity == null) {
            onComplete(false)
            return
        }
        // Main thread only — must happen before the capture callback, which
        // fires on a background executor where View drawing isn't allowed.
        val confettiFrame = captureConfettiOverlayFrame()
        val executor = analysisExecutor ?: ContextCompat.getMainExecutor(activity)
        try {
            capture.takePicture(
                executor,
                object : ImageCapture.OnImageCapturedCallback() {
                    override fun onCaptureSuccess(image: ImageProxy) {
                        try {
                            var selfie = bakeCapturedImageProxy(image)
                            if (selfie == null || isMostlyEmpty(selfie)) {
                                selfie?.recycle()
                                confettiFrame?.takeIf { !it.isRecycled }?.recycle()
                                onComplete(false)
                                return
                            }
                            selfie = compositeConfettiOnto(selfie, confettiFrame)
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
                        confettiFrame?.takeIf { !it.isRecycled }?.recycle()
                        onComplete(false)
                    }
                },
            )
        } catch (_: Exception) {
            confettiFrame?.takeIf { !it.isRecycled }?.recycle()
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
            alreadySmoothed: Boolean = false,
        ): Boolean {
            return try {
                if (savePhotoBitmapToFile(bitmap, outputFile, quality, maxEdge, skipSmoothing = alreadySmoothed)) {
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

        // OES preview path: grab a fresh GL frame when still bound to OES — already
        // has skin-smoothing + temporal denoise baked in, so skip the CPU pass.
        if (boundToOes) {
            takePhotoFromGl(::deliver) { bmp -> saveBaked(bmp, alreadySmoothed = true) }
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
                !boundToOes
            ) {
                if (simpleHardwareRecorder.isAvailable()) {
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
                // VideoCapture not bound in idle preview — rebind with video, then
                // start. Only reached when NOT on the OES beauty preview (see the
                // !boundToOes guard above) — e.g. a PNG-overlay filter. Normal Mode
                // (boundToOes) always falls through to startGlSurfaceRecording below
                // so the live beauty/color-filter effect actually gets baked into
                // the recorded video — a GPU-shader effect can only be captured by
                // rendering it, not by a plain hardware Recorder.
                preferVideoBinding = true
                pendingHardwareRecordFile = file
                pendingHardwareRecordCb = onResult
                if (canRebindCamera()) {
                    requestPreviewRebind()
                } else {
                    pendingHardwareRecordFile = null
                    pendingHardwareRecordCb = null
                    preferVideoBinding = false
                    startBitmapRecording(file, onResult)
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
            } else if (ArCameraBridge.currentFilter.isScreenOverlay()) {
                // No GL/analysis stream feeds these filters — pull frames
                // ourselves (preview + overlay composited) so the animation
                // actually bakes into the saved video instead of only showing
                // up live.
                startConfettiFramePump()
            }
            scheduleMaxDurationStop()
            onResult(true, null)
        } catch (e: Exception) {
            recording = false
            hardwareRecording = false
            glSurfaceRecording = false
            stopConfettiFramePump()
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
                preferVideoBinding = false
                if (file != null) {
                    lastStoppedPath = file.absolutePath
                    onResult(file.absolutePath, null)
                } else {
                    onResult(null, err ?: "empty_video")
                }
                // Drop VideoCapture so idle preview stream quality returns.
                if (started &&
                    !boundToOes &&
                    canRebindCamera() &&
                    !needsAnalysisUseCase(ArCameraBridge.currentFilter)
                ) {
                    requestPreviewRebind()
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
        stopConfettiFramePump()
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

    @Volatile
    private var confettiFramePumpActive = false

    /**
     * Confetti has no GL/analysis stream of its own — this grabs the live
     * PreviewView frame plus the confetti overlay's current animation frame,
     * composites them, and hands the result to the same [offerRecordingFrameAsync]
     * → [pumpRecordFrame] pipeline everything else uses, so the effect is
     * actually baked into the saved video and not just visible live.
     * [requestConfettiFrame] does the actual work (async where possible); this
     * Runnable only paces it on [CONFETTI_RECORD_INTERVAL_MS].
     */
    private val confettiFrameRunnable = object : Runnable {
        override fun run() {
            if (!confettiFramePumpActive) return
            if (recording && ArCameraBridge.currentFilter.isScreenOverlay()) {
                requestConfettiFrame()
            } else {
                confettiFramePumpActive = false
            }
        }
    }

    private fun startConfettiFramePump() {
        if (confettiFramePumpActive) return
        confettiFramePumpActive = true
        mainHandler.post(confettiFrameRunnable)
    }

    private fun stopConfettiFramePump() {
        confettiFramePumpActive = false
        mainHandler.removeCallbacks(confettiFrameRunnable)
        confettiPixelCopyBusy.set(false)
    }

    private fun scheduleNextConfettiTick() {
        if (confettiFramePumpActive) {
            mainHandler.postDelayed(confettiFrameRunnable, CONFETTI_RECORD_INTERVAL_MS)
        }
    }

    /**
     * Grabs a base frame for the confetti recording composite, preferring an
     * async [PixelCopy] straight off previewView's backing [SurfaceView] (runs
     * on [pixelCopyHandlerThread], never blocks the main thread) over the old
     * `PreviewView.getBitmap()` (a synchronous, main-thread-blocking GPU
     * readback — confirmed the dominant cost behind the overlay+recording lag).
     * Requesting directly at ~[RECORD_PROCESS_EDGE] also means the copy itself
     * moves fewer pixels, on top of not blocking anything.
     *
     * Deliberately does NOT add another concurrent camera stream (that was
     * tried and reverted — it forced the whole camera session into a lower
     * guaranteed-quality stream combination). This only changes *how* the
     * already-existing PreviewView's pixels are read, so camera quality is
     * unaffected either way.
     *
     * Falls back to the old synchronous path if the SurfaceView isn't found
     * (e.g. PreviewView fell back to TextureView) or PixelCopy can't be
     * started, so this can only be as slow as before, never worse.
     */
    private fun requestConfettiFrame() {
        if (!confettiPixelCopyBusy.compareAndSet(false, true)) {
            scheduleNextConfettiTick()
            return
        }
        val previewView = ArCameraBridge.previewView
        val overlay = ArCameraBridge.confettiOverlay
        if (previewView == null || overlay == null ||
            overlay.visibility != View.VISIBLE || overlay.width <= 0 || overlay.height <= 0
        ) {
            confettiPixelCopyBusy.set(false)
            scheduleNextConfettiTick()
            return
        }

        val handler = pixelCopyHandler
        val surfaceView = previewView.getChildAt(0) as? SurfaceView
        val surface = surfaceView?.holder?.surface
        if (handler != null && surface != null && surface.isValid) {
            val srcW = previewView.width.coerceAtLeast(1)
            val srcH = previewView.height.coerceAtLeast(1)
            val scale = kotlin.math.min(1f, RECORD_PROCESS_EDGE.toFloat() / kotlin.math.max(srcW, srcH))
            val dstW = (srcW * scale).toInt().coerceAtLeast(1)
            val dstH = (srcH * scale).toInt().coerceAtLeast(1)
            val dest = try {
                Bitmap.createBitmap(dstW, dstH, Bitmap.Config.ARGB_8888)
            } catch (_: Exception) {
                null
            }
            if (dest != null) {
                try {
                    PixelCopy.request(
                        surfaceView,
                        dest,
                        { result ->
                            if (result == PixelCopy.SUCCESS) {
                                mainHandler.post { finishConfettiFrame(overlay, dest) }
                            } else {
                                dest.recycle()
                                confettiPixelCopyBusy.set(false)
                                scheduleNextConfettiTick()
                            }
                        },
                        handler,
                    )
                    return
                } catch (_: Exception) {
                    dest.recycle()
                    // Falls through to the synchronous fallback below.
                }
            }
        }

        val raw = try {
            previewView.bitmap
        } catch (_: Exception) {
            null
        }
        if (raw == null) {
            confettiPixelCopyBusy.set(false)
            scheduleNextConfettiTick()
            return
        }
        finishConfettiFrame(overlay, raw)
    }

    /** Runs on the main thread — [LottieAnimationView.draw] requires it. */
    private fun finishConfettiFrame(overlay: LottieAnimationView, base: Bitmap) {
        val composed = composeConfettiOverlay(overlay, base)
        composed?.let { offerRecordingFrameAsync(it, recycleSourceAlways = true) }
        confettiPixelCopyBusy.set(false)
        scheduleNextConfettiTick()
    }

    private fun composeConfettiOverlay(overlay: LottieAnimationView, raw: Bitmap): Bitmap? {
        return try {
            // Shrink before the Lottie draw below, not after: overlay.draw(canvas)'s
            // cost scales with the canvas pixel area, and frameForRecording() rescales
            // this whole composite down to RECORD_PROCESS_EDGE anyway once it reaches
            // the background executor. (The PixelCopy path above already requests
            // roughly this size, so this is usually a no-op there — still matters
            // for the synchronous previewView.bitmap() fallback.)
            val base = try {
                val shrunk = ImageProxyBitmapUtils.scaleToMaxDimension(raw, RECORD_PROCESS_EDGE, filter = true)
                if (shrunk !== raw) raw.recycle()
                shrunk
            } catch (_: Exception) {
                raw
            }
            val target = if (base.isMutable && base.config == Bitmap.Config.ARGB_8888) {
                base
            } else {
                val copy = base.copy(Bitmap.Config.ARGB_8888, true) ?: return base
                base.recycle()
                copy
            }
            val canvas = Canvas(target)
            if (target.width != overlay.width || target.height != overlay.height) {
                canvas.save()
                canvas.scale(
                    target.width.toFloat() / overlay.width,
                    target.height.toFloat() / overlay.height,
                )
                overlay.draw(canvas)
                canvas.restore()
            } else {
                overlay.draw(canvas)
            }
            target
        } catch (_: Exception) {
            raw
        }
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
        var scaled = try {
            ImageProxyBitmapUtils.scaleToMaxDimension(source, maxEdge, filter = true)
        } catch (_: Exception) {
            source
        }
        scaled = applyCaptureSmoothing(scaled, keep = source)

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

    /**
     * Bakes [CAPTURE_SMOOTH_STRENGTH] bilateral smoothing into a captured photo or
     * video frame. Recycles [bitmap] when a new (smoothed) bitmap is produced,
     * unless it's the same instance as [keep] (a bitmap owned by the caller, e.g.
     * the original un-scaled source frame, that must survive this call).
     */
    private fun applyCaptureSmoothing(bitmap: Bitmap, keep: Bitmap? = null): Bitmap {
        val smoothed = try {
            BeautyFilterProcessor.smoothSkin(bitmap, CAPTURE_SMOOTH_STRENGTH)
        } catch (_: Throwable) {
            bitmap
        }
        if (smoothed !== bitmap && bitmap !== keep && !bitmap.isRecycled) {
            try {
                bitmap.recycle()
            } catch (_: Exception) {
            }
        }
        return smoothed
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

    /**
     * Live Preview — production ISP tuning via Camera2Interop (Preview use case only).
     * Normal Mode goal: bright, sharp, low-noise vs stock camera (no beauty shaders).
     *
     * Every option here is set via [Camera2Interop.Extender] on the Preview UseCase
     * builder specifically — scoped to Preview's own repeating request, so it cannot
     * bleed into ImageCapture's still JPEG request. That distinction used to be lost:
     * [applyPreviewLook] previously *upgraded* noise/edge mode (and re-asserted
     * CONTROL_CAPTURE_INTENT_PREVIEW) via [Camera2CameraControl.setCaptureRequestOptions],
     * which applies camera-wide — to every capture request the camera device services,
     * including still photos. Still captures ended up shot with PREVIEW capture intent
     * plus HIGH_QUALITY noise reduction instead of the HAL's normal STILL_CAPTURE
     * pipeline, which read as dark, over-smoothed photos. Best noise/edge mode is
     * resolved here instead, up front from [cameraProvider]'s characteristics for the
     * lens we're about to bind, before build — no post-bind camera-wide override needed.
     */
    @OptIn(ExperimentalCamera2Interop::class)
    private fun buildLivePreview(
        displayRotation: Int,
        cameraProvider: ProcessCameraProvider,
    ): Preview {
        val resolutionSelector = ResolutionSelector.Builder()
            .setAspectRatioStrategy(
                AspectRatioStrategy(
                    AspectRatio.RATIO_4_3,
                    AspectRatioStrategy.FALLBACK_RULE_AUTO,
                ),
            )
            .setResolutionStrategy(
                ResolutionStrategy(
                    Size(PREVIEW_TARGET_WIDTH, PREVIEW_TARGET_HEIGHT),
                    ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER,
                ),
            )
            .build()

        val builder = Preview.Builder()
            .setResolutionSelector(resolutionSelector)
            .setTargetRotation(displayRotation)

        val selector = if (ArCameraBridge.isFrontCamera) {
            CameraSelector.DEFAULT_FRONT_CAMERA
        } else {
            CameraSelector.DEFAULT_BACK_CAMERA
        }
        val previewCameraInfo = try {
            selector.filter(cameraProvider.availableCameraInfos).firstOrNull()
        } catch (t: Throwable) {
            null
        }
        val noiseMode = previewCameraInfo?.let { bestNoiseReductionMode(it) }
            ?: CaptureRequest.NOISE_REDUCTION_MODE_FAST
        val edgeMode = previewCameraInfo?.let { bestEdgeMode(it) }
            ?: CaptureRequest.EDGE_MODE_FAST

        Camera2Interop.Extender(builder)
            .setCaptureRequestOption(
                CaptureRequest.CONTROL_MODE,
                CaptureRequest.CONTROL_MODE_AUTO,
            )
            // PREVIEW intent (not VIDEO_RECORD) — matches the 3A/ISP tuning stock
            // camera apps use for the live viewfinder. VIDEO_RECORD intent biases AE
            // toward slower, flicker-safe transitions and can read as sluggish/dim
            // next to a native viewfinder. Scoped to this Preview UseCase only — see
            // the class doc above for why that scoping matters.
            .setCaptureRequestOption(
                CaptureRequest.CONTROL_CAPTURE_INTENT,
                CaptureRequest.CONTROL_CAPTURE_INTENT_PREVIEW,
            )
            .setCaptureRequestOption(
                CaptureRequest.CONTROL_AE_MODE,
                CaptureRequest.CONTROL_AE_MODE_ON,
            )
            .setCaptureRequestOption(
                CaptureRequest.CONTROL_AF_MODE,
                CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE,
            )
            .setCaptureRequestOption(
                CaptureRequest.CONTROL_AWB_MODE,
                CaptureRequest.CONTROL_AWB_MODE_AUTO,
            )
            .setCaptureRequestOption(
                CaptureRequest.CONTROL_AE_EXPOSURE_COMPENSATION,
                PREVIEW_EXPOSURE_BIAS,
            )
            .setCaptureRequestOption(
                CaptureRequest.NOISE_REDUCTION_MODE,
                noiseMode,
            )
            .setCaptureRequestOption(
                CaptureRequest.HOT_PIXEL_MODE,
                CaptureRequest.HOT_PIXEL_MODE_HIGH_QUALITY,
            )
            .setCaptureRequestOption(
                CaptureRequest.EDGE_MODE,
                edgeMode,
            )

        return builder.build()
    }

    /**
     * Strongest noise reduction the device advertises. HIGH_QUALITY gives the
     * cleanest result (fewer visible grain "dots") and is preferred even though
     * it's the mode documented as possibly reducing frame rate — noise was the
     * user-visible complaint, not preview smoothness. Falls back to MINIMAL, then
     * the always-guaranteed FAST if neither richer mode is supported.
     */
    private fun bestNoiseReductionMode(info: CameraInfo): Int {
        val modes = try {
            Camera2CameraInfo.from(info).getCameraCharacteristic(
                CameraCharacteristics.NOISE_REDUCTION_AVAILABLE_NOISE_REDUCTION_MODES,
            )
        } catch (t: Throwable) {
            null
        }
        return when {
            modes?.contains(CaptureRequest.NOISE_REDUCTION_MODE_HIGH_QUALITY) == true ->
                CaptureRequest.NOISE_REDUCTION_MODE_HIGH_QUALITY
            modes?.contains(CaptureRequest.NOISE_REDUCTION_MODE_MINIMAL) == true ->
                CaptureRequest.NOISE_REDUCTION_MODE_MINIMAL
            else -> CaptureRequest.NOISE_REDUCTION_MODE_FAST
        }
    }

    /**
     * Strongest edge/sharpening mode the device advertises. FAST's more aggressive
     * sharpening amplifies sensor grain into visible speckle on top of it — HIGH_QUALITY
     * sharpens less naively and reads as cleaner paired with [bestNoiseReductionMode].
     */
    private fun bestEdgeMode(info: CameraInfo): Int {
        val modes = try {
            Camera2CameraInfo.from(info).getCameraCharacteristic(
                CameraCharacteristics.EDGE_AVAILABLE_EDGE_MODES,
            )
        } catch (t: Throwable) {
            null
        }
        return when {
            modes?.contains(CaptureRequest.EDGE_MODE_HIGH_QUALITY) == true ->
                CaptureRequest.EDGE_MODE_HIGH_QUALITY
            else -> CaptureRequest.EDGE_MODE_FAST
        }
    }

    /**
     * Variable AE target-FPS range biased toward smooth motion. A fixed 30-30 range
     * forces a short exposure time in low light (extra ISO gain -> darker/grainier),
     * but letting AE sink all the way to a device's lowest supported floor (seen as
     * low as 14fps on one test device) makes motion visibly juddery/stuttery, which
     * reads as "not smooth" — a worse trade than the noise it's meant to fix. Cap the
     * floor at ~20fps so AE gets a little low-light headroom without going choppy,
     * matching how short-form-video camera UIs (TikTok/Instagram) behave: they stay
     * close to 30fps and accept more grain in genuinely dark scenes rather than
     * dropping frame rate.
     */
    private fun bestPreviewFpsRange(info: CameraInfo): Range<Int> {
        val ranges = try {
            Camera2CameraInfo.from(info).getCameraCharacteristic(
                CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES,
            )
        } catch (t: Throwable) {
            null
        }
        if (ranges.isNullOrEmpty()) return Range(24, 30)
        return ranges.filter { it.upper in 24..30 && it.lower >= 20 }.minByOrNull { it.lower }
            ?: ranges.firstOrNull { it.lower == it.upper && it.upper in 24..30 }
            ?: ranges.filter { it.upper in 24..30 }.maxByOrNull { it.lower }
            ?: Range(30, 30)
    }

    /** Apply EV + AE FPS range after bindToLifecycle (device-clamped, camera-wide). */
    @OptIn(ExperimentalCamera2Interop::class)
    private fun applyPreviewLook(bound: Camera) {
        try {
            val exposure = bound.cameraInfo.exposureState
            if (exposure.isExposureCompensationSupported) {
                val range = exposure.exposureCompensationRange
                // Convert the target EV bias to a raw index using this device's actual
                // step size (1/3, 1/2, or 1 EV all exist in the wild) — a fixed raw
                // index like "1" can be a negligible +0.17EV nudge on some devices and
                // a full stop on others, so it can't reliably brighten every phone.
                val step = exposure.exposureCompensationStep.toFloat().let {
                    if (it > 0f) it else 1f
                }
                val rawIndex = Math.round(PREVIEW_EXPOSURE_EV_STOPS / step)
                val index = rawIndex.coerceIn(range.lower, range.upper)
                Log.i(
                    PREVIEW_QUALITY_TAG,
                    "EV range=[${range.lower},${range.upper}] " +
                        "step=${exposure.exposureCompensationStep} " +
                        "applyIndex=$index current=${exposure.exposureCompensationIndex}",
                )
                if (index != exposure.exposureCompensationIndex) {
                    bound.cameraControl.setExposureCompensationIndex(index)
                }
            } else {
                Log.i(PREVIEW_QUALITY_TAG, "EV compensation not supported on this camera")
            }
        } catch (t: Throwable) {
            Log.w(PREVIEW_QUALITY_TAG, "applyPreviewLook exposure failed", t)
        }

        // NOTE: noise/edge mode and capture intent are intentionally NOT re-asserted
        // here via Camera2CameraControl — that applies camera-wide (including to
        // ImageCapture's still JPEG request) and was why photos were coming out dark
        // and over-smoothed. Preview.Builder's own Camera2Interop.Extender in
        // [buildLivePreview] already sets the right per-device modes, scoped only to
        // the Preview stream. AE FPS range below is a legitimate camera-wide 3A
        // setting (there's no "preview-only" framerate), so that one stays.
        try {
            val camera2 = Camera2CameraControl.from(bound.cameraControl)
            val fpsRange = bestPreviewFpsRange(bound.cameraInfo)
            Log.i(PREVIEW_QUALITY_TAG, "preview AE target fps range=$fpsRange")
            camera2.addCaptureRequestOptions(
                CaptureRequestOptions.Builder()
                    .setCaptureRequestOption(
                        CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE,
                        fpsRange,
                    )
                    .build(),
            )
        } catch (t: Throwable) {
            Log.w(PREVIEW_QUALITY_TAG, "fps range apply skipped", t)
        }
    }

    /**
     * Backs the front-camera preview out to [FRONT_ZOOM_OUT_RATIO] so selfie mode
     * doesn't feel as tightly cropped. No-op on devices whose front lens can't zoom
     * under 1.0x (target clamps into the reported range, so it becomes 1.0 there —
     * i.e. unchanged) and on the back camera, which is left at its default 1.0x.
     */
    private fun applyFrontZoomOut(bound: Camera) {
        if (!ArCameraBridge.isFrontCamera) return
        try {
            val zoomState = bound.cameraInfo.zoomState.value ?: return
            val target = FRONT_ZOOM_OUT_RATIO.coerceIn(zoomState.minZoomRatio, zoomState.maxZoomRatio)
            if (target < zoomState.zoomRatio) {
                bound.cameraControl.setZoomRatio(target)
                Log.i(PREVIEW_QUALITY_TAG, "front zoom-out applied ratio=$target")
            }
        } catch (t: Throwable) {
            Log.w(PREVIEW_QUALITY_TAG, "front zoom-out failed", t)
        }
    }

    /** PreviewView surface with resolution audit log (actual stream size). */
    private fun attachPreviewSurfaceProvider(preview: Preview, previewView: PreviewView) {
        val viewProvider = previewView.surfaceProvider
        preview.setSurfaceProvider { request ->
            val res = request.resolution
            Log.i(
                PREVIEW_QUALITY_TAG,
                "Preview SurfaceRequest ${res.width}x${res.height} " +
                    "view=${previewView.width}x${previewView.height} " +
                    "mode=${previewView.implementationMode} scale=${previewView.scaleType}",
            )
            viewProvider.onSurfaceRequested(request)
        }
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
            // Keep camera buffer aspect (e.g. 1440x1080 → scaled). Do NOT force
            // phone screen aspect — that stretched/squashed faces.
            // CAPTURE_MAX_EDGE (not a lower "warm buffer" cap like the old 960) —
            // this OES texture is now also the full-res live viewfinder for Normal
            // Mode (Stage 1), not just a background photo-capture buffer, so it
            // needs to match the sharpness Normal Mode already had.
            val maxBuf = CAPTURE_MAX_EDGE
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
            val pngFast = ArCameraBridge.currentFilter.isPngOverlay()
            val analysisTarget = if (pngFast) {
                Size(PNG_ANALYSIS_WIDTH, PNG_ANALYSIS_HEIGHT)
            } else {
                Size(ANALYSIS_WIDTH, ANALYSIS_HEIGHT)
            }

            val preview = buildLivePreview(displayRotation, cameraProvider)

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
                applyPreviewLook(bound)
                applyFrontZoomOut(bound)
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

                // Normal Mode only — small background analysis stream feeding the
                // landmark-rasterized skin mask (see processSkinMaskFrame /
                // buildFaceSkinMaskBitmap). Attempted first; if this 3rd concurrent
                // stream isn't supported on a given device, the catch block below
                // falls back to the proven 2-stream (Preview + ImageCapture) bind.
                val wantSkinMask = ArCameraBridge.currentFilter == FilterType.NONE
                val skinMaskAnalysis = if (wantSkinMask) {
                    ImageAnalysis.Builder()
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                        .setTargetResolution(Size(SKIN_MASK_ANALYSIS_EDGE, SKIN_MASK_ANALYSIS_EDGE))
                        .setTargetRotation(displayRotation)
                        .build()
                        .also { a -> a.setAnalyzer(executor) { imageProxy -> processSkinMaskFrame(imageProxy) } }
                } else {
                    null
                }
                imageAnalysis = skinMaskAnalysis

                try {
                    val bound = if (skinMaskAnalysis != null) {
                        cameraProvider.bindToLifecycle(
                            lifecycleOwner,
                            selector,
                            preview,
                            capture,
                            skinMaskAnalysis,
                        )
                    } else {
                        cameraProvider.bindToLifecycle(
                            lifecycleOwner,
                            selector,
                            preview,
                            capture,
                        )
                    }
                    applyTorchAfterBind(bound)
                    android.util.Log.i(
                        "ArCameraOES",
                        "bindCamera: OES bind OK skinMask=${skinMaskAnalysis != null} " +
                            "cost=${android.os.SystemClock.elapsedRealtime() - bindStart}ms " +
                            "+${ArCameraBridge.oesDiagElapsedMs()}ms",
                    )
                    analysisUseCaseBound = skinMaskAnalysis != null
                    pngFastAnalysisBound = false
                    videoUseCaseBound = false
                    videoCapture = null
                    simpleHardwareRecorder.attach(null)
                    scheduleOesPhotoWarmup(glView)
                } catch (_: Exception) {
                    try {
                        cameraProvider.unbindAll()
                        imageAnalysis = null
                        applyTorchAfterBind(
                            cameraProvider.bindToLifecycle(
                                lifecycleOwner,
                                selector,
                                preview,
                                capture,
                            ),
                        )
                        analysisUseCaseBound = false
                        android.util.Log.w(
                            "ArCameraOES",
                            "bindCamera: OES bind fallback without skin-mask analysis " +
                                "+${ArCameraBridge.oesDiagElapsedMs()}ms",
                        )
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
                }
                switchingCamera = false
                return@addListener
            }

            boundToOes = false
            glView?.setOesEnabled(false)

            val filter = ArCameraBridge.currentFilter
            val needAnalysis = needsAnalysisUseCase(filter)
            val needVideo = preferVideoBinding
            // Normal idle: Preview ONLY. Capture binds on shutter; Analysis on effects; Video on record.
            val needCapture = preferCaptureBinding || needAnalysis || needVideo
            val capture = if (needCapture) {
                buildImageCapture(displayRotation).also { imageCapture = it }
            } else {
                imageCapture = null
                null
            }

            attachPreviewSurfaceProvider(preview, previewView)

            val analysis = if (needAnalysis) {
                ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                    .setTargetResolution(analysisTarget)
                    .setTargetRotation(displayRotation)
                    .build()
                    .also { a ->
                        a.setAnalyzer(executor) { imageProxy ->
                            processImage(imageProxy, faceOverlay, activity)
                        }
                    }
            } else {
                null
            }
            imageAnalysis = analysis

            val hwVideo = if (needVideo) {
                val recorder = Recorder.Builder()
                    .setQualitySelector(
                        QualitySelector.fromOrderedList(
                            listOf(Quality.HD, Quality.SD, Quality.LOWEST),
                            FallbackStrategy.lowerQualityOrHigherThan(Quality.SD),
                        ),
                    )
                    .build()
                VideoCapture.Builder(recorder)
                    .setMirrorMode(MirrorMode.MIRROR_MODE_ON_FRONT_ONLY)
                    .build()
                    .also { it.targetRotation = displayRotation }
            } else {
                null
            }

            fun bindCombo(
                withAnalysis: Boolean,
                withVideo: Boolean,
                withCapture: Boolean,
                withPngEffect: Boolean,
            ): Boolean {
                return try {
                    val useAnalysis = withAnalysis && analysis != null
                    val useVideo = withVideo && hwVideo != null
                    val useCapture = withCapture && capture != null
                    if (withPngEffect && useAnalysis && useVideo && useCapture && pngFast) {
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
                            .addUseCase(analysis!!)
                            .addUseCase(capture!!)
                            .addUseCase(hwVideo!!)
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
                        val cases = buildList {
                            add(preview)
                            if (useAnalysis) add(analysis!!)
                            if (useCapture) add(capture!!)
                            if (useVideo) add(hwVideo!!)
                        }
                        // Tie VideoCapture/ImageCapture's crop to the same field of
                        // view as Preview. Without a shared ViewPort, CameraX picks
                        // each use case's resolution independently — e.g. the
                        // Recorder's own 16:9 quality target vs. the full-screen
                        // PreviewView — so recorded video/photos end up framed
                        // differently than what was actually shown live.
                        val viewPort = if (useVideo || useCapture) {
                            try {
                                previewView.getViewPort(displayRotation)
                            } catch (_: Exception) {
                                null
                            }
                        } else {
                            null
                        }
                        val bound = if (viewPort != null) {
                            val groupBuilder = UseCaseGroup.Builder().setViewPort(viewPort)
                            cases.forEach { groupBuilder.addUseCase(it) }
                            cameraProvider.bindToLifecycle(
                                lifecycleOwner,
                                selector,
                                groupBuilder.build(),
                            )
                        } else {
                            cameraProvider.bindToLifecycle(
                                lifecycleOwner,
                                selector,
                                *cases.toTypedArray(),
                            )
                        }
                        applyTorchAfterBind(bound)
                    }
                    analysisUseCaseBound = useAnalysis
                    pngFastAnalysisBound = useAnalysis && pngFast
                    if (useVideo) {
                        videoCapture = hwVideo
                        simpleHardwareRecorder.attach(hwVideo)
                        videoUseCaseBound = true
                    } else {
                        videoCapture = null
                        simpleHardwareRecorder.attach(null)
                        videoUseCaseBound = false
                    }
                    if (!useCapture) {
                        imageCapture = null
                    }
                    true
                } catch (_: Exception) {
                    false
                }
            }

            try {
                val ok = when {
                    needAnalysis && needVideo && pngFast ->
                        bindCombo(true, true, true, withPngEffect = true) ||
                            bindCombo(true, true, true, withPngEffect = false)
                    needAnalysis && needVideo ->
                        bindCombo(true, true, true, withPngEffect = false)
                    needAnalysis ->
                        bindCombo(true, false, true, withPngEffect = false)
                    needVideo ->
                        bindCombo(false, true, true, withPngEffect = false)
                    needCapture ->
                        bindCombo(false, false, true, withPngEffect = false)
                    else ->
                        // Sharpest Normal Mode path: Preview use case alone.
                        bindCombo(false, false, false, withPngEffect = false)
                }
                if (!ok) {
                    cameraProvider.unbindAll()
                    applyTorchAfterBind(
                        cameraProvider.bindToLifecycle(
                            lifecycleOwner,
                            selector,
                            preview,
                        ),
                    )
                    analysisUseCaseBound = false
                    pngFastAnalysisBound = false
                    videoCapture = null
                    simpleHardwareRecorder.attach(null)
                    videoUseCaseBound = false
                    imageCapture = null
                }
                Log.i(
                    PREVIEW_QUALITY_TAG,
                    "bind done filter=$filter analysis=$analysisUseCaseBound " +
                        "video=$videoUseCaseBound capture=${imageCapture != null} " +
                        "impl=${previewView.implementationMode}",
                )
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
                    analysisUseCaseBound = false
                    pngFastAnalysisBound = false
                    videoCapture = null
                    simpleHardwareRecorder.attach(null)
                    videoUseCaseBound = false
                    imageCapture = null
                } catch (_: Exception) {
                    camera = null
                    imageCapture = null
                    analysisUseCaseBound = false
                    pngFastAnalysisBound = false
                    videoUseCaseBound = false
                }
            } finally {
                switchingCamera = false
                flushPendingHardwareRecordStart()
                flushPendingPhotoCapture()
            }
        }, ContextCompat.getMainExecutor(activity))
    }

    private fun flushPendingPhotoCapture() {
        val cb = pendingPhotoCb ?: return
        val file = pendingPhotoFile
        pendingPhotoCb = null
        pendingPhotoFile = null
        val capture = imageCapture
        if (file == null || capture == null) {
            preferCaptureBinding = false
            cb(false)
            return
        }
        takePictureWithBoundCapture(capture, file, 95) { ok ->
            cb(ok)
            preferCaptureBinding = false
            if (ArCameraBridge.currentFilter == FilterType.NONE &&
                !preferVideoBinding &&
                canRebindCamera()
            ) {
                requestPreviewRebind()
            }
        }
    }

    private fun flushPendingHardwareRecordStart() {
        val cb = pendingHardwareRecordCb ?: return
        val file = pendingHardwareRecordFile
        pendingHardwareRecordCb = null
        pendingHardwareRecordFile = null
        val activity = ArCameraBridge.hostActivity
        if (file == null || activity == null) {
            preferVideoBinding = false
            cb(false, "no_activity")
            return
        }
        if (simpleHardwareRecorder.isAvailable()) {
            simpleHardwareRecorder.start(activity, file) { ok, err ->
                if (ok) {
                    recording = true
                    hardwareRecording = true
                    glSurfaceRecording = false
                    scheduleMaxDurationStop()
                    cb(true, null)
                } else {
                    preferVideoBinding = false
                    startBitmapRecording(file, cb)
                }
            }
        } else {
            preferVideoBinding = false
            startBitmapRecording(file, cb)
        }
    }

    /**
     * Normal Mode's dedicated skin-mask analyzer (separate from [processImage],
     * which stays untouched/unused while boundToOes). Landmark-based — the ML
     * segmentation model (FaceSegmenterHelper) was retired after it caused an
     * app crash when running alongside face-landmark detection (two concurrent
     * MediaPipe graphs fighting for native resources); this uses the single
     * face-landmark model already proven stable elsewhere in the app instead,
     * rasterizing a face-oval-minus-features mask on the CPU (cheap, no 2nd ML
     * model). Throttled + drops frames while a previous run is still going, so
     * this can't pile up behind a slow device.
     */
    private fun processSkinMaskFrame(imageProxy: ImageProxy) {
        skinMaskFrameCounter++
        val shouldRun = skinMaskFrameCounter % SKIN_MASK_DETECT_EVERY == 0
        if (!shouldRun || !skinMaskBusy.compareAndSet(false, true)) {
            imageProxy.close()
            return
        }

        // imageProxy is read and closed here, exactly once, before any further
        // processing — avoids a double-close if something below throws.
        val rotation = imageProxy.imageInfo.rotationDegrees
        val rawBitmap = try {
            ImageProxyBitmapUtils.toBitmap(imageProxy)
        } catch (_: Exception) {
            null
        }
        imageProxy.close()

        if (rawBitmap == null) {
            skinMaskBusy.set(false)
            return
        }

        try {
            // Oriented but NOT mirrored — matches FaceCoordinateMapper.toWarpUv's
            // convention (mirror applied at sample time in the shader, not baked
            // into the bitmap), same as how landmark frames are already prepared
            // for the proven nose-warp feature.
            val oriented = try {
                ImageProxyBitmapUtils.orientScaled(rawBitmap, rotation, false, SKIN_MASK_ANALYSIS_EDGE)
            } catch (_: Exception) {
                rawBitmap
            }
            if (oriented !== rawBitmap && !rawBitmap.isRecycled) rawBitmap.recycle()

            try {
                val landmarker = FaceLandmarkerHolder.get()
                val snapshot = if (landmarker != null) {
                    try {
                        landmarker.detect(oriented)?.let { result ->
                            FaceLandmarkMapper.fromResult(result, oriented.width, oriented.height)
                        }
                    } catch (t: Throwable) {
                        null
                    }
                } else {
                    null
                }
                val maskBitmap = if (snapshot != null) {
                    try {
                        buildFaceSkinMaskBitmap(snapshot, SKIN_MASK_ANALYSIS_EDGE)
                    } catch (t: Throwable) {
                        null
                    }
                } else {
                    null
                }
                if (maskBitmap != null) {
                    ArCameraBridge.warpGlView?.updateSkinMask(maskBitmap)
                }
            } finally {
                if (!oriented.isRecycled) oriented.recycle()
            }
        } finally {
            skinMaskBusy.set(false)
        }
    }

    /**
     * Rasterizes a skin-only mask (ALPHA_8, 255=skin) from face landmarks: the
     * face oval, minus eyes/eyebrows/lips (cut out with a small safety margin so
     * smoothing can't bleed onto those features). Cheap Canvas fill — no ML
     * inference — safe to run every throttled analysis frame.
     */
    private fun buildFaceSkinMaskBitmap(snapshot: FaceLandmarkSnapshot, size: Int): Bitmap {
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ALPHA_8)
        val canvas = Canvas(bmp)
        val scaleX = size / snapshot.imageWidth.toFloat()
        val scaleY = size / snapshot.imageHeight.toFloat()
        val landmarks = snapshot.landmarks

        // Genuinely soft edges (not just anti-aliasing) — a hard-edged mask is
        // invisible for a gentle blur (smoothing), but any stronger effect
        // (whiten/brighten) makes its exact shape visible as an ugly patch. Blur
        // radius scales with mask resolution so it stays soft after upscaling to
        // full screen.
        val blurRadius = size * 0.06f

        fun pathFor(indices: IntArray, expand: Float): Path {
            val path = Path()
            val cx = indices.sumOf { landmarks[it].x.toDouble() }.toFloat() / indices.size
            val cy = indices.sumOf { landmarks[it].y.toDouble() }.toFloat() / indices.size
            indices.forEachIndexed { i, idx ->
                val p = landmarks[idx]
                val x = (cx + (p.x - cx) * expand) * scaleX
                val y = (cy + (p.y - cy) * expand) * scaleY
                if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
            }
            path.close()
            return path
        }

        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.FILL
            maskFilter = BlurMaskFilter(blurRadius, BlurMaskFilter.Blur.NORMAL)
        }
        canvas.drawPath(pathFor(MediaPipeLandmarkIndices.FACE_OVAL, 1f), fillPaint)

        val clearPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.TRANSPARENT
            style = Paint.Style.FILL
            xfermode = PorterDuffXfermode(PorterDuff.Mode.CLEAR)
            maskFilter = BlurMaskFilter(blurRadius * 0.8f, BlurMaskFilter.Blur.NORMAL)
        }
        // Expanded ~30-40% around each feature's own center — soft safety margin
        // so eyes/eyebrows/lips (and skin right around them) resist smoothing.
        canvas.drawPath(pathFor(MediaPipeLandmarkIndices.LEFT_EYE, 1.4f), clearPaint)
        canvas.drawPath(pathFor(MediaPipeLandmarkIndices.RIGHT_EYE, 1.4f), clearPaint)
        canvas.drawPath(pathFor(MediaPipeLandmarkIndices.LEFT_EYEBROW, 1.3f), clearPaint)
        canvas.drawPath(pathFor(MediaPipeLandmarkIndices.RIGHT_EYEBROW, 1.3f), clearPaint)
        canvas.drawPath(pathFor(MediaPipeLandmarkIndices.LIPS_OUTER, 1.3f), clearPaint)

        return bmp
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
