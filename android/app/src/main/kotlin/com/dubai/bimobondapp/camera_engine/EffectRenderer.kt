package com.dubai.bimobondapp.camera_engine

/**
 * Phase 2–4 GPU effect contracts — extend without rewriting the pipeline.
 */
interface EffectRenderer {
    /** Called on the GL thread with an OES external texture already bound as unit 0. */
    fun draw(
        oesTextureId: Int,
        width: Int,
        height: Int,
        transformMatrix: FloatArray,
    )

    fun release()
}

interface Effect {
    val id: String
    var enabled: Boolean
    /** 0.0–1.0 */
    var intensity: Float
}

/** Marker for shader-based full-frame effects. */
interface ShaderEffect : Effect

/** Full-frame color filter (Phase 2). */
interface FilterEffect : ShaderEffect

/** Face-anchored 2D overlay (Phase 4). */
interface FaceOverlayEffect : Effect

/** Masked beauty processing (Phase 5). */
interface BeautyShaderEffect : Effect

/** GPU face mesh deformation (Phase 6). */
interface FaceWarpShaderEffect : Effect

/** Region-masked makeup blending (Phase 7). */
interface MakeupShaderEffect : Effect
