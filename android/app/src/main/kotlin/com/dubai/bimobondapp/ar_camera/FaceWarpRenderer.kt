package com.dubai.bimobondapp.ar_camera

import android.graphics.Bitmap
import android.graphics.SurfaceTexture
import android.opengl.EGL14
import android.opengl.EGLExt
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.opengl.GLUtils
import android.os.SystemClock
import android.view.Surface
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10
import android.opengl.EGLConfig as AndroidEglConfig
import android.opengl.EGLSurface as AndroidEglSurface

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
    private var uRetouchSaturation = 0
    private var uRetouchBrightness = 0
    private var uRetouchContrast = 0
    private var uRetouchExposure = 0
    private var uRetouchWhiteBalance = 0
    private var uRetouchHighlights = 0
    private var uRetouchShadows = 0
    private var uRetouchNose = 0
    private var uNoseWingL = 0
    private var uNoseWingR = 0
    private var uNoseRadius = 0

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
    private var oesURetouchSaturation = 0
    private var oesURetouchBrightness = 0
    private var oesURetouchContrast = 0
    private var oesURetouchExposure = 0
    private var oesURetouchWhiteBalance = 0
    private var oesURetouchHighlights = 0
    private var oesURetouchShadows = 0
    private var oesURetouchNose = 0
    private var oesUNoseWingL = 0
    private var oesUNoseWingR = 0
    private var oesUNoseRadius = 0

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
    var onCameraSurfaceReady: ((SurfaceTexture) -> Unit)? = null

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
        uRetouchSaturation = GLES20.glGetUniformLocation(program, "uRetouchSaturation")
        uRetouchBrightness = GLES20.glGetUniformLocation(program, "uRetouchBrightness")
        uRetouchContrast = GLES20.glGetUniformLocation(program, "uRetouchContrast")
        uRetouchExposure = GLES20.glGetUniformLocation(program, "uRetouchExposure")
        uRetouchWhiteBalance = GLES20.glGetUniformLocation(program, "uRetouchWhiteBalance")
        uRetouchHighlights = GLES20.glGetUniformLocation(program, "uRetouchHighlights")
        uRetouchShadows = GLES20.glGetUniformLocation(program, "uRetouchShadows")
        uRetouchNose = GLES20.glGetUniformLocation(program, "uRetouchNose")
        uNoseWingL = GLES20.glGetUniformLocation(program, "uNoseWingL")
        uNoseWingR = GLES20.glGetUniformLocation(program, "uNoseWingR")
        uNoseRadius = GLES20.glGetUniformLocation(program, "uNoseRadius")

        val textures = IntArray(2)
        GLES20.glGenTextures(2, textures, 0)
        textureId = textures[0]
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureId)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)

        oesTextureId = textures[1]
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
        oesURetouchSaturation = GLES20.glGetUniformLocation(oesProgram, "uRetouchSaturation")
        oesURetouchBrightness = GLES20.glGetUniformLocation(oesProgram, "uRetouchBrightness")
        oesURetouchContrast = GLES20.glGetUniformLocation(oesProgram, "uRetouchContrast")
        oesURetouchExposure = GLES20.glGetUniformLocation(oesProgram, "uRetouchExposure")
        oesURetouchWhiteBalance = GLES20.glGetUniformLocation(oesProgram, "uRetouchWhiteBalance")
        oesURetouchHighlights = GLES20.glGetUniformLocation(oesProgram, "uRetouchHighlights")
        oesURetouchShadows = GLES20.glGetUniformLocation(oesProgram, "uRetouchShadows")
        oesURetouchNose = GLES20.glGetUniformLocation(oesProgram, "uRetouchNose")
        oesUNoseWingL = GLES20.glGetUniformLocation(oesProgram, "uNoseWingL")
        oesUNoseWingR = GLES20.glGetUniformLocation(oesProgram, "uNoseWingR")
        oesUNoseRadius = GLES20.glGetUniformLocation(oesProgram, "uNoseRadius")

        val st = SurfaceTexture(oesTextureId)
        cameraSurfaceTexture = st
        onCameraSurfaceReady?.invoke(st)

        texMatrixReady = false
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        GLES20.glViewport(0, 0, width, height)
    }

    override fun onDrawFrame(gl: GL10?) {
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)

        val st = cameraSurfaceTexture
        if (oesEnabled && st != null) {
            try {
                st.updateTexImage()
                st.getTransformMatrix(stMatrix)
            } catch (_: Throwable) {
                return
            }
            drawOes()

            presentToEncoder { drawOes() }
            if (captureEnabled) captureFrontBuffer { drawOes() }
            onFramePresented?.invoke()
            return
        }

        uploadPendingBitmap()
        if (textureWidth <= 0 || textureHeight <= 0) return

        drawBitmapFrame()
        presentToEncoder { drawBitmapFrame() }
        if (captureEnabled) captureFrontBuffer { drawBitmapFrame() }
        onFramePresented?.invoke()
    }

    private fun drawBitmapFrame() {
        val params = warpParams
        GLES20.glUseProgram(program)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureId)
        GLES20.glUniform1i(uTexture, 0)

        GLES20.glUniform1i(uFilterType, params.filterType)
        GLES20.glUniform4fv(uBulge1, 1, params.bulge1, 0)
        GLES20.glUniform4fv(uBulge2, 1, params.bulge2, 0)
        GLES20.glUniform4fv(uNoseRect, 1, params.noseRect, 0)
        GLES20.glUniform1f(uNosePull, params.nosePull)

        GLES20.glGetIntegerv(GLES20.GL_VIEWPORT, captureViewport, 0)
        GLES20.glUniform2f(uViewSize, captureViewport[2].toFloat(), captureViewport[3].toFloat())
        GLES20.glUniform2f(uTexSize, textureWidth.toFloat(), textureHeight.toFloat())
        bindRetouchUniforms(
            uRetouchSaturation,
            uRetouchBrightness,
            uRetouchContrast,
            uRetouchExposure,
            uRetouchWhiteBalance,
            uRetouchHighlights,
            uRetouchShadows,
            uRetouchNose,
            uNoseWingL,
            uNoseWingR,
            uNoseRadius,
        )

        GLES20.glEnableVertexAttribArray(aPosition)
        GLES20.glVertexAttribPointer(aPosition, 2, GLES20.GL_FLOAT, false, 16, vertexBuffer)

        GLES20.glEnableVertexAttribArray(aTexCoord)
        vertexBuffer.position(2)
        GLES20.glVertexAttribPointer(aTexCoord, 2, GLES20.GL_FLOAT, false, 16, vertexBuffer)
        vertexBuffer.position(0)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

        GLES20.glDisableVertexAttribArray(aPosition)
        GLES20.glDisableVertexAttribArray(aTexCoord)
    }

    private fun drawOes() {
        if (oesProgram == 0 || oesTextureId == 0) return
        GLES20.glUseProgram(oesProgram)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, oesTextureId)
        GLES20.glUniform1i(oesUTexture, 0)

        GLES20.glUniformMatrix4fv(oesUStMatrix, 1, false, stMatrix, 0)

        // Y-flip (GL vs Android). Required — without this the preview is upside-down.
        if (!texMatrixReady) {
            texMatrixGl[0] = 1f; texMatrixGl[1] = 0f; texMatrixGl[2] = 0f
            texMatrixGl[3] = 0f; texMatrixGl[4] = -1f; texMatrixGl[5] = 0f
            texMatrixGl[6] = 0f; texMatrixGl[7] = 1f; texMatrixGl[8] = 1f
            texMatrixReady = true
        }
        GLES20.glUniformMatrix3fv(oesUTexTransform, 1, false, texMatrixGl, 0)

        GLES20.glGetIntegerv(GLES20.GL_VIEWPORT, oesViewport, 0)
        GLES20.glUniform2f(oesUViewSize, oesViewport[2].toFloat(), oesViewport[3].toFloat())

        // After rot 90/270 the displayed frame is portrait — swap for FILL_CENTER.
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
        bindRetouchUniforms(
            oesURetouchSaturation,
            oesURetouchBrightness,
            oesURetouchContrast,
            oesURetouchExposure,
            oesURetouchWhiteBalance,
            oesURetouchHighlights,
            oesURetouchShadows,
            oesURetouchNose,
            oesUNoseWingL,
            oesUNoseWingR,
            oesUNoseRadius,
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

    @Volatile
    private var encoderAndroidSurface: Surface? = null

    @Volatile
    private var encoderWidth = 0

    @Volatile
    private var encoderHeight = 0

    private var encoderEglSurface: AndroidEglSurface? = null
    private var lastEncoderSwapMs = 0L
    private val encoderMinIntervalMs = 33L
    private val encoderRestoreViewport = IntArray(4)

    fun setEncoderTarget(surface: Surface?, width: Int, height: Int) {
        destroyEncoderEglSurface()
        encoderAndroidSurface = surface
        encoderWidth = width.coerceAtLeast(2)
        encoderHeight = height.coerceAtLeast(2)
        lastEncoderSwapMs = 0L
    }

    private fun destroyEncoderEglSurface() {
        val eglSurf = encoderEglSurface
        encoderEglSurface = null
        if (eglSurf != null && eglSurf != EGL14.EGL_NO_SURFACE) {
            val display = EGL14.eglGetCurrentDisplay()
            if (display != null && display != EGL14.EGL_NO_DISPLAY) {
                try {
                    EGL14.eglDestroySurface(display, eglSurf)
                } catch (_: Throwable) {
                }
            }
        }
    }

    private fun chooseRecordableConfig(
        display: android.opengl.EGLDisplay,
    ): AndroidEglConfig? {
        val attribList = intArrayOf(
            EGL14.EGL_RED_SIZE, 8,
            EGL14.EGL_GREEN_SIZE, 8,
            EGL14.EGL_BLUE_SIZE, 8,
            EGL14.EGL_ALPHA_SIZE, 8,
            EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
            EGLExt.EGL_RECORDABLE_ANDROID, 1,
            EGL14.EGL_NONE,
        )
        val configs = arrayOfNulls<AndroidEglConfig>(1)
        val numConfigs = IntArray(1)
        if (!EGL14.eglChooseConfig(display, attribList, 0, configs, 0, 1, numConfigs, 0)) {

            val fallback = intArrayOf(
                EGL14.EGL_RED_SIZE, 8,
                EGL14.EGL_GREEN_SIZE, 8,
                EGL14.EGL_BLUE_SIZE, 8,
                EGL14.EGL_ALPHA_SIZE, 8,
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL14.EGL_NONE,
            )
            if (!EGL14.eglChooseConfig(display, fallback, 0, configs, 0, 1, numConfigs, 0)) {
                return null
            }
        }
        return configs[0]
    }

    private fun presentToEncoder(draw: () -> Unit) {
        val androidSurface = encoderAndroidSurface ?: return
        if (!androidSurface.isValid) return
        val encW = encoderWidth
        val encH = encoderHeight
        if (encW < 2 || encH < 2) return

        val now = SystemClock.elapsedRealtime()
        if (now - lastEncoderSwapMs < encoderMinIntervalMs) return

        val eglDisplay = EGL14.eglGetCurrentDisplay()
        val eglContext = EGL14.eglGetCurrentContext()
        val backupDraw = EGL14.eglGetCurrentSurface(EGL14.EGL_DRAW)
        val backupRead = EGL14.eglGetCurrentSurface(EGL14.EGL_READ)
        if (eglDisplay == EGL14.EGL_NO_DISPLAY ||
            eglContext == EGL14.EGL_NO_CONTEXT ||
            backupDraw == EGL14.EGL_NO_SURFACE
        ) {
            return
        }

        GLES20.glGetIntegerv(GLES20.GL_VIEWPORT, encoderRestoreViewport, 0)

        var eglSurf = encoderEglSurface
        if (eglSurf == null || eglSurf == EGL14.EGL_NO_SURFACE) {
            val config = chooseRecordableConfig(eglDisplay) ?: return
            val surfaceAttribs = intArrayOf(EGL14.EGL_NONE)
            eglSurf = EGL14.eglCreateWindowSurface(
                eglDisplay,
                config,
                androidSurface,
                surfaceAttribs,
                0,
            )
            if (eglSurf == null || eglSurf == EGL14.EGL_NO_SURFACE) return
            encoderEglSurface = eglSurf
        }

        if (!EGL14.eglMakeCurrent(eglDisplay, eglSurf, eglSurf, eglContext)) return
        try {
            GLES20.glViewport(0, 0, encW, encH)
            GLES20.glClearColor(0f, 0f, 0f, 1f)
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
            draw()
            EGLExt.eglPresentationTimeANDROID(
                eglDisplay,
                eglSurf,
                now * 1_000_000L,
            )
            EGL14.eglSwapBuffers(eglDisplay, eglSurf)
            lastEncoderSwapMs = now
        } catch (_: Throwable) {
        } finally {
            EGL14.eglMakeCurrent(eglDisplay, backupDraw, backupRead, eglContext)
            GLES20.glViewport(
                encoderRestoreViewport[0],
                encoderRestoreViewport[1],
                encoderRestoreViewport[2],
                encoderRestoreViewport[3],
            )
        }
    }

    @Volatile
    var captureMaxEdge: Int = 960

    private val captureLock = Any()
    private var lastCapturedFrame: Bitmap? = null

    private var captureReadBuf: ByteBuffer? = null
    private var captureFlipBuf: ByteBuffer? = null
    private var captureRowBuf: ByteArray? = null
    private var captureBufBytes = 0
    private var lastCaptureMs = 0L
    /** ~10fps readback — enough for instant shutter, light on GPU. */
    private val captureMinIntervalMs = 100L

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

    fun takeLastCapturedFrame(): Bitmap? = synchronized(captureLock) {
        val frame = lastCapturedFrame
        lastCapturedFrame = null
        if (frame == null || frame.isRecycled) return null
        return frame
    }

    fun clearLastCapturedFrame() = synchronized(captureLock) {
        val frame = lastCapturedFrame
        lastCapturedFrame = null
        if (frame != null && !frame.isRecycled) {
            try {
                frame.recycle()
            } catch (_: Exception) {
            }
        }
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

    private var captureFboId = 0
    private var captureFboTexId = 0
    private var captureFboW = 0
    private var captureFboH = 0

    private fun ensureCaptureFbo(w: Int, h: Int) {
        if (captureFboId != 0 && captureFboW == w && captureFboH == h) return
        releaseCaptureFbo()
        val tex = IntArray(1)
        GLES20.glGenTextures(1, tex, 0)
        captureFboTexId = tex[0]
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, captureFboTexId)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexImage2D(
            GLES20.GL_TEXTURE_2D,
            0,
            GLES20.GL_RGBA,
            w,
            h,
            0,
            GLES20.GL_RGBA,
            GLES20.GL_UNSIGNED_BYTE,
            null,
        )
        val fbo = IntArray(1)
        GLES20.glGenFramebuffers(1, fbo, 0)
        captureFboId = fbo[0]
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, captureFboId)
        GLES20.glFramebufferTexture2D(
            GLES20.GL_FRAMEBUFFER,
            GLES20.GL_COLOR_ATTACHMENT0,
            GLES20.GL_TEXTURE_2D,
            captureFboTexId,
            0,
        )
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
        captureFboW = w
        captureFboH = h
    }

    private fun releaseCaptureFbo() {
        if (captureFboId != 0) {
            GLES20.glDeleteFramebuffers(1, intArrayOf(captureFboId), 0)
            captureFboId = 0
        }
        if (captureFboTexId != 0) {
            GLES20.glDeleteTextures(1, intArrayOf(captureFboTexId), 0)
            captureFboTexId = 0
        }
        captureFboW = 0
        captureFboH = 0
    }

    private fun captureFrontBuffer(redraw: (() -> Unit)? = null) {
        val now = android.os.SystemClock.elapsedRealtime()
        val force = forceCaptureNextFrame
        if (!force && now - lastCaptureMs < captureMinIntervalMs) return
        forceCaptureNextFrame = false
        lastCaptureMs = now

        GLES20.glGetIntegerv(GLES20.GL_VIEWPORT, captureViewport, 0)
        val screenX = captureViewport[0]
        val screenY = captureViewport[1]
        val screenW = captureViewport[2]
        val screenH = captureViewport[3]
        if (screenW <= 1 || screenH <= 1) return

        val maxEdge = captureMaxEdge.coerceAtLeast(2)
        val largest = maxOf(screenW, screenH)
        val useFbo = redraw != null && largest > maxEdge
        val readW: Int
        val readH: Int
        if (useFbo) {
            val s = maxEdge.toFloat() / largest
            readW = ((screenW * s).toInt() and 1.inv()).coerceAtLeast(2)
            readH = ((screenH * s).toInt() and 1.inv()).coerceAtLeast(2)
            ensureCaptureFbo(readW, readH)
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, captureFboId)
            GLES20.glViewport(0, 0, readW, readH)
            GLES20.glClearColor(0f, 0f, 0f, 1f)
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
            try {
                redraw!!()
            } catch (_: Throwable) {
                GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
                GLES20.glViewport(screenX, screenY, screenW, screenH)
                return
            }
        } else {
            readW = screenW
            readH = screenH
        }

        val rowBytes = readW * 4
        val bytes = rowBytes * readH
        ensureCaptureBuffers(bytes, rowBytes)
        val buf = captureReadBuf!!
        val flipped = captureFlipBuf!!
        val rowBuf = captureRowBuf!!
        buf.clear()
        flipped.clear()

        GLES20.glReadPixels(0, 0, readW, readH, GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, buf)

        if (useFbo) {
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
            GLES20.glViewport(screenX, screenY, screenW, screenH)
        }

        for (row in 0 until readH) {
            buf.position((readH - 1 - row) * rowBytes)
            buf.get(rowBuf, 0, rowBytes)
            flipped.put(rowBuf)
        }
        flipped.rewind()

        var scratch = captureScratchBitmap
        if (scratch == null || scratch.isRecycled ||
            scratch.width != readW || scratch.height != readH
        ) {
            scratch?.recycle()
            scratch = Bitmap.createBitmap(readW, readH, Bitmap.Config.ARGB_8888)
            captureScratchBitmap = scratch
        }
        scratch.copyPixelsFromBuffer(flipped)

        val out: Bitmap = if (!useFbo && largest > maxEdge) {
            val s = maxEdge.toFloat() / largest
            val sw = ((readW * s).toInt() and 1.inv()).coerceAtLeast(2)
            val sh = ((readH * s).toInt() and 1.inv()).coerceAtLeast(2)
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
        destroyEncoderEglSurface()
        encoderAndroidSurface = null
        encoderWidth = 0
        encoderHeight = 0
        synchronized(captureLock) {
            lastCapturedFrame?.recycle()
            lastCapturedFrame = null
        }
        pendingBitmap?.recycle()
        pendingBitmap = null
        oesEnabled = false
        texMatrixReady = false
        captureScratchBitmap?.recycle()
        captureScratchBitmap = null
        captureReadBuf = null
        captureFlipBuf = null
        captureRowBuf = null
        captureBufBytes = 0
        releaseCaptureFbo()
        try {
            cameraSurfaceTexture?.release()
        } catch (_: Throwable) {
        }
        cameraSurfaceTexture = null
        if (textureId != 0) {
            GLES20.glDeleteTextures(1, intArrayOf(textureId), 0)
            textureId = 0
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

    private fun bindRetouchUniforms(
        locSaturation: Int,
        locBrightness: Int,
        locContrast: Int,
        locExposure: Int,
        locWhiteBalance: Int,
        locHighlights: Int,
        locShadows: Int,
        locNose: Int,
        locWingL: Int,
        locWingR: Int,
        locRadius: Int,
    ) {
        val adj = LiveRetouchState.adjustments
        if (locSaturation >= 0) GLES20.glUniform1f(locSaturation, adj.saturation)
        if (locBrightness >= 0) GLES20.glUniform1f(locBrightness, adj.brightness)
        if (locContrast >= 0) GLES20.glUniform1f(locContrast, adj.contrast)
        if (locExposure >= 0) GLES20.glUniform1f(locExposure, adj.exposure)
        if (locWhiteBalance >= 0) GLES20.glUniform1f(locWhiteBalance, adj.whiteBalance)
        if (locHighlights >= 0) GLES20.glUniform1f(locHighlights, adj.highlights)
        if (locShadows >= 0) GLES20.glUniform1f(locShadows, adj.shadows)
        if (locNose >= 0) GLES20.glUniform1f(locNose, adj.nose)
        if (locWingL >= 0) {
            GLES20.glUniform2fv(locWingL, 1, LiveRetouchState.noseWingL, 0)
        }
        if (locWingR >= 0) {
            GLES20.glUniform2fv(locWingR, 1, LiveRetouchState.noseWingR, 0)
        }
        if (locRadius >= 0) GLES20.glUniform1f(locRadius, LiveRetouchState.noseRadius)
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

        private const val RETOUCH_UNIFORMS = """
            uniform float uRetouchSaturation;
            uniform float uRetouchBrightness;
            uniform float uRetouchContrast;
            uniform float uRetouchExposure;
            uniform float uRetouchWhiteBalance;
            uniform float uRetouchHighlights;
            uniform float uRetouchShadows;
            uniform float uRetouchNose;
            uniform vec2 uNoseWingL;
            uniform vec2 uNoseWingR;
            uniform float uNoseRadius;
        """

        private const val RETOUCH_FUNCTIONS = """
            float retouchLuma(vec3 c) {
                return dot(c, vec3(0.2126, 0.7152, 0.0722));
            }

            vec3 applyRetouchColor(vec3 col) {
                float ev = uRetouchExposure;
                if (abs(ev) > 0.01) {
                    col *= pow(2.0, ev);
                }
                float wb = uRetouchWhiteBalance;
                if (abs(wb) > 0.01) {
                    float k = wb * 0.3;
                    col.r *= (1.0 + k);
                    col.b *= (1.0 - k);
                }
                float c = uRetouchContrast;
                if (abs(c) > 0.01) {
                    float alpha = 1.0 + c * 0.5;
                    col = (col - 0.5) * alpha + 0.5;
                }
                float b = uRetouchBrightness;
                if (abs(b) > 0.01) {
                    col += b * (60.0 / 255.0);
                }
                float hl = uRetouchHighlights;
                float sh = uRetouchShadows;
                if (abs(hl) > 0.01 || abs(sh) > 0.01) {
                    float l = retouchLuma(col);
                    float hlW = l * l;
                    float shW = (1.0 - l) * (1.0 - l);
                    col += hl * (70.0 / 255.0) * hlW + sh * (70.0 / 255.0) * shW;
                }
                float sat = uRetouchSaturation;
                if (abs(sat) > 0.01) {
                    float l = retouchLuma(col);
                    float factor = sat >= 0.0 ? (1.0 + sat * 0.85) : max(1.0 + sat, 0.0);
                    col = mix(vec3(l), col, factor);
                }
                return clamp(col, 0.0, 1.0);
            }

            vec2 retouchWingDisp(vec2 uv, vec2 wing, float shiftX, float radius) {
                if (radius <= 0.001) return uv;
                vec2 d = uv - wing;
                float rmax2 = radius * radius;
                float dist2 = dot(d, d);
                if (dist2 >= rmax2) return uv;
                float d2 = shiftX * shiftX;
                float f = (rmax2 - dist2) / (rmax2 - dist2 + d2);
                f = f * f;
                return uv - vec2(f * shiftX, 0.0);
            }

            vec2 applyRetouchNoseWarp(vec2 uv) {
                if (abs(uRetouchNose) < 0.01 || uNoseRadius <= 0.001) return uv;
                float k = 0.28 * (-uRetouchNose);
                float tipX = (uNoseWingL.x + uNoseWingR.x) * 0.5;
                float shiftL = (tipX - uNoseWingL.x) * k;
                float shiftR = (tipX - uNoseWingR.x) * k;
                uv = retouchWingDisp(uv, uNoseWingL, shiftL, uNoseRadius);
                uv = retouchWingDisp(uv, uNoseWingR, shiftR, uNoseRadius);
                return uv;
            }
        """

        private const val OES_FRAGMENT_SHADER = """
            #extension GL_OES_EGL_image_external : require
            precision highp float;
            varying vec2 vTexCoord;
            uniform samplerExternalOES uTexture;
            uniform mat4 uStMatrix;
            uniform mat3 uTexTransform;
            uniform vec2 uViewSize;
            uniform vec2 uTexSize;
            $RETOUCH_UNIFORMS
            $RETOUCH_FUNCTIONS

            // Same as PreviewView FILL_CENTER: fill the view, crop overflow, keep aspect.
            vec2 fillCenter(vec2 uv) {
                float viewAspect = uViewSize.x / max(uViewSize.y, 1.0);
                float texAspect = uTexSize.x / max(uTexSize.y, 1.0);
                if (texAspect > viewAspect) {
                    float s = viewAspect / texAspect;
                    return vec2(uv.x * s + (1.0 - s) * 0.5, uv.y);
                } else {
                    float s = texAspect / viewAspect;
                    return vec2(uv.x, uv.y * s + (1.0 - s) * 0.5);
                }
            }

            void main() {
                vec2 d = fillCenter(vTexCoord);
                vec2 uv = (uTexTransform * vec3(d, 1.0)).xy;
                vec2 st = (uStMatrix * vec4(uv, 0.0, 1.0)).xy;
                st = applyRetouchNoseWarp(st);
                vec3 col = texture2D(uTexture, st).rgb;
                col = applyRetouchColor(col);
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
            $RETOUCH_UNIFORMS
            $RETOUCH_FUNCTIONS

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

                tc = applyRetouchNoseWarp(tc);

                vec4 sourceColor;
                if (uFilterType == 0) {
                    sourceColor = texture2D(uTexture, tc);
                } else {
                    sourceColor = sharpenSample(tc, uTexSize);
                }

                vec3 col = sourceColor.rgb;
                col = applyRetouchColor(col);

                gl_FragColor = vec4(col, sourceColor.a);
            }
        """
    }
}
