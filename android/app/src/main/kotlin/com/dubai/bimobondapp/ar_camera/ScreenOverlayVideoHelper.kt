package com.dubai.bimobondapp.ar_camera

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import android.view.TextureView
import android.view.View
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Full-screen MP4/WebM overlay — same role as Lottie on the AR camera.
 *
 * TextureView so it renders inside Flutter's AndroidView/PlatformView.
 * ExoPlayer is reused, muted, cache-first, and decode-capped.
 */
class ScreenOverlayVideoHelper(
    private val textureView: TextureView,
    private val context: Context,
) {
    private var player: ExoPlayer? = null
    private var loadedKey: String? = null
    private var textureAttached = false

    fun load(source: ScreenOverlaySource) {
        if (!source.isValid || source.mediaType != ScreenOverlayMediaType.VIDEO) {
            unload()
            return
        }
        val key = source.cacheKey
        if (key == loadedKey && player != null &&
            player?.playbackState != Player.STATE_IDLE
        ) {
            if (player?.isPlaying != true) player?.play()
            return
        }
        val item = buildMediaItem(source) ?: return
        textureView.isOpaque = true
        val exo = ensurePlayer()
        exo.repeatMode =
            if (source.loop) Player.REPEAT_MODE_ONE else Player.REPEAT_MODE_OFF
        exo.volume = 0f
        exo.setMediaItem(item)
        exo.prepare()
        exo.playWhenReady = true
        loadedKey = key
    }

    fun pause() {
        player?.pause()
    }

    fun resume() {
        player?.play()
    }

    fun unload() {
        val exo = player ?: return
        try {
            exo.playWhenReady = false
            exo.stop()
            exo.clearMediaItems()
        } catch (_: Throwable) {
        }
        loadedKey = null
    }

    fun release() {
        try {
            player?.release()
        } catch (_: Throwable) {
        }
        player = null
        loadedKey = null
        textureAttached = false
    }

    fun stop() = release()

    fun captureFrame(maxEdge: Int = DEFAULT_CAPTURE_EDGE): Bitmap? {
        if (textureView.visibility != View.VISIBLE) return null
        val vw = textureView.width
        val vh = textureView.height
        if (vw <= 0 || vh <= 0) return null
        val longEdge = max(vw, vh)
        val scale =
            if (longEdge > maxEdge && maxEdge > 0) {
                maxEdge.toFloat() / longEdge.toFloat()
            } else {
                1f
            }
        val w = (vw * scale).roundToInt().coerceAtLeast(1)
        val h = (vh * scale).roundToInt().coerceAtLeast(1)
        return try {
            textureView.getBitmap(w, h)
        } catch (_: Throwable) {
            null
        }
    }

    private fun ensurePlayer(): ExoPlayer {
        player?.let { return it }
        val trackSelector = DefaultTrackSelector(context).apply {
            parameters = buildUponParameters()
                .setMaxVideoSize(DECODE_MAX_WIDTH, DECODE_MAX_HEIGHT)
                .setMaxVideoBitrate(DECODE_MAX_BITRATE)
                .setForceHighestSupportedBitrate(false)
                .setTrackTypeDisabled(C.TRACK_TYPE_AUDIO, true)
                .build()
        }
        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(500, 2_000, 250, 500)
            .build()
        val exo = ExoPlayer.Builder(context)
            .setTrackSelector(trackSelector)
            .setLoadControl(loadControl)
            .setHandleAudioBecomingNoisy(false)
            .setPauseAtEndOfMediaItems(false)
            .build()
            .apply {
                volume = 0f
                videoScalingMode = C.VIDEO_SCALING_MODE_SCALE_TO_FIT_WITH_CROPPING
            }
        if (!textureAttached) {
            exo.setVideoTextureView(textureView)
            textureAttached = true
        }
        player = exo
        return exo
    }

    private fun buildMediaItem(source: ScreenOverlaySource): MediaItem? {
        val url = source.url?.trim().orEmpty()
        if (url.isNotEmpty()) {
            val cached = ScreenOverlayVideoCache.readyFile(context, url)
            if (cached != null) {
                return MediaItem.fromUri(Uri.fromFile(cached))
            }
            ScreenOverlayVideoCache.requestDownload(context, url)
            return MediaItem.fromUri(Uri.parse(url))
        }
        val asset = source.assetName?.trim().orEmpty()
        if (asset.isNotEmpty()) {
            return MediaItem.fromUri(Uri.parse("asset:///$asset"))
        }
        return null
    }

    companion object {
        const val DEFAULT_CAPTURE_EDGE = 1280
        const val PHOTO_CAPTURE_EDGE = 1920
        private const val DECODE_MAX_WIDTH = 720
        private const val DECODE_MAX_HEIGHT = 1280
        private const val DECODE_MAX_BITRATE = 2_500_000
    }
}
