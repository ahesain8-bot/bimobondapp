package com.dubai.bimobondapp.camera_engine

/**
 * Head pose in degrees (MediaPipe facial transformation matrix).
 */
data class FacePose(
    val pitchDeg: Float = 0f,
    val yawDeg: Float = 0f,
    val rollDeg: Float = 0f,
    val hasPose: Boolean = false,
)

/**
 * One tracked face — normalized landmark UVs in image space [0,1].
 * Stays on the native side; not streamed to Dart every frame.
 */
data class FaceLandmarks(
    /** Packed xy pairs in [0,1] image space (size = count * 2). */
    val normalizedXy: FloatArray,
    val count: Int,
    val centerX: Float,
    val centerY: Float,
    val scale: Float,
    val pose: FacePose,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is FaceLandmarks) return false
        return count == other.count &&
            centerX == other.centerX &&
            centerY == other.centerY &&
            scale == other.scale &&
            pose == other.pose &&
            normalizedXy.contentEquals(other.normalizedXy)
    }

    override fun hashCode(): Int {
        var result = normalizedXy.contentHashCode()
        result = 31 * result + count
        result = 31 * result + centerX.hashCode()
        result = 31 * result + centerY.hashCode()
        result = 31 * result + scale.hashCode()
        result = 31 * result + pose.hashCode()
        return result
    }
}

data class FaceTrackerResult(
    val faces: List<FaceLandmarks>,
    val imageWidth: Int,
    val imageHeight: Int,
    val timestampMs: Long,
)

interface FaceTracker {
    fun start()
    fun stop()
    fun isReady(): Boolean

    /** Runs on a background analyzer thread. */
    fun processBitmap(
        bitmap: android.graphics.Bitmap,
        timestampMs: Long,
    ): FaceTrackerResult?

    fun release()
}
