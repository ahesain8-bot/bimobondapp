package com.dubai.bimobondapp.ar_camera

import android.graphics.Bitmap
import android.graphics.SurfaceTexture
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.opengl.GLUtils
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

class FaceWarpRenderer : GLSurfaceView.Renderer {

    private val vertexBuffer: FloatBuffer = ByteBuffer
        .allocateDirect(QUAD_VERTICES.size * 4)
        .order(ByteOrder.nativeOrder())
        .asFloatBuffer()
        .apply {
            put(QUAD_VERTICES)
            position(0)
        }

    private var program = 0
    private var textureId = 0
    private var textureWidth = 0
    private var textureHeight = 0

    @Volatile
    private var pendingBitmap: Bitmap? = null

    @Volatile
    private var warpParams: FaceWarpParams = FaceWarpParams.INACTIVE

    private var aPosition = 0
    private var aTexCoord = 0
    private var uTexture = 0
    private var uFilterType = 0
    private var uBulge1 = 0
    private var uBulge2 = 0
    private var uNoseRect = 0
    private var uNosePull = 0
    private var uViewSize = 0
    private var uTexSize = 0
    private var uLipRect = 0
    private var uBeauty = 0
    private var uIntensity = 0
    private var uLut = 0
    private var uHasLut = 0

    private var lutTextureId = 0

    // LUT bitmaps come from LutStore's cache — never recycle them here.
    @Volatile
    private var pendingLut: Bitmap? = null

    @Volatile
    private var wantLut = false
    private var lutReady = false

    // ---- OES direct-camera pipeline (stock-camera-smooth color grades) --------
    // When [oesEnabled], the camera renders straight into an EXTERNAL_OES texture
    // via [cameraSurfaceTexture] and we grade it on the GPU in one pass — no
    // per-frame Bitmap conversion or upload. The classic bitmap path below stays
    // intact for face filters (glasses/dog/eyes/nose/beauty) and as a fallback.
    private var oesProgram = 0
    private var oesTextureId = 0
    private var cameraSurfaceTexture: SurfaceTexture? = null
    private val stMatrix = FloatArray(16)

    private var oesAPosition = 0
    private var oesATexCoord = 0
    private var oesUTexture = 0
    private var oesUStMatrix = 0
    private var oesUTexTransform = 0
    private var oesUViewSize = 0
    private var oesUTexSize = 0
    private var oesULut = 0
    private var oesUHasLut = 0
    private var oesUIntensity = 0

    // Constant Y-flip (GL vs Android). Built once — was rebuilt every frame before.
    private val texMatrixGl = FloatArray(9)
    private var texMatrixReady = false
    private val oesViewport = IntArray(4)

    @Volatile
    var oesEnabled = false

    @Volatile
    private var cameraRotationDegrees = 0

    @Volatile
    private var cameraFrontMirror = false

    @Volatile
    private var cameraBufW = 0

    @Volatile
    private var cameraBufH = 0

    @Volatile
    var lutIntensity = 1f

    /** Called on the GL thread once the camera SurfaceTexture exists (bind camera). */
    @Volatile
    var onCameraSurfaceReady: ((SurfaceTexture) -> Unit)? = null

    /** Called on the GL thread after each presented frame (drives preview swap + record). */
    @Volatile
    var onFramePresented: (() -> Unit)? = null

    fun setCameraTransform(rotationDegrees: Int, frontMirror: Boolean, bufW: Int, bufH: Int) {
        cameraRotationDegrees = ((rotationDegrees % 360) + 360) % 360
        cameraFrontMirror = frontMirror
        if (bufW > 0) cameraBufW = bufW
        if (bufH > 0) cameraBufH = bufH
    }

    fun updateTexture(bitmap: Bitmap) {
        pendingBitmap?.recycle()
        pendingBitmap = bitmap
    }

    fun setWarpParams(params: FaceWarpParams) {
        warpParams = params
    }

    /** Sets (or clears, when null) the active color-grade LUT bitmap. */
    fun setLut(bitmap: Bitmap?) {
        if (bitmap == null) {
            wantLut = false
            pendingLut = null
            return
        }
        pendingLut = bitmap
        wantLut = true
    }

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        program = buildProgram(VERTEX_SHADER, FRAGMENT_SHADER)
        aPosition = GLES20.glGetAttribLocation(program, "aPosition")
        aTexCoord = GLES20.glGetAttribLocation(program, "aTexCoord")
        uTexture = GLES20.glGetUniformLocation(program, "uTexture")
        uFilterType = GLES20.glGetUniformLocation(program, "uFilterType")
        uBulge1 = GLES20.glGetUniformLocation(program, "uBulge1")
        uBulge2 = GLES20.glGetUniformLocation(program, "uBulge2")
        uNoseRect = GLES20.glGetUniformLocation(program, "uNoseRect")
        uNosePull = GLES20.glGetUniformLocation(program, "uNosePull")
        uViewSize = GLES20.glGetUniformLocation(program, "uViewSize")
        uTexSize = GLES20.glGetUniformLocation(program, "uTexSize")
        uLipRect = GLES20.glGetUniformLocation(program, "uLipRect")
        uBeauty = GLES20.glGetUniformLocation(program, "uBeauty")
        uIntensity = GLES20.glGetUniformLocation(program, "uIntensity")
        uLut = GLES20.glGetUniformLocation(program, "uLut")
        uHasLut = GLES20.glGetUniformLocation(program, "uHasLut")

        val textures = IntArray(3)
        GLES20.glGenTextures(3, textures, 0)
        textureId = textures[0]
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureId)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)

        lutTextureId = textures[1]
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, lutTextureId)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)

        // External OES texture the camera renders into directly (no Bitmap path).
        oesTextureId = textures[2]
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, oesTextureId)
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR,
        )
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR,
        )
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE,
        )
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE,
        )

        oesProgram = buildProgram(VERTEX_SHADER, OES_FRAGMENT_SHADER)
        oesAPosition = GLES20.glGetAttribLocation(oesProgram, "aPosition")
        oesATexCoord = GLES20.glGetAttribLocation(oesProgram, "aTexCoord")
        oesUTexture = GLES20.glGetUniformLocation(oesProgram, "uTexture")
        oesUStMatrix = GLES20.glGetUniformLocation(oesProgram, "uStMatrix")
        oesUTexTransform = GLES20.glGetUniformLocation(oesProgram, "uTexTransform")
        oesUViewSize = GLES20.glGetUniformLocation(oesProgram, "uViewSize")
        oesUTexSize = GLES20.glGetUniformLocation(oesProgram, "uTexSize")
        oesULut = GLES20.glGetUniformLocation(oesProgram, "uLut")
        oesUHasLut = GLES20.glGetUniformLocation(oesProgram, "uHasLut")
        oesUIntensity = GLES20.glGetUniformLocation(oesProgram, "uIntensity")

        val st = SurfaceTexture(oesTextureId)
        cameraSurfaceTexture = st
        onCameraSurfaceReady?.invoke(st)

        // GL context (re)created: any previously uploaded LUT is gone.
        lutReady = false
        texMatrixReady = false
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        GLES20.glViewport(0, 0, width, height)
    }

    override fun onDrawFrame(gl: GL10?) {
        uploadPendingLut()

        GLES20.glClearColor(0f, 0f, 0f, 1f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)

        // Direct GPU path: camera → OES texture → grade → screen. Zero CPU/Bitmap.
        val st = cameraSurfaceTexture
        if (oesEnabled && st != null) {
            try {
                st.updateTexImage()
                st.getTransformMatrix(stMatrix)
            } catch (_: Throwable) {
                return
            }
            drawOes()
            if (captureEnabled) captureFrontBuffer()
            onFramePresented?.invoke()
            return
        }

        uploadPendingBitmap()
        if (textureWidth <= 0 || textureHeight <= 0) return

        val params = warpParams
        GLES20.glUseProgram(program)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureId)
        GLES20.glUniform1i(uTexture, 0)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE1)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, lutTextureId)
        GLES20.glUniform1i(uLut, 1)
        GLES20.glUniform1f(uHasLut, if (lutReady && wantLut) 1f else 0f)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)

        GLES20.glUniform1i(uFilterType, params.filterType)
        GLES20.glUniform4fv(uBulge1, 1, params.bulge1, 0)
        GLES20.glUniform4fv(uBulge2, 1, params.bulge2, 0)
        GLES20.glUniform4fv(uNoseRect, 1, params.noseRect, 0)
        GLES20.glUniform1f(uNosePull, params.nosePull)
        GLES20.glUniform4fv(uLipRect, 1, params.lipRect, 0)
        GLES20.glUniform1f(uBeauty, params.beauty)
        GLES20.glUniform1f(uIntensity, params.intensity.coerceIn(0f, 1f))

        val viewport = IntArray(4)
        GLES20.glGetIntegerv(GLES20.GL_VIEWPORT, viewport, 0)
        GLES20.glUniform2f(uViewSize, viewport[2].toFloat(), viewport[3].toFloat())
        GLES20.glUniform2f(uTexSize, textureWidth.toFloat(), textureHeight.toFloat())

        GLES20.glEnableVertexAttribArray(aPosition)
        GLES20.glVertexAttribPointer(aPosition, 2, GLES20.GL_FLOAT, false, 16, vertexBuffer)

        GLES20.glEnableVertexAttribArray(aTexCoord)
        vertexBuffer.position(2)
        GLES20.glVertexAttribPointer(aTexCoord, 2, GLES20.GL_FLOAT, false, 16, vertexBuffer)
        vertexBuffer.position(0)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

        GLES20.glDisableVertexAttribArray(aPosition)
        GLES20.glDisableVertexAttribArray(aTexCoord)

        if (captureEnabled) {
            captureFrontBuffer()
        }
    }

    private fun drawOes() {
        if (oesProgram == 0 || oesTextureId == 0) return
        GLES20.glUseProgram(oesProgram)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, oesTextureId)
        GLES20.glUniform1i(oesUTexture, 0)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE1)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, lutTextureId)
        GLES20.glUniform1i(oesULut, 1)
        GLES20.glUniform1f(oesUHasLut, if (lutReady && wantLut) 1f else 0f)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)

        GLES20.glUniformMatrix4fv(oesUStMatrix, 1, false, stMatrix, 0)
        GLES20.glUniform1f(oesUIntensity, lutIntensity.coerceIn(0f, 1f))

        // Y-flip only (GL vs Android). Built once — no per-frame Matrix work.
        if (!texMatrixReady) {
            // Column-major mat3 for scale(1, -1) about (0.5, 0.5):
            // x' = x
            // y' = 1 - y
            texMatrixGl[0] = 1f; texMatrixGl[1] = 0f; texMatrixGl[2] = 0f
            texMatrixGl[3] = 0f; texMatrixGl[4] = -1f; texMatrixGl[5] = 0f
            texMatrixGl[6] = 0f; texMatrixGl[7] = 1f; texMatrixGl[8] = 1f
            texMatrixReady = true
        }
        GLES20.glUniformMatrix3fv(oesUTexTransform, 1, false, texMatrixGl, 0)

        GLES20.glGetIntegerv(GLES20.GL_VIEWPORT, oesViewport, 0)
        GLES20.glUniform2f(oesUViewSize, oesViewport[2].toFloat(), oesViewport[3].toFloat())

        // ST matrix already orients the buffer, so crop aspect uses the DISPLAY
        // size (swap W/H when CameraX reports 90/270).
        val rot = cameraRotationDegrees
        val dw: Int
        val dh: Int
        if (rot == 90 || rot == 270) {
            dw = cameraBufH
            dh = cameraBufW
        } else {
            dw = cameraBufW
            dh = cameraBufH
        }
        GLES20.glUniform2f(
            oesUTexSize,
            dw.toFloat().coerceAtLeast(1f),
            dh.toFloat().coerceAtLeast(1f),
        )

        GLES20.glEnableVertexAttribArray(oesAPosition)
        GLES20.glVertexAttribPointer(oesAPosition, 2, GLES20.GL_FLOAT, false, 16, vertexBuffer)
        GLES20.glEnableVertexAttribArray(oesATexCoord)
        vertexBuffer.position(2)
        GLES20.glVertexAttribPointer(oesATexCoord, 2, GLES20.GL_FLOAT, false, 16, vertexBuffer)
        vertexBuffer.position(0)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

        GLES20.glDisableVertexAttribArray(oesAPosition)
        GLES20.glDisableVertexAttribArray(oesATexCoord)
    }

    @Volatile
    var captureEnabled: Boolean = false

    /** Cap GPU→CPU readback size while recording (full-screen read was a major lag source). */
    @Volatile
    var captureMaxEdge: Int = 960

    private val captureLock = Any()
    private var lastCapturedFrame: Bitmap? = null

    // Reused across frames — allocating ~10–20MB direct buffers every frame caused GC jank.
    private var captureReadBuf: ByteBuffer? = null
    private var captureFlipBuf: ByteBuffer? = null
    private var captureRowBuf: ByteArray? = null
    private var captureBufBytes = 0
    private var lastCaptureMs = 0L
    private val captureMinIntervalMs = 33L // ~30 fps — matches the encoder pump

    /** When true, the next draw ignores the capture throttle (still photo). */
    @Volatile
    var forceCaptureNextFrame: Boolean = false

    fun peekLastCapturedFrame(): Bitmap? = synchronized(captureLock) { lastCapturedFrame }

    fun copyLastCapturedFrame(): Bitmap? = synchronized(captureLock) {
        val frame = lastCapturedFrame
        if (frame == null || frame.isRecycled) return null
        return try {
            frame.copy(Bitmap.Config.ARGB_8888, false)
        } catch (_: Exception) {
            null
        }
    }

    /** Ownership transfer — no copy. Caller must recycle. */
    fun takeLastCapturedFrame(): Bitmap? = synchronized(captureLock) {
        val frame = lastCapturedFrame
        lastCapturedFrame = null
        if (frame == null || frame.isRecycled) return null
        return frame
    }

    private fun ensureCaptureBuffers(bytes: Int, rowBytes: Int) {
        if (captureBufBytes >= bytes && captureReadBuf != null && captureFlipBuf != null) {
            captureReadBuf!!.clear()
            captureFlipBuf!!.clear()
            if (captureRowBuf == null || captureRowBuf!!.size < rowBytes) {
                captureRowBuf = ByteArray(rowBytes)
            }
            return
        }
        captureReadBuf = ByteBuffer.allocateDirect(bytes).order(ByteOrder.nativeOrder())
        captureFlipBuf = ByteBuffer.allocateDirect(bytes).order(ByteOrder.nativeOrder())
        captureRowBuf = ByteArray(rowBytes)
        captureBufBytes = bytes
    }

    private var captureScratchBitmap: Bitmap? = null
    private val captureViewport = IntArray(4)

    private fun captureFrontBuffer() {
        val now = android.os.SystemClock.elapsedRealtime()
        val force = forceCaptureNextFrame
        if (!force && now - lastCaptureMs < captureMinIntervalMs) return
        forceCaptureNextFrame = false
        lastCaptureMs = now

        GLES20.glGetIntegerv(GLES20.GL_VIEWPORT, captureViewport, 0)
        val w = captureViewport[2]
        val h = captureViewport[3]
        if (w <= 1 || h <= 1) return

        val rowBytes = w * 4
        val bytes = rowBytes * h
        ensureCaptureBuffers(bytes, rowBytes)
        val buf = captureReadBuf!!
        val flipped = captureFlipBuf!!
        val rowBuf = captureRowBuf!!
        buf.clear()
        flipped.clear()

        GLES20.glReadPixels(0, 0, w, h, GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, buf)

        // GL origin is bottom-left — flip rows into Bitmap order (bulk row copies).
        for (row in 0 until h) {
            buf.position((h - 1 - row) * rowBytes)
            buf.get(rowBuf, 0, rowBytes)
            flipped.put(rowBuf)
        }
        flipped.rewind()

        // Reuse the full-res scratch bitmap (avoid createBitmap every frame).
        var scratch = captureScratchBitmap
        if (scratch == null || scratch.isRecycled || scratch.width != w || scratch.height != h) {
            scratch?.recycle()
            scratch = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            captureScratchBitmap = scratch
        }
        scratch.copyPixelsFromBuffer(flipped)

        // Shrink once for the encoder — encoder MAX_EDGE is 1280; 960 keeps
        // readback→scale cheaper without a visible quality drop on phone screens.
        val maxEdge = captureMaxEdge.coerceAtLeast(2)
        val largest = maxOf(w, h)
        val out: Bitmap = if (largest > maxEdge) {
            val s = maxEdge.toFloat() / largest
            val sw = ((w * s).toInt() and 1.inv()).coerceAtLeast(2)
            val sh = ((h * s).toInt() and 1.inv()).coerceAtLeast(2)
            Bitmap.createScaledBitmap(scratch, sw, sh, true)
        } else {
            scratch.copy(Bitmap.Config.ARGB_8888, false)
        }

        synchronized(captureLock) {
            val previous = lastCapturedFrame
            lastCapturedFrame = out
            if (previous != null && previous !== out && !previous.isRecycled) {
                previous.recycle()
            }
        }
    }

    fun release() {
        captureEnabled = false
        synchronized(captureLock) {
            lastCapturedFrame?.recycle()
            lastCapturedFrame = null
        }
        pendingBitmap?.recycle()
        pendingBitmap = null
        pendingLut = null
        lutReady = false
        oesEnabled = false
        texMatrixReady = false
        captureScratchBitmap?.recycle()
        captureScratchBitmap = null
        captureReadBuf = null
        captureFlipBuf = null
        captureRowBuf = null
        captureBufBytes = 0
        try {
            cameraSurfaceTexture?.release()
        } catch (_: Throwable) {
        }
        cameraSurfaceTexture = null
        if (textureId != 0) {
            GLES20.glDeleteTextures(1, intArrayOf(textureId), 0)
            textureId = 0
        }
        if (lutTextureId != 0) {
            GLES20.glDeleteTextures(1, intArrayOf(lutTextureId), 0)
            lutTextureId = 0
        }
        if (oesTextureId != 0) {
            GLES20.glDeleteTextures(1, intArrayOf(oesTextureId), 0)
            oesTextureId = 0
        }
        if (program != 0) {
            GLES20.glDeleteProgram(program)
            program = 0
        }
        if (oesProgram != 0) {
            GLES20.glDeleteProgram(oesProgram)
            oesProgram = 0
        }
    }

    private fun uploadPendingLut() {
        val bitmap = pendingLut ?: return
        pendingLut = null
        if (bitmap.isRecycled) return
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, lutTextureId)
        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0)
        lutReady = true
        // Do NOT recycle: LutStore owns/caches this bitmap.
    }

    private fun uploadPendingBitmap() {
        val bitmap = pendingBitmap ?: return
        pendingBitmap = null

        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureId)
        if (bitmap.width == textureWidth && bitmap.height == textureHeight && textureId != 0) {
            GLUtils.texSubImage2D(GLES20.GL_TEXTURE_2D, 0, 0, 0, bitmap)
        } else {
            GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0)
            textureWidth = bitmap.width
            textureHeight = bitmap.height
        }
        bitmap.recycle()
    }

    private fun buildProgram(vertexSource: String, fragmentSource: String): Int {
        val vertexShader = compileShader(GLES20.GL_VERTEX_SHADER, vertexSource)
        val fragmentShader = compileShader(GLES20.GL_FRAGMENT_SHADER, fragmentSource)
        val program = GLES20.glCreateProgram()
        GLES20.glAttachShader(program, vertexShader)
        GLES20.glAttachShader(program, fragmentShader)
        GLES20.glLinkProgram(program)

        val linkStatus = IntArray(1)
        GLES20.glGetProgramiv(program, GLES20.GL_LINK_STATUS, linkStatus, 0)
        if (linkStatus[0] != GLES20.GL_TRUE) {
            android.util.Log.e(TAG, "Program link failed: ${GLES20.glGetProgramInfoLog(program)}")
        }

        GLES20.glDeleteShader(vertexShader)
        GLES20.glDeleteShader(fragmentShader)
        return program
    }

    private fun compileShader(type: Int, source: String): Int {
        val shader = GLES20.glCreateShader(type)
        GLES20.glShaderSource(shader, source)
        GLES20.glCompileShader(shader)

        val status = IntArray(1)
        GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, status, 0)
        if (status[0] != GLES20.GL_TRUE) {
            android.util.Log.e(TAG, "Shader compile failed: ${GLES20.glGetShaderInfoLog(shader)}")
        }
        return shader
    }

    companion object {
        private const val TAG = "FaceWarpRenderer"

        private val QUAD_VERTICES = floatArrayOf(
            -1f, -1f, 0f, 1f,
            1f, -1f, 1f, 1f,
            -1f, 1f, 0f, 0f,
            1f, 1f, 1f, 0f,
        )

        private const val VERTEX_SHADER = """
            attribute vec4 aPosition;
            attribute vec2 aTexCoord;
            varying vec2 vTexCoord;
            void main() {
                gl_Position = aPosition;
                vTexCoord = aTexCoord;
            }
        """

        // Direct camera (EXTERNAL_OES) → color grade in ONE GPU pass. This is the
        // "stock-camera-smooth" path: the camera writes into the OES texture and we
        // grade it here — no Bitmap, no CPU LUT, no glReadPixels for preview.
        private const val OES_FRAGMENT_SHADER = """
            #extension GL_OES_EGL_image_external : require
            precision highp float;
            varying vec2 vTexCoord;
            uniform samplerExternalOES uTexture;
            uniform sampler2D uLut;
            uniform float uHasLut;
            uniform mat4 uStMatrix;
            uniform mat3 uTexTransform;
            uniform vec2 uViewSize;
            uniform vec2 uTexSize;
            uniform float uIntensity;

            vec3 applyLut(vec3 texColor) {
                float blueColor = texColor.b * 63.0;
                vec2 quad1;
                quad1.y = floor(floor(blueColor) / 8.0);
                quad1.x = floor(blueColor) - (quad1.y * 8.0);
                vec2 quad2;
                quad2.y = floor(ceil(blueColor) / 8.0);
                quad2.x = ceil(blueColor) - (quad2.y * 8.0);
                vec2 texPos1;
                texPos1.x = (quad1.x * 0.125) + 0.5/512.0 + ((0.125 - 1.0/512.0) * texColor.r);
                texPos1.y = (quad1.y * 0.125) + 0.5/512.0 + ((0.125 - 1.0/512.0) * texColor.g);
                vec2 texPos2;
                texPos2.x = (quad2.x * 0.125) + 0.5/512.0 + ((0.125 - 1.0/512.0) * texColor.r);
                texPos2.y = (quad2.y * 0.125) + 0.5/512.0 + ((0.125 - 1.0/512.0) * texColor.g);
                vec4 newColor1 = texture2D(uLut, texPos1);
                vec4 newColor2 = texture2D(uLut, texPos2);
                return mix(newColor1, newColor2, fract(blueColor)).rgb;
            }

            vec2 centerCrop(vec2 uv) {
                float viewAspect = uViewSize.x / uViewSize.y;
                float texAspect = uTexSize.x / uTexSize.y;
                if (texAspect > viewAspect) {
                    float scale = viewAspect / texAspect;
                    float offset = (1.0 - scale) * 0.5;
                    return vec2(uv.x * scale + offset, uv.y);
                } else {
                    float scale = texAspect / viewAspect;
                    float offset = (1.0 - scale) * 0.5;
                    return vec2(uv.x, uv.y * scale + offset);
                }
            }

            void main() {
                vec2 d = centerCrop(vTexCoord);
                vec3 b = uTexTransform * vec3(d, 1.0);
                vec2 st = (uStMatrix * vec4(b.xy, 0.0, 1.0)).xy;
                vec3 col = texture2D(uTexture, st).rgb;
                if (uHasLut > 0.5) {
                    vec3 graded = applyLut(clamp(col, 0.0, 1.0));
                    col = mix(col, graded, clamp(uIntensity, 0.0, 1.0));
                }
                gl_FragColor = vec4(col, 1.0);
            }
        """

        private const val FRAGMENT_SHADER = """
            precision highp float;
            varying vec2 vTexCoord;
            uniform sampler2D uTexture;
            uniform int uFilterType;
            uniform vec4 uBulge1;
            uniform vec4 uBulge2;
            uniform vec4 uNoseRect;
            uniform float uNosePull;
            uniform vec2 uViewSize;
            uniform vec2 uTexSize;
            uniform vec4 uLipRect;
            uniform float uBeauty;
            uniform float uIntensity;
            uniform sampler2D uLut;
            uniform float uHasLut;

            // 512x512 lookup LUT sampling (8x8 tiles of 64x64 = 64^3 cube).
            // Mirrors LutStore.kt so live preview and the baked photo match.
            vec3 applyLut(vec3 texColor) {
                float blueColor = texColor.b * 63.0;
                vec2 quad1;
                quad1.y = floor(floor(blueColor) / 8.0);
                quad1.x = floor(blueColor) - (quad1.y * 8.0);
                vec2 quad2;
                quad2.y = floor(ceil(blueColor) / 8.0);
                quad2.x = ceil(blueColor) - (quad2.y * 8.0);
                vec2 texPos1;
                texPos1.x = (quad1.x * 0.125) + 0.5/512.0 + ((0.125 - 1.0/512.0) * texColor.r);
                texPos1.y = (quad1.y * 0.125) + 0.5/512.0 + ((0.125 - 1.0/512.0) * texColor.g);
                vec2 texPos2;
                texPos2.x = (quad2.x * 0.125) + 0.5/512.0 + ((0.125 - 1.0/512.0) * texColor.r);
                texPos2.y = (quad2.y * 0.125) + 0.5/512.0 + ((0.125 - 1.0/512.0) * texColor.g);
                vec4 newColor1 = texture2D(uLut, texPos1);
                vec4 newColor2 = texture2D(uLut, texPos2);
                return mix(newColor1, newColor2, fract(blueColor)).rgb;
            }

            vec2 centerCrop(vec2 uv) {
                float viewAspect = uViewSize.x / uViewSize.y;
                float texAspect = uTexSize.x / uTexSize.y;
                if (texAspect > viewAspect) {
                    float scale = viewAspect / texAspect;
                    float offset = (1.0 - scale) * 0.5;
                    return vec2(uv.x * scale + offset, uv.y);
                } else {
                    float scale = texAspect / viewAspect;
                    float offset = (1.0 - scale) * 0.5;
                    return vec2(uv.x, uv.y * scale + offset);
                }
            }

            vec2 applyBulge(vec2 tc, vec4 bulge, vec2 texSize) {
                if (bulge.w <= 0.0) return tc;
                vec2 center = bulge.xy;
                float radiusX = max(bulge.z, 0.001);
                float radiusY = max(bulge.z * (texSize.x / texSize.y), 0.001);
                vec2 d = vec2((tc.x - center.x) / radiusX, (tc.y - center.y) / radiusY);
                float dist = length(d);
                if (dist >= 1.0) return tc;
                float weight = 1.0 - dist * dist;
                float smoothVal = exp(-dist * dist * 1.5) * weight * weight;
                float scale = 1.0 + bulge.w * smoothVal;
                vec2 offset = vec2(d.x * radiusX, d.y * radiusY);
                return center + offset / scale;
            }

            vec4 sharpenSample(vec2 tc, vec2 texSize) {
                vec2 px = vec2(1.0 / texSize.x, 1.0 / texSize.y);
                vec4 center = texture2D(uTexture, tc);
                vec4 blur = (
                    texture2D(uTexture, tc + vec2(px.x, 0.0)) +
                    texture2D(uTexture, tc - vec2(px.x, 0.0)) +
                    texture2D(uTexture, tc + vec2(0.0, px.y)) +
                    texture2D(uTexture, tc - vec2(0.0, px.y))
                ) * 0.25;
                return center + (center - blur) * 0.55;
            }

            float luma(vec3 c) {
                return dot(c, vec3(0.299, 0.587, 0.114));
            }

            // Edge-aware skin smoothing: blur skin tones while preserving strong
            // edges (eyes, brows, lips) using a luminance-weighted average.
            vec3 smoothSkin(vec2 tc, vec2 texSize, vec3 orig, float strength) {
                if (strength <= 0.0) return orig;
                vec2 px = vec2(1.0 / texSize.x, 1.0 / texSize.y) * 2.0;
                float centerL = luma(orig);
                vec3 sum = orig;
                float wsum = 1.0;
                for (int i = 0; i < 12; i++) {
                    vec2 o;
                    if (i == 0) o = vec2( 1.0,  0.0);
                    else if (i == 1) o = vec2(-1.0,  0.0);
                    else if (i == 2) o = vec2( 0.0,  1.0);
                    else if (i == 3) o = vec2( 0.0, -1.0);
                    else if (i == 4) o = vec2( 1.0,  1.0);
                    else if (i == 5) o = vec2(-1.0,  1.0);
                    else if (i == 6) o = vec2( 1.0, -1.0);
                    else if (i == 7) o = vec2(-1.0, -1.0);
                    else if (i == 8) o = vec2( 2.0,  0.0);
                    else if (i == 9) o = vec2(-2.0,  0.0);
                    else if (i == 10) o = vec2( 0.0,  2.0);
                    else o = vec2( 0.0, -2.0);
                    vec3 s = texture2D(uTexture, tc + o * px).rgb;
                    float w = exp(-abs(luma(s) - centerL) * 8.0);
                    sum += s * w;
                    wsum += w;
                }
                vec3 blurred = sum / wsum;
                return mix(orig, blurred, strength);
            }

            float lipMask(vec2 tc, vec3 c) {
                if (uLipRect.z <= uLipRect.x) return 0.0;
                vec2 lipCenter = (uLipRect.xy + uLipRect.zw) * 0.5;
                vec2 lipHalf = max((uLipRect.zw - uLipRect.xy) * 0.5, vec2(0.001));
                vec2 d = (tc - lipCenter) / lipHalf;
                float inside = 1.0 - smoothstep(0.7, 1.0, length(d));
                // Redness test isolates lips from surrounding skin.
                float redness = c.r - (c.g + c.b) * 0.5;
                float red = smoothstep(0.02, 0.14, redness);
                return inside * red;
            }

            void main() {
                vec2 tc = centerCrop(vTexCoord);

                if (uFilterType == 3) {
                    vec2 center = uBulge1.xy;
                    float sigmaX = max(uBulge1.z, 0.001);
                    float sigmaY = max(uBulge1.w, 0.001);
                    float dx = (tc.x - center.x) / sigmaX;
                    float dy = (tc.y - center.y) / sigmaY;
                    float yFactor = smoothstep(-1.2, 0.8, dy);
                    float mask = exp(-(dx * dx * 1.3 + dy * dy * 0.8));
                    tc.y -= uNosePull * yFactor * mask;
                } else if (uFilterType == 1 || uFilterType == 2) {
                    tc = applyBulge(tc, uBulge1, uTexSize);
                    tc = applyBulge(tc, uBulge2, uTexSize);
                }

                vec4 sourceColor;
                if (uFilterType == 0) {
                    sourceColor = texture2D(uTexture, tc);
                } else {
                    sourceColor = sharpenSample(tc, uTexSize);
                }

                vec3 col = sourceColor.rgb;

                // Skin smoothing for beauty grades (whitening / rosy).
                if (uBeauty > 0.0) {
                    col = smoothSkin(tc, uTexSize, col, uBeauty);
                }

                if (uHasLut > 0.5) {
                    // Professional path: sample the color grade from the LUT.
                    col = applyLut(clamp(col, 0.0, 1.0));
                } else if (uFilterType == 4) { // Beauty / skin smooth
                    vec3 b = pow(col, vec3(0.90));
                    b = mix(b, b + vec3(0.04, 0.03, 0.03), 0.55);
                    b = mix(b, vec3(luma(b)), 0.04);
                    col = clamp(b, 0.0, 1.0);
                    float lm = lipMask(tc, sourceColor.rgb);
                    col = mix(col, clamp(col * vec3(1.18, 0.82, 0.88), 0.0, 1.0), lm * 0.38);
                } else if (uFilterType == 5) { // Warm / Peach
                    vec3 w = vec3(col.r * 1.10, col.g * 1.03, col.b * 0.88);
                    w = pow(w, vec3(0.95));
                    col = clamp(w, 0.0, 1.0);
                } else if (uFilterType == 6) { // Black & White (film)
                    float g = luma(col);
                    g = clamp((g - 0.5) * 1.22 + 0.5, 0.0, 1.0);
                    col = vec3(g);
                } else if (uFilterType == 7) { // Cool
                    vec3 cc = vec3(col.r * 0.92, col.g * 1.0, col.b * 1.12);
                    cc = clamp((cc - 0.5) * 1.06 + 0.5, 0.0, 1.0);
                    col = cc;
                } else if (uFilterType == 8) { // Vintage / Film
                    vec3 v = col;
                    v = clamp((v - 0.5) * 0.90 + 0.5, 0.0, 1.0);
                    v = vec3(
                        v.r * 1.06 + 0.04,
                        v.g * 1.01 + 0.02,
                        v.b * 0.86
                    );
                    // Subtle vignette.
                    float vg = distance(vTexCoord, vec2(0.5));
                    v *= 1.0 - smoothstep(0.55, 0.95, vg) * 0.35;
                    col = clamp(v, 0.0, 1.0);
                } else if (uFilterType == 9) { // Rosy
                    vec3 r = pow(col, vec3(0.92));
                    r = mix(r, r * vec3(1.04, 0.97, 0.98), 0.45);
                    r += vec3(0.02, 0.01, 0.015);
                    col = clamp(r, 0.0, 1.0);
                    float lm = lipMask(tc, sourceColor.rgb);
                    col = mix(col, clamp(col * vec3(1.22, 0.78, 0.84), 0.0, 1.0), lm * 0.42);
                } else if (uFilterType == 10) { // Clarendon (IG)
                    vec3 c = clamp((col - 0.5) * 1.18 + 0.5, 0.0, 1.0);
                    c.r = c.r * 1.04 + 0.01;
                    c.b = c.b * 1.08 + 0.02;
                    c.g = c.g * 1.02;
                    col = clamp(c, 0.0, 1.0);
                } else if (uFilterType == 11) { // Valencia (IG)
                    vec3 v = col;
                    v = mix(v, v * vec3(1.14, 1.06, 0.86), 0.72);
                    v = pow(v, vec3(0.94));
                    v = v * 0.94 + 0.06;
                    col = clamp(v, 0.0, 1.0);
                } else if (uFilterType == 12) { // Ludwig (IG)
                    vec3 l = pow(col, vec3(0.91));
                    l = mix(l, vec3(luma(l)), 0.06);
                    l = l * 1.04 + 0.035;
                    l = mix(l, l * vec3(1.02, 1.0, 1.01), 0.5);
                    col = clamp(l, 0.0, 1.0);
                    float lm = lipMask(tc, sourceColor.rgb);
                    col = mix(col, clamp(col * vec3(1.12, 0.86, 0.90), 0.0, 1.0), lm * 0.28);
                }

                // Intensity: blend unfiltered look back in (TikTok-style strength).
                if (uFilterType >= 4 && uIntensity < 0.999) {
                    vec3 base = texture2D(uTexture, tc).rgb;
                    col = mix(base, col, clamp(uIntensity, 0.0, 1.0));
                }

                gl_FragColor = vec4(col, sourceColor.a);
            }
        """
    }
}
