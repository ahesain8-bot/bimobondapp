package com.dubai.bimobondapp.ar_camera

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Handler
import android.os.Looper
import android.util.Size
import android.view.PixelCopy
import android.view.SurfaceView
import android.view.View
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
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
            ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.CAMERA), 100)
            return
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

    /** Saves the current on-screen (filtered) frame as a JPEG. */
    fun takePhoto(onResult: (String?, String?) -> Unit) {
        if (!captureBusy.compareAndSet(false, true)) {
            onResult(null, "busy")
            return
        }
        val activity = ArCameraBridge.hostActivity
        if (activity == null) {
            captureBusy.set(false)
            onResult(null, "no_activity")
            return
        }

        snapshotVisibleFrame { bitmap ->
            val activityRef = ArCameraBridge.hostActivity
            val deliver = { path: String?, error: String? ->
                activityRef?.runOnUiThread { onResult(path, error) } ?: onResult(path, error)
            }
            try {
                if (bitmap == null) {
                    deliver(null, "no_frame")
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
                deliver(null, e.message ?: "photo_failed")
            } finally {
                captureBusy.set(false)
            }
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
            // Encoder starts on the first PixelCopy frame so aspect matches preview.
            videoRecorder.arm(file)
            recording = true
            lastRecordCopyMs = 0L
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

    private fun snapshotVisibleFrame(onDone: (Bitmap?) -> Unit) {
        // PNG overlays (glasses/dog) live on FaceOverlayView — bake them onto the camera frame.
        if (ArCameraBridge.currentFilter.isPngOverlay()) {
            mainHandler.post {
                val base = safeCopyBitmap(lastCaptureBitmap)
                if (base == null) {
                    onDone(null)
                    return@post
                }
                val composed = try {
                    ArCameraBridge.faceOverlay?.composeOnto(base) ?: base
                } catch (_: Exception) {
                    base
                }
                onDone(composed)
            }
            return
        }

        val root = ArCameraBridge.platformRoot
        if (root == null || root.width <= 0 || root.height <= 0) {
            onDone(safeCopyBitmap(lastCaptureBitmap))
            return
        }

        mainHandler.post {
            try {
                val w = root.width
                val h = root.height
                val out = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                val target = findPixelCopyTarget(root)
                if (target != null) {
                    PixelCopy.request(target, out, { result ->
                        if (result == PixelCopy.SUCCESS) {
                            val scaled = try {
                                ImageProxyBitmapUtils.scaleToMaxDimension(
                                    out,
                                    CAPTURE_MAX_EDGE,
                                    filter = true,
                                )
                            } catch (_: Exception) {
                                out
                            }
                            if (scaled !== out) out.recycle()
                            onDone(scaled)
                        } else {
                            out.recycle()
                            onDone(drawSoftwareSnapshot(root) ?: safeCopyBitmap(lastCaptureBitmap))
                        }
                    }, mainHandler)
                } else {
                    val soft = drawSoftwareSnapshot(root)
                    if (soft != null) {
                        out.recycle()
                        onDone(soft)
                    } else {
                        onDone(out)
                    }
                }
            } catch (_: Exception) {
                onDone(safeCopyBitmap(lastCaptureBitmap))
            }
        }
    }

    private fun safeCopyBitmap(source: Bitmap?): Bitmap? {
        if (source == null || source.isRecycled) return null
        return try {
            source.copy(Bitmap.Config.ARGB_8888, false)
        } catch (_: Exception) {
            null
        }
    }

    private fun findPixelCopyTarget(root: View): SurfaceView? {
        val gl = ArCameraBridge.warpGlView
        if (gl != null && gl.visibility == View.VISIBLE) return gl
        // PreviewView often hosts a TextureView/SurfaceView internally.
        return findSurfaceView(root)
    }

    private fun findSurfaceView(view: View): SurfaceView? {
        if (view is SurfaceView) return view
        if (view is android.view.ViewGroup) {
            for (i in 0 until view.childCount) {
                val found = findSurfaceView(view.getChildAt(i))
                if (found != null) return found
            }
        }
        return null
    }

    private fun drawSoftwareSnapshot(root: View): Bitmap? {
        return try {
            val bmp = Bitmap.createBitmap(root.width, root.height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            root.draw(canvas)
            bmp
        } catch (_: Exception) {
            null
        }
    }

    private fun retainCaptureFrame(source: Bitmap) {
        // Keep frames for PNG overlays so photo/video can bake glasses/dog stickers.
        val needFrame =
            recording ||
                captureBusy.get() ||
                ArCameraBridge.currentFilter.isPngOverlay()
        if (!needFrame) return
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

    private fun maybeCaptureRecordingFrame() {
        if (!recording || !videoRecorder.isRecording()) return
        val now = android.os.SystemClock.elapsedRealtime()
        if (now - lastRecordCopyMs < RECORD_FRAME_INTERVAL_MS) return
        if (!recordingPixelCopyBusy.compareAndSet(false, true)) return
        lastRecordCopyMs = now

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

            cameraProvider.unbindAll()
            cameraProvider.bindToLifecycle(
                lifecycleOwner,
                CameraSelector.DEFAULT_FRONT_CAMERA,
                preview,
                imageAnalysis,
            )
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

            // Plain live preview: CameraX PreviewView already shows the feed.
            // Still release the converting lock via finally.
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

            frameCounter++
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
