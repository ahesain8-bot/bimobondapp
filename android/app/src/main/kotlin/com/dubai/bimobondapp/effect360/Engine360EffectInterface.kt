package com.dubai.bimobondapp.effect360

interface Engine360EffectInterface {
    fun initialize()
    fun load360Effect(videoUrl: String, alphaUrl: String? = null)
    fun remove360Effect()
    fun set360EffectOpacity(opacity: Float)
    fun set360EffectTransform(matrix: FloatArray)
    fun update(presentationTimeNs: Long)
    fun render(
        cameraOesTextureId: Int,
        width: Int,
        height: Int,
        projectionMatrix: FloatArray,
        viewMatrix: FloatArray
    )
    fun getState(): Engine360State
}
