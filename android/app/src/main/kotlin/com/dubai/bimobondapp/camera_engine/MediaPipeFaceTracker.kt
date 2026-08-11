package com.dubai.bimobondapp.camera_engine

import android.content.Context
import android.graphics.Bitmap
import android.os.SystemClock
import android.util.Log
import com.dubai.bimobondapp.ar_camera.FaceLandmarkMapper
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/**
 * Phase 3 MediaPipe Face Landmarker tracker.
 *
 * Landmarks stay native — never pushed to Flutter per frame.
 * Uses CPU delegate to avoid GPU contention with the preview shader.
 */
class MediaPipeFaceTracker(
    context: Context,
    private val maxFaces: Int = 2,
) : FaceTracker {

    private val appContext = context.applicationContext
    private var faceLandmarker: FaceLandmarker? = null
    private var frameTimestampMs = 0L

    @Volatile
    private var ready = false

    override fun start() {
        if (ready && faceLandmarker != null) return
        try {
            faceLandmarker = try {
                createLandmarker(Delegate.CPU)
            } catch (e: Exception) {
                Log.w(TAG, "CPU delegate unavailable, falling back to GPU", e)
                createLandmarker(Delegate.GPU)
            }
            ready = true
            Log.i(TAG, "FaceTracker ready (maxFaces=$maxFaces)")
        } catch (t: Throwable) {
            Log.e(TAG, "FaceTracker start failed", t)
            ready = false
            faceLandmarker = null
        }
    }

    override fun stop() {
        // Keep model warm between toggles; release on [release].
    }

    override fun isReady(): Boolean = ready && faceLandmarker != null

    override fun processBitmap(bitmap: Bitmap, timestampMs: Long): FaceTrackerResult? {
        val landmarker = faceLandmarker ?: return null
        val now = if (timestampMs > 0) timestampMs else SystemClock.uptimeMillis()
        frameTimestampMs = if (now > frameTimestampMs) now else frameTimestampMs + 1L

        val result = try {
            val mpImage = BitmapImageBuilder(bitmap).build()
            landmarker.detectForVideo(mpImage, frameTimestampMs)
        } catch (t: Throwable) {
            Log.w(TAG, "detect failed", t)
            return null
        }

        val faces = mutableListOf<FaceLandmarks>()
        val faceCount = min(result.faceLandmarks().size, maxFaces)
        for (i in 0 until faceCount) {
            val list = result.faceLandmarks()[i]
            if (list.size < 100) continue

            val snapshot = if (i == 0) {
                FaceLandmarkMapper.fromResult(result, bitmap.width, bitmap.height)
            } else {
                null
            }

            val xy = FloatArray(list.size * 2)
            var minX = 1f
            var minY = 1f
            var maxX = 0f
            var maxY = 0f
            for (j in list.indices) {
                val lx = list[j].x().coerceIn(0f, 1f)
                val ly = list[j].y().coerceIn(0f, 1f)
                xy[j * 2] = lx
                xy[j * 2 + 1] = ly
                minX = min(minX, lx)
                minY = min(minY, ly)
                maxX = max(maxX, lx)
                maxY = max(maxY, ly)
            }
            val cx = (minX + maxX) * 0.5f
            val cy = (minY + maxY) * 0.5f
            val scale = hypot((maxX - minX).toDouble(), (maxY - minY).toDouble()).toFloat()

            val pose = if (snapshot != null) {
                FacePose(
                    pitchDeg = snapshot.pitchDeg,
                    yawDeg = snapshot.yawDeg,
                    rollDeg = snapshot.rollDeg,
                    hasPose = snapshot.hasHeadPose,
                )
            } else {
                FacePose()
            }

            faces.add(
                FaceLandmarks(
                    normalizedXy = xy,
                    count = list.size,
                    centerX = cx,
                    centerY = cy,
                    scale = scale,
                    pose = pose,
                ),
            )
        }

        return FaceTrackerResult(
            faces = faces,
            imageWidth = bitmap.width,
            imageHeight = bitmap.height,
            timestampMs = frameTimestampMs,
        )
    }

    override fun release() {
        ready = false
        try {
            faceLandmarker?.close()
        } catch (_: Throwable) {
        }
        faceLandmarker = null
        frameTimestampMs = 0L
    }

    private fun createLandmarker(delegate: Delegate): FaceLandmarker {
        return try {
            createLandmarker(delegate, outputPoseMatrix = true)
        } catch (e: Exception) {
            Log.w(TAG, "Pose matrices unavailable, landmarks-only", e)
            createLandmarker(delegate, outputPoseMatrix = false)
        }
    }

    private fun createLandmarker(delegate: Delegate, outputPoseMatrix: Boolean): FaceLandmarker {
        val baseOptions = BaseOptions.builder()
            .setDelegate(delegate)
            .setModelAssetPath(MODEL_ASSET)
            .build()

        val builder = FaceLandmarker.FaceLandmarkerOptions.builder()
            .setBaseOptions(baseOptions)
            .setRunningMode(RunningMode.VIDEO)
            .setNumFaces(maxFaces.coerceIn(1, 4))
            .setMinFaceDetectionConfidence(0.5f)
            .setMinFacePresenceConfidence(0.5f)
            .setMinTrackingConfidence(0.5f)
        if (outputPoseMatrix) {
            builder.setOutputFacialTransformationMatrixes(true)
        }
        return FaceLandmarker.createFromOptions(appContext, builder.build())
    }

    companion object {
        private const val TAG = "MediaPipeFaceTracker"
        private const val MODEL_ASSET = "face_landmarker.task"
    }
}
