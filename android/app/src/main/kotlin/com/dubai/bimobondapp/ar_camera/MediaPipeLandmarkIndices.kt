package com.dubai.bimobondapp.ar_camera

object MediaPipeLandmarkIndices {
    const val NOSE_TIP = 1
    const val NOSE_BRIDGE = 168
    const val FOREHEAD = 10
    const val CHIN = 152
    const val MOUTH_LEFT = 61
    const val MOUTH_RIGHT = 291
    const val MOUTH_BOTTOM = 17
    const val MOUTH_TOP = 0

    val TOP_HEAD = intArrayOf(
        10, 109, 67, 103, 54, 21, 162, 127, 234, 93, 132, 58, 172, 136, 150, 149, 176, 148,
    )

    const val LEFT_CHEEK = 234
    const val RIGHT_CHEEK = 454

    val LEFT_EYE = intArrayOf(
        33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246,
    )

    val RIGHT_EYE = intArrayOf(
        362, 382, 381, 380, 374, 373, 390, 249, 263, 466, 388, 387, 386, 385, 384, 398,
    )

    val LEFT_EYE_BULGE = intArrayOf(33, 133, 159, 145, 158, 157, 173, 160)
    val RIGHT_EYE_BULGE = intArrayOf(263, 362, 386, 374, 385, 373, 380, 381)

    val NOSE_BRIDGE_LINE = intArrayOf(
        168, 6, 197, 195, 5, 4, 1,
    )

    val NOSE_WING_ZONE = intArrayOf(
        48, 64, 98, 129, 219, 235,
        278, 294, 327, 358, 439, 455,
    )

    val UPPER_LIP = intArrayOf(
        61, 185, 40, 39, 37, 0, 267, 269, 270, 409, 291,
    )

    val LOWER_LIP = intArrayOf(
        61, 146, 91, 181, 84, 17, 314, 405, 320, 307, 375, 321, 308, 324, 318, 402, 317, 14, 87, 178, 88, 95, 78, 191, 80, 81, 82, 13, 312, 311, 310, 415, 291,
    )

    val FACE_OVAL = intArrayOf(
        10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288,
        397, 365, 379, 378, 400, 377, 152, 148, 176, 149, 150, 136,
        172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67, 109,
    )

    val LEFT_EYEBROW = intArrayOf(
        70, 63, 105, 66, 107, 55, 65, 52, 53, 46,
    )

    val RIGHT_EYEBROW = intArrayOf(
        300, 293, 334, 296, 336, 285, 295, 282, 283, 276,
    )

    val LIPS_OUTER = intArrayOf(
        61, 146, 91, 181, 84, 17, 314, 405, 321, 375, 291,
        409, 270, 269, 267, 0, 37, 39, 40, 185,
    )
}
