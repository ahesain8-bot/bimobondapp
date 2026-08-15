package com.dubai.bimobondapp.ar_camera

import android.content.Context
import android.graphics.SurfaceTexture
import android.net.Uri
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.view.Surface
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer

/**
 * Hardware-accelerated MP4 video decoder outputting directly to an OpenGL OES GPU texture.
 * Uses Media3 ExoPlayer bound to a SurfaceTexture/Surface so decoded frames remain on the GPU.
 */
class GpuVideoDecoder(private val context: Context) : SurfaceTexture.OnFrameAvailableListener {

    var textureId: Int = 0
        private set

    var surfaceTexture: SurfaceTexture? = null
        private set

    var surface: Surface? = null
        private set

    private var player: ExoPlayer? = null
    val transformMatrix = FloatArray(16)

    @Volatile
    var isReady: Boolean = false
        private set

    private var onFrameAvailableCallback: (() -> Unit)? = null

    fun initialize(onFrameAvailable: (() -> Unit)? = null) {
        onFrameAvailableCallback = onFrameAvailable
        val textures = IntArray(1)
        GLES20.glGenTextures(1, textures, 0)
        textureId = textures[0]
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, textureId)
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_MIN_FILTER,
            GLES20.GL_LINEAR
        )
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_MAG_FILTER,
            GLES20.GL_LINEAR
        )
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_WRAP_S,
            GLES20.GL_CLAMP_TO_EDGE
        )
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_WRAP_T,
            GLES20.GL_CLAMP_TO_EDGE
        )

        val st = SurfaceTexture(textureId)
        st.setOnFrameAvailableListener(this)
        surfaceTexture = st
        val s = Surface(st)
        surface = s

        val exo = ExoPlayer.Builder(context)
            .setHandleAudioBecomingNoisy(false)
            .build()
        exo.volume = 0f
        exo.setVideoSurface(s)
        exo.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(state: Int) {
                if (state == Player.STATE_READY) {
                    isReady = true
                }
            }
        })
        player = exo
    }

    fun load(source: VideoOverlaySource, onLoaded: ((Boolean) -> Unit)? = null) {
        val exo = player ?: return
        isReady = false
        val uri = when {
            !source.url.isNullOrBlank() -> Uri.parse(source.url)
            !source.assetName.isNullOrBlank() -> Uri.parse("asset:///${source.assetName}")
            else -> {
                onLoaded?.invoke(false)
                return
            }
        }
        exo.repeatMode = if (source.loop) Player.REPEAT_MODE_ONE else Player.REPEAT_MODE_OFF
        exo.setMediaItem(MediaItem.fromUri(uri))
        exo.prepare()
        exo.playWhenReady = true
        onLoaded?.invoke(true)
    }

    override fun onFrameAvailable(st: SurfaceTexture?) {
        onFrameAvailableCallback?.invoke()
    }

    fun updateFrame() {
        val st = surfaceTexture ?: return
        try {
            st.updateTexImage()
            st.getTransformMatrix(transformMatrix)
        } catch (_: Exception) {
        }
    }

    fun pause() {
        player?.pause()
    }

    fun resume() {
        player?.play()
    }

    fun stop() {
        player?.stop()
        isReady = false
    }

    fun release() {
        onFrameAvailableCallback = null
        isReady = false
        try {
            player?.release()
        } catch (_: Exception) {
        }
        player = null

        try {
            surface?.release()
        } catch (_: Exception) {
        }
        surface = null

        try {
            surfaceTexture?.release()
        } catch (_: Exception) {
        }
        surfaceTexture = null

        if (textureId != 0) {
            val textures = intArrayOf(textureId)
            GLES20.glDeleteTextures(1, textures, 0)
            textureId = 0
        }
    }
}
