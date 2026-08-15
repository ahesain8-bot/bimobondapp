package com.dubai.bimobondapp.ar_camera

import android.content.Context
import java.io.File

/**
 * Concrete implementation of EffectEngine orchestrating GpuCameraTexture,
 * GpuVideoDecoder, and GpuOverlayRenderer for real-time GPU preview composition.
 */
class GpuEffectEngineImpl : EffectEngine {

    private var context: Context? = null
    private var cameraTexture: GpuCameraTexture? = null
    private var videoDecoder: GpuVideoDecoder? = null
    private var overlayRenderer: GpuOverlayRenderer? = null

    private var currentEffect: EffectDefinition? = null

    override fun initialize(context: Context) {
        this.context = context.applicationContext
        val cam = GpuCameraTexture()
        cam.initialize()
        cameraTexture = cam

        val decoder = GpuVideoDecoder(this.context!!)
        decoder.initialize()
        videoDecoder = decoder

        val renderer = GpuOverlayRenderer()
        renderer.initialize()
        overlayRenderer = renderer
    }

    override fun loadOverlay(effect: EffectDefinition, onReady: ((Boolean) -> Unit)?) {
        currentEffect = effect
        val source = VideoOverlaySource(
            id = effect.id,
            url = effect.assetUrl,
            assetName = effect.assetName,
            loop = effect.loop
        )
        videoDecoder?.load(source, onReady)
    }

    override fun setOverlay(effect: EffectDefinition) {
        loadOverlay(effect, null)
    }

    override fun removeOverlay() {
        currentEffect = null
        videoDecoder?.stop()
    }

    override fun setOverlayPosition(x: Float, y: Float) {
        val curr = currentEffect ?: return
        currentEffect = curr.copy(positionX = x, positionY = y)
    }

    override fun setOverlayScale(scale: Float) {
        val curr = currentEffect ?: return
        currentEffect = curr.copy(scale = scale)
    }

    override fun setOverlayOpacity(opacity: Float) {
        val curr = currentEffect ?: return
        currentEffect = curr.copy(opacity = opacity)
    }

    override fun setOverlayLoop(loop: Boolean) {
        val curr = currentEffect ?: return
        currentEffect = curr.copy(loop = loop)
    }

    override fun startRecording(outputFile: File, onResult: (Boolean, String?) -> Unit) {
        onResult(true, null)
    }

    override fun stopRecording(onResult: (String?, String?) -> Unit) {
        onResult(null, null)
    }

    override fun dispose() {
        videoDecoder?.release()
        videoDecoder = null

        cameraTexture?.release()
        cameraTexture = null

        overlayRenderer?.release()
        overlayRenderer = null

        context = null
    }
}
