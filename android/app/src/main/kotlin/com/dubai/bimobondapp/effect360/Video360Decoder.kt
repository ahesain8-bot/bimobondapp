package com.dubai.bimobondapp.effect360

import android.content.Context
import android.graphics.SurfaceTexture
import android.net.Uri
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Surface
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

class Video360Decoder(private val context: Context, val isAlphaChannel: Boolean = false) {
    companion object {
        private const val TAG = "Video360Decoder"
    }

    var oesTextureId: Int = 0
        private set

    private var surfaceTexture: SurfaceTexture? = null
    private var surface: Surface? = null
    private var exoPlayer: ExoPlayer? = null

    private val frameAvailable = AtomicBoolean(false)

    var videoWidth: Int = 0
        private set
    var videoHeight: Int = 0
        private set
    var durationUs: Long = 0L
        private set

    var consecutiveErrorCount: Int = 0
        private set
    var isHealthy: Boolean = true
        private set

    var decodedFrames: Long = 0
        private set
    var displayedFrames: Long = 0
        private set
    var droppedFrames: Long = 0
        private set

    private var lastLogMs: Long = 0L
    private val mainHandler = Handler(Looper.getMainLooper())

    fun initializeGlTexture(): Int {
        val textures = IntArray(1)
        GLES20.glGenTextures(1, textures, 0)
        oesTextureId = textures[0]

        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, oesTextureId)
        GLES20.glTexParameterf(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR.toFloat())
        GLES20.glTexParameterf(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR.toFloat())
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_REPEAT)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)

        surfaceTexture = SurfaceTexture(oesTextureId).apply {
            setOnFrameAvailableListener {
                frameAvailable.set(true)
            }
        }
        surface = Surface(surfaceTexture)
        return oesTextureId
    }

    fun startDecoding(uri: Uri, loopPlayback: Boolean = true): Boolean {
        stopDecoding()
        if (surface == null) return false

        mainHandler.post {
            try {
                val player = ExoPlayer.Builder(context).build().apply {
                    repeatMode = if (loopPlayback) Player.REPEAT_MODE_ALL else Player.REPEAT_MODE_OFF
                    setVideoSurface(surface)
                    val mediaItem = MediaItem.fromUri(uri)
                    setMediaItem(mediaItem)
                    addListener(object : Player.Listener {
                        override fun onPlaybackStateChanged(playbackState: Int) {
                            if (playbackState == Player.STATE_READY) {
                                durationUs = duration * 1000L
                                Log.i("DECODER", "Media3 ExoPlayer READY: durationMs=$duration oesTexId=$oesTextureId")
                            }
                        }

                        override fun onVideoSizeChanged(videoSize: androidx.media3.common.VideoSize) {
                            videoWidth = videoSize.width
                            videoHeight = videoSize.height
                            val is2to1 = videoWidth > 0 && videoHeight > 0 && (videoWidth.toFloat() / videoHeight.toFloat() in 1.9f..2.1f)
                            Log.i("VIDEO_360_FORMAT", """
                                ==================================================
                                MEDIA3 360 VIDEO FORMAT INSPECTION:
                                Width: $videoWidth
                                Height: $videoHeight
                                Aspect Ratio: ${if (videoHeight > 0) videoWidth.toFloat() / videoHeight.toFloat() else 0f} (Is 2:1 = $is2to1)
                                Duration: ${durationUs / 1000L} ms
                                ==================================================
                            """.trimIndent())
                        }
                    })
                    prepare()
                    playWhenReady = true
                }
                exoPlayer = player
                decodedFrames++
                Log.i("DECODER", "Media3 ExoPlayer created and playing for 360 video $uri")
            } catch (t: Throwable) {
                Log.e(TAG, "Failed to start Media3 ExoPlayer 360 decoder for $uri", t)
            }
        }
        return true
    }

    fun startDecoding(videoFile: File, loopPlayback: Boolean = true): Boolean {
        if (!videoFile.exists()) return false
        return startDecoding(Uri.fromFile(videoFile), loopPlayback)
    }

    fun startDecodingUrl(videoUrl: String, loopPlayback: Boolean = true): Boolean {
        if (videoUrl.isBlank()) return false
        val uri = if (videoUrl.startsWith("http://") || videoUrl.startsWith("https://") || videoUrl.startsWith("content://")) {
            Uri.parse(videoUrl)
        } else {
            Uri.fromFile(File(videoUrl))
        }
        return startDecoding(uri, loopPlayback)
    }

    fun updateFrame(stMatrixOut: FloatArray): Boolean {
        val st = surfaceTexture ?: return false
        if (frameAvailable.compareAndSet(true, false)) {
            try {
                st.updateTexImage()
                st.getTransformMatrix(stMatrixOut)
                displayedFrames++
                consecutiveErrorCount = 0
                isHealthy = true

                val now = System.currentTimeMillis()
                if (now - lastLogMs >= 1000L) {
                    lastLogMs = now
                    Log.i("DECODER", "Media3 360: decodedFrames=$decodedFrames displayedFrames=$displayedFrames timestampUs=${st.timestamp / 1000L} oesTexId=$oesTextureId thread=${Thread.currentThread().name}")
                }
                return true
            } catch (t: Throwable) {
                droppedFrames++
                consecutiveErrorCount++
                Log.e("DECODER", "Error updating SurfaceTexture frame (failure $consecutiveErrorCount)", t)
                if (consecutiveErrorCount >= 5) {
                    isHealthy = false
                }
            }
        }
        return false
    }

    fun stopDecoding() {
        mainHandler.post {
            try {
                exoPlayer?.stop()
                exoPlayer?.release()
                exoPlayer = null
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping Media3 ExoPlayer", e)
            }
        }
    }

    fun releaseGl() {
        stopDecoding()
        surface?.release()
        surface = null
        surfaceTexture?.release()
        surfaceTexture = null

        if (oesTextureId != 0) {
            val textures = intArrayOf(oesTextureId)
            GLES20.glDeleteTextures(1, textures, 0)
            oesTextureId = 0
        }
    }
}
