package com.dubai.bimobondapp.ar_camera

/**
 * Key indices for MediaPipe 468-point face mesh.
 * Reference: https://github.com/google/mediapipe/blob/master/mediapipe/modules/face_geometry/data/canonical_face_model_uv_visualization.png
 */
object MediaPipeLandmarkIndices {
    const val NOSE_TIP = 1
    const val NOSE_BRIDGE = 168
    const val FOREHEAD = 10
    const val CHIN = 152
    const val MOUTH_LEFT = 61
    const val MOUTH_RIGHT = 291
    const val MOUTH_BOTTOM = 17
    const val MOUTH_TOP = 0

    /** Top-of-head contour for ear / hat placement. */
    val TOP_HEAD = intArrayOf(
        10, 109, 67, 103, 54, 21, 162, 127, 234, 93, 132, 58, 172, 136, 150, 149, 176, 148,
    )

    val LEFT_EYE = intArrayOf(
        33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246,
    )

    val RIGHT_EYE = intArrayOf(
        362, 382, 381, 380, 374, 373, 390, 249, 263, 466, 388, 387, 386, 385, 384, 398,
    )

    /** Iris-focused centers for eye-bulge warp. */
    val LEFT_EYE_BULGE = intArrayOf(33, 133, 159, 145, 158, 157, 173, 160)
    val RIGHT_EYE_BULGE = intArrayOf(263, 362, 386, 374, 385, 373, 380, 381)

    val NOSE_BRIDGE_LINE = intArrayOf(
        168, 6, 197, 195, 5, 4, 1,
    )

    val UPPER_LIP = intArrayOf(
        61, 185, 40, 39, 37, 0, 267, 269, 270, 409, 291,
    )

    val LOWER_LIP = intArrayOf(
        61, 146, 91, 181, 84, 17, 314, 405, 320, 307, 375, 321, 308, 324, 318, 402, 317, 14, 87, 178, 88, 95, 78, 191, 80, 81, 82, 13, 312, 311, 310, 415, 291,
    )
}
