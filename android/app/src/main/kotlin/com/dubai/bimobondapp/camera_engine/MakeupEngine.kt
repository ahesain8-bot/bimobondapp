package com.dubai.bimobondapp.camera_engine

/**
 * Phase 7 Makeup facade — region masks + [MakeupEffect].
 */
class MakeupEngine {
    val effect = MakeupEffect()

    @Volatile
    private var parameters: MakeupParameters = MakeupParameters()

    fun getParameters(): MakeupParameters = parameters

    fun setParameters(next: MakeupParameters) {
        parameters = next.clamped()
        effect.setParameters(parameters)
    }

    fun updateRegions(faces: List<FaceLandmarks>) {
        if (!parameters.needsFaceTracking()) {
            effect.clearRegions()
            return
        }
        effect.setRegions(MakeupFaceRegions.fromFaces(faces))
    }

    fun clearRegions() {
        effect.clearRegions()
    }

    fun isActive(): Boolean = parameters.isVisuallyActive()

    fun needsTracking(): Boolean = parameters.needsFaceTracking()

    fun ensureGl() {
        effect.ensureProgram()
    }

    fun release() {
        effect.release()
        parameters = MakeupParameters()
    }
}
