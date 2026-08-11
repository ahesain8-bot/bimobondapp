package com.dubai.bimobondapp.camera_engine

/**
 * Phase 6 face deformation facade — [WarpParameters], [FaceMesh], [FaceWarpEffect].
 */
class FaceWarpEngine {
    val effect = FaceWarpEffect()

    @Volatile
    private var parameters: WarpParameters = WarpParameters()

    fun getParameters(): WarpParameters = parameters

    fun setParameters(next: WarpParameters) {
        parameters = next.clamped()
        effect.setParameters(parameters)
    }

    fun updateFromFaces(faces: List<FaceLandmarks>) {
        effect.updateFromFaces(faces)
    }

    fun clearFace() {
        effect.clearFace()
    }

    fun isActive(): Boolean = parameters.isVisuallyActive()

    fun needsTracking(): Boolean = parameters.needsFaceTracking()

    fun ensureGl() {
        effect.ensureProgram()
    }

    fun release() {
        effect.release()
        parameters = WarpParameters()
    }
}
