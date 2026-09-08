package com.dubai.bimobondapp.ar_camera.beauty_v3

/**
 * Builds semantic region contours from raw/motion-compensated canonical UVs.
 *
 * Construction lives in [V3FaceRegionState.prepareDraw] (reuses draw buffers).
 * This type documents the V3-1.5 pipeline stage:
 *
 * ```
 * raw canonical landmarks
 *   → head-motion compensation
 *   → MediaPipe topology contours ([V3FaceRegionTopology])
 *   → region-local calibration ([V3FaceRegionCalibration])
 *   → draw buffers (debug only)
 * ```
 */
object V3FaceRegionBuilder {
    /** Face width = cheek-to-cheek (234↔454). Face height = forehead↔chin (10↔152). */
    const val FACE_WIDTH_LEFT = V3FaceRegionTopology.LEFT_CHEEK_POINT
    const val FACE_WIDTH_RIGHT = V3FaceRegionTopology.RIGHT_CHEEK_POINT
    const val FACE_HEIGHT_TOP = V3FaceRegionTopology.FOREHEAD_POINT
    const val FACE_HEIGHT_BOTTOM = V3FaceRegionTopology.CHIN_POINT

    /** Teeth ROI inset fraction toward mouth-opening centroid (not true teeth). */
    const val TEETH_ROI_INSET = 0.35f
}
