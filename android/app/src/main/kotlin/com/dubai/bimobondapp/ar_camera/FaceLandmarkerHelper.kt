package com.dubai.bimobondapp.ar_camera

import android.content.Context
import android.graphics.Bitmap
import android.os.SystemClock
import android.util.Log
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarkerResult

class FaceLandmarkerHelper(context: Context) {

    private val appContext = context.applicationContext
    private var faceLandmarker: FaceLandmarker? = null
    private var frameTimestampMs = 0L

    fun setup() {
        if (faceLandmarker != null) return
        // Try GPU first for lower latency, fall back to CPU.
        faceLandmarker = try {
            createLandmarker(Delegate.GPU)
        } catch (e: Exception) {
            Log.w(TAG, "GPU delegate unavailable, falling back to CPU", e)
            createLandmarker(Delegate.CPU)
        }
    }

    fun detect(bitmap: Bitmap): FaceLandmarkerResult? {
        val landmarker = faceLandmarker ?: return null
        // VIDEO mode requires strictly increasing timestamps.
        val now = SystemClock.uptimeMillis()
        frameTimestampMs = if (now > frameTimestampMs) now else frameTimestampMs + 1L
        val mpImage = BitmapImageBuilder(bitmap).build()
        return landmarker.detectForVideo(mpImage, frameTimestampMs)
    }

    fun close() {
        faceLandmarker?.close()
        faceLandmarker = null
        frameTimestampMs = 0L
    }

    private fun createLandmarker(delegate: Delegate): FaceLandmarker {
        val baseOptions = BaseOptions.builder()
            .setDelegate(delegate)
            .setModelAssetPath(MODEL_ASSET)
            .build()

        val options = FaceLandmarker.FaceLandmarkerOptions.builder()
            .setBaseOptions(baseOptions)
            .setRunningMode(RunningMode.VIDEO)
            .setNumFaces(1)
            .setMinFaceDetectionConfidence(0.5f)
            .setMinFacePresenceConfidence(0.5f)
            .setMinTrackingConfidence(0.5f)
            .build()

        return FaceLandmarker.createFromOptions(appContext, options)
    }

    companion object {
        private const val TAG = "FaceLandmarkerHelper"
        private const val MODEL_ASSET = "face_landmarker.task"
    }
}
