package com.dubai.bimobondapp.camera_engine

/**
 * Native camera engine constants.
 *
 * Pipeline: CameraX → GPU effects → Flutter Texture;
 * Phase 9–10 recording + music; Phase 11 Media3 export ≤1080p H.264.
 */
object NativeCameraConstants {
    const val CHANNEL = "com.dubai.bimobondapp/native_camera"

    /** Portrait 9:16 target; CameraX may pick the closest supported size. */
    const val PREVIEW_WIDTH = 1080
    const val PREVIEW_HEIGHT = 1920

    const val PERMISSION_REQUEST_CODE = 101
}
