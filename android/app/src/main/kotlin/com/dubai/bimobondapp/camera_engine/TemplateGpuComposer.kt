package com.dubai.bimobondapp.camera_engine

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.SurfaceTexture
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLExt
import android.opengl.EGLSurface
import android.opengl.GLES20
import android.opengl.GLUtils
import android.opengl.Matrix
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.view.Surface
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max
import kotlin.math.min

/**
 * Shared OpenGL ES timeline composer for templates.
 *
 * Same [drawFrame] path presents to:
 * - Flutter [SurfaceTexture] (live preview), or
 * - MediaCodec input [Surface] (hardware H.264 export).
 */
class TemplateGpuComposer(@Suppress("UNUSED_PARAMETER") context: Context) {
    companion object {
        private const val TAG = "TemplateGpuComposer"
        private const val EGL_RECORDABLE_ANDROID = 0x3142
        private const val MIME = MediaFormat.MIMETYPE_VIDEO_AVC

        private val VERTEX = """
            attribute vec4 aPosition;
            attribute vec2 aTexCoord;
            varying vec2 vTexCoord;
            uniform mat4 uTexMatrix;
            void main() {
              gl_Position = aPosition;
              vTexCoord = (uTexMatrix * vec4(aTexCoord, 0.0, 1.0)).xy;
            }
        """.trimIndent()

        private val FRAGMENT = """
            precision mediump float;
            varying vec2 vTexCoord;
            uniform sampler2D uTexture;
            uniform float uCM[20];
            uniform float uUseColorMatrix;
            uniform float uOpacity;
            void main() {
              vec4 c = texture2D(uTexture, vTexCoord);
              if (uUseColorMatrix > 0.5) {
                float r = c.r*uCM[0] + c.g*uCM[1] + c.b*uCM[2] + c.a*uCM[3] + uCM[4];
                float g = c.r*uCM[5] + c.g*uCM[6] + c.b*uCM[7] + c.a*uCM[8] + uCM[9];
                float b = c.r*uCM[10] + c.g*uCM[11] + c.b*uCM[12] + c.a*uCM[13] + uCM[14];
                float a = c.r*uCM[15] + c.g*uCM[16] + c.b*uCM[17] + c.a*uCM[18] + uCM[19];
                c = vec4(r, g, b, a);
              }
              c.a *= uOpacity;
              gl_FragColor = c;
            }
        """.trimIndent()
    }

    data class Clip(
        val type: String,
        val path: String,
        val durationMs: Long,
        val trimStartMs: Long? = null,
        val trimEndMs: Long? = null,
    )

    data class Overlay(
        val path: String,
        val startMs: Long = 0L,
        val endMs: Long = Long.MAX_VALUE,
        val opacity: Float = 1f,
    )

    data class Request(
        val width: Int,
        val height: Int,
        val fps: Int,
        val bitrate: Int,
        val clips: List<Clip>,
        val audioPath: String? = null,
        val audioStartMs: Long = 0L,
        val audioVolume: Float = 1f,
        /** Flutter ColorFilter 5x4 (20 floats); null = off. */
        val colorMatrix: FloatArray? = null,
        val overlays: List<Overlay> = emptyList(),
    )

    data class Outcome(val ok: Boolean, val path: String? = null, val error: String? = null)

    private val lock = Any()
    private var glThread: HandlerThread? = null
    private var glHandler: Handler? = null

    private var eglDisplay: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var eglContext: EGLContext = EGL14.EGL_NO_CONTEXT
    private var eglConfig: EGLConfig? = null
    private var previewEglSurface: EGLSurface = EGL14.EGL_NO_SURFACE
    private var encoderEglSurface: EGLSurface = EGL14.EGL_NO_SURFACE

    private var program = 0
    private var aPosition = 0
    private var aTexCoord = 0
    private var uTexMatrix = 0
    private var uTexture = 0
    private var uCM = IntArray(20)
    private var uUseColorMatrix = 0
    private var uOpacity = 0
    private var quadBuffer: FloatBuffer? = null

    private var width = 1080
    private var height = 1920
    private var fps = 30
    private var bitrate = 8_000_000
    private var clips: List<Clip> = emptyList()
    private var overlays: List<Overlay> = emptyList()
    private var colorMatrix: FloatArray? = null
    private var audioPath: String? = null
    private var audioStartMs = 0L
    private var audioVolume = 1f

    private var playheadMs = 0L
    private var playing = AtomicBoolean(false)
    private var previewSurfaceTexture: SurfaceTexture? = null

    private val imageTexCache = HashMap<String, Int>()
    private val overlayTexCache = HashMap<String, Int>()
    private val videoFrameCache = HashMap<String, Pair<Long, Int>>() // key -> (timeMs, tex)
    private val identityMatrix = FloatArray(16).also { Matrix.setIdentityM(it, 0) }
    private val coverMatrix = FloatArray(16)

    private val ready = AtomicBoolean(false)

    fun totalDurationMs(): Long = clips.sumOf { it.durationMs.coerceAtLeast(200L) }

    fun configure(request: Request) {
        width = even(request.width.coerceIn(2, 1080))
        height = even(request.height.coerceIn(2, 1920))
        fps = request.fps.coerceIn(15, 60)
        bitrate = request.bitrate.coerceIn(1_000_000, 20_000_000)
        clips = request.clips
        overlays = request.overlays
        colorMatrix = request.colorMatrix
        audioPath = request.audioPath
        audioStartMs = request.audioStartMs
        audioVolume = request.audioVolume
    }

    /** Bind Flutter preview texture (creates GL thread + EGL). */
    fun attachPreview(surfaceTexture: SurfaceTexture) {
        ensureGlThread()
        runOnGl("attachPreview") {
            previewSurfaceTexture = surfaceTexture
            surfaceTexture.setDefaultBufferSize(width, height)
            initEglIfNeeded()
            createPreviewSurface(surfaceTexture)
            ensureProgram()
            ready.set(true)
            drawFrame(playheadMs, presentToPreview = true, presentToEncoder = false)
        }
    }

    fun seekMs(ms: Long) {
        playheadMs = ms.coerceIn(0L, max(0L, totalDurationMs()))
        if (!ready.get()) return
        runOnGl("seek") {
            drawFrame(playheadMs, presentToPreview = true, presentToEncoder = false)
        }
    }

    fun play() {
        if (!ready.get() || clips.isEmpty()) return
        playing.set(true)
        glHandler?.post(object : Runnable {
            override fun run() {
                if (!playing.get()) return
                val frameMs = 1000L / fps
                playheadMs = min(playheadMs + frameMs, totalDurationMs())
                drawFrame(playheadMs, presentToPreview = true, presentToEncoder = false)
                if (playheadMs >= totalDurationMs()) {
                    playing.set(false)
                    return
                }
                glHandler?.postDelayed(this, frameMs)
            }
        })
    }

    fun pause() {
        playing.set(false)
    }

    fun export(output: File): Outcome {
        if (clips.isEmpty()) return Outcome(false, error = "no_clips")
        ensureGlThread()
        var outcome = Outcome(false, error = "export_failed")
        runOnGl("export", timeoutSec = 600) {
            outcome = exportOnGlThread(output)
        }
        return outcome
    }

    fun release() {
        playing.set(false)
        ready.set(false)
        val handler = glHandler
        val thread = glThread
        if (handler != null && thread != null) {
            val latch = CountDownLatch(1)
            handler.post {
                try {
                    releaseGlLocked()
                } finally {
                    latch.countDown()
                }
            }
            latch.await(3, TimeUnit.SECONDS)
            thread.quitSafely()
            try {
                thread.join(1000)
            } catch (_: InterruptedException) {
            }
        }
        glHandler = null
        glThread = null
    }

    // --- GL / export internals ---

    private fun exportOnGlThread(output: File): Outcome {
        try {
            initEglIfNeeded()
            ensureProgram()
            output.parentFile?.mkdirs()
            output.delete()

            val encoder = startEncoder(output, width, height, fps, bitrate)
            val inputSurface = encoder.inputSurface
                ?: return Outcome(false, error = "encoder_surface_missing")
            createEncoderSurface(inputSurface)

            val frameCount = max(1, ((totalDurationMs() * fps) / 1000L).toInt())
            val frameUs = 1_000_000L / fps
            for (i in 0 until frameCount) {
                val tMs = (i * 1000L) / fps
                playheadMs = tMs
                drawFrame(tMs, presentToPreview = false, presentToEncoder = true)
                EGLExt.eglPresentationTimeANDROID(
                    eglDisplay,
                    encoderEglSurface,
                    i * frameUs * 1000L,
                )
                EGL14.eglSwapBuffers(eglDisplay, encoderEglSurface)
                encoder.drain(false)
            }
            encoder.signalEos()
            encoder.drain(true)
            encoder.release()

            destroyEncoderSurface()

            val music = audioPath
            if (!music.isNullOrBlank() && File(music).exists()) {
                val mixed = File(
                    output.parentFile,
                    "${output.nameWithoutExtension}_m.mp4",
                )
                val ok = AudioMusicMixer.mixToMp4(
                    videoFile = output,
                    micFile = null,
                    config = AudioMusicMixer.Config(
                        musicPath = music,
                        musicOffsetMs = audioStartMs,
                        musicVolume = audioVolume.coerceIn(0f, 1f),
                        originalVolume = 0f,
                    ),
                    outFile = mixed,
                )
                if (ok && mixed.exists() && mixed.length() > 0) {
                    output.delete()
                    mixed.renameTo(output)
                }
            }
            return if (output.exists() && output.length() > 0) {
                Outcome(true, path = output.absolutePath)
            } else {
                Outcome(false, error = "export_empty")
            }
        } catch (t: Throwable) {
            Log.e(TAG, "export failed", t)
            return Outcome(false, error = t.message ?: "export_failed")
        }
    }

    private fun drawFrame(
        timeMs: Long,
        presentToPreview: Boolean,
        presentToEncoder: Boolean,
    ) {
        if (program == 0) return
        val clipTex = textureForTimeline(timeMs) ?: return

        fun drawTo(surface: EGLSurface, w: Int, h: Int) {
            if (surface == EGL14.EGL_NO_SURFACE) return
            if (!EGL14.eglMakeCurrent(eglDisplay, surface, surface, eglContext)) return
            GLES20.glViewport(0, 0, w, h)
            GLES20.glClearColor(0f, 0f, 0f, 1f)
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
            drawTexturedQuad(clipTex, coverMatrixFor(clipTex), colorMatrix, 1f)

            // Phase C — overlay quads while active.
            for (overlay in overlays) {
                if (timeMs < overlay.startMs || timeMs > overlay.endMs) continue
                val oTex = overlayTexture(overlay.path) ?: continue
                drawTexturedQuad(
                    oTex,
                    identityMatrix,
                    null,
                    overlay.opacity.coerceIn(0f, 1f),
                )
            }
            GLES20.glFinish()
        }

        if (presentToEncoder && encoderEglSurface != EGL14.EGL_NO_SURFACE) {
            drawTo(encoderEglSurface, width, height)
        }
        if (presentToPreview && previewEglSurface != EGL14.EGL_NO_SURFACE) {
            drawTo(previewEglSurface, width, height)
            EGL14.eglSwapBuffers(eglDisplay, previewEglSurface)
        }
    }

    private fun drawTexturedQuad(
        textureId: Int,
        texMatrix: FloatArray,
        colorMat: FloatArray?,
        opacity: Float,
    ) {
        GLES20.glUseProgram(program)
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)

        val buf = quadBuffer ?: return
        buf.position(0)
        GLES20.glEnableVertexAttribArray(aPosition)
        GLES20.glVertexAttribPointer(aPosition, 2, GLES20.GL_FLOAT, false, 16, buf)
        buf.position(2)
        GLES20.glEnableVertexAttribArray(aTexCoord)
        GLES20.glVertexAttribPointer(aTexCoord, 2, GLES20.GL_FLOAT, false, 16, buf)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureId)
        GLES20.glUniform1i(uTexture, 0)
        GLES20.glUniformMatrix4fv(uTexMatrix, 1, false, texMatrix, 0)
        GLES20.glUniform1f(uOpacity, opacity.coerceIn(0f, 1f))
        if (colorMat != null && colorMat.size >= 20) {
            GLES20.glUniform1f(uUseColorMatrix, 1f)
            for (i in 0 until 20) {
                GLES20.glUniform1f(uCM[i], colorMat[i])
            }
        } else {
            GLES20.glUniform1f(uUseColorMatrix, 0f)
        }

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(aPosition)
        GLES20.glDisableVertexAttribArray(aTexCoord)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
        GLES20.glDisable(GLES20.GL_BLEND)
    }

    private fun textureForTimeline(timeMs: Long): Int? {
        var cursor = 0L
        for (clip in clips) {
            val dur = clip.durationMs.coerceAtLeast(200L)
            if (timeMs < cursor + dur) {
                val local = timeMs - cursor
                return if (clip.type.equals("image", ignoreCase = true)) {
                    imageTexture(clip.path)
                } else {
                    val start = clip.trimStartMs ?: 0L
                    val end = clip.trimEndMs ?: (start + dur)
                    val srcTime = (start + local).coerceIn(start, max(start, end - 1))
                    videoTexture(clip.path, srcTime)
                }
            }
            cursor += dur
        }
        val last = clips.lastOrNull() ?: return null
        return if (last.type.equals("image", ignoreCase = true)) {
            imageTexture(last.path)
        } else {
            videoTexture(last.path, last.trimStartMs ?: 0L)
        }
    }

    private fun imageTexture(path: String): Int? {
        imageTexCache[path]?.let { return it }
        val opts = BitmapFactory.Options().apply { inSampleSize = 1 }
        val bmp = BitmapFactory.decodeFile(path, opts) ?: return null
        val scaled = scaleBitmapCover(bmp, width, height)
        if (scaled !== bmp) bmp.recycle()
        val tex = uploadBitmap(scaled)
        scaled.recycle()
        imageTexCache[path] = tex
        return tex
    }

    private fun overlayTexture(path: String): Int? {
        overlayTexCache[path]?.let { return it }
        val bmp = BitmapFactory.decodeFile(path) ?: return null
        val tex = uploadBitmap(bmp)
        bmp.recycle()
        overlayTexCache[path] = tex
        return tex
    }

    private fun videoTexture(path: String, timeMs: Long): Int? {
        val key = path
        val bucket = (timeMs / 33L) * 33L // ~30fps cache bucket
        videoFrameCache[key]?.let { (t, tex) ->
            if (t == bucket) return tex
        }
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(path)
            val frame = retriever.getFrameAtTime(
                timeMs * 1000L,
                MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
            ) ?: return imageTexture(path)
            val scaled = scaleBitmapCover(frame, width, height)
            if (scaled !== frame) frame.recycle()
            // Replace previous cached tex for this clip.
            videoFrameCache[key]?.let { (_, old) -> deleteTexture(old) }
            val tex = uploadBitmap(scaled)
            scaled.recycle()
            videoFrameCache[key] = bucket to tex
            tex
        } catch (t: Throwable) {
            Log.w(TAG, "video frame $path@$timeMs", t)
            null
        } finally {
            try {
                retriever.release()
            } catch (_: Throwable) {
            }
        }
    }

    private fun scaleBitmapCover(src: Bitmap, tw: Int, th: Int): Bitmap {
        val sw = src.width.toFloat()
        val sh = src.height.toFloat()
        val scale = max(tw / sw, th / sh)
        val nw = max(1, (sw * scale).toInt())
        val nh = max(1, (sh * scale).toInt())
        val scaled = Bitmap.createScaledBitmap(src, nw, nh, true)
        val x = ((nw - tw) / 2).coerceAtLeast(0)
        val y = ((nh - th) / 2).coerceAtLeast(0)
        val cropped = Bitmap.createBitmap(scaled, x, y, min(tw, nw), min(th, nh))
        if (scaled !== src && scaled !== cropped) scaled.recycle()
        return cropped
    }

    private fun uploadBitmap(bitmap: Bitmap): Int {
        val tex = IntArray(1)
        GLES20.glGenTextures(1, tex, 0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, tex[0])
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
        return tex[0]
    }

    private fun coverMatrixFor(@Suppress("UNUSED_PARAMETER") textureId: Int): FloatArray {
        Matrix.setIdentityM(coverMatrix, 0)
        return coverMatrix
    }

    private fun deleteTexture(id: Int) {
        if (id != 0) GLES20.glDeleteTextures(1, intArrayOf(id), 0)
    }

    private fun ensureGlThread() {
        if (glThread != null) return
        val thread = HandlerThread("template-gpu-gl").also { it.start() }
        glThread = thread
        glHandler = Handler(thread.looper)
    }

    private fun runOnGl(label: String, timeoutSec: Long = 15, block: () -> Unit) {
        val handler = glHandler ?: return
        val latch = CountDownLatch(1)
        var error: Throwable? = null
        handler.post {
            try {
                block()
            } catch (t: Throwable) {
                error = t
                Log.e(TAG, label, t)
            } finally {
                latch.countDown()
            }
        }
        latch.await(timeoutSec, TimeUnit.SECONDS)
        error?.let { throw it }
    }

    private fun initEglIfNeeded() {
        if (eglDisplay != EGL14.EGL_NO_DISPLAY) return
        eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        val version = IntArray(2)
        EGL14.eglInitialize(eglDisplay, version, 0, version, 1)
        val attribList = intArrayOf(
            EGL14.EGL_RED_SIZE, 8,
            EGL14.EGL_GREEN_SIZE, 8,
            EGL14.EGL_BLUE_SIZE, 8,
            EGL14.EGL_ALPHA_SIZE, 8,
            EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
            EGL14.EGL_SURFACE_TYPE, EGL14.EGL_WINDOW_BIT,
            EGL_RECORDABLE_ANDROID, 1,
            EGL14.EGL_NONE,
        )
        val configs = arrayOfNulls<EGLConfig>(1)
        val num = IntArray(1)
        if (!EGL14.eglChooseConfig(eglDisplay, attribList, 0, configs, 0, 1, num, 0) ||
            num[0] == 0
        ) {
            val fallback = intArrayOf(
                EGL14.EGL_RED_SIZE, 8,
                EGL14.EGL_GREEN_SIZE, 8,
                EGL14.EGL_BLUE_SIZE, 8,
                EGL14.EGL_ALPHA_SIZE, 8,
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL14.EGL_SURFACE_TYPE, EGL14.EGL_WINDOW_BIT,
                EGL14.EGL_NONE,
            )
            EGL14.eglChooseConfig(eglDisplay, fallback, 0, configs, 0, 1, num, 0)
        }
        eglConfig = configs[0]
        val ctxAttribs = intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE)
        eglContext = EGL14.eglCreateContext(
            eglDisplay,
            eglConfig,
            EGL14.EGL_NO_CONTEXT,
            ctxAttribs,
            0,
        )
        // Pbuffer so we can init program before window surfaces exist.
        val pbufAttribs = intArrayOf(EGL14.EGL_WIDTH, 2, EGL14.EGL_HEIGHT, 2, EGL14.EGL_NONE)
        val pbuffer = EGL14.eglCreatePbufferSurface(eglDisplay, eglConfig, pbufAttribs, 0)
        EGL14.eglMakeCurrent(eglDisplay, pbuffer, pbuffer, eglContext)
    }

    private fun createPreviewSurface(st: SurfaceTexture) {
        destroyPreviewSurface()
        val attribs = intArrayOf(EGL14.EGL_NONE)
        previewEglSurface = EGL14.eglCreateWindowSurface(eglDisplay, eglConfig, st, attribs, 0)
    }

    private fun createEncoderSurface(surface: Surface) {
        destroyEncoderSurface()
        val attribs = intArrayOf(EGL14.EGL_NONE)
        encoderEglSurface = EGL14.eglCreateWindowSurface(eglDisplay, eglConfig, surface, attribs, 0)
    }

    private fun destroyPreviewSurface() {
        if (previewEglSurface != EGL14.EGL_NO_SURFACE) {
            EGL14.eglDestroySurface(eglDisplay, previewEglSurface)
            previewEglSurface = EGL14.EGL_NO_SURFACE
        }
    }

    private fun destroyEncoderSurface() {
        if (encoderEglSurface != EGL14.EGL_NO_SURFACE) {
            EGL14.eglDestroySurface(eglDisplay, encoderEglSurface)
            encoderEglSurface = EGL14.EGL_NO_SURFACE
        }
    }

    private fun ensureProgram() {
        if (program != 0) return
        program = linkProgram(VERTEX, FRAGMENT)
        aPosition = GLES20.glGetAttribLocation(program, "aPosition")
        aTexCoord = GLES20.glGetAttribLocation(program, "aTexCoord")
        uTexMatrix = GLES20.glGetUniformLocation(program, "uTexMatrix")
        uTexture = GLES20.glGetUniformLocation(program, "uTexture")
        uUseColorMatrix = GLES20.glGetUniformLocation(program, "uUseColorMatrix")
        uOpacity = GLES20.glGetUniformLocation(program, "uOpacity")
        for (i in 0 until 20) {
            uCM[i] = GLES20.glGetUniformLocation(program, "uCM[$i]")
        }
        val verts = floatArrayOf(
            // x, y, u, v
            -1f, -1f, 0f, 1f,
            1f, -1f, 1f, 1f,
            -1f, 1f, 0f, 0f,
            1f, 1f, 1f, 0f,
        )
        quadBuffer = ByteBuffer.allocateDirect(verts.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .put(verts)
        quadBuffer?.position(0)
    }

    private fun releaseGlLocked() {
        playing.set(false)
        imageTexCache.values.forEach { deleteTexture(it) }
        imageTexCache.clear()
        overlayTexCache.values.forEach { deleteTexture(it) }
        overlayTexCache.clear()
        videoFrameCache.values.forEach { deleteTexture(it.second) }
        videoFrameCache.clear()
        destroyPreviewSurface()
        destroyEncoderSurface()
        if (program != 0) {
            GLES20.glDeleteProgram(program)
            program = 0
        }
        if (eglDisplay != EGL14.EGL_NO_DISPLAY) {
            EGL14.eglMakeCurrent(
                eglDisplay,
                EGL14.EGL_NO_SURFACE,
                EGL14.EGL_NO_SURFACE,
                EGL14.EGL_NO_CONTEXT,
            )
            if (eglContext != EGL14.EGL_NO_CONTEXT) {
                EGL14.eglDestroyContext(eglDisplay, eglContext)
            }
            EGL14.eglTerminate(eglDisplay)
        }
        eglDisplay = EGL14.EGL_NO_DISPLAY
        eglContext = EGL14.EGL_NO_CONTEXT
        eglConfig = null
        previewSurfaceTexture = null
    }

    private fun startEncoder(
        output: File,
        w: Int,
        h: Int,
        frameRate: Int,
        bitRate: Int,
    ): SurfaceEncoder {
        return SurfaceEncoder(output, w, h, frameRate, bitRate)
    }

    private fun even(v: Int): Int = if (v % 2 == 0) v else v + 1

    private fun linkProgram(vsSrc: String, fsSrc: String): Int {
        val vs = compileShader(GLES20.GL_VERTEX_SHADER, vsSrc)
        val fs = compileShader(GLES20.GL_FRAGMENT_SHADER, fsSrc)
        val prog = GLES20.glCreateProgram()
        GLES20.glAttachShader(prog, vs)
        GLES20.glAttachShader(prog, fs)
        GLES20.glLinkProgram(prog)
        GLES20.glDeleteShader(vs)
        GLES20.glDeleteShader(fs)
        return prog
    }

    private fun compileShader(type: Int, source: String): Int {
        val shader = GLES20.glCreateShader(type)
        GLES20.glShaderSource(shader, source)
        GLES20.glCompileShader(shader)
        return shader
    }

    /** Minimal MediaCodec Surface encoder + muxer. */
    private class SurfaceEncoder(
        output: File,
        w: Int,
        h: Int,
        frameRate: Int,
        bitRate: Int,
    ) {
        val inputSurface: Surface?
        private val codec: MediaCodec
        private val muxer: MediaMuxer
        private var track = -1
        private var muxerStarted = false
        private val bufferInfo = MediaCodec.BufferInfo()

        init {
            val format = MediaFormat.createVideoFormat(MIME, w, h).apply {
                setInteger(
                    MediaFormat.KEY_COLOR_FORMAT,
                    MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface,
                )
                setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
                setInteger(MediaFormat.KEY_FRAME_RATE, frameRate)
                setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            }
            codec = MediaCodec.createEncoderByType(MIME)
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            inputSurface = codec.createInputSurface()
            codec.start()
            muxer = MediaMuxer(output.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        }

        fun drain(endOfStream: Boolean) {
            if (endOfStream) {
                try {
                    codec.signalEndOfInputStream()
                } catch (_: Throwable) {
                }
            }
            while (true) {
                val outIndex = codec.dequeueOutputBuffer(bufferInfo, 10_000)
                when {
                    outIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                        if (!endOfStream) break
                    }
                    outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        track = muxer.addTrack(codec.outputFormat)
                        muxer.start()
                        muxerStarted = true
                    }
                    outIndex >= 0 -> {
                        val encoded = codec.getOutputBuffer(outIndex)
                        if (encoded != null && bufferInfo.size > 0 && muxerStarted) {
                            encoded.position(bufferInfo.offset)
                            encoded.limit(bufferInfo.offset + bufferInfo.size)
                            muxer.writeSampleData(track, encoded, bufferInfo)
                        }
                        codec.releaseOutputBuffer(outIndex, false)
                        if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            break
                        }
                    }
                    else -> break
                }
            }
        }

        fun signalEos() {
            try {
                codec.signalEndOfInputStream()
            } catch (_: Throwable) {
            }
        }

        fun release() {
            try {
                codec.stop()
            } catch (_: Throwable) {
            }
            try {
                codec.release()
            } catch (_: Throwable) {
            }
            try {
                if (muxerStarted) muxer.stop()
            } catch (_: Throwable) {
            }
            try {
                muxer.release()
            } catch (_: Throwable) {
            }
            try {
                inputSurface?.release()
            } catch (_: Throwable) {
            }
        }
    }
}
