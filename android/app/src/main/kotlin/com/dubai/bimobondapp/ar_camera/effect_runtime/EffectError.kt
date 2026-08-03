package com.dubai.bimobondapp.ar_camera.effect_runtime

enum class EffectErrorCode {
    INVALID_JSON,
    UNSUPPORTED_SCHEMA_VERSION,
    MISSING_REQUIRED_FIELD,
    INVALID_FIELD_TYPE,
    INVALID_EFFECT_ID,
    INVALID_EFFECT_VERSION,
    INVALID_MAX_FACES,
    EMPTY_GRAPH,
    DUPLICATE_NODE_ID,
    UNSUPPORTED_NODE_TYPE,
    INVALID_FACE_TARGET,
    INVALID_ASSET_PATH,
    INVALID_LANDMARK,
    INVALID_OPACITY,
    INVALID_TRANSFORM,
    INVALID_BLEND_MODE,
    INVALID_PIN,
}

data class EffectError(
    val code: EffectErrorCode,
    val message: String,
    val field: String? = null,
    val nodeId: String? = null,
)

sealed interface EffectManifestResult {
    data class Success(val manifest: EffectManifest) : EffectManifestResult
    data class Failure(val errors: List<EffectError>) : EffectManifestResult
}
