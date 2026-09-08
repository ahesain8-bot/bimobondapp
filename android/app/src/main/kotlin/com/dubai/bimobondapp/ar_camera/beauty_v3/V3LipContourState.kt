package com.dubai.bimobondapp.ar_camera.beauty_v3

/**
 * Fixed reusable lip contour buffer (canonical UV, +Y down).
 * Geometry comes from shared [V3TrackedFaceState] via [V3FaceRegionState.copyLipContours].
 */
internal object V3LipContourState {
    /** Latest contours: upperOuter, upperInner, lowerOuter, lowerInner. */
    val canonUv = FloatArray(V3LipTopology.CONTOUR_FLOATS)

    @Volatile
    var valid: Boolean = false
        private set

    fun reset() {
        valid = false
    }

    /**
     * Pulls full ordered lip polylines via [V3FaceRegionState.copyLipContours]
     * (already display-time tracked). No per-effect EMA.
     */
    fun update(): Boolean {
        if (!V3FaceRegionState.copyLipContours(canonUv)) {
            valid = false
            return false
        }
        valid = true
        return true
    }
}
