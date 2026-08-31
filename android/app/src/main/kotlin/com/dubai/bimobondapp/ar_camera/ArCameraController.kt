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
import android.graphics.Rect
import android.graphics.RectF
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CaptureRequest
import android.media.MediaCodec
import android.media.MediaFormat
import android.os.Handler
import android.os.Looper
import android.util.Range
import android.util.Size
import android.os.HandlerThread
import android.view.Surface
import android.view.TextureView
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
import androidx.camera.core.DynamicRange
import androidx.camera.core.FocusMeteringAction
import androidx.camera.core.SurfaceOrientedMeteringPointFactory
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.ImageProxy
import androidx.camera.core.MirrorMode
import androidx.camera.core.Preview
import androidx.camera.core.UseCase
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
import com.airbnb.lottie.LottieComposition
import com.airbnb.lottie.LottieDrawable
import com.airbnb.lottie.RenderMode
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
    /**
     * Live Preview target (9:16 portrait) — matches tall phone / TikTok FOV.
     *
     * This stream is the ceiling on recorded and captured quality, not just on
     * what the viewfinder shows: the OES pipeline records and photographs from
     * this same texture. At 1080x1920 the portrait frame cropped to a tall phone
     * aspect left only ~851px of recorded width, below 1080p.
     *
     * Two higher targets were tried and both hit the same real limit: with the
     * skin-mask analysis stream also bound (Normal Mode's actual recording
     * condition, not the cold-open preview-only bind), CameraX silently drops
     * back to 1920x1080 regardless of what's requested — confirmed via the
     * "supported preview (SurfaceTexture) sizes" log ([logSupportedPreviewSizes])
     * showing 3072x1728 is on this device's list, yet "bindPreviewToOes cam=..."
     * during an actual recording still read 1920x1080. This is a genuine Camera2
     * guaranteed-stream-combination cap for 2+ concurrent streams on this chip,
     * not a config mistake — asking higher only pays for a resolution search
     * that gets discarded. 1080p is this device's real multi-stream ceiling; the
     * fix for reaching a full 1080x1920 *recording* despite the crop is in
     * [startSurfaceRecording]'s encoder-size calculation, not here.
     *
     * Note this is passed to CameraX in sensor/landscape order (see
     * [buildLivePreview]) — width/height here are the portrait orientation.
     */
    private const val PREVIEW_TARGET_WIDTH = 1080
    private const val PREVIEW_TARGET_HEIGHT = 1920

    /** Landmarks / distortion only — keep low so Preview stream stays sharp. */
    private const val ANALYSIS_WIDTH = 640
    private const val ANALYSIS_HEIGHT = 480
    /** Analysis while PNG stickers active. Photos use ImageCapture (unchanged). */
    private const val PNG_ANALYSIS_WIDTH = 480
    private const val PNG_ANALYSIS_HEIGHT = 640

    /** Fallback raw EV index used only for the pre-bind builder (device step unknown yet). */
    private const val PREVIEW_EXPOSURE_BIAS = 0

    /**
     * Front gets a mild positive EV so selfies open up toward TikTok brightness.
     * Back stays slightly negative so the brighter rear sensor does not wash out.
     */
    private const val PREVIEW_EXPOSURE_EV_STOPS = 0.55f
    private const val PREVIEW_EXPOSURE_EV_STOPS_BACK = -0.35f

    /**
     * Front-camera zoom ratio applied on bind. Selfie lenses/HAL 1.0x defaults are
     * often pre-cropped tighter than the sensor's true FOV; pulling under 1.0 backs
     * the frame out toward TikTok-style head+shoulders coverage. Clamped to the
     * device's actual supported range in [applyFrontZoomOut] — devices whose
     * minimum is already 1.0 (most single-lens front cameras) are left untouched
     * and rely on [FaceWarpRenderer]'s software wide-zoom instead.
     */
    private const val FRONT_ZOOM_OUT_RATIO = 0.75f

    /** How many times a failed camera-provider resolution is retried before degrading. */
    private const val CAMERA_INIT_MAX_ATTEMPTS = 3

    /** Base backoff between those retries; multiplied by the attempt number. */
    private const val CAMERA_INIT_RETRY_MS = 400L

    /**
     * Bilateral-filter smoothing strength baked into captured photos and recorded
     * video frames (see [BeautyFilterProcessor.smoothSkin]). Kept light — this
     * stacks on top of the HAL's own still-capture noise reduction (now correctly
     * STILL_CAPTURE-intent quality processing, not leaked-in preview settings — see
     * [buildLivePreview]), so it only needs to nudge things further, not do the
     * heavy lifting itself. Live viewfinder preview is untouched; this only bakes
     * into saved media.
     *
     * Lowered from 0.18 once [buildImageCapture] switched to
     * CAPTURE_MODE_MAXIMIZE_QUALITY: the HAL's own still pipeline now does real
     * multi-frame denoising, so this pass was mostly costing fine detail rather
     * than removing noise — part of the "photos look dull" complaint. Raise it
     * again if skin reads as too noisy.
     */
    private const val CAPTURE_SMOOTH_STRENGTH = 0.10f

    /**
     * How long [onHostResume] waits for a replacement OES SurfaceTexture before
     * binding without one. Comfortably longer than a healthy resume, which
     * publishes the new surface in well under this — it only ever fires when the
     * surface genuinely never arrives.
     */
    private const val RESUME_SURFACE_TIMEOUT_MS = 1_200L

    /** Delay before each post-resume frame/visibility health check. */
    private const val RESUME_HEALTH_CHECK_MS = 1_500L

    /**
     * Frames that must have arrived within [RESUME_HEALTH_CHECK_MS] for a resume
     * to count as healthy. A working resume measured ~39 in two seconds and a
     * black one ~5, so this sits far enough below the healthy figure to avoid
     * false alarms on a slow start while still catching a stalled pipeline.
     */
    private const val RESUME_MIN_HEALTHY_FRAMES = 12

    /** Bounded retries so a genuinely broken device falls through to simple mode. */
    private const val RESUME_RECOVERY_ATTEMPTS = 2

    private const val PREVIEW_QUALITY_TAG = "ArPreviewQuality"
    private const val DETECT_MAX_DIMENSION = 384

    /** Skin-mask analysis/rasterize edge — small is fine, it's a soft gating mask.
     *  Lowered from 256: smaller analysis bitmap means less per-detect work
     *  (scaling, MediaPipe inference, mask rasterize) without changing what
     *  the mask visually does — it was already a soft gate, not a precise one. */
    private const val SKIN_MASK_ANALYSIS_EDGE = 144

    /** Run landmark detect + mask rasterize every Nth analysis frame — mask
     *  changes slowly, so a soft gating mask doesn't need every-frame updates.
     *  Raised from 2: MediaPipe inference + bitmap allocation every other
     *  frame is sustained CPU/GC pressure — a likely source of the
     *  continuous lag reported across live preview and recording. Mask,
     *  brightness and smooth all ease/smooth over several frames already, so
     *  a less frequent detect does not make them look stale. */
    private const val SKIN_MASK_DETECT_EVERY = 10
    /** Sticker video encode edge — keep modest so preview stays responsive while recording. */
    private const val PNG_RECORD_EDGE = 640
    private const val PNG_RECORD_INTERVAL_MS = 66L
    private const val GL_MAX_EDGE = 1280

    /**
     * Long-edge ceiling for the OES texture buffer, photo readback and GL video
     * encode.
     *
     * Must not exceed what the Preview stream actually delivers — raising this
     * past the camera's real bound size does not add detail, it just upscales
     * (confirmed twice: 2560 and 3072 both got silently downgraded to 1920x1080
     * by the camera itself once a second stream was bound — see
     * PREVIEW_TARGET_WIDTH/HEIGHT's comment — so the encoder recorded an
     * upscale from a 1080p source instead of genuine extra detail, costing GPU
     * time and file size for nothing). 1920 matches this device's real
     * multi-stream ceiling.
     */
    private const val CAPTURE_MAX_EDGE = 1920
    /**
     * Warm-buffer edge for the OES photo path. This is only the size the GL view
     * keeps a capture ready at between shutter taps — the shutter itself asks for
     * a fresh [CAPTURE_MAX_EDGE] frame (see [takePhotoFromGl]). Kept modest so
     * the occasional warm glReadPixels does not stall the live preview.
     */
    private const val INSTANT_CAPTURE_EDGE = 720

    /**
     * JPEG quality for saved photos. Was 85 on the OES path, which is visibly
     * lossy on skin gradients — the exact "dull/blotchy" look this pipeline is
     * meant to avoid. Photos are written once to a cache file and handed
     * straight to the editor, so the extra bytes cost nothing that matters.
     */
    private const val PHOTO_JPEG_QUALITY = 96

    /**
     * Still-capture target used when several streams are already bound — see
     * [buildImageCapture]'s allowFullSensor. Roughly 6MP: comfortably supported
     * everywhere, and these captures get an overlay composited onto them anyway.
     */
    private const val PHOTO_FALLBACK_WIDTH = 2160
    private const val PHOTO_FALLBACK_HEIGHT = 2880

    /** Fallback quality for the emergency/degraded save paths. */
    private const val INSTANT_JPEG_QUALITY = 90

    /**
     * Whether full-resolution stills go through the beauty shader.
     *
     * On: sensor JPEG is run through the still beauty pass so brightness/polish
     * match the live preview (used when the GL-frame path cannot deliver).
     * Off: raw HAL JPEG — sharper on paper, but darker/duller than the live look.
     */
    private const val STILL_APPLY_BEAUTY = true

    /** How long the shutter waits for a fresh full-resolution GL frame. */
    private const val FULL_RES_GL_WAIT_MS = 220L
    private const val INSTANT_GL_POLL_MS = 96L
    private const val INSTANT_GL_COLD_POLL_MS = 400L
    /** Cold start only — get one warm frame quickly, then idle. */
    private const val OES_PHOTO_WARM_INTERVAL_MS = 120L
    /** Once warm, rarely refresh — continuous readback was stalling live preview. */
    private const val OES_PHOTO_WARM_READY_INTERVAL_MS = 1500L
    private const val RECORD_PROCESS_EDGE = ArFilteredVideoRecorder.MAX_EDGE

    // Matches CAPTURE_MAX_EDGE — Normal Mode video now records from the same
    // full-res OES pipeline the live preview and photos use (Stage 1), so it no
    // longer needs a lower cap than those.
    private const val RECORD_GL_EDGE = CAPTURE_MAX_EDGE
    private const val RECORD_FRAME_INTERVAL_MS = 33L

    // Screen-overlay filters capture recording frames from the OES beauty buffer
    // (or PreviewView fallback) plus a headless composite. Paced to ~30fps
    // (matching RECORD_FRAME_INTERVAL_MS) so the recorded video plays back smoothly
    // in preview and after sending without low-frame-rate stutter.
    private const val CONFETTI_RECORD_INTERVAL_MS = 33L

    private const val NO_FACE_CLEAR_THRESHOLD = 2

    /** Face movement (fraction of frame) that justifies re-metering exposure. */
    /**
     * Face-region AE/AWB metering, off.
     *
     * It works — a backlit face does come out better exposed — but the cost is
     * not worth it. Handing the camera a new metering region makes it converge
     * AE and AWB again, and that convergence is plainly visible: the image washes
     * out, goes soft, and settles over roughly a second. It fires exactly when a
     * person is most likely to be looking at their own face — when the camera
     * opens and the first face is found, whenever they move, and every time a
     * face leaves the frame and comes back — so in practice the artefact showed
     * up constantly while the benefit only mattered in awkward backlight.
     *
     * The camera's own metering handles ordinary lighting perfectly well, and the
     * shader's brighten already lifts an underexposed face without touching the
     * sensor at all. Left in place rather than deleted so it can be reinstated if
     * a smoother way to apply it turns up.
     */
    private const val FACE_METERING_ENABLED = false

    private const val FACE_METER_MOVE_THRESHOLD = 0.08f

    /** Minimum gap between metering requests — AE needs time to converge. */
    private const val FACE_METER_INTERVAL_MS = 2_000L

    /**
     * Metering region size as a fraction of the frame. Wide enough to cover the
     * face rather than a single feature, so exposure follows the skin as a whole
     * and not, say, an eyebrow.
     */
    private const val FACE_METER_SIZE = 0.25f

    /** Sample points per axis across the face when measuring skin tone. */
    private const val SKIN_TONE_GRID = 12

    /** Below this many skin-like samples the measurement isn't trustworthy. */
    private const val SKIN_TONE_MIN_SAMPLES = 20

    /** Easing for the measured tone — slow, it describes a person not a frame. */
    private const val SKIN_TONE_EASE = 0.12f

    /** Grid resolution for the whole-frame brightness read — see measureSceneLuma. */
    private const val SCENE_LUMA_GRID = 16

    /**
     * Slower than the skin-tone easing on purpose. Lighting genuinely changes as
     * you turn around, and the strengths riding it must not visibly pump while
     * that happens — the renderer's own per-frame easing then smooths what's left.
     */
    private const val SCENE_LUMA_EASE = 0.08f

    /**
     * How long to wait after a hardware recording finalizes before rebinding the
     * camera back to its idle (no VideoCapture) configuration — see the call site
     * in [stopRecording]. Long enough for the Flutter navigation to the editor to
     * finish, short enough that a user who stays on the camera screen doesn't
     * notice the preview running on the recording bind.
     */
    private const val POST_RECORD_REBIND_DELAY_MS = 700L

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

    /** Guards against overlapping [requestConfettiFrame] ticks. */
    private val confettiPixelCopyBusy = AtomicBoolean(false)

    private var pixelCopyThread: HandlerThread? = null
    private var pixelCopyHandler: Handler? = null

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

    /** Consecutive failed [ProcessCameraProvider] resolutions; see [onCameraProviderUnavailable]. */
    private var cameraInitAttempts = 0

    /**
     * True while a retry is already scheduled.
     *
     * Several bind requests are usually in flight at once (the preview, the
     * resume path and a filter change all ask), and without this they each
     * failed and each incremented [cameraInitAttempts] — the whole budget went
     * in about ten milliseconds, so the app gave up long before a camera that
     * was merely busy could come back.
     */
    private var cameraInitRetryPending = false

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

    /** Hardware VideoCapture Lottie bake (screen-overlay filters) — see [ScreenOverlayCameraEffect]. */
    private var screenOverlayCameraEffect: ScreenOverlayCameraEffect? = null

    @Volatile
    private var camera: Camera? = null

    /** True when the bound CameraX lens is the front (selfie) camera. */
    private fun isBoundFrontLens(): Boolean {
        val bound = camera
        if (bound != null) {
            return bound.cameraInfo.lensFacing == CameraSelector.LENS_FACING_FRONT
        }
        return ArCameraBridge.isFrontCamera
    }

    /**
     * Keep the selected lens on real devices, but do not fail a live session
     * when an emulator (or a legacy device) exposes only one camera.  CameraX
     * otherwise accepts the request late and the AR/WebRTC path receives no
     * frames, which used to make the app leave the live room.
     */
    private fun availableCameraSelector(cameraProvider: ProcessCameraProvider): CameraSelector {
        val requested = if (ArCameraBridge.isFrontCamera) {
            CameraSelector.DEFAULT_FRONT_CAMERA
        } else {
            CameraSelector.DEFAULT_BACK_CAMERA
        }
        val fallback = if (ArCameraBridge.isFrontCamera) {
            CameraSelector.DEFAULT_BACK_CAMERA
        } else {
            CameraSelector.DEFAULT_FRONT_CAMERA
        }
        return try {
            if (requested.filter(cameraProvider.availableCameraInfos).isNotEmpty()) {
                requested
            } else {
                Log.w(PREVIEW_QUALITY_TAG, "requested camera unavailable; using available fallback lens")
                fallback
            }
        } catch (_: Throwable) {
            fallback
        }
    }

    private fun notifyBackPersonPresence(faceFill: Float) {
        if (isBoundFrontLens()) {
            BackPersonPresence.clearForFrontCamera()
        } else {
            BackPersonPresence.updateFromBackCamera(faceFill)
        }
    }

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
        if (started) {
            // Flutter may replace its Android PlatformView while the Activity
            // and CameraX controller stay alive (notably Opening -> Ready).
            // Rebind the running camera to the new owner instead of leaving it
            // attached to the disposed PreviewView/GL surface.
            previewView.implementationMode = PreviewView.ImplementationMode.PERFORMANCE
            previewView.scaleType = PreviewView.ScaleType.FILL_CENTER
            previewView.visibility = View.VISIBLE
            previewView.post {
                if (started &&
                    ArCameraBridge.previewView === previewView &&
                    ArCameraBridge.faceOverlay === faceOverlay
                ) {
                    Log.i("ArCameraLifecycle", "Controller.start HANDOFF to current PlatformView")
                    bindCamera(lifecycleOwner, previewView, faceOverlay)
                    ArCameraBridge.applyCurrentFilter()
                } else {
                    Log.i("ArCameraLifecycle", "Controller.start ignored stale PlatformView handoff")
                }
            }
            return
        }
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
        stickerCameraOverlay = StickerCameraOverlay(activity.applicationContext)
        screenOverlayCameraEffect = ScreenOverlayCameraEffect()

        ArCameraWatchdog.reset()
        ArCameraWatchdog.onDegrade = { enterSimpleMode() }
        ArCameraWatchdog.isPaused = { isRecordingActive() || previewSuspended }

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
        BackPersonPresence.reset()
        if (ArCameraBridge.isFrontCamera) {
            BackPersonPresence.clearForFrontCamera()
        }
        convertingFrame.set(false)
        faceOverlay.resetForNonPngFilter()

        activity.runOnUiThread {
            // Flip goes straight to bindCamera rather than through
            // requestPreviewRebind, so it needs its own cover over the unbind.
            if (!preferOesBinding) {
                ArCameraBridge.coverPreviewForRebind()
            }
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
        if (!filter.isScreenOverlay()) {
            screenOverlayCameraEffect?.clear()
        }
        // Rebind when the required use-case set changes (NONE = no Analysis →
        // sharper Preview stream; overlay filters keep VideoCapture bound so the
        // shutter doesn't have to rebind — see [needsVideoUseCase]).
        val wantAnalysis = needsAnalysisUseCase(filter)
        val wantPngFast = filter.isPngOverlay()
        val wantVideo = needsVideoUseCase(filter)
        if (started &&
            !isRecordingActive() &&
            !boundToOes &&
            canRebindCamera() &&
            (wantAnalysis != analysisUseCaseBound ||
                wantVideo != videoUseCaseBound ||
                (wantAnalysis && wantPngFast != pngFastAnalysisBound))
        ) {
            requestPreviewRebind()
        }
    }

    /**
     * True when the watchdog has given up on the full pipeline for this session
     * — see [ArCameraWatchdog]. Everything that adds a stream, a GL surface or an
     * effect checks this and stays out.
     */
    private fun inSimpleMode(): Boolean = ArCameraWatchdog.degraded

    private fun needsAnalysisUseCase(filter: FilterType): Boolean =
        !inSimpleMode() && (filter.isDistortion() || filter.isPngOverlay())

    /**
     * Filters whose recording runs through the hardware [VideoCapture] pipeline
     * keep it bound the whole time they're selected, not just while recording.
     *
     * Binding it lazily on the shutter meant every record start paid a full
     * `unbindAll()` + rebind, which blanks the preview surface for the best part
     * of a second — the black screen users saw right after tapping record. The
     * other two categories don't need this: Normal Mode and the distortion
     * filters record by attaching an encoder surface to the already-running GL
     * view, so they never rebind to start.
     *
     * Side benefit: what's on screen while composing is now produced by the exact
     * same binding that records, so framing can't shift when recording starts.
     */
    private fun needsVideoUseCase(filter: FilterType): Boolean =
        // Screen overlays now record via OES beauty + Lottie composite (same
        // polish as Normal Mode). Only PNG stickers still keep VideoCapture
        // bound for the hardware OverlayEffect path.
        !inSimpleMode() && filter.isPngOverlay()

    /**
     * Cached answer to "can this device comfortably run the demanding camera
     * configuration?" Resolved once per session from the camera's own reported
     * hardware level, so nothing here is guessed per device model.
     *
     * Everything the AR camera does at full strength — a full-sensor still
     * alongside a 1080p video stream and a GL effect node — needs a camera that
     * supports several concurrent streams. LEGACY and LIMITED devices do not, and
     * CameraX's bind fails and falls back to preview-only; the user sees that as
     * the camera freezing or going black. Asking for less on those devices means
     * they get a working camera at lower quality instead.
     */
    @Volatile
    private var deviceIsHighCapability: Boolean? = null

    /**
     * Recording qualities to try, best first, taken from what this camera
     * actually reports rather than a fixed list.
     *
     * The previous hardcoded `FHD, HD, SD` did two things wrong at once: it asked
     * for FHD on cameras that never offer it (the bind then fails and falls back,
     * which the user sees as a black screen), and it capped cameras that could do
     * better. Asking the Recorder for the real list fixes both.
     *
     * Deliberately capped at FHD. UHD is often listed but pushes four times the
     * pixels through the effect node, the encoder and the overlay raster —
     * exactly the load that caused the freezes this module has just been
     * stabilised against. Raising that cap is a separate decision.
     */
    private fun preferredRecordQualities(
        info: CameraInfo?,
        highCapability: Boolean,
    ): List<Quality> {
        val ceiling = if (highCapability) Quality.FHD else Quality.HD
        val ranked = listOf(Quality.FHD, Quality.HD, Quality.SD)
        val allowed = ranked.dropWhile { it != ceiling }

        val supported = info?.let {
            try {
                Recorder.getVideoCapabilities(it).getSupportedQualities(DynamicRange.SDR)
            } catch (t: Throwable) {
                Log.w(PREVIEW_QUALITY_TAG, "video capabilities query failed", t)
                null
            }
        }

        val result = if (supported.isNullOrEmpty()) {
            allowed
        } else {
            allowed.filter { supported.contains(it) }.ifEmpty { allowed }
        }
        Log.i(
            PREVIEW_QUALITY_TAG,
            "record qualities device=$supported ceiling=$ceiling chosen=$result",
        )
        return result
    }

    @OptIn(ExperimentalCamera2Interop::class)
    private fun isHighCapabilityDevice(info: CameraInfo): Boolean {
        deviceIsHighCapability?.let { return it }
        val level = try {
            Camera2CameraInfo.from(info).getCameraCharacteristic(
                CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL,
            )
        } catch (t: Throwable) {
            null
        }
        // FULL / LEVEL_3 guarantee the multi-stream combinations we rely on.
        // Anything else (or an unknown level) is treated as constrained — the
        // safe assumption, since the cost of being wrong is a broken camera.
        val high = level == CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_FULL ||
            level == CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_3
        deviceIsHighCapability = high
        Log.i(PREVIEW_QUALITY_TAG, "camera hardware level=$level highCapability=$high")
        return high
    }

    fun stop() {
        abortCapture()
        ArCameraWatchdog.onDegrade = null
        ArCameraWatchdog.isPaused = null
        ArCameraWatchdog.reset()
        started = false
        previewSuspended = false
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
        stopConfettiFramePump()
        confettiHeadlessDrawable = null
        confettiHeadlessComposition = null
        try {
            stickerCameraOverlay?.release()
        } catch (_: Exception) {
        }
        stickerCameraOverlay = null
        try {
            screenOverlayCameraEffect?.release()
        } catch (_: Exception) {
        }
        screenOverlayCameraEffect = null
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
        // Non-blocking unbind: the synchronous [unbindCamera] (via `.get()`)
        // runs on the main thread while the app is actively rendering and was
        // observed to freeze the whole UI during the live-room handoff.
        unbindCameraAsync()
    }

    /**
     * Non-blocking variant of [unbindCamera] for the full-teardown path
     * ([stop], invoked from the "stopCamera" channel when the live room takes
     * over the lens). The synchronous version blocks the calling (main) thread
     * with `ProcessCameraProvider.getInstance(...).get()`. Using
     * [ListenableFuture.addListener] the callback only runs once the provider
     * is ready, so `get()` inside it returns immediately.
     */
    private fun unbindCameraAsync() {
        val activity = ArCameraBridge.hostActivity ?: return
        try {
            val provider = ProcessCameraProvider.getInstance(activity)
            provider.addListener(
                {
                    try {
                        provider.get().unbindAll()
                    } catch (_: Exception) {
                    }
                },
                ContextCompat.getMainExecutor(activity),
            )
        } catch (_: Exception) {
        }
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
        val interval =
            if (oesPhotoReady) OES_PHOTO_WARM_READY_INTERVAL_MS else OES_PHOTO_WARM_INTERVAL_MS
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
            // Stop continuous GPU readback — that was the live-preview lag.
            // Shutter re-enables capture for a fresh full-res frame.
            gl.setCaptureEnabled(false)
            return
        }
        cached?.recycle()

        gl.setCaptureMaxEdge(INSTANT_CAPTURE_EDGE)
        gl.setCaptureEnabled(true)
        gl.requestCaptureNow()
    }

    private fun scheduleOesPhotoWarmup(glView: FaceWarpGlView) {
        glView.setCaptureMaxEdge(INSTANT_CAPTURE_EDGE)
        // Two light kicks are enough to seed the warm buffer; a 6× burst was
        // stalling the first second of live preview with glReadPixels.
        repeat(2) { index ->
            mainHandler.postDelayed({
                if (!boundToOes || recording) return@postDelayed
                glView.setCaptureEnabled(true)
                glView.requestCaptureNow()
                warmOesPhotoCaptureIfNeeded()
            }, 80L + index * 160L)
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
        jpegQuality: Int = PHOTO_JPEG_QUALITY,
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

    private fun captureConfettiOverlayFrame(): Bitmap? =
        ArCameraBridge.captureScreenOverlayFrame()

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

        // Dispatch by filter CATEGORY first (Normal Mode / distortion / PNG-overlay /
        // screen-overlay), not by the shared boundToOes flag alone — screen overlays
        // also use OES for beauty, but still need Lottie composited on top.
        when {
            filter == FilterType.NONE -> {
                // First-open / no-filter: use retained analysis frame so editor isn't
                // black. Never use this path once OES is bound (must bake live GL).
                if (!boundToOes) {
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
                // Exact match to live preview: the OES/GL frame already has beauty,
                // polish, framing and colour grade baked in. Full-sensor JPEG alone
                // looks darker/different because it skips that pipeline — only used
                // as fallback inside takePhotoFromGl / takeFullResStill.
                if (boundToOes) {
                    takePhotoFromGl(::deliver) { bmp ->
                        saveBaked(
                            bmp,
                            quality = PHOTO_JPEG_QUALITY,
                            maxEdge = 0,
                            alreadySmoothed = true,
                        )
                    }
                    return
                }
                if (!ArCameraBridge.isPreviewLetterboxed()) {
                    takePhotoWithImageCapture(::deliver)
                    return
                }
                tryBaked(1)
            }

            filter.isPngOverlay() -> {
                // Stickers: always use hardware ImageCapture (hi-res) then bake
                // overlay — analysis frames are intentionally small for tracking
                // and look soft if used.
                takePhotoWithImageCapture(::deliver)
            }

            filter.isDistortion() -> {
                tryBaked(2)
            }

            filter.isScreenOverlay() -> {
                // Same OES beauty buffer as live preview / Normal Mode photos,
                // then bake the Lottie on top (View draw must stay on main).
                if (boundToOes) {
                    val confettiFrame = captureConfettiOverlayFrame()
                    takePhotoFromGl(::deliver) { bmp ->
                        val withOverlay = compositeConfettiOnto(bmp, confettiFrame)
                        saveBaked(
                            withOverlay,
                            quality = PHOTO_JPEG_QUALITY,
                            maxEdge = 0,
                            alreadySmoothed = true,
                        )
                    }
                    return
                }
                tryBaked(1)
            }

            else -> {
                takePhotoWithImageCapture(::deliver)
            }
        }
    }

    /**
     * Captures at the sensor's own resolution and runs it through the still
     * beauty shader, so the saved photo matches what the preview showed but is
     * several times sharper.
     *
     * Falls back to [takePhotoFromGl] (the live preview buffer) whenever anything
     * here cannot deliver — no ImageCapture bound, capture error, or GL unable to
     * render the still. The fallback is the behaviour photos had before, so a
     * failure here costs sharpness, never the photo.
     */
    private fun takeFullResStill(
        outputFile: File,
        onResult: (String?, String?) -> Unit,
        saveBaked: (Bitmap) -> Boolean,
    ) {
        val activity = ArCameraBridge.hostActivity
        val capture = imageCapture
        val gl = ArCameraBridge.warpGlView
        if (activity == null || capture == null || gl == null || !gl.isGlInitialized()) {
            takePhotoFromGl(onResult, saveBaked)
            return
        }

        fun fallback() {
            mainHandler.post { takePhotoFromGl(onResult, saveBaked) }
        }

        // Straight to disk: CameraX writes the HAL's own JPEG bytes to the file.
        // Every other path here decodes that JPEG to a Bitmap and re-encodes it,
        // which throws away quality for nothing when the frame is being saved
        // unmodified anyway. Only usable when nothing has to be composited onto
        // the image, so letterbox mode still goes the long way round.
        if (!STILL_APPLY_BEAUTY && !ArCameraBridge.isPreviewLetterboxed()) {
            val metadata = ImageCapture.Metadata().apply {
                // The preview is mirrored on the front camera, so the saved photo
                // has to be too or it comes back flipped.
                isReversedHorizontal = ArCameraBridge.isFrontCamera
            }
            val options = ImageCapture.OutputFileOptions
                .Builder(outputFile)
                .setMetadata(metadata)
                .build()
            try {
                capture.takePicture(
                    options,
                    analysisExecutor ?: ContextCompat.getMainExecutor(activity),
                    object : ImageCapture.OnImageSavedCallback {
                        override fun onImageSaved(output: ImageCapture.OutputFileResults) {
                            if (outputFile.exists() && outputFile.length() > 0L) {
                                Log.i(
                                    PREVIEW_QUALITY_TAG,
                                    "still saved unmodified ${outputFile.length() / 1024}KB",
                                )
                                onResult(outputFile.absolutePath, null)
                            } else {
                                fallback()
                            }
                        }

                        override fun onError(exception: ImageCaptureException) {
                            Log.w(PREVIEW_QUALITY_TAG, "direct still save failed", exception)
                            fallback()
                        }
                    },
                )
            } catch (t: Throwable) {
                Log.w(PREVIEW_QUALITY_TAG, "direct still save threw", t)
                fallback()
            }
            return
        }

        val executor = analysisExecutor ?: ContextCompat.getMainExecutor(activity)
        try {
            capture.takePicture(
                executor,
                object : ImageCapture.OnImageCapturedCallback() {
                    override fun onCaptureSuccess(image: ImageProxy) {
                        var source: Bitmap? = null
                        var rendered: Bitmap? = null
                        try {
                            source = ImageProxyBitmapUtils.toUprightCapture(
                                image,
                                mirrorFront = ArCameraBridge.isFrontCamera,
                            )
                            if (source == null) {
                                fallback()
                                return
                            }
                            // Blocking, but this callback is already on a
                            // background executor.
                            Log.i(
                                PREVIEW_QUALITY_TAG,
                                "full-res still captured ${source.width}x${source.height} " +
                                    "beautify=$STILL_APPLY_BEAUTY",
                            )
                            // Match the live preview: run the still through the
                            // beauty/polish shader (same brighten + BASE_LIFT as OES).
                            rendered = if (STILL_APPLY_BEAUTY) {
                                gl.renderStillBlocking(source)
                            } else {
                                null
                            }
                            val out = rendered ?: source
                            if (isMostlyEmpty(out)) {
                                fallback()
                                return
                            }
                            if (!saveBaked(out)) fallback()
                        } catch (t: Throwable) {
                            Log.w(PREVIEW_QUALITY_TAG, "full-res still failed", t)
                            fallback()
                        } finally {
                            image.close()
                            // saveBaked owns whichever bitmap it was handed.
                            if (rendered != null && source !== rendered) {
                                source?.takeIf { !it.isRecycled }?.recycle()
                            }
                        }
                    }

                    override fun onError(exception: ImageCaptureException) {
                        Log.w(PREVIEW_QUALITY_TAG, "full-res capture failed", exception)
                        fallback()
                    }
                },
            )
        } catch (t: Throwable) {
            Log.w(PREVIEW_QUALITY_TAG, "full-res capture threw", t)
            fallback()
        }
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
            // Back down to the small warm buffer and stop continuous readback so
            // live preview stays smooth. One forced warm frame seeds the cache;
            // the next shutter raises the edge again for its own capture.
            gl.setCaptureMaxEdge(INSTANT_CAPTURE_EDGE)
            if (boundToOes && !recording) {
                gl.requestCaptureNow()
                mainHandler.postDelayed({
                    if (boundToOes && !recording) {
                        gl.setCaptureEnabled(false)
                    }
                }, 200L)
            } else if (!recording) {
                gl.setCaptureEnabled(false)
            }
        }

        fun saveOnExecutor(gpu: Bitmap) {
            val exec = analysisExecutor
                ?: ArCameraBridge.hostActivity?.let {
                    ContextCompat.getMainExecutor(it)
                }
            val work = Runnable {
                val ok = saveBaked(gpu)
                mainHandler.post {
                    if (ok) {
                        finishGlKeepWarm()
                    } else {
                        gl.setCaptureEnabled(false)
                        takePhotoWithImageCapture(onResult)
                    }
                }
            }
            if (exec != null) exec.execute(work) else work.run()
        }

        // Ask for a fresh full-resolution frame instead of saving the warm buffer
        // straight out. That buffer is only [INSTANT_CAPTURE_EDGE] on its long edge
        // — under a megapixel — which is the main reason Normal Mode photos looked
        // soft and noisy next to the stock camera app. Waiting a couple of frames
        // for the real one is worth it, and once the deadline passes we take
        // whatever is available rather than failing.
        gl.setCaptureMaxEdge(CAPTURE_MAX_EDGE)
        gl.setCaptureEnabled(true)
        gl.requestCaptureNow()

        val deadline = android.os.SystemClock.elapsedRealtime() + FULL_RES_GL_WAIT_MS

        fun awaitFrame() {
            val gpu = try {
                gl.copyLastFilteredFrame()
            } catch (_: Exception) {
                null
            }
            val expired = android.os.SystemClock.elapsedRealtime() >= deadline
            val usable = gpu != null && !isMostlyEmpty(gpu)
            // The capture is the fresh full-resolution one once it outgrows the
            // warm buffer; before the deadline, keep waiting for exactly that.
            val fullRes = usable && maxOf(gpu!!.width, gpu.height) > INSTANT_CAPTURE_EDGE
            if (usable && (fullRes || expired)) {
                saveOnExecutor(gpu!!)
                return
            }
            gpu?.recycle()
            if (expired) {
                finishGlKeepWarm()
                // Keep the live look: beautified full-res still, not raw HAL JPEG.
                val activity = ArCameraBridge.hostActivity
                if (activity != null && imageCapture != null) {
                    val file = File(
                        activity.cacheDir,
                        "ar_photo_${System.currentTimeMillis()}.jpg",
                    )
                    takeFullResStill(file, onResult, saveBaked)
                } else {
                    takePhotoWithImageCapture(onResult)
                }
                return
            }
            gl.requestCaptureNow()
            mainHandler.postDelayed({ awaitFrame() }, 16)
        }

        mainHandler.post { awaitFrame() }
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

        // Tries the fast hardware Recorder first (works when preview isn't
        // GPU-bound); if unavailable, rebinds with VideoCapture then starts.
        // Shared by Normal Mode (cold-start, before OES binds) and
        // PNG-overlay — the two categories that can use the plain hardware
        // recorder instead of GPU-surface encoding.
        fun startHardwareOrRebind() {
            if (simpleHardwareRecorder.isAvailable()) {
                simpleHardwareRecorder.start(activity, file) { ok, _ ->
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
            // VideoCapture not bound in idle preview — rebind with video, then start.
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
        }

        try {
            if (!hasMicPermission(activity)) {
                ActivityCompat.requestPermissions(
                    activity,
                    arrayOf(Manifest.permission.RECORD_AUDIO),
                    101,
                )
            }

            // Dispatch by filter CATEGORY, not by the shared boundToOes flag —
            // same reasoning as takePhoto()'s category-first dispatch: keeps
            // each category's recording path from being silently steered by
            // another category's OES/GL state.
            when (val filter = ArCameraBridge.currentFilter) {
                FilterType.NONE -> {
                    // Always record the rendered GL output. The hardware
                    // recorder sees only raw camera pixels, so its cold-start
                    // path silently dropped Magic, retouch and color grading.
                    // startGlSurfaceRecording has a filtered-bitmap fallback if
                    // GL is still warming up.
                    startGlSurfaceRecording(file, onResult)
                }

                else -> when {
                    filter.isPngOverlay() -> {
                        if (!ArCameraBridge.isPreviewLetterboxed()) {
                            startHardwareOrRebind()
                        } else {
                            startBitmapRecording(file, onResult)
                        }
                    }

                    filter.isDistortion() -> startGlSurfaceRecording(file, onResult)

                    filter.isScreenOverlay() -> {
                        val isVideoOverlay = ArCameraBridge.currentOverlaySource?.isVideo == true
                        if (isVideoOverlay || boundToOes) {
                            startBitmapRecording(file, onResult)
                        } else if (!ArCameraBridge.isPreviewLetterboxed()) {
                            prepareScreenOverlaySource()
                            startHardwareOrRebind()
                        } else {
                            startBitmapRecording(file, onResult)
                        }
                    }

                    // Any other/unknown category: no GL/OES stream feeds these —
                    // handled entirely by startBitmapRecording.
                    else -> startBitmapRecording(file, onResult)
                }
            }
        } catch (e: Exception) {
            recording = false
            hardwareRecording = false
            glSurfaceRecording = false
            cancelMaxDurationStop()
            onResult(false, e.message ?: "record_start_failed")
        }
    }

    /**
     * Hands the currently-loaded Lottie composition to [ScreenOverlayCameraEffect]
     * so its raster thread can bake it into the video buffer. The effect advances
     * the animation on its own clock rather than following the on-screen view —
     * see ScreenOverlayCameraEffect.animationProgress for why.
     */
    fun updateScreenOverlayComposition(composition: LottieComposition?) {
        if (ArCameraBridge.currentOverlaySource?.isVideo == true) {
            screenOverlayCameraEffect?.clear()
            return
        }
        val effect = screenOverlayCameraEffect ?: return
        if (composition == null) {
            effect.clear()
            return
        }
        effect.setSource(composition)
    }

    private fun prepareScreenOverlaySource() {
        updateScreenOverlayComposition(ArCameraBridge.confettiOverlay?.composition)
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
        // Standard 9:16 export, not the screen's own (narrower) shape.
        //
        // The screen-matched canvas used before this (warpViewWidth/Height, e.g.
        // 1080x2436) cropped the camera's 1080-wide portrait frame down to
        // ~851px to fit that narrower shape — recorded video came out below
        // 1080p no matter how large the encoder itself was allowed to be. This
        // camera's native portrait frame (rotated 1920x1080 sensor output) is
        // already exactly 9:16, so exporting at 9:16 instead uses the full
        // 1080px the sensor provides: no crop, no upscale, genuinely 1080x1920.
        //
        // Trade-off, deliberately accepted: the saved video now shows a little
        // more top/bottom than what was framed live on a taller screen. Live
        // preview framing itself is unchanged — this only affects what's saved.
        val maxEdge = RECORD_GL_EDGE
        val encH = (maxEdge.toInt() and 1.inv()).coerceAtLeast(2)
        val encW = ((maxEdge * 9 / 16).toInt() and 1.inv()).coerceAtLeast(2)

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

            // Category-first: screen-overlay is checked unconditionally, on its
            // own, rather than as an "else" alongside the OES/shader check —
            // so its confetti pump can never be silently skipped by another
            // category's OES state (boundToOes is only ever true for Normal
            // Mode today, but this keeps that true structurally, not by
            // coincidence).
            val filter = ArCameraBridge.currentFilter
            if (filter.isScreenOverlay()) {
                // Pull beautified GL (or PreviewView fallback) + overlay into the
                // bitmap recorder — see [requestConfettiFrame].
                if (boundToOes) {
                    val gl = ArCameraBridge.warpGlView
                    gl?.setCaptureEnabled(true)
                    // Overlay composites downscale anyway; smaller readback keeps
                    // live preview responsive while recording.
                    gl?.setCaptureMaxEdge(RECORD_PROCESS_EDGE)
                }
                startConfettiFramePump()
            } else if (boundToOes || filter.useShader()) {
                val gl = ArCameraBridge.warpGlView
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
                //
                // Deliberately deferred: this is a full camera unbind/rebind (and
                // with a screen-overlay filter it also tears down the effect's GL
                // node), and firing it the instant recording finalizes puts it on
                // the main thread at exactly the moment Flutter is animating over
                // to the editor screen — which is what the post-record hitch was.
                // Nothing needs the idle-quality preview stream during that
                // transition, so let the navigation settle first. The guards are
                // re-checked on the delayed run, so a filter switch or a new
                // recording started in the meantime cancels it naturally.
                mainHandler.postDelayed({
                    val current = ArCameraBridge.currentFilter
                    if (started &&
                        !boundToOes &&
                        canRebindCamera() &&
                        !preferVideoBinding &&
                        // Overlay filters want VideoCapture bound at idle too, so
                        // there is nothing to drop — rebinding would only blank
                        // the preview for no gain.
                        !needsVideoUseCase(current) &&
                        !needsAnalysisUseCase(current)
                    ) {
                        requestPreviewRebind()
                    }
                }, POST_RECORD_REBIND_DELAY_MS)
            }
            return
        }

        if (glSurfaceRecording || videoRecorder.isSurfaceSession()) {
            recording = false
            glSurfaceRecording = false
            val gl = ArCameraBridge.warpGlView

            // videoRecorder.stop() blocks its calling thread 150ms+ (drain
            // sleep) plus muxing time — stopRecording() runs on the main
            // thread (direct MethodChannel handler call), so doing this
            // inline froze the UI on every stop. Moved to recordOfferExecutor;
            // gl.clearEncoderSurface() is itself already safe to call off the
            // main thread (GLSurfaceView.queueEvent), so the existing
            // "stop the encoder before clearing its surface" ordering (avoids
            // an extra black frame as the clip's last sample) still holds,
            // just both steps now happen on the background thread instead.
            fun finishStop(after: () -> Unit) {
                try {
                    val file = videoRecorder.stop()
                    if (file != null && file.exists() && file.length() > 0L) {
                        lastStoppedPath = file.absolutePath
                        mainHandler.post { onResult(file.absolutePath, null) }
                    } else {
                        mainHandler.post { onResult(null, "empty_video") }
                    }
                } catch (e: Exception) {
                    mainHandler.post { onResult(null, e.message ?: "record_stop_failed") }
                } finally {
                    after()
                }
            }
            val executor = recordOfferExecutor
            if (executor != null) {
                executor.execute {
                    finishStop { gl?.clearEncoderSurface(null) }
                }
            } else {
                finishStop { gl?.clearEncoderSurface(null) }
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

            // videoRecorder.stop() blocks its calling thread for 150ms+ (a
            // hardcoded drain sleep) plus however long muxing the audio/video
            // takes — stopRecording() is invoked directly from the Flutter
            // method channel handler (MainActivity), i.e. the MAIN thread, so
            // doing this inline froze the UI on every stop ("lag after
            // recording"). Run it on recordOfferExecutor (already used for
            // this same recording's frame work, so it naturally serializes
            // after any in-flight frame) and hop back to mainHandler only for
            // the result callback, which ends in a MethodChannel.Result that
            // must complete on the platform thread.
            val executor = recordOfferExecutor
            if (executor != null) {
                executor.execute {
                    val (path, error) = try {
                        val file = videoRecorder.stop()
                        if (file != null && file.exists() && file.length() > 0L) {
                            lastStoppedPath = file.absolutePath
                            file.absolutePath to null
                        } else {
                            null to "empty_video"
                        }
                    } catch (e: Exception) {
                        null to (e.message ?: "record_stop_failed")
                    }
                    mainHandler.post { onResult(path, error) }
                }
                return
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
     * Confetti has no dedicated encoder stream — this grabs the live beautified
     * OES frame (or PreviewView fallback) plus the confetti overlay's current
     * animation frame, composites them, and hands the result to the same
     * [offerRecordingFrameAsync] → [pumpRecordFrame] pipeline everything else
     * uses, so beauty + overlay both bake into the saved video.
     * [requestConfettiFrame] does the actual work; this Runnable only paces it
     * on [CONFETTI_RECORD_INTERVAL_MS].
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
        if (pixelCopyThread == null) {
            val thread = HandlerThread("ar-pixel-copy")
            thread.start()
            pixelCopyThread = thread
            pixelCopyHandler = Handler(thread.looper)
        }
        mainHandler.post(confettiFrameRunnable)
    }

    private fun stopConfettiFramePump() {
        confettiFramePumpActive = false
        mainHandler.removeCallbacks(confettiFrameRunnable)
        confettiPixelCopyBusy.set(false)
        pixelCopyThread?.quitSafely()
        pixelCopyThread = null
        pixelCopyHandler = null
    }

    private fun scheduleNextConfettiTick() {
        if (confettiFramePumpActive) {
            mainHandler.postDelayed(confettiFrameRunnable, CONFETTI_RECORD_INTERVAL_MS)
        }
    }

    /** Reused across recording composite ticks — see [composeConfettiOverlay].
     *  Only ever touched from [recordOfferExecutor]'s single thread. */
    private var confettiHeadlessDrawable: LottieDrawable? = null
    private var confettiHeadlessComposition: LottieComposition? = null

    /**
     * Grabs a base frame for the confetti recording composite via
     * `previewView.bitmap()` — synchronous and main-thread-blocking (a real
     * cost; see [CONFETTI_RECORD_INTERVAL_MS]'s throttling), but a direct
     * screenshot of exactly what's on screen with no separate width/height
     * calculation of our own to get wrong.
     * History — every async alternative tried here has failed for a
     * different, fundamental reason: `PixelCopy` on the raw `SurfaceView`
     * copies pre-transform pixels (confirmed stretch bug); a `Window`-level
     * `PixelCopy` captures a black rect where the camera preview is (raw
     * camera SurfaceViews are often composited via a hardware overlay that
     * bypasses the window's normal buffer — a real Android platform
     * limitation, not fixable in app code); switching `previewView` to
     * `TextureView` (`ImplementationMode.COMPATIBLE`) so `getBitmap()` works
     * correctly avoids both of those, but makes the *continuous* live camera
     * rendering itself measurably more expensive every frame (a known,
     * documented SurfaceView-vs-TextureView cost — see the comment on
     * `implementationMode = PERFORMANCE` in `start()`), which compounds with
     * video encoding's own load during recording and produced *more* lag
     * than the synchronous baseline, not less. There is no capture mechanism
     * available here that is simultaneously async, correctly transformed,
     * and free of added continuous rendering cost — getting further would
     * need real on-device profiling, not more static-code attempts. The
     * Lottie composite draw itself still runs off the main thread (see
     * [finishConfettiFrame]/[composeConfettiOverlay]), just not this capture.
     */
    private fun requestConfettiFrame() {
        if (!confettiPixelCopyBusy.compareAndSet(false, true)) {
            scheduleNextConfettiTick()
            return
        }
        if (ArCameraBridge.currentOverlaySource?.isVideo == true) {
            requestVideoOverlayFrame()
            return
        }
        val overlay = ArCameraBridge.confettiOverlay
        val composition = overlay?.composition
        val viewW = overlay?.width ?: 0
        val viewH = overlay?.height ?: 0
        if (overlay == null || composition == null ||
            overlay.visibility != View.VISIBLE || viewW <= 0 || viewH <= 0
        ) {
            confettiPixelCopyBusy.set(false)
            scheduleNextConfettiTick()
            return
        }
        // Snapshot the on-screen view's current animation position now, on the
        // main thread (cheap field read) — the actual draw happens later, off
        // this thread, via a headless LottieDrawable that never touches the
        // View, so it can't race the main thread's own animator.
        val progress = overlay.progress

        // Prefer the live OES beauty buffer so overlay videos match Normal Mode
        // polish. copy (not take) so photo-warm / other readers keep a frame.
        if (boundToOes) {
            val beauty = try {
                ArCameraBridge.warpGlView?.copyLastFilteredFrame()
            } catch (_: Exception) {
                null
            }
            if (beauty != null) {
                finishConfettiFrame(composition, progress, beauty, viewW, viewH)
                return
            }
        }

        val previewView = ArCameraBridge.previewView
        val raw = try {
            previewView?.bitmap
        } catch (_: Exception) {
            null
        }
        if (raw == null) {
            confettiPixelCopyBusy.set(false)
            scheduleNextConfettiTick()
            return
        }
        finishConfettiFrame(
            composition,
            progress,
            raw,
            previewView?.width?.takeIf { it > 0 } ?: viewW,
            previewView?.height?.takeIf { it > 0 } ?: viewH,
        )
    }

    private fun requestVideoOverlayFrame() {
        val overlayFrame =
            ArCameraBridge.ensureVideoHelper()?.captureFrame(RECORD_PROCESS_EDGE)
        val viewW = ArCameraBridge.videoOverlay?.width ?: 0
        val viewH = ArCameraBridge.videoOverlay?.height ?: 0
        if (overlayFrame == null || viewW <= 0 || viewH <= 0) {
            confettiPixelCopyBusy.set(false)
            scheduleNextConfettiTick()
            return
        }
        if (boundToOes) {
            val beauty = try {
                ArCameraBridge.warpGlView?.copyLastFilteredFrame()
            } catch (_: Exception) {
                null
            }
            if (beauty != null) {
                finishVideoOverlayFrame(overlayFrame, beauty, viewW, viewH)
                return
            }
        }
        val previewView = ArCameraBridge.previewView
        val raw = try {
            previewView?.bitmap
        } catch (_: Exception) {
            null
        }
        if (raw == null) {
            overlayFrame.recycle()
            confettiPixelCopyBusy.set(false)
            scheduleNextConfettiTick()
            return
        }
        finishVideoOverlayFrame(
            overlayFrame,
            raw,
            previewView?.width?.takeIf { it > 0 } ?: viewW,
            previewView?.height?.takeIf { it > 0 } ?: viewH,
        )
    }

    private fun finishVideoOverlayFrame(
        overlayFrame: Bitmap,
        base: Bitmap,
        viewW: Int,
        viewH: Int,
    ) {
        val executor = recordOfferExecutor
        if (executor == null) {
            confettiPixelCopyBusy.set(false)
            scheduleNextConfettiTick()
            if (!overlayFrame.isRecycled) overlayFrame.recycle()
            if (!base.isRecycled) base.recycle()
            return
        }
        executor.execute {
            var composed: Bitmap? = null
            try {
                val targetH = RECORD_PROCESS_EDGE
                val targetW = ((targetH * 9 / 16) and 1.inv()).coerceAtLeast(2)

                val output = Bitmap.createBitmap(targetW, targetH, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(output)
                val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)

                val baseW = base.width
                val baseH = base.height
                val baseAspect = baseW.toFloat() / baseH.toFloat()
                val targetAspect = targetW.toFloat() / targetH.toFloat()
                val cropW: Int
                val cropH: Int
                if (baseAspect > targetAspect) {
                    cropH = baseH
                    cropW = (baseH * targetAspect).toInt().coerceAtMost(baseW)
                } else {
                    cropW = baseW
                    cropH = (baseW / targetAspect).toInt().coerceAtMost(baseH)
                }
                val left = ((baseW - cropW) / 2).coerceAtLeast(0)
                val top = ((baseH - cropH) / 2).coerceAtLeast(0)
                val srcRect = Rect(left, top, left + cropW, top + cropH)
                val dstRect = RectF(0f, 0f, targetW.toFloat(), targetH.toFloat())

                canvas.drawBitmap(base, srcRect, dstRect, paint)

                val overlaySrcRect = Rect(0, 0, overlayFrame.width, overlayFrame.height)
                canvas.drawBitmap(overlayFrame, overlaySrcRect, dstRect, paint)

                composed = output
            } catch (_: Exception) {
                composed = base
            } finally {
                if (!overlayFrame.isRecycled) overlayFrame.recycle()
                if (base !== composed && !base.isRecycled) base.recycle()
            }
            composed?.let { offerRecordingFrameAsync(it, recycleSourceAlways = true) }
            confettiPixelCopyBusy.set(false)
            scheduleNextConfettiTick()
        }
    }

    /**
     * Dispatches the Lottie composite to [recordOfferExecutor] so the
     * per-layer Lottie rasterization (see [composeConfettiOverlay]) never
     * touches the main thread.
     */
    private fun finishConfettiFrame(
        composition: LottieComposition,
        progress: Float,
        base: Bitmap,
        viewW: Int,
        viewH: Int,
    ) {
        val executor = recordOfferExecutor
        if (executor == null) {
            confettiPixelCopyBusy.set(false)
            scheduleNextConfettiTick()
            if (!base.isRecycled) base.recycle()
            return
        }
        executor.execute {
            val composed = try {
                composeConfettiOverlay(base, composition, progress, viewW, viewH)
            } catch (_: Exception) {
                base
            }
            composed?.let { offerRecordingFrameAsync(it, recycleSourceAlways = true) }
            confettiPixelCopyBusy.set(false)
            scheduleNextConfettiTick()
        }
    }

    /**
     * Draws the Lottie animation onto [raw] using a headless [LottieDrawable]
     * (SOFTWARE render mode, matching the software Bitmap [Canvas] it draws
     * to) instead of the on-screen `confettiOverlay` View.
     */
    private fun composeConfettiOverlay(
        raw: Bitmap,
        composition: LottieComposition,
        progress: Float,
        viewW: Int,
        viewH: Int,
    ): Bitmap? {
        var current: Bitmap = raw
        return try {
            // Crop raw to the aspect ratio of the viewport to prevent stretching!
            val cropped = try {
                val c = ImageProxyBitmapUtils.cropFillCenterToViewport(current, viewW, viewH)
                if (c !== current) {
                    current.recycle()
                    current = c
                }
                c
            } catch (_: Exception) {
                current
            }

            // Shrink before the Lottie draw below, not after
            val base = try {
                val shrunk = ImageProxyBitmapUtils.scaleToMaxDimension(current, RECORD_PROCESS_EDGE, filter = true)
                if (shrunk !== current) {
                    current.recycle()
                    current = shrunk
                }
                shrunk
            } catch (_: Exception) {
                current
            }

            val target = if (base.isMutable && base.config == Bitmap.Config.ARGB_8888) {
                base
            } else {
                val copy = base.copy(Bitmap.Config.ARGB_8888, true) ?: return base
                base.recycle()
                copy
            }
            val drawable = confettiHeadlessDrawable?.takeIf { confettiHeadlessComposition === composition }
                ?: LottieDrawable().apply {
                    setComposition(composition)
                    setRenderMode(RenderMode.SOFTWARE)
                }.also {
                    confettiHeadlessDrawable = it
                    confettiHeadlessComposition = composition
                }
            drawable.progress = progress

            val srcW = composition.bounds.width().toFloat().coerceAtLeast(1f)
            val srcH = composition.bounds.height().toFloat().coerceAtLeast(1f)
            val dstW = target.width.toFloat()
            val dstH = target.height.toFloat()
            val cropScale = kotlin.math.max(dstW / srcW, dstH / srcH)
            val scaledW = (srcW * cropScale)
            val scaledH = (srcH * cropScale)
            val left = ((dstW - scaledW) / 2f).toInt()
            val top = ((dstH - scaledH) / 2f).toInt()

            val canvas = Canvas(target)
            drawable.setBounds(left, top, left + scaledW.toInt(), top + scaledH.toInt())
            drawable.draw(canvas)
            target
        } catch (_: Exception) {
            current
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

        // Screen-overlay (confetti/snowfall/etc.) frames come from
        // previewView.bitmap()/PixelCopy — a screenshot of the ALREADY
        // letterbox-margined PreviewView (its own top/bottom margins are set
        // by ArCameraBridge.applyPreviewLetterbox() whenever letterbox mode
        // is on), so any letterboxing is already baked into `source`. Every
        // other recording path captures from a raw, unmargined camera buffer
        // and needs the compose below to letterbox it for the first time —
        // applying it again here to an already-letterboxed screen-overlay
        // frame would letterbox it twice, distorting the frame.
        if (!ArCameraBridge.isPreviewLetterboxed() ||
            ArCameraBridge.currentFilter.isScreenOverlay()
        ) {
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
        // CPU Bilateral filter (OpenCV) takes 150ms+ per frame, which severely drops video recording frame rate.
        // Skip CPU bilateral filter during continuous video recording; live preview shaders handle beauty on GPU.
        if (recording) return bitmap
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

    /**
     * Still capture, configured for quality rather than shutter speed.
     *
     * Two changes from the original here, both aimed at the "photos look dull and
     * noisy next to the stock camera app" gap:
     *
     * - CAPTURE_MODE_MAXIMIZE_QUALITY lets the HAL run its full still pipeline
     *   (multi-frame noise reduction, stronger tone mapping on most vendors)
     *   instead of the fast path MINIMIZE_LATENCY asks for. It also raises
     *   CameraX's own intermediate JPEG quality to 100, so decoding and
     *   re-encoding the frame to composite overlays no longer stacks two lossy
     *   passes. Costs a few hundred ms of shutter latency.
     * - A high resolution target instead of the old fixed 2160x2880, which was
     *   pinning captures near 6MP on sensors that can do far more. 4:3 is
     *   requested because that is the sensor's native aspect on virtually every
     *   phone — anything else is a crop of it.
     *
     * [allowFullSensor] exists because those two settings are not free. A
     * full-sensor still plus MAXIMIZE_QUALITY is a large surface and a demanding
     * stream combination; on capable phones it binds fine, on weaker ones the
     * whole bind fails and the fallback chain drops to preview-only, which the
     * user sees as the camera freezing or going black. So it is only requested
     * where few streams are in play. When several are (stickers and overlays bind
     * Preview + Analysis + Capture + Video + an effect), this asks for a bounded
     * target and lets CameraX pick something the device can actually service.
     */
    private fun buildImageCapture(
        displayRotation: Int,
        allowFullSensor: Boolean,
    ): ImageCapture {
        val resolutionStrategy = if (allowFullSensor) {
            ResolutionStrategy.HIGHEST_AVAILABLE_STRATEGY
        } else {
            ResolutionStrategy(
                Size(PHOTO_FALLBACK_WIDTH, PHOTO_FALLBACK_HEIGHT),
                ResolutionStrategy.FALLBACK_RULE_CLOSEST_LOWER_THEN_HIGHER,
            )
        }
        val resolutionSelector = ResolutionSelector.Builder()
            .setAspectRatioStrategy(
                AspectRatioStrategy(
                    AspectRatio.RATIO_4_3,
                    AspectRatioStrategy.FALLBACK_RULE_AUTO,
                ),
            )
            .setResolutionStrategy(resolutionStrategy)
            .build()

        return ImageCapture.Builder()
            .setCaptureMode(
                if (allowFullSensor) {
                    ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY
                } else {
                    ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY
                },
            )
            .setResolutionSelector(resolutionSelector)
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
                    // 16:9 (portrait 9:16) matches tall phone screens — 4:3 was
                    // side-cropping so hard that the selfie looked face-only vs TikTok.
                    AspectRatio.RATIO_16_9,
                    AspectRatioStrategy.FALLBACK_RULE_AUTO,
                ),
            )
            .setResolutionStrategy(
                ResolutionStrategy(
                    // CameraX matches this bound size against the camera's stream
                    // sizes, which are always reported in sensor/landscape order
                    // (width >= height) regardless of final display rotation —
                    // passing our portrait 1080x1920 target here (width < height)
                    // fed it a shape that doesn't exist in that list, and the
                    // higher-then-lower fallback jumped to the nearest 16:9 match
                    // it could find: 3072x1728 (~5.3MP, 2.5x the intended ~2MP).
                    // Swapping to landscape order (1920x1080) matches CameraX's
                    // expected convention; AspectRatioStrategy above still locks
                    // it to 16:9, and setTargetRotation handles final rotation.
                    Size(PREVIEW_TARGET_HEIGHT, PREVIEW_TARGET_WIDTH),
                    ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER,
                ),
            )
            .build()

        val builder = Preview.Builder()
            .setResolutionSelector(resolutionSelector)
            .setTargetRotation(displayRotation)

        val selector = availableCameraSelector(cameraProvider)
        val previewCameraInfo = try {
            selector.filter(cameraProvider.availableCameraInfos).firstOrNull()
        } catch (t: Throwable) {
            null
        }
        val noiseMode = previewCameraInfo?.let { bestNoiseReductionMode(it) }
            ?: CaptureRequest.NOISE_REDUCTION_MODE_FAST
        val edgeMode = previewCameraInfo?.let { bestEdgeMode(it) }
            ?: CaptureRequest.EDGE_MODE_FAST
        Log.i(PREVIEW_QUALITY_TAG, "live preview quality: noiseMode=$noiseMode edgeMode=$edgeMode")
        logSupportedPreviewSizes(previewCameraInfo)

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
     * One-time dump of the sizes this camera can actually hand a SurfaceTexture,
     * so stream resolution is chosen from what the device offers rather than
     * guessed. Asking for a size the camera does not publish gets silently
     * resolved to something else — which is how a QHD request ended up still
     * delivering 1920x1080 while downstream stages had already been widened to
     * expect more.
     */
    @OptIn(ExperimentalCamera2Interop::class)
    private fun logSupportedPreviewSizes(info: CameraInfo?) {
        if (info == null || loggedPreviewSizes) return
        loggedPreviewSizes = true
        try {
            val map = Camera2CameraInfo.from(info).getCameraCharacteristic(
                CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP,
            ) ?: return
            val sizes = map.getOutputSizes(android.graphics.SurfaceTexture::class.java)
                ?.sortedByDescending { it.width.toLong() * it.height.toLong() }
                ?.joinToString(", ") { "${it.width}x${it.height}" }
            Log.i(PREVIEW_QUALITY_TAG, "supported preview (SurfaceTexture) sizes: $sizes")
        } catch (t: Throwable) {
            Log.w(PREVIEW_QUALITY_TAG, "preview size query failed", t)
        }
    }

    @Volatile
    private var loggedPreviewSizes = false

    /**
     * Strongest noise reduction the device advertises. HIGH_QUALITY gives the
     * cleanest result (fewer visible grain "dots") and is preferred even though
     * it's the mode documented as possibly reducing frame rate — noise was the
     * user-visible complaint, not preview smoothness. FAST is the next choice;
     * MINIMAL deliberately performs less denoising and is only a last resort.
     *
     * Measured, not assumed: this was tested as a suspected cause of camera lag by
     * forcing FAST on every device, and it made no measurable difference —
     * `camerahalserver` stayed at ~154% CPU either way. The real cause was the
     * beauty shader's per-pixel texture-fetch load (see FaceWarpGlView's
     * render-resolution cap). Leaving this at HIGH_QUALITY keeps the image quality
     * it was chosen for; do not "optimise" it again without re-measuring.
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
            modes?.contains(CaptureRequest.NOISE_REDUCTION_MODE_FAST) == true ->
                CaptureRequest.NOISE_REDUCTION_MODE_FAST
            modes?.contains(CaptureRequest.NOISE_REDUCTION_MODE_MINIMAL) == true ->
                CaptureRequest.NOISE_REDUCTION_MODE_MINIMAL
            else -> CaptureRequest.NOISE_REDUCTION_MODE_FAST
        }
    }

    /**
     * Strongest edge/sharpening mode the device advertises. FAST's more aggressive
     * sharpening amplifies sensor grain into visible speckle on top of it — HIGH_QUALITY
     * sharpens less naively and reads as cleaner paired with [bestNoiseReductionMode].
     * Same measured finding as that function: forcing FAST here changed nothing about
     * lag, so it stays on the setting chosen for image quality.
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
                val targetEv = if (ArCameraBridge.isFrontCamera) {
                    PREVIEW_EXPOSURE_EV_STOPS
                } else {
                    PREVIEW_EXPOSURE_EV_STOPS_BACK
                }
                val rawIndex = Math.round(targetEv / step)
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

    /**
     * GL frames presented since the last resume — diagnostic only, read by the
     * post-resume health check in [onHostResume]. Distinguishes "the camera
     * rebound but no frames are flowing" from "frames are flowing but nothing is
     * visible", which the bind logs alone cannot tell apart.
     */
    @Volatile
    private var framesSinceResume = 0

    private fun onOesFramePresented() {
        framesSinceResume++
        ArCameraWatchdog.onFrame()
        ArCameraBridge.onGlFramePresented()
        warmOesPhotoCaptureIfNeeded()

        // Screen-overlay recording owns frames via the confetti pump (beauty +
        // Lottie). Feeding maybeCaptureRecordingFrame here would race it and
        // bake beauty-only frames without the overlay.
        if (recording &&
            !hardwareRecording &&
            !glSurfaceRecording &&
            !ArCameraBridge.currentFilter.isScreenOverlay()
        ) {
            maybeCaptureRecordingFrame()
        }
    }

    fun isBoundToOes(): Boolean = boundToOes

    fun setPreferOesBinding(prefer: Boolean) {
        preferOesBinding = prefer
    }

    /**
     * Tears the fancy pipeline down and rebinds the camera as plainly as
     * possible: no OES/GL preview, no effects, no extra streams — just CameraX
     * driving the PreviewView, which is the one configuration every Android
     * device supports.
     *
     * Invoked by [ArCameraWatchdog] when frames stop arriving. Filters stop
     * working from here on, and that is the intended trade: a plain but live
     * camera beats a frozen one with features.
     */
    private fun enterSimpleMode() {
        if (!started) return
        Log.w(PREVIEW_QUALITY_TAG, "entering simple mode — rebinding plain preview")
        val activity = ArCameraBridge.hostActivity ?: return
        activity.runOnUiThread {
            try {
                ArCameraBridge.forceSimplePreview()
            } catch (t: Throwable) {
                Log.e(PREVIEW_QUALITY_TAG, "simple-mode UI switch failed", t)
            }
            preferOesBinding = false
            preferVideoBinding = false
            preferCaptureBinding = false
            boundToOes = false
            rebindPosted = false
            forcePreviewViewRebind()
        }
    }

    fun canRebindCamera(): Boolean = started && !isRecordingActive() && !previewSuspended

    /**
     * True while the camera screen is covered by another Flutter route (e.g. the
     * media studio editor) — see [suspendPreview].
     */
    @Volatile
    private var previewSuspended = false

    @Volatile
    private var hostWasPaused = false

    @Volatile
    private var hostResumeGeneration = 0

    /**
     * Fully stops the camera pipeline while the camera screen is still mounted
     * but no longer visible.
     *
     * Pushing the editor route does NOT pause the host Activity, so without this
     * everything kept running behind it: the camera stream, the GL view, and — for
     * screen-overlay filters — a full-screen 60fps Lottie animation. That load
     * doesn't disappear just because Flutter stopped painting the route, and it
     * was competing with video playback on the editor screen. It also let the
     * deferred post-record rebind (see [stopRecording]) fire right as the editor
     * was opening; [canRebindCamera] now reports false here, so that rebind and
     * any other queued one drop out on their own.
     *
     * Deliberately does NOT unbind the camera. That was tried and it is exactly
     * the wrong thing to do on this path: `unbindAll()` is main-thread-only and
     * tears down the capture session, which showed up as a visible freeze on the
     * tap that opens the editor. What actually costs continuous work behind the
     * editor is the animation and the GL renderer, and both stop cheaply.
     *
     * No-op mid-recording — that path owns the camera.
     */
    fun suspendPreview() {
        if (!started || previewSuspended) return
        if (isRecordingActive()) return
        previewSuspended = true
        val activity = ArCameraBridge.hostActivity
        val work = Runnable {
            try {
                ArCameraBridge.confettiOverlay?.pauseAnimation()
            } catch (_: Throwable) {
            }
            try {
                ArCameraBridge.ensureVideoHelper()?.pause()
            } catch (_: Throwable) {
            }
            try {
                ArCameraBridge.warpGlView?.onPause()
            } catch (_: Throwable) {
            }
            applyScreenFlash(false)
        }
        if (activity != null) activity.runOnUiThread(work) else work.run()
    }

    /**
     * Undoes [suspendPreview]. The camera itself was deliberately left bound, so
     * keep that live binding when EGL was preserved instead of tearing it down
     * and exposing partially initialized frames on every return from the editor.
     */
    fun resumePreview() {
        if (!started || !previewSuspended) return
        previewSuspended = false
        val activity = ArCameraBridge.hostActivity ?: return
        val gl = ArCameraBridge.warpGlView

        if (boundToOes && gl?.cameraSurfaceTexture() != null) {
            activity.runOnUiThread {
                try {
                    gl.onResume()
                    gl.ensureGlInitialized()
                    gl.resetAfterRouteResume()
                    ArCameraBridge.syncPreviewNaturalOrientation()
                    ArCameraBridge.applyCurrentFilter()
                    gl.requestRender()
                } catch (t: Throwable) {
                    Log.w("ArCameraController", "fast preview resume failed; rebinding", t)
                    onHostResume(force = true)
                }
            }
            return
        }

        // PreviewView/simple-mode and any device that lost its GL surface still
        // use the full recovery path.
        onHostResume(force = true)
    }

    fun onHostPause() {
        Log.i(
            "ArCameraLifecycle",
            "Controller.onHostPause started=$started recording=${isRecordingActive()} " +
                "suspended=$previewSuspended boundOes=$boundToOes " +
                "preferOes=$preferOesBinding filter=${ArCameraBridge.currentFilter} " +
                "glSurface=${ArCameraBridge.warpGlView?.cameraSurfaceTexture() != null}",
        )
        if (!started) return
        hostWasPaused = true
        hostResumeGeneration++
        // Do not leave lifecycle-bound use cases around for CameraX to
        // auto-reattach during onResume. That automatic attach was racing the
        // explicit fresh-OES rebind below, so whichever session won determined
        // whether the preview resumed or stayed black.
        unbindCamera()
        camera = null
        boundToOes = false
        rebindPosted = false
        switchingCamera = false
        ArCameraWatchdog.stop()
        Log.i("ArCameraLifecycle", "Controller.onHostPause camera fully unbound")
        try {
            ArCameraBridge.warpGlView?.onPause()
        } catch (_: Throwable) {
        }
    }

    /**
     * Watches for a resume that bound successfully but is not actually producing
     * frames, and rebuilds the GL producer when it finds one.
     *
     * A black preview after returning from another app does not show up in the
     * bind logs at all — CameraX reports the session opening normally and the GL
     * view is visible; what is missing is frames. Measured on a failing resume:
     * ~5 frames in two seconds against ~39 on a healthy one. Rather than depend
     * on having found every root cause (the stale-GL-handle fix in
     * FaceWarpRenderer.forgetGlObjectsForNewContext addresses one), this notices
     * the symptom directly and recreates the camera SurfaceTexture and camera
     * binding, which is the same recovery the resume path itself performs.
     *
     * Retries a bounded number of times so a genuinely broken device settles into
     * the existing simple-mode fallback instead of looping forever.
     */
    private fun scheduleResumeHealthCheck(
        gl: FaceWarpGlView?,
        resumeGeneration: Int,
        attempt: Int,
    ) {
        mainHandler.postDelayed({
            if (resumeGeneration != hostResumeGeneration) return@postDelayed
            if (!started || previewSuspended || isRecordingActive()) return@postDelayed

            val frames = framesSinceResume
            val healthy = frames >= RESUME_MIN_HEALTHY_FRAMES
            Log.i(
                "ArCameraLifecycle",
                "Controller.resumeHealth attempt=$attempt frames=$frames " +
                    "healthy=$healthy boundOes=$boundToOes glVis=${gl?.visibility} " +
                    "previewVis=${ArCameraBridge.previewView?.visibility} " +
                    "gl=${gl?.width}x${gl?.height} " +
                    "glSurface=${gl?.cameraSurfaceTexture() != null}",
            )
            if (healthy) return@postDelayed

            if (attempt > RESUME_RECOVERY_ATTEMPTS || gl == null) {
                Log.e(
                    "ArCameraLifecycle",
                    "Controller.resumeHealth GAVE UP after $attempt attempts — " +
                        "leaving watchdog to degrade",
                )
                return@postDelayed
            }

            Log.w(
                "ArCameraLifecycle",
                "Controller.resumeHealth RECOVERING attempt=$attempt frames=$frames",
            )
            framesSinceResume = 0
            boundToOes = false
            rebindPosted = false
            gl.awaitCameraSurface {
                if (resumeGeneration == hostResumeGeneration) {
                    Log.i("ArCameraLifecycle", "Controller.resumeHealth recovery surface ready")
                    requestPreviewRebind()
                }
            }
            gl.setOesEnabled(true)
            gl.recreateCameraSurfaceTexture()
            gl.requestRender()

            scheduleResumeHealthCheck(gl, resumeGeneration, attempt + 1)
        }, RESUME_HEALTH_CHECK_MS)
    }

    fun onHostResume(force: Boolean = false) {
        Log.i(
            "ArCameraLifecycle",
            "Controller.onHostResume ENTER force=$force started=$started " +
                "recording=${isRecordingActive()} suspended=$previewSuspended " +
                "hostWasPaused=$hostWasPaused generation=$hostResumeGeneration " +
                "boundOes=$boundToOes preferOes=$preferOesBinding " +
                "filter=${ArCameraBridge.currentFilter} " +
                "glSurface=${ArCameraBridge.warpGlView?.cameraSurfaceTexture() != null}",
        )
        if (!started) {
            Log.w("ArCameraLifecycle", "Controller.onHostResume SKIP notStarted")
            return
        }
        if (isRecordingActive()) {
            Log.w("ArCameraLifecycle", "Controller.onHostResume SKIP recording")
            return
        }
        // App foregrounded while the editor is on top — leave the camera stopped;
        // [resumePreview] clears the flag before delegating here.
        if (previewSuspended) {
            Log.w("ArCameraLifecycle", "Controller.onHostResume SKIP previewSuspended")
            return
        }
        if (ArCameraBridge.hostActivity == null) {
            Log.e("ArCameraLifecycle", "Controller.onHostResume SKIP activity=null")
            return
        }
        val gl = ArCameraBridge.warpGlView

        // Adding the PlatformView observer while the Activity is already resumed
        // also invokes this callback. Only rebuild after a real background pause.
        if (!hostWasPaused && !force) {
            Log.i("ArCameraLifecycle", "Controller.onHostResume SKIP noRealPause")
            return
        }
        hostWasPaused = false
        val resumeGeneration = ++hostResumeGeneration
        Log.i(
            "ArCameraLifecycle",
            "Controller.onHostResume SCHEDULE generation=$resumeGeneration " +
                "gl=${gl?.width}x${gl?.height} glVis=${gl?.visibility} " +
                "previewVis=${ArCameraBridge.previewView?.visibility}",
        )

        try {
            gl?.onResume()
        } catch (_: Throwable) {
        }

        // CameraX closes the capture session while the Activity is stopped and
        // SurfaceView may recreate its producer afterwards. Waiting briefly lets
        // both lifecycle and GL surfaces become valid, then performs one explicit
        // bind instead of relying on the stale pre-background session.
        mainHandler.postDelayed({
            if (!started ||
                previewSuspended ||
                isRecordingActive() ||
                resumeGeneration != hostResumeGeneration
            ) {
                Log.w(
                    "ArCameraLifecycle",
                    "Controller.resumeRebind CANCEL generation=$resumeGeneration " +
                        "currentGeneration=$hostResumeGeneration started=$started " +
                        "suspended=$previewSuspended recording=${isRecordingActive()}",
                )
                return@postDelayed
            }

            Log.i(
                "ArCameraLifecycle",
                "Controller.resumeRebind START generation=$resumeGeneration " +
                    "filter=${ArCameraBridge.currentFilter} " +
                    "glSurface=${gl?.cameraSurfaceTexture() != null}",
            )
            ArCameraBridge.syncPreviewNaturalOrientation()
            gl?.ensureGlInitialized()
            gl?.resetAfterRouteResume()
            ArCameraBridge.prepareForHostResume()
            framesSinceResume = 0

            scheduleResumeHealthCheck(gl, resumeGeneration, attempt = 1)

            val filter = ArCameraBridge.currentFilter
            preferOesBinding = !filter.useShader() && !filter.isPngOverlay()
            boundToOes = false
            rebindPosted = false
            switchingCamera = false
            convertingFrame.set(false)

            fun requestFreshBind() {
                Log.i(
                    "ArCameraLifecycle",
                    "Controller.resumeRebind REQUEST preferOes=$preferOesBinding " +
                        "glSurface=${gl?.cameraSurfaceTexture() != null}",
                )
                requestPreviewRebind()

                // Restore the selected filter/UI after the new CameraX session
                // has attached its surface.
                mainHandler.postDelayed({
                    if (started &&
                        !previewSuspended &&
                        resumeGeneration == hostResumeGeneration
                    ) {
                        Log.i(
                            "ArCameraLifecycle",
                            "Controller.resumeReveal APPLY boundOes=$boundToOes " +
                                "preferOes=$preferOesBinding " +
                                "glSurface=${gl?.cameraSurfaceTexture() != null}",
                        )
                        ArCameraBridge.applyCurrentFilter()
                        gl?.requestRender()
                    } else {
                        Log.w(
                            "ArCameraLifecycle",
                            "Controller.resumeReveal CANCEL generation=$resumeGeneration " +
                                "currentGeneration=$hostResumeGeneration",
                        )
                    }
                }, 500L)
            }

            if (preferOesBinding && gl != null) {
                // The logs show CameraX reopening successfully against the old
                // OES SurfaceTexture but no GL frames arriving afterwards. The
                // Activity's SurfaceViews were destroyed/recreated, so replace
                // the OES producer too and only bind once the new one exists.
                var boundFromSurface = false
                gl.awaitCameraSurface {
                    if (resumeGeneration == hostResumeGeneration) {
                        boundFromSurface = true
                        Log.i(
                            "ArCameraLifecycle",
                            "Controller.resumeRebind NEW_OES_SURFACE ready",
                        )
                        requestFreshBind()
                    }
                }
                gl.setOesEnabled(true)
                gl.recreateCameraSurfaceTexture()

                // Safety net: bind anyway if no new surface ever arrives.
                // recreateCameraSurfaceTexture() is a no-op when GL is not
                // initialised, and the waiter above is also skipped when its
                // generation went stale — in both cases nothing else would ever
                // rebind and the preview stays black until the screen is
                // reopened. Guarded by boundFromSurface/boundToOes so a normal
                // resume, which binds well inside this window, is untouched.
                mainHandler.postDelayed({
                    if (!boundFromSurface &&
                        !boundToOes &&
                        started &&
                        !previewSuspended &&
                        !isRecordingActive() &&
                        resumeGeneration == hostResumeGeneration
                    ) {
                        Log.w(
                            "ArCameraLifecycle",
                            "Controller.resumeRebind NO_OES_SURFACE — forcing bind",
                        )
                        requestFreshBind()
                    }
                }, RESUME_SURFACE_TIMEOUT_MS)
            } else {
                requestFreshBind()
            }
        }, 300L)
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

            gl.awaitCameraSurface {
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

        if (previewSuspended) return

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
            // Freeze the last preview frame over the unbind so the surface going
            // black isn't visible. Skipped for the OES path, which runs its own
            // freeze-frame transition (ArCameraBridge.beginOesTransitionWithFreeze).
            if (!preferOesBinding) {
                ArCameraBridge.coverPreviewForRebind()
            }
            bindCamera(lifecycleOwner, previewView, faceOverlay)
        }
    }

    /**
     * CameraX could not hand us a provider.
     *
     * The message it carries ("Retrying initialization might resolve temporary
     * camera errors") is worth taking literally: the common causes — another
     * app still releasing the lens, a HAL restart, a cold emulator — clear on
     * their own within a second. Retry a few times on a short backoff, then
     * stop and degrade rather than spin: a device with no usable lens at all
     * (an emulator booted `-camera-front none -camera-back none`) would
     * otherwise rebind forever.
     */
    private fun onCameraProviderUnavailable(
        cause: Throwable,
        lifecycleOwner: LifecycleOwner,
        previewView: PreviewView,
        faceOverlay: FaceOverlayView,
    ) {
        switchingCamera = false
        // A retry for this same failure is already queued; let it do the work.
        if (cameraInitRetryPending) return
        cameraInitAttempts++
        if (cameraInitAttempts > CAMERA_INIT_MAX_ATTEMPTS) {
            Log.e(
                PREVIEW_QUALITY_TAG,
                "camera provider unavailable after $CAMERA_INIT_MAX_ATTEMPTS attempts; giving up",
                cause,
            )
            camera = null
            imageCapture = null
            analysisUseCaseBound = false
            pngFastAnalysisBound = false
            videoUseCaseBound = false
            ArCameraWatchdog.reportGlFailure()
            return
        }
        Log.w(
            PREVIEW_QUALITY_TAG,
            "camera provider unavailable (attempt $cameraInitAttempts); retrying",
            cause,
        )
        val activity = ArCameraBridge.hostActivity ?: return
        cameraInitRetryPending = true
        activity.window.decorView.postDelayed({
            cameraInitRetryPending = false
            if (ArCameraBridge.hostActivity == null) return@postDelayed
            bindCamera(lifecycleOwner, previewView, faceOverlay)
        }, CAMERA_INIT_RETRY_MS * cameraInitAttempts)
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
            // CameraX resolves this future with a failure when the device
            // reports no usable camera — a transient HAL hiccup, another app
            // holding the lens, or an emulator booted with a lens set to
            // `none`. This runs on the main thread from a Handler callback, so
            // letting the ExecutionException out of here does not fail the
            // bind, it kills the process: the user tapped "go live" and the app
            // vanished. Retry a bounded number of times (CameraX's own message
            // says a retry often clears it) and then degrade to no preview.
            val cameraProvider = try {
                cameraProviderFuture.get().also { cameraInitAttempts = 0 }
            } catch (t: Throwable) {
                onCameraProviderUnavailable(t, lifecycleOwner, previewView, faceOverlay)
                return@addListener
            }
            try {
                val displayRotation = activity.windowManager.defaultDisplay.rotation
                val pngFast = ArCameraBridge.currentFilter.isPngOverlay()
                val analysisTarget = if (pngFast) {
                    Size(PNG_ANALYSIS_WIDTH, PNG_ANALYSIS_HEIGHT)
                } else {
                    Size(ANALYSIS_WIDTH, ANALYSIS_HEIGHT)
                }

                val preview = buildLivePreview(displayRotation, cameraProvider)

                val glView = ArCameraBridge.warpGlView
                // Simple mode never binds the camera into the GL/OES pipeline — that
                // is the path with the most moving parts (a second EGL surface, an
                // encoder surface, shaders) and therefore the most ways for an
                // unfamiliar driver to stall it.
                val useOes = !inSimpleMode() &&
                    preferOesBinding &&
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

                val selector = availableCameraSelector(cameraProvider)

                fun applyTorchAfterBind(bound: Camera?) {
                    camera = bound
                    if (bound == null) return
                    // Restarts the stall timer. Only the OES/GL path reports frames
                    // individually, so only that path can be watched for stalls —
                    // see ArCameraWatchdog.onCameraBound.
                    ArCameraWatchdog.onCameraBound(hasPerFrameSignal = useOes)
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
                    // Lazy, same as the non-OES bind path below ("Capture binds
                    // on shutter"): idle Normal Mode is Preview + Analysis only —
                    // two streams, not three. takePhotoWithImageCaptureToFile
                    // already handles imageCapture being null (sets
                    // preferCaptureBinding + requestPreviewRebind, this same
                    // function then runs again with it true) and its own
                    // callback already resets preferCaptureBinding back to false
                    // for FilterType.NONE afterward — this plumbing already
                    // existed, Normal Mode just never used it, and instead bound
                    // ImageCapture (even at the now-reduced moderate resolution)
                    // continuously, which was keeping the camera HAL close to
                    // saturated (measured ~97% on camerahalserver).
                    val capture = if (preferCaptureBinding) {
                        buildImageCapture(displayRotation, allowFullSensor = false)
                    } else {
                        null
                    }
                    imageCapture = capture

                    // Normal Mode only — small background analysis stream feeding the
                    // landmark-rasterized skin mask (see processSkinMaskFrame /
                    // buildFaceSkinMaskBitmap). Attempted first; if this 3rd concurrent
                    // stream isn't supported on a given device, the catch block below
                    // falls back to the proven 2-stream (Preview + ImageCapture) bind.
                    // Preview + Analysis + Capture is one of CameraX's guaranteed
                    // stream combinations all the way down to LEGACY, so this does
                    // not need a hardware-level gate — and gating it did real damage:
                    // the landmarks this stream produces are what drive both the skin
                    // mask and face-metered exposure, and most phones report LIMITED,
                    // so on most phones neither was running at all. The bind is still
                    // wrapped in the fallback below for anything that surprises us.
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
                        val useCases = buildList<UseCase> {
                            add(preview)
                            capture?.let { add(it) }
                            skinMaskAnalysis?.let { add(it) }
                        }
                        val bound = cameraProvider.bindToLifecycle(
                            lifecycleOwner,
                            selector,
                            *useCases.toTypedArray(),
                        )
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
                            val fallbackUseCases = buildList<UseCase> {
                                add(preview)
                                capture?.let { add(it) }
                            }
                            applyTorchAfterBind(
                                cameraProvider.bindToLifecycle(
                                    lifecycleOwner,
                                    selector,
                                    *fallbackUseCases.toTypedArray(),
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
                val needVideo = preferVideoBinding || needsVideoUseCase(filter)
                // Normal idle: Preview ONLY. Capture binds on shutter; Analysis on effects; Video on record.
                val needCapture = preferCaptureBinding || needAnalysis || needVideo
                val boundCameraInfo = try {
                    selector.filter(cameraProvider.availableCameraInfos).firstOrNull()
                } catch (_: Throwable) {
                    null
                }
                val highCapability = boundCameraInfo?.let { isHighCapabilityDevice(it) } ?: false

                val capture = if (needCapture) {
                    // Full sensor only when nothing else is competing for the camera
                    // AND the device can take it; sticker/overlay binds add Analysis
                    // + Video + an effect on top.
                    val heavyBind = needAnalysis || needVideo
                    buildImageCapture(
                        displayRotation,
                        allowFullSensor = !heavyBind && highCapability,
                    ).also { imageCapture = it }
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
                    // FHD first: the previous HD-then-SD list capped every hardware
                    // recording at 720p, which is well under what the stock camera app
                    // writes and reads as soft/noisy on a 1080p+ screen. 4K is left out
                    // deliberately — it would have to go through the same GL effect node
                    // as the overlay filters.
                    val preferred = preferredRecordQualities(boundCameraInfo, highCapability)
                    val recorder = Recorder.Builder()
                        .setQualitySelector(
                            QualitySelector.fromOrderedList(
                                preferred,
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
                    withScreenEffect: Boolean = false,
                ): Boolean {
                    return try {
                        val useAnalysis = withAnalysis && analysis != null
                        val useVideo = withVideo && hwVideo != null
                        val useCapture = withCapture && capture != null
                        if (withPngEffect && useAnalysis && useVideo && useCapture && pngFast &&
                            !inSimpleMode()
                        ) {
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
                            // Bakes the full-screen Lottie into the recorded stream
                            // (VIDEO_CAPTURE target only, so Preview/ImageCapture are
                            // untouched). Needs a UseCaseGroup, so when there's no
                            // ViewPort to build one around we still make one here.
                            val screenEffect = if (withScreenEffect && useVideo && !inSimpleMode()) {
                                val overlay = screenOverlayCameraEffect
                                    ?: ScreenOverlayCameraEffect().also {
                                        screenOverlayCameraEffect = it
                                    }
                                overlay.ensureEffect()
                            } else {
                                null
                            }
                            val bound = if (viewPort != null || screenEffect != null) {
                                val groupBuilder = UseCaseGroup.Builder()
                                if (viewPort != null) groupBuilder.setViewPort(viewPort)
                                if (screenEffect != null) groupBuilder.addEffect(screenEffect)
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
                        needVideo && filter.isScreenOverlay() &&
                            ArCameraBridge.currentOverlaySource?.isVideo != true ->
                            // Fall back to a plain video bind if the device can't take
                            // the effect — recording still works, the overlay just
                            // isn't baked in, same shape as the PNG-effect fallback.
                            bindCombo(false, true, true, withPngEffect = false, withScreenEffect = true) ||
                                bindCombo(false, true, true, withPngEffect = false)
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
            } catch (t: Throwable) {
                // Same rule as the future above: nothing in the bind path is
                // worth taking the whole app down for. Drop to no preview and
                // let the watchdog's degrade path pick it up.
                Log.e(PREVIEW_QUALITY_TAG, "bindCamera failed", t)
                switchingCamera = false
                camera = null
                imageCapture = null
                analysisUseCaseBound = false
                pngFastAnalysisBound = false
                videoUseCaseBound = false
                ArCameraWatchdog.reportGlFailure()
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
        takePictureWithBoundCapture(capture, file, PHOTO_JPEG_QUALITY) { ok ->
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
        // Tooth visibility must react quickly when lips close; the regular skin
        // mask can remain throttled because its geometry changes slowly.
        val detectEvery = if (
            kotlin.math.abs(LiveRetouchState.adjustments.tooth) > 0.01f
        ) {
            2
        } else {
            SKIN_MASK_DETECT_EVERY
        }
        val shouldRun = skinMaskFrameCounter % detectEvery == 0
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
                // Independent of the face — the light in the room is worth
                // tracking whether or not anyone is detected in the frame.
                measureSceneLuma(oriented)
                if (snapshot != null) {
                    @Suppress("ConstantConditionIf")
                    if (FACE_METERING_ENABLED) {
                        meterExposureOnFace(snapshot, oriented.width, oriented.height, rotation)
                    }
                    measureSkinTone(oriented, snapshot)
                    LiveRetouchState.updateNoseLandmarks(
                        snapshot,
                        oriented.width,
                        oriented.height,
                    )
                    LiveRetouchState.updateJawLandmarks(
                        snapshot,
                        oriented.width,
                        oriented.height,
                    )
                    LiveRetouchState.updateEyeLandmarks(
                        snapshot,
                        oriented.width,
                        oriented.height,
                    )
                    LiveRetouchState.updateMouthLandmarks(
                        snapshot,
                        oriented.width,
                        oriented.height,
                    )
                } else {
                    // No face — decay fill so smooth/bright stop; empty grade stays.
                    decayFacePresence()
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

    // ------------------------------------------------------ scene light measure

    /** Smoothed whole-frame luminance — see [measureSceneLuma]. */
    private var sceneLumaAverage = -1f

    /** Reused full-row scratch for [measureSceneLuma]; grown to the frame width. */
    private var sceneLumaRow = IntArray(0)

    /**
     * Measures how much light the camera is actually working in, so the beauty
     * strengths can follow the room instead of staying put.
     *
     * This is deliberately the whole frame rather than the face. What it really
     * stands in for is sensor gain: a dim scene means the camera is amplifying,
     * and an amplified frame carries noise that smoothing should absorb and
     * sharpening would only make worse. The face alone would not show that — face
     * metering (see [meterExposureOnFace]) works to keep the face well exposed
     * precisely so it *doesn't* go dark, which is exactly the signal we'd lose.
     *
     * A coarse grid over the already-downscaled analysis bitmap, on the same
     * throttled frames the skin mask uses, so it costs nothing extra per frame.
     */
    private fun measureSceneLuma(oriented: Bitmap) {
        if (oriented.isRecycled) return
        val w = oriented.width
        val h = oriented.height
        if (w <= 0 || h <= 0) return

        if (sceneLumaRow.size < w) sceneLumaRow = IntArray(w)
        val rows = SCENE_LUMA_GRID.coerceAtMost(h)
        val cols = SCENE_LUMA_GRID.coerceAtMost(w)

        var total = 0f
        var samples = 0
        for (gy in 0 until rows) {
            val y = ((gy + 0.5f) / rows * h).toInt().coerceIn(0, h - 1)
            // One getPixels per sampled row — the per-pixel getPixel call is where
            // the cost of this would otherwise land.
            oriented.getPixels(sceneLumaRow, 0, w, 0, y, w, 1)
            for (gx in 0 until cols) {
                val x = ((gx + 0.5f) / cols * w).toInt().coerceIn(0, w - 1)
                total += lumaOf(sceneLumaRow[x])
                samples++
            }
        }
        if (samples == 0) return

        val frameLuma = total / samples
        sceneLumaAverage = if (sceneLumaAverage < 0f) {
            frameLuma
        } else {
            sceneLumaAverage + (frameLuma - sceneLumaAverage) * SCENE_LUMA_EASE
        }
        ArCameraBridge.warpGlView?.updateSceneLuma(sceneLumaAverage)
    }

    private fun lumaOf(pixel: Int): Float {
        val r = (pixel shr 16) and 0xFF
        val g = (pixel shr 8) and 0xFF
        val b = pixel and 0xFF
        return (0.299f * r + 0.587f * g + 0.114f * b) / 255f
    }

    // ------------------------------------------------------- skin tone measure

    /** Smoothed skin luminance — see [measureSkinTone]. */
    private var skinLumaAverage = -1f

    /** Smoothed face-box area / frame area — drives close-up denoise boost. */
    private var faceFillAverage = -1f

    /**
     * When landmarks disappear, ease face fill toward 0 so GPU beauty
     * (smooth / bright / auto-lift) turns off and empty-frame grade stays.
     */
    private fun decayFacePresence() {
        if (faceFillAverage < 0f) {
            ArCameraBridge.warpGlView?.updateFaceFill(0f)
            notifyBackPersonPresence(0f)
            return
        }
        faceFillAverage *= 0.85f
        if (faceFillAverage < 0.012f) faceFillAverage = 0f
        ArCameraBridge.warpGlView?.updateFaceFill(faceFillAverage)
        notifyBackPersonPresence(faceFillAverage.coerceAtLeast(0f))
        if (skinLumaAverage > 0f) {
            val target = FaceWarpRenderer.SKIN_LUMA_TARGET
            skinLumaAverage += (target - skinLumaAverage) * 0.25f
            ArCameraBridge.warpGlView?.updateSkinTone(skinLumaAverage)
        }
    }

    /**
     * Measures how bright this person's skin actually is, so the tone curve can
     * adapt to them instead of applying the same lift to everyone.
     *
     * The alternative — a fixed strength — fails at both ends. On already-bright
     * skin it clips and flattens; on deeper skin it is far too weak to do
     * anything, and any lift that does land drains the colour and leaves it
     * looking ashy. Knowing the actual tone lets the shader scale both the lift
     * and the chroma compensation to the person in frame.
     *
     * Samples a coarse grid across the middle of the face — cheap, and it runs on
     * the same throttled analysis frames the skin mask already uses.
     */
    private fun measureSkinTone(oriented: Bitmap, snapshot: FaceLandmarkSnapshot) {
        if (oriented.isRecycled) return
        val landmarks = snapshot.landmarks
        if (landmarks.isEmpty()) return

        var minX = Float.MAX_VALUE
        var minY = Float.MAX_VALUE
        var maxX = -Float.MAX_VALUE
        var maxY = -Float.MAX_VALUE
        for (index in MediaPipeLandmarkIndices.FACE_OVAL) {
            val p = landmarks.getOrNull(index) ?: continue
            if (p.x < minX) minX = p.x
            if (p.x > maxX) maxX = p.x
            if (p.y < minY) minY = p.y
            if (p.y > maxY) maxY = p.y
        }
        if (minX >= maxX || minY >= maxY) return

        // Face fill of the landmark frame — larger when the user leans in.
        val frameArea =
            (snapshot.imageWidth * snapshot.imageHeight).toFloat().coerceAtLeast(1f)
        val faceArea = (maxX - minX).coerceAtLeast(1f) * (maxY - minY).coerceAtLeast(1f)
        val frameFill = (faceArea / frameArea).coerceIn(0f, 1f)
        faceFillAverage = if (faceFillAverage < 0f) {
            frameFill
        } else {
            faceFillAverage + (frameFill - faceFillAverage) * SKIN_TONE_EASE
        }
        ArCameraBridge.warpGlView?.updateFaceFill(faceFillAverage)
        notifyBackPersonPresence(faceFillAverage)

        val scaleX = oriented.width / snapshot.imageWidth.toFloat()
        val scaleY = oriented.height / snapshot.imageHeight.toFloat()

        // Inset well inside the oval: the outer edge picks up hair, ears and
        // background, all of which would drag the measurement off.
        val insetX = (maxX - minX) * 0.22f
        val insetY = (maxY - minY) * 0.22f
        val left = ((minX + insetX) * scaleX).toInt().coerceIn(0, oriented.width - 1)
        val right = ((maxX - insetX) * scaleX).toInt().coerceIn(0, oriented.width - 1)
        val top = ((minY + insetY) * scaleY).toInt().coerceIn(0, oriented.height - 1)
        val bottom = ((maxY - insetY) * scaleY).toInt().coerceIn(0, oriented.height - 1)
        if (right <= left || bottom <= top) return

        val stepX = ((right - left) / SKIN_TONE_GRID).coerceAtLeast(1)
        val stepY = ((bottom - top) / SKIN_TONE_GRID).coerceAtLeast(1)

        var total = 0f
        var samples = 0
        var y = top
        while (y <= bottom) {
            var x = left
            while (x <= right) {
                val c = try {
                    oriented.getPixel(x, y)
                } catch (_: Exception) {
                    0
                }
                val r = ((c shr 16) and 0xFF) / 255f
                val g = ((c shr 8) and 0xFF) / 255f
                val b = (c and 0xFF) / 255f

                // Same skin test the shader uses, so the measurement matches what
                // the shader will actually treat. Keeps shadowed nostrils, teeth
                // and stray highlights out of the average.
                val cb = -0.169f * r - 0.331f * g + 0.5f * b + 0.5f
                val cr = 0.5f * r - 0.419f * g - 0.081f * b + 0.5f
                if (cb in 0.28f..0.54f && cr in 0.46f..0.74f) {
                    total += 0.299f * r + 0.587f * g + 0.114f * b
                    samples++
                }
                x += stepX
            }
            y += stepY
        }
        if (samples < SKIN_TONE_MIN_SAMPLES) return

        val frameLuma = total / samples
        // Detect underexposure quickly; ease up more gently when light improves.
        val ease = if (skinLumaAverage >= 0f && frameLuma < skinLumaAverage) {
            0.32f
        } else {
            SKIN_TONE_EASE
        }
        skinLumaAverage = if (skinLumaAverage < 0f) {
            frameLuma
        } else {
            skinLumaAverage + (frameLuma - skinLumaAverage) * ease
        }
        ArCameraBridge.warpGlView?.updateSkinTone(skinLumaAverage)
    }

    // --------------------------------------------------- face-metered exposure

    /** Where the face was when exposure was last metered, in sensor space. */
    private var lastMeterX = -1f
    private var lastMeterY = -1f
    private var lastMeterMs = 0L

    /**
     * Points the camera's auto-exposure and white balance at the face.
     *
     * Left to itself, AE meters the whole frame, so a bright wall or window
     * behind someone drags the exposure down and leaves the face dim — no amount
     * of brightening in the shader recovers detail the sensor never captured.
     * Metering on the face fixes the cause instead of the symptom, and it costs
     * nothing on the GPU.
     *
     * Deliberately AE and AWB only, never AF: repeatedly re-triggering autofocus
     * makes the preview hunt in and out, which is far more noticeable than the
     * exposure problem being solved.
     */
    private fun meterExposureOnFace(
        snapshot: FaceLandmarkSnapshot,
        imageWidth: Int,
        imageHeight: Int,
        rotationDegrees: Int,
    ) {
        if (!boundToOes || isRecordingActive() || previewSuspended) return
        val cam = camera ?: return
        val analysis = imageAnalysis ?: return
        if (imageWidth <= 0 || imageHeight <= 0) return

        val landmarks = snapshot.landmarks
        if (landmarks.isEmpty()) return

        // Face centre in the ORIENTED analysis image, normalised.
        var sumX = 0f
        var sumY = 0f
        for (index in MediaPipeLandmarkIndices.FACE_OVAL) {
            val p = landmarks.getOrNull(index) ?: continue
            sumX += p.x
            sumY += p.y
        }
        val count = MediaPipeLandmarkIndices.FACE_OVAL.size
        if (count == 0) return
        val ox = (sumX / count) / snapshot.imageWidth.toFloat()
        val oy = (sumY / count) / snapshot.imageHeight.toFloat()
        if (ox.isNaN() || oy.isNaN()) return

        // Back out the rotation applied when the analysis frame was oriented —
        // the metering factory works in the use case's own, unrotated surface
        // space, and a point handed over rotated meters the wrong part of the
        // scene entirely.
        val rot = ((rotationDegrees % 360) + 360) % 360
        val sx: Float
        val sy: Float
        when (rot) {
            90 -> { sx = oy; sy = 1f - ox }
            180 -> { sx = 1f - ox; sy = 1f - oy }
            270 -> { sx = 1f - oy; sy = ox }
            else -> { sx = ox; sy = oy }
        }
        if (sx !in 0f..1f || sy !in 0f..1f) return

        // Re-meter only when the face has actually moved.
        //
        // Nothing here is on a timer any more. Re-issuing the action makes the
        // camera converge AE/AWB again, and that convergence is visible — the
        // image washes out and settles over about a second. Doing that on an
        // interval meant a face sitting still in front of the camera got the
        // whole disturbance every couple of seconds for no gain: the metering
        // region had not changed, so it converged straight back to where it
        // already was.
        //
        // The interval survives only as a rate limit on real movement, so a face
        // hovering near the threshold cannot trigger convergence continuously.
        val now = android.os.SystemClock.elapsedRealtime()
        val moved = kotlin.math.abs(sx - lastMeterX) > FACE_METER_MOVE_THRESHOLD ||
            kotlin.math.abs(sy - lastMeterY) > FACE_METER_MOVE_THRESHOLD
        if (!moved) return
        if (lastMeterMs != 0L && now - lastMeterMs < FACE_METER_INTERVAL_MS) return
        lastMeterX = sx
        lastMeterY = sy
        lastMeterMs = now

        try {
            val factory = SurfaceOrientedMeteringPointFactory(1f, 1f, analysis)
            val point = factory.createPoint(sx, sy, FACE_METER_SIZE)
            val action = FocusMeteringAction.Builder(
                point,
                FocusMeteringAction.FLAG_AE or FocusMeteringAction.FLAG_AWB,
            ).disableAutoCancel().build()
            cam.cameraControl.startFocusAndMetering(action)
        } catch (t: Throwable) {
            Log.w(PREVIEW_QUALITY_TAG, "face metering failed", t)
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
            if (activeSnapshot != null) {
                LiveRetouchState.updateNoseLandmarks(
                    activeSnapshot,
                    oriented.width,
                    oriented.height,
                )
                LiveRetouchState.updateJawLandmarks(
                    activeSnapshot,
                    oriented.width,
                    oriented.height,
                )
                LiveRetouchState.updateEyeLandmarks(
                    activeSnapshot,
                    oriented.width,
                    oriented.height,
                )
                LiveRetouchState.updateMouthLandmarks(
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
