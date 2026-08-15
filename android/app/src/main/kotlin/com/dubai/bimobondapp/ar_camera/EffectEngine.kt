package com.dubai.bimobondapp.ar_camera

import android.content.Context
import android.graphics.Bitmap

/**
 * Normalized overlay configuration model sent from Flutter to native Android.
 * Position, scale, opacity, and timing parameters use normalized 0.0..1.0 values.
 */
data class EffectDefinition(
    val id: String,
    val type: String = "screen_overlay", // "screen_overlay" | "lottie" | "video" | "filter"
    val assetUrl: String? = null,
    val assetName: String? = null,
    val durationMs: Long = 0L,
    val loop: Boolean = true,
    val startTimeMs: Long = 0L,
    val endTimeMs: Long = 0L,
    val opacity: Float = 1.0f,
    val scale: Float = 1.0f,
    val positionX: Float = 0.5f,
    val positionY: Float = 0.5f,
    val rotation: Float = 0.0f,
    val blendMode: String = "normal",
) {
    val isVideo: Boolean
        get() = type.equals("video", ignoreCase = true) ||
                (assetUrl?.endsWith(".mp4", ignoreCase = true) == true) ||
                (assetUrl?.endsWith(".webm", ignoreCase = true) == true)

    val isLottie: Boolean
        get() = type.equals("lottie", ignoreCase = true) ||
                (assetUrl?.endsWith(".json", ignoreCase = true) == true)
}

/**
 * Abstraction layer for video overlay sources. Allows switching between hardware
 * video decoding, chroma-key shaders, or separate alpha streams without breaking
 * the higher-level EffectEngine API.
 */
class VideoOverlaySource(
    val id: String,
    val url: String?,
    val assetName: String?,
    val loop: Boolean = true,
    val mediaType: ScreenOverlayMediaType = ScreenOverlayMediaType.VIDEO,
) {
    val isValid: Boolean
        get() = !url.isNullOrBlank() || !assetName.isNullOrBlank()

    val cacheKey: String
        get() = url?.trim()?.takeIf { it.isNotEmpty() }
            ?: assetName?.trim()
            ?: "unknown_overlay"
}

/**
 * Core interface for native GPU composition engine.
 * Encapsulates live camera preview textures, MP4 video overlays, Lottie animations,
 * and hardware MediaCodec recording.
 */
interface EffectEngine {
    fun initialize(context: Context)
    fun loadOverlay(effect: EffectDefinition, onReady: ((Boolean) -> Unit)? = null)
    fun setOverlay(effect: EffectDefinition)
    fun removeOverlay()
    fun setOverlayPosition(x: Float, y: Float)
    fun setOverlayScale(scale: Float)
    fun setOverlayOpacity(opacity: Float)
    fun setOverlayLoop(loop: Boolean)
    fun startRecording(outputFile: java.io.File, onResult: (Boolean, String?) -> Unit)
    fun stopRecording(onResult: (String?, String?) -> Unit)
    fun dispose()
}
