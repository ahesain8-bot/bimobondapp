package com.dubai.bimobondapp.camera_engine

/**
 * Phase 5 Beauty Engine facade — parameters, face mask, GPU [BeautyEffect].
 */
class BeautyEngine {
    val effect = BeautyEffect()

    @Volatile
    private var parameters: BeautyParameters = BeautyParameters(enabled = true)

    fun getParameters(): BeautyParameters = parameters

    fun setParameters(next: BeautyParameters) {
        parameters = next.clamped()
        effect.setParameters(parameters)
    }

    fun updateMask(faces: List<FaceLandmarks>) {
        if (!parameters.needsFaceMask()) {
            effect.clearFaceMask()
            return
        }
        effect.setFaceMask(BeautyFaceMask.fromFaces(faces))
    }

    fun clearMask() {
        effect.clearFaceMask()
    }

    fun isActive(): Boolean = parameters.isVisuallyActive()

    fun needsTracking(): Boolean = parameters.needsFaceMask()

    fun ensureGl() {
        effect.ensureProgram()
    }

    fun release() {
        effect.release()
        parameters = BeautyParameters()
    }
}
