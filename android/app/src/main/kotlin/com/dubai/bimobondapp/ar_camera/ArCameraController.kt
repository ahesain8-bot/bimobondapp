package com.dubai.bimobondapp.ar_camera

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import android.util.Size
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
import java.util.concurrent.atomic.AtomicBoolean

object ArCameraController {
    // Live preview uses a lighter analysis size for smooth filter FPS.
    private const val ANALYSIS_WIDTH = 720
    private const val ANALYSIS_HEIGHT = 960
    private const val DETECT_MAX_DIMENSION = 320
    private const val GL_MAX_EDGE = 720
    private const val CAPTURE_MAX_EDGE = 720
    private const val RECORD_FRAME_INTERVAL_MS = 66L // ~15 fps while recording

    private var faceLandmarker: FaceLandmarkerHelper? = null
    private var started = false
    private var analysisExecutor: ExecutorService? = null
    private val convertingFrame = AtomicBoolean(false)
    private var frameCounter = 0
    private val mainHandler = Handler(Looper.getMainLooper())
    private val videoRecorder = ArFilteredVideoRecorder()
    private val captureBusy = AtomicBoolean(false)
    private val recordingPixelCopyBusy = AtomicBoolean(false)

    @Volatile
    private var imageCapture: ImageCapture? = null

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
        convertingFrame.set(false)
        frameCounter = 0
        cachedWarpParams = FaceWarpParams.INACTIVE
        cachedSnapshot = null
        FaceLandmarkSmoother.reset()
        faceLandmarker = null
        analysisExecutor?.shutdownNow()
        analysisExecutor = null
        imageCapture = null
        lastCaptureBitmap?.recycle()
        lastCaptureBitmap = null
        ArCameraBridge.faceOverlay?.clearUnderlay()
        unbindCamera()
    }

    fun abortCapture() {
        recording = false
        videoRecorder.abort()
        captureBusy.set(false)
        recordingPixelCopyBusy.set(false)
    }

    /** Saves a still photo. Uses CameraX ImageCapture (reliable); bakes AR filter when needed. */
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

        // Hard timeout so Flutter never hangs with isBusy forever.
        mainHandler.postDelayed({
            deliver(null, "photo_timeout")
        }, 8_000L)

        val filter = ArCameraBridge.currentFilter
        if (filter != FilterType.NONE) {
            // One short wait for a baked filtered frame, then fall back to ImageCapture.
            fun tryBaked(remaining: Int) {
                snapshotVisibleFrame { bitmap ->
                    if (bitmap != null) {
                        try {
                            val activity = ArCameraBridge.hostActivity
                                ?: run {
                                    deliver(null, "no_activity")
                                    return@snapshotVisibleFrame
                                }
                            val file = File(
                                activity.cacheDir,
                                "ar_photo_${System.currentTimeMillis()}.jpg",
                            )
                            FileOutputStream(file).use { out ->
                                bitmap.compress(Bitmap.CompressFormat.JPEG, 92, out)
                            }
                            if (bitmap !== lastCaptureBitmap) bitmap.recycle()
                            deliver(file.absolutePath, null)
                        } catch (e: Exception) {
                            takePhotoWithImageCapture(::deliver)
                        }
                        return@snapshotVisibleFrame
                    }
                    if (remaining > 0) {
                        mainHandler.postDelayed({ tryBaked(remaining - 1) }, 50)
                    } else {
                        takePhotoWithImageCapture(::deliver)
                    }
                }
            }
            tryBaked(6)
            return
        }

        takePhotoWithImageCapture(::deliver)
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
                            var selfie = ImageProxyBitmapUtils.toUprightMirroredSelfie(image)
                            if (selfie == null) {
                                onResult(null, "decode_failed")
                                return
                            }
                            selfie = bakeFilterOntoBitmap(selfie)
                            FileOutputStream(file).use { out ->
                                selfie.compress(Bitmap.CompressFormat.JPEG, 92, out)
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
            // Encoder starts on the first PixelCopy frame so aspect matches preview.
            videoRecorder.arm(file, activity)
            recording = true
            lastRecordCopyMs = 0L
            if (ArCameraBridge.currentFilter.isDistortion()) {
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
        try {
            ArCameraBridge.warpGlView?.setCaptureEnabled(
                ArCameraBridge.currentFilter.isDistortion(),
            )
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

    private fun snapshotVisibleFrame(onDone: (Bitmap?) -> Unit) {
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

        // PNG + color grades: bake on CPU from the live analysis frame (reliable).
        if (!filter.isDistortion()) {
            mainHandler.post { onDone(bakeAnalysisFrame()) }
            return
        }

        // Face warp: prefer the last GPU-rendered frame over unfiltered analysis.
        val gl = ArCameraBridge.warpGlView
        if (gl != null && gl.visibility == View.VISIBLE && gl.isGlInitialized()) {
            gl.setCaptureEnabled(true)
            // Let at least one filtered draw land, then read it back.
            mainHandler.postDelayed({
                val gpu = try {
                    gl.copyLastFilteredFrame()
                } catch (_: Exception) {
                    null
                }
                if (gpu != null && !isMostlyEmpty(gpu)) {
                    val scaled = try {
                        ImageProxyBitmapUtils.scaleToMaxDimension(
                            gpu,
                            CAPTURE_MAX_EDGE,
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
            }, 60)
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
        // Distortion: pull the latest GL-filtered frame directly (no PixelCopy race).
        if (filter.isDistortion()) {
            val gl = ArCameraBridge.warpGlView
            gl?.setCaptureEnabled(true)
            val gpu = try {
                gl?.copyLastFilteredFrame()
            } catch (_: Exception) {
                null
            }
            if (gpu != null && !isMostlyEmpty(gpu)) {
                try {
                    if (recording && videoRecorder.isRecording()) {
                        videoRecorder.offerFrame(gpu)
                    }
                } finally {
                    gpu.recycle()
                    recordingPixelCopyBusy.set(false)
                }
                return
            }
            gpu?.recycle()
        }

        snapshotVisibleFrame { bitmap ->
            try {
                if (bitmap != null && recording && videoRecorder.isRecording()) {
                    videoRecorder.offerFrame(bitmap)
                }
            } finally {
                if (bitmap != null && bitmap !== lastCaptureBitmap) bitmap.recycle()
                recordingPixelCopyBusy.set(false)
            }
        }
    }

    /** Applies active PNG / color-grade filter onto a mirrored camera bitmap. */
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
        // Always keep the latest analysis frame so shutter works on Original and
        // color grades without waiting on fragile SurfaceView PixelCopy.
        if (source.isRecycled) return
        val copy = try {
            ImageProxyBitmapUtils.scaleToMaxDimension(source, CAPTURE_MAX_EDGE, filter = true)
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

    private fun bindCamera(
        lifecycleOwner: LifecycleOwner,
        previewView: PreviewView,
        faceOverlay: FaceOverlayView,
    ) {
        val activity = ArCameraBridge.hostActivity ?: return
        val executor = analysisExecutor ?: return
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
            preview.surfaceProvider = previewView.surfaceProvider

            val imageAnalysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                .setTargetResolution(target)
                .setTargetRotation(displayRotation)
                .build()

            imageAnalysis.setAnalyzer(executor) { imageProxy ->
                processImage(imageProxy, faceOverlay, activity)
            }

            val capture = ImageCapture.Builder()
                .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
                .setTargetRotation(displayRotation)
                .build()
            imageCapture = capture

            cameraProvider.unbindAll()
            try {
                cameraProvider.bindToLifecycle(
                    lifecycleOwner,
                    CameraSelector.DEFAULT_FRONT_CAMERA,
                    preview,
                    imageAnalysis,
                    capture,
                )
            } catch (_: Exception) {
                // Prefer keeping ImageCapture so the shutter still works.
                try {
                    cameraProvider.unbindAll()
                    cameraProvider.bindToLifecycle(
                        lifecycleOwner,
                        CameraSelector.DEFAULT_FRONT_CAMERA,
                        preview,
                        capture,
                    )
                    imageCapture = capture
                } catch (_: Exception) {
                    try {
                        cameraProvider.unbindAll()
                        cameraProvider.bindToLifecycle(
                            lifecycleOwner,
                            CameraSelector.DEFAULT_FRONT_CAMERA,
                            preview,
                            imageAnalysis,
                        )
                    } catch (_: Exception) {
                    }
                    imageCapture = null
                }
            }
        }, ContextCompat.getMainExecutor(activity))
    }

    private fun processImage(
        imageProxy: ImageProxy,
        faceOverlay: FaceOverlayView,
        activity: Activity,
    ) {
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

            // Original filter: PreviewView shows the live feed. Skip heavy
            // bitmap conversion — stills use CameraX ImageCapture instead.
            if (filter == FilterType.NONE && !recording) {
                imageProxy.close()
                return
            }

            val rawBitmap = ImageProxyBitmapUtils.toBitmap(imageProxy)
            imageProxy.close()

            if (rawBitmap == null) {
                convertingFrame.set(false)
                return
            }

            oriented = ImageProxyBitmapUtils.rotate(rawBitmap, rotation)
            if (oriented !== rawBitmap) rawBitmap.recycle()

            val needsFace =
                filter.isDistortion() || filter.isBeauty() || filter.isPngOverlay()
            // Less frequent detection keeps live preview snappy.
            val detectEvery = if (needsFace) 3 else 4
            val runDetection =
                needsFace && (frameCounter % detectEvery == 0 || cachedSnapshot == null)

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
                        cachedSnapshot = FaceLandmarkSmoother.smooth(raw)
                    } else if (filter.isDistortion()) {
                        cachedSnapshot = null
                        cachedWarpParams = FaceWarpParams.INACTIVE
                    }
                }
            }

            val activeSnapshot = cachedSnapshot

            when {
                filter.useShader() -> {
                    display = ImageProxyBitmapUtils.mirrorHorizontally(oriented)
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

                    // Downscale before GPU upload — biggest live FPS win.
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

                    retainCaptureFrame(display)
                    glView.submitFrameWithParams(display, params)
                    display = null
                    ArCameraBridge.onGlFramePresented()
                    maybeCaptureRecordingFrame()
                }

                else -> {
                    val mirrored = ImageProxyBitmapUtils.mirrorHorizontally(oriented)
                    if (mirrored !== oriented) {
                        oriented.recycle()
                        oriented = null
                    }
                    retainCaptureFrame(mirrored)

                    if (filter.isPngOverlay()) {
                        // Same mirrored frame landmarks come from — locks glasses/dog to the face.
                        val underlay = try {
                            ImageProxyBitmapUtils.scaleToMaxDimension(
                                mirrored,
                                CAPTURE_MAX_EDGE,
                                filter = true,
                            ).let { scaled ->
                                if (scaled !== mirrored) {
                                    scaled
                                } else {
                                    mirrored.copy(Bitmap.Config.ARGB_8888, false)
                                }
                            }
                        } catch (_: Exception) {
                            null
                        }
                        val snapshots = activeSnapshot?.let { listOf(it) } ?: emptyList()
                        val landmarkW = activeSnapshot?.imageWidth ?: mirrored.width
                        val landmarkH = activeSnapshot?.imageHeight ?: mirrored.height
                        val expectedFilter = filter
                        activity.runOnUiThread {
                            // Drop late frames after user swiped back to Original / another filter.
                            if (ArCameraBridge.currentFilter != expectedFilter) {
                                underlay?.takeIf { !it.isRecycled }?.recycle()
                                return@runOnUiThread
                            }
                            if (underlay != null) {
                                faceOverlay.setUnderlayFrame(underlay)
                            }
                            faceOverlay.setLandmarks(
                                snapshots,
                                landmarkW,
                                landmarkH,
                                isFrontCamera = true,
                            )
                        }
                    }

                    if (mirrored !== lastCaptureBitmap) {
                        mirrored.recycle()
                    }
                    maybeCaptureRecordingFrame()
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
