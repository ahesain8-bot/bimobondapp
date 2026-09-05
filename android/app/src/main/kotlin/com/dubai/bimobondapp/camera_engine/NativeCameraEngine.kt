package com.dubai.bimobondapp.camera_engine

import android.Manifest
import android.content.ComponentCallbacks2
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.util.Size
import android.view.Surface
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.dubai.bimobondapp.ar_camera.ImageProxyBitmapUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.view.TextureRegistry
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

/**
 * Native camera engine (Phase 1–11).
 *
 * Pipeline:
 * CameraX → OES → color → beauty → warp → makeup → stickers → debug → Flutter Texture.
 * Recording: GPU compose → MediaCodec H.264; mic + music mixed into AAC (video copied).
 * Export: Media3 Transformer → ≤1080p H.264 @ ~8 Mbps (passthrough when already compliant).
 */
class NativeCameraEngine(
    private val activity: FlutterActivity,
    private val textureRegistry: TextureRegistry,
) {
    companion object {
        private const val TAG = "NativeCameraEngine"
        private const val ANALYSIS_WIDTH = 320
        private const val ANALYSIS_HEIGHT = 240
        private const val ANALYSIS_MAX_EDGE = 256
        /** Skip frames to cut YUV→Bitmap GC pressure while tracking. */
        private const val ANALYSIS_FRAME_STRIDE = 3
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val cameraExecutor = Executors.newSingleThreadExecutor { r ->
        Thread(r, "native-camera-engine").apply { isDaemon = true }
    }
    private val analysisExecutor = Executors.newSingleThreadExecutor { r ->
        Thread(r, "native-camera-face").apply { isDaemon = true }
    }

    private val trimCallbacks = object : ComponentCallbacks2 {
        override fun onTrimMemory(level: Int) {
            if (level >= ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW) {
                // Drop MediaPipe when camera is unbound (background / stopped).
                if (!bound) {
                    releaseFaceTracker()
                }
            }
            if (level >= ComponentCallbacks2.TRIM_MEMORY_COMPLETE ||
                level >= ComponentCallbacks2.TRIM_MEMORY_MODERATE
            ) {
                purgeOldCacheFiles()
            }
        }

        override fun onConfigurationChanged(newConfig: Configuration) {}

        override fun onLowMemory() {
            if (!bound) releaseFaceTracker()
            purgeOldCacheFiles()
        }
    }

    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var gpuPipeline: GpuPreviewPipeline? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var preview: Preview? = null
    private var imageAnalysis: ImageAnalysis? = null
    private var camera: Camera? = null
    private var faceTracker: FaceTracker? = null

    @Volatile
    private var lensFacing: Int = CameraSelector.LENS_FACING_FRONT

    @Volatile
    private var torchEnabled: Boolean = false

    @Volatile
    private var bound: Boolean = false

    @Volatile
    private var faceTrackingEnabled: Boolean = false

    @Volatile
    private var landmarkDebugEnabled: Boolean = false

    @Volatile
    private var previewWidth: Int = NativeCameraConstants.PREVIEW_WIDTH

    @Volatile
    private var previewHeight: Int = NativeCameraConstants.PREVIEW_HEIGHT

    private val starting = AtomicBoolean(false)
    private val analyzing = AtomicBoolean(false)
    private val disposed = AtomicBoolean(false)
    private val analysisFrameCounter = AtomicInteger(0)
    private val lastFaceCount = AtomicInteger(0)
    @Volatile
    private var lastPose: FacePose = FacePose()
    private var pendingStart: ((Result) -> Unit)? = null

    private val recorder = HardwareVideoRecorder()
    private val exporter = VideoExporter(activity)
    private val recordingLock = Any()
    @Volatile
    private var recordingActive = false
    @Volatile
    private var lastRecordingPath: String? = null
    @Volatile
    private var lastExportPath: String? = null
    @Volatile
    private var lastExportPassthrough: Boolean = false
    @Volatile
    private var exportProgressPct: Int = 0

    @Volatile
    private var musicPath: String? = null
    @Volatile
    private var musicOffsetMs: Long = 0L
    @Volatile
    private var musicVolume: Float = 0.8f
    @Volatile
    private var originalVolume: Float = 0.2f

    init {
        try {
            activity.applicationContext.registerComponentCallbacks(trimCallbacks)
        } catch (t: Throwable) {
            Log.w(TAG, "registerComponentCallbacks", t)
        }
    }

    data class Result(
        val ok: Boolean,
        val textureId: Long? = null,
        val width: Int = 0,
        val height: Int = 0,
        val isFront: Boolean = true,
        val torchEnabled: Boolean = false,
        val torchAvailable: Boolean = false,
        val filterEnabled: Boolean = true,
        val filterIntensity: Float = 0.55f,
        val faceTrackingEnabled: Boolean = false,
        val landmarkDebugEnabled: Boolean = false,
        val faceCount: Int = 0,
        val pitchDeg: Float = 0f,
        val yawDeg: Float = 0f,
        val rollDeg: Float = 0f,
        val activeFaceEffectId: String? = null,
        val beautyEnabled: Boolean = true,
        val beautySkinSmooth: Float = 0f,
        val beautyBrightness: Float = 0f,
        val beautySkinTone: Float = 0f,
        val beautySharpen: Float = 0f,
        val beautyEyeEnhancement: Float = 0f,
        val warpEnabled: Boolean = true,
        val warpFaceSlim: Float = 0f,
        val warpBigEyes: Float = 0f,
        val warpSmallNose: Float = 0f,
        val warpBigLips: Float = 0f,
        val warpJaw: Float = 0f,
        val warpChin: Float = 0f,
        val makeupEnabled: Boolean = true,
        val makeupLipstick: Float = 0f,
        val makeupBlush: Float = 0f,
        val makeupEyeliner: Float = 0f,
        val makeupEyeshadow: Float = 0f,
        val recording: Boolean = false,
        val recordingPath: String? = null,
        val recordingDurationMs: Long = 0L,
        val musicPath: String? = null,
        val musicOffsetMs: Long = 0L,
        val musicVolume: Float = 0.8f,
        val originalVolume: Float = 0.2f,
        val exporting: Boolean = false,
        val exportPath: String? = null,
        val exportProgress: Int = 0,
        val exportPassthrough: Boolean = false,
        val error: String? = null,
    )

    fun hasCameraPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.CAMERA,
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun requestCameraPermission() {
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.CAMERA),
            NativeCameraConstants.PERMISSION_REQUEST_CODE,
        )
    }

    fun onPermissionResult(granted: Boolean) {
        val cb = pendingStart
        pendingStart = null
        if (cb == null) return
        if (disposed.get()) {
            cb(Result(ok = false, error = "disposed"))
            return
        }
        if (!granted) {
            cb(Result(ok = false, error = "camera_permission_denied"))
            return
        }
        startInternal(cb)
    }

    fun start(callback: (Result) -> Unit) {
        if (disposed.get()) {
            callback(Result(ok = false, error = "disposed"))
            return
        }
        if (!hasCameraPermission()) {
            if (pendingStart != null) {
                callback(Result(ok = false, error = "start_in_progress"))
                return
            }
            pendingStart = callback
            requestCameraPermission()
            return
        }
        startInternal(callback)
    }

    private fun startInternal(callback: (Result) -> Unit) {
        if (disposed.get()) {
            callback(Result(ok = false, error = "disposed"))
            return
        }
        if (!starting.compareAndSet(false, true)) {
            callback(Result(ok = false, error = "start_in_progress"))
            return
        }

        // Always rebind CameraX when pipeline exists — activity stop may have
        // unbound use cases while we kept the GL pipeline for fast resume.
        if (textureEntry != null && gpuPipeline != null) {
            val future = ProcessCameraProvider.getInstance(activity)
            future.addListener(
                {
                    try {
                        if (disposed.get()) {
                            starting.set(false)
                            mainHandler.post {
                                callback(Result(ok = false, error = "disposed"))
                            }
                            return@addListener
                        }
                        val provider = future.get()
                        cameraProvider = provider
                        bindPreview(provider)
                        starting.set(false)
                        mainHandler.post { callback(currentResult(ok = true)) }
                    } catch (t: Throwable) {
                        Log.e(TAG, "rebind failed", t)
                        starting.set(false)
                        mainHandler.post {
                            callback(Result(ok = false, error = t.message ?: "rebind_failed"))
                        }
                    }
                },
                ContextCompat.getMainExecutor(activity),
            )
            return
        }

        try {
            ensureTextureEntry()
            ensureGpuPipeline()
        } catch (t: Throwable) {
            Log.e(TAG, "pipeline init failed", t)
            starting.set(false)
            releaseGpuPipeline()
            callback(Result(ok = false, error = t.message ?: "pipeline_init_failed"))
            return
        }

        val future = ProcessCameraProvider.getInstance(activity)
        future.addListener(
            {
                try {
                    if (disposed.get()) {
                        starting.set(false)
                        mainHandler.post {
                            callback(Result(ok = false, error = "disposed"))
                        }
                        return@addListener
                    }
                    val provider = future.get()
                    cameraProvider = provider
                    bindPreview(provider)
                    starting.set(false)
                    mainHandler.post { callback(currentResult(ok = true)) }
                } catch (t: Throwable) {
                    Log.e(TAG, "start failed", t)
                    starting.set(false)
                    mainHandler.post {
                        callback(Result(ok = false, error = t.message ?: "start_failed"))
                    }
                }
            },
            ContextCompat.getMainExecutor(activity),
        )
    }

    fun switchCamera(callback: (Result) -> Unit) {
        if (recordingActive) {
            callback(currentResult(ok = false, error = "recording_in_progress"))
            return
        }
        if (!bound || gpuPipeline == null) {
            callback(Result(ok = false, error = "not_started"))
            return
        }
        lensFacing = if (lensFacing == CameraSelector.LENS_FACING_FRONT) {
            CameraSelector.LENS_FACING_BACK
        } else {
            CameraSelector.LENS_FACING_FRONT
        }
        if (lensFacing == CameraSelector.LENS_FACING_FRONT) {
            torchEnabled = false
        }
        val provider = cameraProvider
        if (provider == null) {
            callback(Result(ok = false, error = "provider_missing"))
            return
        }
        try {
            bindPreview(provider)
            callback(currentResult(ok = true))
        } catch (t: Throwable) {
            Log.e(TAG, "switchCamera failed", t)
            callback(Result(ok = false, error = t.message ?: "switch_failed"))
        }
    }

    fun setFlash(enabled: Boolean, callback: (Result) -> Unit) {
        val cam = camera
        if (cam == null || !bound) {
            callback(Result(ok = false, error = "not_started"))
            return
        }
        if (lensFacing != CameraSelector.LENS_FACING_BACK) {
            callback(Result(ok = false, error = "torch_front_unsupported", isFront = true))
            return
        }
        if (!cam.cameraInfo.hasFlashUnit()) {
            callback(Result(ok = false, error = "torch_unavailable", isFront = false))
            return
        }
        try {
            cam.cameraControl.enableTorch(enabled)
            torchEnabled = enabled
            callback(currentResult(ok = true))
        } catch (t: Throwable) {
            Log.e(TAG, "setFlash failed", t)
            callback(Result(ok = false, error = t.message ?: "torch_failed"))
        }
    }

    /** Phase 2: enable/disable + intensity for the GPU color filter (no Flutter rebuild needed native-side). */
    fun setColorFilter(enabled: Boolean, intensity: Float, callback: (Result) -> Unit) {
        val pipeline = gpuPipeline
        if (pipeline == null) {
            callback(Result(ok = false, error = "not_started"))
            return
        }
        pipeline.setFilterEnabled(enabled)
        pipeline.setFilterIntensity(intensity)
        callback(currentResult(ok = true))
    }

    /** Phase 3: toggle face tracking (+ optional landmark debug overlay). */
    fun setFaceTracking(
        enabled: Boolean,
        landmarkDebug: Boolean,
        callback: (Result) -> Unit,
    ) {
        faceTrackingEnabled = enabled
        landmarkDebugEnabled = enabled && landmarkDebug
        if (!enabled) {
            lastFaceCount.set(0)
            lastPose = FacePose()
            gpuPipeline?.setLandmarkDebugEnabled(false)
            gpuPipeline?.updateLandmarkDebugPoints(FloatArray(0))
            // Keep active effect id, but clear transforms until tracking is back.
            gpuPipeline?.clearFaceEffectTransforms()
            gpuPipeline?.clearBeautyFaceMask()
            gpuPipeline?.clearWarpFace()
            gpuPipeline?.clearMakeupRegions()
        } else {
            ensureFaceTracker()
            gpuPipeline?.setLandmarkDebugEnabled(landmarkDebugEnabled)
        }
        val provider = cameraProvider
        if (bound && provider != null) {
            try {
                bindPreview(provider)
            } catch (t: Throwable) {
                Log.e(TAG, "rebind for face tracking", t)
                callback(Result(ok = false, error = t.message ?: "face_tracking_rebind_failed"))
                return
            }
        }
        callback(currentResult(ok = true))
    }

    /**
     * Phase 4: select a 2D face effect (`null` / `"none"` clears).
     * Enables face tracking automatically when an effect is selected.
     */
    fun setFaceEffect(effectId: String?, callback: (Result) -> Unit) {
        val pipeline = gpuPipeline
        if (pipeline == null) {
            callback(Result(ok = false, error = "not_started"))
            return
        }
        val id = effectId?.takeIf { it.isNotBlank() && !it.equals("none", ignoreCase = true) }
        if (id != null) {
            val known = pipeline.listFaceEffects().any { it.id == id }
            if (!known) {
                callback(Result(ok = false, error = "unknown_effect:$id"))
                return
            }
        }
        pipeline.setFaceEffect(id)
        if (id != null && !faceTrackingEnabled) {
            setFaceTracking(
                enabled = true,
                landmarkDebug = landmarkDebugEnabled,
                callback = callback,
            )
            return
        }
        if (id == null) {
            pipeline.clearFaceEffectTransforms()
        }
        callback(currentResult(ok = true))
    }

    fun listFaceEffects(): List<FaceEffectInfo> {
        return gpuPipeline?.listFaceEffects() ?: FaceEffectCatalog.infoList()
    }

    /**
     * Phase 8: install a remote face effect from local files + layer config.
     */
    fun installFaceEffect(
        id: String,
        name: String,
        version: Int,
        layers: List<Map<String, Any?>>,
        force: Boolean,
        callback: (Result) -> Unit,
    ) {
        val pipeline = gpuPipeline
        if (pipeline == null) {
            callback(Result(ok = false, error = "not_started"))
            return
        }
        try {
            val stickerLayers = ArrayList<FaceStickerLayer>()
            val files = LinkedHashMap<String, String>()
            for (raw in layers) {
                val assetId = raw["assetId"]?.toString() ?: continue
                val filePath = raw["filePath"]?.toString() ?: continue
                files[assetId] = filePath
                stickerLayers.add(
                    FaceStickerLayer(
                        assetId = assetId,
                        leftLandmark = (raw["leftLandmark"] as? Number)?.toInt() ?: 33,
                        rightLandmark = (raw["rightLandmark"] as? Number)?.toInt() ?: 263,
                        anchorLandmark = (raw["anchorLandmark"] as? Number)?.toInt() ?: 168,
                        pinX = parsePinX(raw["pinX"]?.toString()),
                        pinY = parsePinY(raw["pinY"]?.toString()),
                        widthOverRef = (raw["widthOverRef"] as? Number)?.toFloat() ?: 2.4f,
                        widthFaceFrac = (raw["widthFaceFrac"] as? Number)?.toFloat() ?: 0f,
                        offsetXFaceFrac = (raw["offsetXFaceFrac"] as? Number)?.toFloat() ?: 0f,
                        offsetYFaceFrac = (raw["offsetYFaceFrac"] as? Number)?.toFloat() ?: 0f,
                        pivotU = (raw["pivotU"] as? Number)?.toFloat() ?: 0.5f,
                        pivotV = (raw["pivotV"] as? Number)?.toFloat() ?: 0.5f,
                        yawSqueeze = (raw["yawSqueeze"] as? Number)?.toFloat() ?: 0.15f,
                        opacity = (raw["opacity"] as? Number)?.toFloat() ?: 1f,
                    ),
                )
            }
            if (stickerLayers.isEmpty()) {
                callback(Result(ok = false, error = "no_layers"))
                return
            }
            val def = FaceEffectDefinition(
                id = id,
                name = name,
                layers = stickerLayers,
                version = version,
                remote = true,
            )
            val ok = pipeline.installRemoteFaceEffect(def, files, force)
            if (!ok) {
                callback(Result(ok = false, error = "install_failed"))
                return
            }
            callback(currentResult(ok = true))
        } catch (t: Throwable) {
            Log.e(TAG, "installFaceEffect", t)
            callback(Result(ok = false, error = t.message ?: "install_failed"))
        }
    }

    fun unloadFaceEffects(ids: List<String>, callback: (Result) -> Unit) {
        val pipeline = gpuPipeline
        if (pipeline == null) {
            callback(Result(ok = true))
            return
        }
        pipeline.unloadFaceEffects(ids)
        callback(currentResult(ok = true))
    }

    private fun parsePinX(raw: String?): EffectPinX = when (raw?.lowercase()) {
        "anchor" -> EffectPinX.ANCHOR
        else -> EffectPinX.REF_MIDPOINT
    }

    private fun parsePinY(raw: String?): EffectPinY = when (raw?.lowercase()) {
        "ref_midline", "refmidline" -> EffectPinY.REF_MIDLINE
        "above_ref", "aboveref" -> EffectPinY.ABOVE_REF
        else -> EffectPinY.ANCHOR
    }

    /**
     * Phase 5: beauty parameters (0–1). Regional effects auto-enable face tracking.
     */
    fun setBeauty(params: BeautyParameters, callback: (Result) -> Unit) {
        val pipeline = gpuPipeline
        if (pipeline == null) {
            callback(Result(ok = false, error = "not_started"))
            return
        }
        val clamped = params.clamped()
        pipeline.setBeauty(clamped)
        if (!clamped.needsFaceMask()) {
            pipeline.clearBeautyFaceMask()
        }
        if (clamped.needsFaceMask() && !faceTrackingEnabled) {
            setFaceTracking(
                enabled = true,
                landmarkDebug = landmarkDebugEnabled,
                callback = callback,
            )
            return
        }
        callback(currentResult(ok = true))
    }

    /**
     * Phase 6: face mesh deformation (0–1). Auto-enables face tracking when active.
     */
    fun setWarp(params: WarpParameters, callback: (Result) -> Unit) {
        val pipeline = gpuPipeline
        if (pipeline == null) {
            callback(Result(ok = false, error = "not_started"))
            return
        }
        val clamped = params.clamped()
        pipeline.setWarp(clamped)
        if (!clamped.needsFaceTracking()) {
            pipeline.clearWarpFace()
        }
        if (clamped.needsFaceTracking() && !faceTrackingEnabled) {
            setFaceTracking(
                enabled = true,
                landmarkDebug = landmarkDebugEnabled,
                callback = callback,
            )
            return
        }
        callback(currentResult(ok = true))
    }

    /**
     * Phase 7: makeup intensities (0–1). Auto-enables face tracking when active.
     */
    fun setMakeup(params: MakeupParameters, callback: (Result) -> Unit) {
        val pipeline = gpuPipeline
        if (pipeline == null) {
            callback(Result(ok = false, error = "not_started"))
            return
        }
        val clamped = params.clamped()
        pipeline.setMakeup(clamped)
        if (!clamped.needsFaceTracking()) {
            pipeline.clearMakeupRegions()
        }
        if (clamped.needsFaceTracking() && !faceTrackingEnabled) {
            setFaceTracking(
                enabled = true,
                landmarkDebug = landmarkDebugEnabled,
                callback = callback,
            )
            return
        }
        callback(currentResult(ok = true))
    }

    /**
     * Phase 10: set app music bed for the next recording.
     * Pass null [path] to clear. Volumes are 0.0–1.0.
     */
    fun setMusic(
        path: String?,
        offsetMs: Long = 0L,
        musicVolume: Float = 0.8f,
        originalVolume: Float = 0.2f,
        callback: (Result) -> Unit,
    ) {
        this.musicPath = path?.takeIf { it.isNotBlank() }
        this.musicOffsetMs = offsetMs.coerceAtLeast(0L)
        this.musicVolume = musicVolume.coerceIn(0f, 1f)
        this.originalVolume = originalVolume.coerceIn(0f, 1f)
        callback(currentResult(ok = true))
    }

    fun clearMusic(callback: (Result) -> Unit) {
        setMusic(null, 0L, musicVolume, originalVolume, callback)
    }

    /**
     * Phase 11: export [inputPath] (or last recording) to ≤1080p H.264 @ ~8 Mbps.
     * Completes via [callback] when done. Passthrough when already within profile
     * unless [force] is true.
     */
    fun exportVideo(
        inputPath: String? = null,
        force: Boolean = false,
        callback: (Result) -> Unit,
    ) {
        if (recordingActive || recorder.isRecording()) {
            callback(currentResult(ok = false, error = "recording_in_progress"))
            return
        }
        if (exporter.isExporting()) {
            callback(currentResult(ok = false, error = "export_in_progress"))
            return
        }
        val srcPath = inputPath?.takeIf { it.isNotBlank() } ?: lastRecordingPath
        if (srcPath.isNullOrBlank()) {
            callback(currentResult(ok = false, error = "no_input_video"))
            return
        }
        val input = File(srcPath)
        if (!input.exists() || input.length() == 0L) {
            callback(currentResult(ok = false, error = "input_missing"))
            return
        }
        val dir = File(activity.cacheDir, "camera_engine_exports")
        if (!dir.exists()) dir.mkdirs()
        val out = File(dir, "exp_${System.currentTimeMillis()}.mp4")
        exportProgressPct = 0
        lastExportPath = null
        lastExportPassthrough = false

        cameraExecutor.execute {
            val latch = java.util.concurrent.CountDownLatch(1)
            var outcome: VideoExporter.ExportOutcome? = null
            exporter.export(
                input = input,
                output = out,
                force = force,
                onProgress = { pct -> exportProgressPct = pct },
                onComplete = { result ->
                    outcome = result
                    latch.countDown()
                },
            )
            try {
                latch.await(5, java.util.concurrent.TimeUnit.MINUTES)
            } catch (_: InterruptedException) {
            }
            val done = outcome
            mainHandler.post {
                exportProgressPct = if (done?.ok == true) 100 else exportProgressPct
                lastExportPath = done?.path
                lastExportPassthrough = done?.passthrough == true
                if (done?.ok == true) {
                    callback(
                        currentResult(ok = true).copy(
                            exportPath = done.path,
                            exportProgress = 100,
                            exportPassthrough = done.passthrough,
                        ),
                    )
                } else {
                    callback(
                        currentResult(
                            ok = false,
                            error = done?.error ?: "export_failed",
                        ),
                    )
                }
            }
        }
    }

    fun cancelExport(callback: (Result) -> Unit) {
        exporter.cancel()
        exportProgressPct = 0
        callback(currentResult(ok = true))
    }

    /**
     * Phase 9–10: start hardware H.264 recording of the GPU-composited preview + audio mix.
     */
    fun startRecording(withAudio: Boolean = true, callback: (Result) -> Unit) {
        val pipeline = gpuPipeline
        if (pipeline == null || !bound) {
            callback(Result(ok = false, error = "not_started"))
            return
        }
        synchronized(recordingLock) {
            if (recordingActive || recorder.isRecording()) {
                callback(currentResult(ok = false, error = "already_recording"))
                return
            }
            val music = AudioMusicMixer.Config(
                musicPath = musicPath,
                musicOffsetMs = musicOffsetMs,
                musicVolume = musicVolume,
                originalVolume = if (withAudio) originalVolume else 0f,
            )
            val needMic = withAudio && music.keepOriginal
            val useAudio = needMic && hasAudioPermission()
            if (needMic && !useAudio) {
                Log.w(TAG, "RECORD_AUDIO missing — recording without mic")
            }
            try {
                val dir = File(activity.cacheDir, "camera_engine_recordings")
                if (!dir.exists()) dir.mkdirs()
                recorder.checkStorage(dir)?.let { err ->
                    callback(currentResult(ok = false, error = err))
                    return
                }
                if (music.hasMusic) {
                    val f = File(music.musicPath!!)
                    if (!f.exists() || f.length() == 0L) {
                        callback(currentResult(ok = false, error = "music_file_missing"))
                        return
                    }
                }
                val out = File(dir, "rec_${System.currentTimeMillis()}.mp4")
                val encW = previewWidth.coerceAtMost(HardwareVideoRecorder.MAX_WIDTH)
                val encH = previewHeight.coerceAtMost(HardwareVideoRecorder.MAX_HEIGHT)
                val mixConfig = music.copy(
                    originalVolume = if (useAudio) music.originalVolume else 0f,
                )
                val surface = recorder.start(
                    output = out,
                    encodeWidth = encW,
                    encodeHeight = encH,
                    orientationHint = 0,
                    withAudio = useAudio,
                    music = mixConfig,
                )
                val mirror = lensFacing == CameraSelector.LENS_FACING_FRONT
                pipeline.setEncoderTarget(surface, encW, encH, mirror)
                recordingActive = true
                lastRecordingPath = null
                Log.i(
                    TAG,
                    "recording started ${out.name} ${encW}x$encH " +
                        "mic=$useAudio music=${mixConfig.hasMusic} " +
                        "origVol=${mixConfig.originalVolume} musicVol=${mixConfig.musicVolume}",
                )
                callback(currentResult(ok = true))
            } catch (t: Throwable) {
                Log.e(TAG, "startRecording", t)
                try {
                    pipeline.clearEncoderTarget()
                } catch (_: Throwable) {
                }
                recorder.cancel()
                recordingActive = false
                callback(currentResult(ok = false, error = t.message ?: "start_recording_failed"))
            }
        }
    }

    fun stopRecording(callback: (Result) -> Unit) {
        cameraExecutor.execute {
            val path = stopRecordingInternal()
            mainHandler.post {
                if (path != null) {
                    callback(currentResult(ok = true).copy(recordingPath = path))
                } else {
                    callback(currentResult(ok = false, error = "stop_recording_failed"))
                }
            }
        }
    }

    fun cancelRecording(callback: (Result) -> Unit) {
        cameraExecutor.execute {
            cancelRecordingInternal()
            mainHandler.post {
                callback(currentResult(ok = true))
            }
        }
    }

    private fun stopRecordingInternal(): String? {
        val shouldStop: Boolean
        synchronized(recordingLock) {
            shouldStop = recordingActive || recorder.isRecording()
            if (!shouldStop) return lastRecordingPath
            recordingActive = false
            try {
                gpuPipeline?.clearEncoderTarget()
            } catch (t: Throwable) {
                Log.w(TAG, "clearEncoderTarget", t)
            }
        }
        // Mix / MediaCodec finalize outside recordingLock so cancel/dispose aren't blocked.
        val file = try {
            recorder.stop()
        } catch (t: Throwable) {
            Log.e(TAG, "recorder.stop", t)
            null
        }
        val path = file?.absolutePath
        lastRecordingPath = path
        Log.i(TAG, "recording stopped path=$path")
        return path
    }

    private fun cancelRecordingInternal() {
        synchronized(recordingLock) {
            try {
                gpuPipeline?.clearEncoderTarget()
            } catch (_: Throwable) {
            }
            try {
                recorder.cancel()
            } catch (_: Throwable) {
            }
            recordingActive = false
            lastRecordingPath = null
        }
    }

    private fun hasAudioPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun stop(callback: (Result) -> Unit) {
        try {
            cancelRecordingInternal()
            unbindCameraOnly()
            callback(Result(ok = true, textureId = textureEntry?.id()))
        } catch (t: Throwable) {
            Log.e(TAG, "stop failed", t)
            callback(Result(ok = false, error = t.message ?: "stop_failed"))
        }
    }

    fun dispose() {
        if (!disposed.compareAndSet(false, true)) return
        pendingStart = null
        faceTrackingEnabled = false
        landmarkDebugEnabled = false
        try {
            activity.applicationContext.unregisterComponentCallbacks(trimCallbacks)
        } catch (_: Throwable) {
        }
        try {
            cancelRecordingInternal()
            exporter.cancel()
            recorder.release()
            unbindCameraOnly()
        } catch (t: Throwable) {
            Log.w(TAG, "dispose unbind", t)
        }
        // Wait briefly for in-flight analyzer frame to finish before tearing GL.
        var spins = 0
        while (analyzing.get() && spins++ < 40) {
            try {
                Thread.sleep(10)
            } catch (_: InterruptedException) {
                break
            }
        }
        releaseFaceTracker()
        releaseGpuPipeline()
        releaseTextureEntry()
        purgeOldCacheFiles()
        cameraProvider = null
        try {
            cameraExecutor.shutdownNow()
        } catch (_: Throwable) {
        }
        try {
            analysisExecutor.shutdownNow()
        } catch (_: Throwable) {
        }
    }

    /** Drop stale recordings/exports from previous sessions (cacheDir). */
    private fun purgeOldCacheFiles() {
        try {
            val roots = listOf(
                File(activity.cacheDir, "camera_engine_recordings"),
                File(activity.cacheDir, "camera_engine_exports"),
            )
            val cutoff = System.currentTimeMillis() - 24L * 60L * 60L * 1000L
            for (dir in roots) {
                if (!dir.isDirectory) continue
                dir.listFiles()?.forEach { f ->
                    if (f.isFile && f.lastModified() < cutoff) {
                        try {
                            f.delete()
                        } catch (_: Exception) {
                        }
                    }
                }
            }
        } catch (t: Throwable) {
            Log.w(TAG, "purgeOldCacheFiles", t)
        }
    }

    fun getState(): Result = currentResult(ok = bound)

    private fun currentResult(ok: Boolean, error: String? = null): Result {
        val cam = camera
        val torchAvail = cam?.cameraInfo?.hasFlashUnit() == true &&
            lensFacing == CameraSelector.LENS_FACING_BACK
        val filter = gpuPipeline?.filterEffect
        val pose = lastPose
        val beauty = currentBeauty()
        val warp = currentWarp()
        val makeup = currentMakeup()
        return Result(
            ok = ok,
            textureId = textureEntry?.id(),
            width = previewWidth,
            height = previewHeight,
            isFront = lensFacing == CameraSelector.LENS_FACING_FRONT,
            torchEnabled = torchEnabled && torchAvail,
            torchAvailable = torchAvail,
            filterEnabled = filter?.enabled ?: true,
            filterIntensity = filter?.intensity ?: 0.55f,
            faceTrackingEnabled = faceTrackingEnabled,
            landmarkDebugEnabled = landmarkDebugEnabled,
            faceCount = lastFaceCount.get(),
            pitchDeg = pose.pitchDeg,
            yawDeg = pose.yawDeg,
            rollDeg = pose.rollDeg,
            activeFaceEffectId = gpuPipeline?.activeFaceEffectId(),
            beautyEnabled = beauty.enabled,
            beautySkinSmooth = beauty.skinSmooth,
            beautyBrightness = beauty.brightness,
            beautySkinTone = beauty.skinTone,
            beautySharpen = beauty.sharpen,
            beautyEyeEnhancement = beauty.eyeEnhancement,
            warpEnabled = warp.enabled,
            warpFaceSlim = warp.faceSlim,
            warpBigEyes = warp.bigEyes,
            warpSmallNose = warp.smallNose,
            warpBigLips = warp.bigLips,
            warpJaw = warp.jaw,
            warpChin = warp.chin,
            makeupEnabled = makeup.enabled,
            makeupLipstick = makeup.lipstick,
            makeupBlush = makeup.blush,
            makeupEyeliner = makeup.eyeliner,
            makeupEyeshadow = makeup.eyeshadow,
            recording = recordingActive || recorder.isRecording(),
            recordingPath = lastRecordingPath,
            recordingDurationMs = recorder.durationMs(),
            musicPath = musicPath,
            musicOffsetMs = musicOffsetMs,
            musicVolume = musicVolume,
            originalVolume = originalVolume,
            exporting = exporter.isExporting(),
            exportPath = lastExportPath,
            exportProgress = when {
                exporter.isExporting() -> exportProgressPct
                lastExportPath != null -> 100
                else -> exportProgressPct
            },
            exportPassthrough = lastExportPassthrough,
            error = error,
        )
    }

    private fun currentBeauty(): BeautyParameters {
        return gpuPipeline?.getBeauty() ?: BeautyParameters()
    }

    private fun currentWarp(): WarpParameters {
        return gpuPipeline?.getWarp() ?: WarpParameters()
    }

    private fun currentMakeup(): MakeupParameters {
        return gpuPipeline?.getMakeup() ?: MakeupParameters()
    }

    private fun ensureTextureEntry() {
        if (textureEntry != null) return
        textureEntry = textureRegistry.createSurfaceTexture()
        Log.i(TAG, "created Flutter texture id=${textureEntry?.id()}")
    }

    private fun ensureGpuPipeline() {
        if (gpuPipeline != null) return
        val entry = textureEntry ?: throw IllegalStateException("texture_missing")
        val flutterSt = entry.surfaceTexture()
        val pipeline = GpuPreviewPipeline(
            flutterSurfaceTexture = flutterSt,
            outputWidth = NativeCameraConstants.PREVIEW_WIDTH,
            outputHeight = NativeCameraConstants.PREVIEW_HEIGHT,
        )
        pipeline.bootstrapFaceEffects(activity)
        // Creates GL thread + camera OES surface.
        pipeline.startAndCreateCameraSurface()
        gpuPipeline = pipeline
        Log.i(TAG, "GPU pipeline started")
    }

    private fun bindPreview(provider: ProcessCameraProvider) {
        val pipeline = gpuPipeline
            ?: throw IllegalStateException("gpu_pipeline_missing")
        val cameraSurface = pipeline.cameraOutputSurface()

        provider.unbindAll()

        val requestedSelector = selectorFor(lensFacing)
        val selector = if (provider.hasCamera(requestedSelector)) {
            requestedSelector
        } else {
            val fallbackLens = if (lensFacing == CameraSelector.LENS_FACING_FRONT) {
                CameraSelector.LENS_FACING_BACK
            } else {
                CameraSelector.LENS_FACING_FRONT
            }
            val fallbackSelector = selectorFor(fallbackLens)
            if (!provider.hasCamera(fallbackSelector)) {
                throw IllegalStateException("no_camera_available")
            }
            Log.w(
                TAG,
                "Requested lens is unavailable; falling back to lensFacing=$fallbackLens",
            )
            lensFacing = fallbackLens
            fallbackSelector
        }

        val resolutionSelector = ResolutionSelector.Builder()
            .setResolutionStrategy(
                ResolutionStrategy(
                    Size(
                        NativeCameraConstants.PREVIEW_WIDTH,
                        NativeCameraConstants.PREVIEW_HEIGHT,
                    ),
                    ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER,
                ),
            )
            .build()

        val previewUseCase = Preview.Builder()
            .setResolutionSelector(resolutionSelector)
            .setTargetRotation(currentDisplayRotation())
            .build()

        previewUseCase.setSurfaceProvider { request ->
            val resolution = request.resolution
            previewWidth = resolution.width
            previewHeight = resolution.height
            gpuPipeline?.setOutputSize(resolution.width, resolution.height)
            Log.i(
                TAG,
                "CameraX→OES ${resolution.width}x${resolution.height} " +
                    "textureId=${textureEntry?.id()} " +
                    "front=${lensFacing == CameraSelector.LENS_FACING_FRONT}",
            )
            // Pipeline owns the Surface — do not release in the completion callback.
            request.provideSurface(cameraSurface, cameraExecutor) {
                // no-op
            }
        }

        val useCases = mutableListOf<androidx.camera.core.UseCase>(previewUseCase)
        imageAnalysis = null
        if (faceTrackingEnabled) {
            ensureFaceTracker()
            val analysis = buildImageAnalysis()
            imageAnalysis = analysis
            useCases.add(analysis)
        }

        val boundCamera = provider.bindToLifecycle(
            activity,
            selector,
            *useCases.toTypedArray(),
        )
        preview = previewUseCase
        camera = boundCamera
        bound = true

        if (torchEnabled &&
            lensFacing == CameraSelector.LENS_FACING_BACK &&
            boundCamera.cameraInfo.hasFlashUnit()
        ) {
            try {
                boundCamera.cameraControl.enableTorch(true)
            } catch (t: Throwable) {
                Log.w(TAG, "re-enable torch", t)
                torchEnabled = false
            }
        } else if (lensFacing == CameraSelector.LENS_FACING_FRONT) {
            torchEnabled = false
        }
    }

    private fun selectorFor(lens: Int): CameraSelector = CameraSelector.Builder()
        .requireLensFacing(lens)
        .build()

    private fun buildImageAnalysis(): ImageAnalysis {
        val resolutionSelector = ResolutionSelector.Builder()
            .setResolutionStrategy(
                ResolutionStrategy(
                    Size(ANALYSIS_WIDTH, ANALYSIS_HEIGHT),
                    ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER,
                ),
            )
            .build()

        return ImageAnalysis.Builder()
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_YUV_420_888)
            .setResolutionSelector(resolutionSelector)
            .setTargetRotation(currentDisplayRotation())
            .build()
            .also { analysis ->
                analysis.setAnalyzer(analysisExecutor) { imageProxy ->
                    if (!faceTrackingEnabled) {
                        imageProxy.close()
                        return@setAnalyzer
                    }
                    val frame = analysisFrameCounter.incrementAndGet()
                    if (frame % ANALYSIS_FRAME_STRIDE != 0) {
                        imageProxy.close()
                        return@setAnalyzer
                    }
                    if (!analyzing.compareAndSet(false, true)) {
                        imageProxy.close()
                        return@setAnalyzer
                    }
                    try {
                        analyzeFaceFrame(imageProxy)
                    } finally {
                        analyzing.set(false)
                    }
                }
            }
    }

    private fun analyzeFaceFrame(imageProxy: androidx.camera.core.ImageProxy) {
        var closed = false
        var raw: android.graphics.Bitmap? = null
        var oriented: android.graphics.Bitmap? = null
        try {
            if (disposed.get() || !faceTrackingEnabled) {
                imageProxy.close()
                closed = true
                return
            }
            val tracker = faceTracker
            if (tracker == null || !tracker.isReady()) {
                imageProxy.close()
                closed = true
                return
            }
            val rotation = imageProxy.imageInfo.rotationDegrees
            raw = ImageProxyBitmapUtils.toBitmap(imageProxy)
            imageProxy.close()
            closed = true
            if (raw == null) return

            val isFront = lensFacing == CameraSelector.LENS_FACING_FRONT
            oriented = ImageProxyBitmapUtils.orientScaled(
                raw,
                rotation,
                isFront,
                ANALYSIS_MAX_EDGE,
            )
            if (oriented !== raw && !raw.isRecycled) {
                raw.recycle()
                raw = null
            }

            val result = tracker.processBitmap(oriented!!, SystemClock.uptimeMillis())
            if (result == null || result.faces.isEmpty()) {
                lastFaceCount.set(0)
                lastPose = FacePose()
                gpuPipeline?.clearFaceEffectTransforms()
                gpuPipeline?.clearBeautyFaceMask()
                gpuPipeline?.clearWarpFace()
                gpuPipeline?.clearMakeupRegions()
                if (landmarkDebugEnabled) {
                    gpuPipeline?.updateLandmarkDebugPoints(FloatArray(0))
                }
                return
            }

            lastFaceCount.set(result.faces.size)
            lastPose = result.faces.first().pose

            // Analysis bitmap is already mirrored for front via orientScaled — no extra mirror.
            gpuPipeline?.updateFaceEffectLandmarks(result.faces, mirrorX = false)
            gpuPipeline?.updateBeautyFaceMask(result.faces)
            gpuPipeline?.updateWarpFromFaces(result.faces)
            gpuPipeline?.updateMakeupRegions(result.faces)

            if (landmarkDebugEnabled) {
                val packed = ArrayList<Float>(result.faces.sumOf { it.count } * 2)
                for (face in result.faces) {
                    for (v in face.normalizedXy) packed.add(v)
                }
                gpuPipeline?.updateLandmarkDebugPoints(packed.toFloatArray())
            }
        } catch (t: Throwable) {
            Log.w(TAG, "analyzeFaceFrame", t)
            if (!closed) {
                try {
                    imageProxy.close()
                } catch (_: Throwable) {
                }
            }
        } finally {
            try {
                if (oriented != null && !oriented.isRecycled) oriented.recycle()
            } catch (_: Throwable) {
            }
            try {
                if (raw != null && !raw.isRecycled) raw.recycle()
            } catch (_: Throwable) {
            }
        }
    }

    private fun ensureFaceTracker() {
        if (faceTracker?.isReady() == true) return
        releaseFaceTracker()
        val tracker = MediaPipeFaceTracker(activity, maxFaces = 2)
        tracker.start()
        faceTracker = tracker
    }

    private fun releaseFaceTracker() {
        try {
            faceTracker?.release()
        } catch (_: Throwable) {
        }
        faceTracker = null
        lastFaceCount.set(0)
        lastPose = FacePose()
    }

    private fun currentDisplayRotation(): Int {
        return if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            activity.display?.rotation ?: Surface.ROTATION_0
        } else {
            @Suppress("DEPRECATION")
            activity.windowManager.defaultDisplay.rotation
        }
    }

    private fun unbindCameraOnly() {
        bound = false
        try {
            camera?.cameraControl?.enableTorch(false)
        } catch (_: Throwable) {
        }
        torchEnabled = false
        try {
            imageAnalysis?.clearAnalyzer()
        } catch (_: Throwable) {
        }
        try {
            cameraProvider?.unbindAll()
        } catch (t: Throwable) {
            Log.w(TAG, "unbindAll", t)
        }
        camera = null
        preview = null
        imageAnalysis = null
    }

    private fun releaseGpuPipeline() {
        try {
            gpuPipeline?.release()
        } catch (t: Throwable) {
            Log.w(TAG, "gpu release", t)
        }
        gpuPipeline = null
    }

    private fun releaseTextureEntry() {
        try {
            textureEntry?.release()
        } catch (t: Throwable) {
            Log.w(TAG, "texture release", t)
        }
        textureEntry = null
    }
}
