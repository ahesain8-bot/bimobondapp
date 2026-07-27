package com.dubai.bimobondapp.ar_camera

import android.graphics.Bitmap
import android.graphics.SurfaceTexture
import android.opengl.EGL14
import android.opengl.EGLExt
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.util.Log
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
    private var oesUSmoothStrength = 0
    private var oesUTexelStep = 0
    private var oesUHistory = 0
    private var oesUHistoryValid = 0
    private var oesUTemporalStrength = 0
    private var oesUWideZoom = 0
    private var oesUSkinMask = 0
    private var oesUSkinMaskValid = 0
    private var oesUIsFrontCamera = 0

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
        if (program == 0) reportGlUnusable("bitmap program")
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
        if (oesProgram == 0) reportGlUnusable("OES program")
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
        oesUSmoothStrength = GLES20.glGetUniformLocation(oesProgram, "uSmoothStrength")
        oesUTexelStep = GLES20.glGetUniformLocation(oesProgram, "uTexelStep")
        oesUHistory = GLES20.glGetUniformLocation(oesProgram, "uHistory")
        oesUHistoryValid = GLES20.glGetUniformLocation(oesProgram, "uHistoryValid")
        oesUTemporalStrength = GLES20.glGetUniformLocation(oesProgram, "uTemporalStrength")
        oesUWideZoom = GLES20.glGetUniformLocation(oesProgram, "uWideZoom")
        oesUSkinMask = GLES20.glGetUniformLocation(oesProgram, "uSkinMask")
        oesUSkinMaskValid = GLES20.glGetUniformLocation(oesProgram, "uSkinMaskValid")
        oesUIsFrontCamera = GLES20.glGetUniformLocation(oesProgram, "uIsFrontCamera")

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
            } catch (t: Throwable) {
                // Silently returning here meant a camera texture the driver
                // refuses to update looked exactly like "nothing to draw" — a
                // black preview with no trace anywhere. Count the failures: one
                // is a transient hiccup, a run of them means this device can't
                // drive the OES path at all.
                oesUpdateFailures++
                Log.e(TAG, "SurfaceTexture.updateTexImage failed (#$oesUpdateFailures)", t)
                if (oesUpdateFailures >= MAX_OES_UPDATE_FAILURES) {
                    reportGlUnusable("camera texture updates keep failing")
                }
                return
            }
            oesUpdateFailures = 0
            uploadPendingSkinMask()
            drawOes()

            presentToEncoder { drawOes() }
            if (captureEnabled) captureFrontBuffer { drawOes() }
            writeHistoryFrame()
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
        // Texel step in the OES buffer's own UV space (pre display-rotation-swap —
        // st sampling happens in raw camera-buffer space via uStMatrix), used by
        // the skin-smoothing ring taps in the shader.
        GLES20.glUniform2f(
            oesUTexelStep,
            1f / cameraBufW.coerceAtLeast(1),
            1f / cameraBufH.coerceAtLeast(1),
        )
        val beauty = LiveBeautyState.adjustments
        GLES20.glUniform1f(oesUSmoothStrength, beauty.smooth)
        GLES20.glUniform1f(
            oesUWideZoom,
            if (ArCameraBridge.isFrontCamera) FRONT_WIDE_ZOOM_OUT else 1f,
        )

        GLES20.glActiveTexture(GLES20.GL_TEXTURE1)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, historyTexId[historyReadIndex])
        GLES20.glUniform1i(oesUHistory, 1)
        GLES20.glUniform1f(oesUHistoryValid, if (historyValid) 1f else 0f)
        GLES20.glUniform1f(oesUTemporalStrength, TEMPORAL_STRENGTH)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE2)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, skinMaskTexId)
        GLES20.glUniform1i(oesUSkinMask, 2)
        GLES20.glUniform1f(oesUSkinMaskValid, if (skinMaskValid) 1f else 0f)
        GLES20.glUniform1f(oesUIsFrontCamera, if (ArCameraBridge.isFrontCamera) 1f else 0f)
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
        probeGlError("OES draw")
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

    /**
     * Tells the rest of the camera that GL cannot render on this device, so it
     * switches to the plain preview pipeline instead of showing a black screen.
     * Routed through the watchdog so there is a single place that decides to
     * degrade, and a single place it can be observed from.
     */
    /** Consecutive [android.graphics.SurfaceTexture.updateTexImage] failures. */
    private var oesUpdateFailures = 0

    private var glErrorProbeCounter = 0

    /**
     * Periodic GL error check. GL fails silently by design — an invalid draw
     * leaves an error flag and produces nothing, which is indistinguishable from
     * a black frame unless someone asks. Probing occasionally (not every frame,
     * glGetError forces a pipeline sync) means a broken draw shows up in logcat
     * instead of only as a black screen on a device we don't have.
     */
    private fun probeGlError(where: String) {
        glErrorProbeCounter++
        if (glErrorProbeCounter % GL_ERROR_PROBE_EVERY != 0) return
        val error = GLES20.glGetError()
        if (error != GLES20.GL_NO_ERROR) {
            Log.e(TAG, "GL error 0x${Integer.toHexString(error)} after $where")
        }
    }

    private fun reportGlUnusable(what: String) {
        Log.e(TAG, "GL unusable on this device ($what) — requesting simple mode")
        ArCameraWatchdog.reportGlFailure()
    }

    /**
     * The EGLConfig the given context was created with, found by matching
     * EGL_CONFIG_ID against the display's configs.
     */
    private fun contextConfig(
        display: android.opengl.EGLDisplay,
        context: android.opengl.EGLContext,
    ): AndroidEglConfig? {
        return try {
            val id = IntArray(1)
            if (!EGL14.eglQueryContext(display, context, EGL14.EGL_CONFIG_ID, id, 0)) {
                return null
            }
            val total = IntArray(1)
            if (!EGL14.eglGetConfigs(display, null, 0, 0, total, 0) || total[0] <= 0) {
                return null
            }
            val configs = arrayOfNulls<AndroidEglConfig>(total[0])
            if (!EGL14.eglGetConfigs(display, configs, 0, total[0], total, 0)) {
                return null
            }
            val value = IntArray(1)
            configs.firstOrNull { cfg ->
                cfg != null &&
                    EGL14.eglGetConfigAttrib(display, cfg, EGL14.EGL_CONFIG_ID, value, 0) &&
                    value[0] == id[0]
            }
        } catch (t: Throwable) {
            Log.w(TAG, "context config lookup failed", t)
            null
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
            // Use the CONTEXT'S OWN config, not a freshly chosen one. Choosing
            // independently produced a config that differed from the one the
            // GLSurfaceView built its context with, and eglMakeCurrent below then
            // failed with EGL_BAD_MATCH on every frame on stricter GPUs — the GL
            // thread stalled and the camera froze / went black. Reusing the
            // context's config makes a match structural rather than a coincidence.
            val config = contextConfig(eglDisplay, eglContext)
                ?: chooseRecordableConfig(eglDisplay)
                ?: return
            val surfaceAttribs = intArrayOf(EGL14.EGL_NONE)
            eglSurf = try {
                EGL14.eglCreateWindowSurface(
                    eglDisplay,
                    config,
                    androidSurface,
                    surfaceAttribs,
                    0,
                )
            } catch (t: Throwable) {
                Log.w(TAG, "encoder EGL surface creation failed", t)
                null
            }
            if (eglSurf == null || eglSurf == EGL14.EGL_NO_SURFACE) return
            encoderEglSurface = eglSurf
        }

        if (!EGL14.eglMakeCurrent(eglDisplay, eglSurf, eglSurf, eglContext)) {
            // Don't retry a surface the driver refuses — a per-frame failure loop
            // is what made this so expensive. Drop it and give up on encoding via
            // GL; the caller's non-GL paths still work.
            Log.e(
                TAG,
                "eglMakeCurrent failed (0x${Integer.toHexString(EGL14.eglGetError())}) " +
                    "— disabling GL encoder surface",
            )
            destroyEncoderEglSurface()
            encoderAndroidSurface = null
            return
        }
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
        } catch (t: Throwable) {
            Log.e(TAG, "encoder frame present failed", t)
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

    // Stage 3 — temporal denoise: ping-pong history of the last blended frame,
    // sampled + re-blended each frame in drawOes() (screen-space UV, since both
    // slots are always sized to match the current viewport).
    private val historyTexId = IntArray(2)
    private val historyFboId = IntArray(2)
    private var historyW = 0
    private var historyH = 0
    private var historyReadIndex = 0
    private var historyValid = false
    private val historyRestoreViewport = IntArray(4)

    // Skin mask (landmark-rasterized, see ArCameraController.buildFaceSkinMaskBitmap)
    // — ALPHA_8 bitmap, alpha=skin confidence directly, uploaded from a background
    // analysis frame, sampled in the shader to gate skin-smoothing precisely
    // instead of the color-tone guess. Uploaded occasionally (analysis is
    // throttled), not every frame like the OES texture.
    private var skinMaskTexId = 0
    @Volatile
    private var pendingSkinMaskBitmap: Bitmap? = null
    private var skinMaskValid = false

    fun updateSkinMask(bitmap: Bitmap) {
        val old = pendingSkinMaskBitmap
        pendingSkinMaskBitmap = bitmap
        if (old != null && old !== bitmap && !old.isRecycled) old.recycle()
    }

    private fun uploadPendingSkinMask() {
        val bmp = pendingSkinMaskBitmap ?: return
        pendingSkinMaskBitmap = null
        if (bmp.isRecycled) return
        try {
            if (skinMaskTexId == 0) {
                val tex = IntArray(1)
                GLES20.glGenTextures(1, tex, 0)
                skinMaskTexId = tex[0]
                GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, skinMaskTexId)
                GLES20.glTexParameteri(
                    GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR,
                )
                GLES20.glTexParameteri(
                    GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR,
                )
                GLES20.glTexParameteri(
                    GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE,
                )
                GLES20.glTexParameteri(
                    GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE,
                )
            } else {
                GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, skinMaskTexId)
            }
            GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bmp, 0)
            skinMaskValid = true
        } catch (t: Throwable) {
            android.util.Log.w(TAG, "skin mask upload failed", t)
        } finally {
            bmp.recycle()
        }
    }

    /**
     * Builds the offscreen framebuffer used to read captured frames back.
     * Returns false when the driver won't give us a usable one.
     *
     * That check is the point. This used to bind whatever came out of
     * glGenFramebuffers and draw into it regardless, so an incomplete FBO
     * produced a stream of GL_INVALID_FRAMEBUFFER_OPERATION and captured
     * nothing — no photo, no recorded frame, and no error the app could act on.
     */
    private fun ensureCaptureFbo(w: Int, h: Int): Boolean {
        if (captureFboId != 0 && captureFboW == w && captureFboH == h) return true
        releaseCaptureFbo()

        // A texture larger than the driver allows is one way to end up with an
        // incomplete framebuffer, and the limit varies widely between GPUs.
        val maxTex = IntArray(1)
        GLES20.glGetIntegerv(GLES20.GL_MAX_TEXTURE_SIZE, maxTex, 0)
        val limit = maxTex[0].takeIf { it > 0 } ?: 2048
        if (w > limit || h > limit) {
            Log.e(TAG, "capture size ${w}x$h exceeds GL_MAX_TEXTURE_SIZE ($limit)")
            return false
        }

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
        val status = GLES20.glCheckFramebufferStatus(GLES20.GL_FRAMEBUFFER)
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
        if (status != GLES20.GL_FRAMEBUFFER_COMPLETE) {
            Log.e(
                TAG,
                "capture framebuffer incomplete (0x${Integer.toHexString(status)}) " +
                    "at ${w}x$h",
            )
            releaseCaptureFbo()
            return false
        }

        captureFboW = w
        captureFboH = h
        return true
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

    private fun ensureHistoryBuffers(w: Int, h: Int) {
        if (historyTexId[0] != 0 && historyW == w && historyH == h) return
        releaseHistoryBuffers()
        val tex = IntArray(2)
        GLES20.glGenTextures(2, tex, 0)
        val fbo = IntArray(2)
        GLES20.glGenFramebuffers(2, fbo, 0)
        for (i in 0..1) {
            historyTexId[i] = tex[i]
            historyFboId[i] = fbo[i]
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, tex[i])
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
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fbo[i])
            GLES20.glFramebufferTexture2D(
                GLES20.GL_FRAMEBUFFER,
                GLES20.GL_COLOR_ATTACHMENT0,
                GLES20.GL_TEXTURE_2D,
                tex[i],
                0,
            )
        }
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
        historyW = w
        historyH = h
        historyReadIndex = 0
        historyValid = false
    }

    private fun releaseHistoryBuffers() {
        if (historyFboId[0] != 0 || historyFboId[1] != 0) {
            GLES20.glDeleteFramebuffers(2, historyFboId, 0)
            historyFboId[0] = 0
            historyFboId[1] = 0
        }
        if (historyTexId[0] != 0 || historyTexId[1] != 0) {
            GLES20.glDeleteTextures(2, historyTexId, 0)
            historyTexId[0] = 0
            historyTexId[1] = 0
        }
        historyW = 0
        historyH = 0
        historyValid = false
    }

    /**
     * Re-renders the just-drawn frame (same shader pass, same history read slot)
     * into the "write" history slot, then flips it to become next frame's "read"
     * slot. This is a recursive/exponential blend by construction — each stored
     * history frame already contains the accumulated result of prior frames, not
     * just one raw frame, so a modest per-frame temporal strength still compounds
     * into meaningful noise averaging over a few frames of a static scene.
     */
    private fun writeHistoryFrame() {
        GLES20.glGetIntegerv(GLES20.GL_VIEWPORT, historyRestoreViewport, 0)
        val w = historyRestoreViewport[2]
        val h = historyRestoreViewport[3]
        if (w <= 1 || h <= 1) return
        ensureHistoryBuffers(w, h)
        val writeIndex = 1 - historyReadIndex
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, historyFboId[writeIndex])
        GLES20.glViewport(0, 0, historyW, historyH)
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        try {
            drawOes()
        } finally {
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
            GLES20.glViewport(
                historyRestoreViewport[0],
                historyRestoreViewport[1],
                historyRestoreViewport[2],
                historyRestoreViewport[3],
            )
        }
        historyReadIndex = writeIndex
        historyValid = true
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
            if (!ensureCaptureFbo(readW, readH)) {
                // No usable framebuffer here — skip the readback rather than draw
                // into an incomplete one and "capture" nothing. Callers already
                // fall back (photos go to hardware ImageCapture).
                return
            }
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, captureFboId)
            GLES20.glViewport(0, 0, readW, readH)
            GLES20.glClearColor(0f, 0f, 0f, 1f)
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
            try {
                redraw!!()
            } catch (t: Throwable) {
                Log.e(TAG, "capture redraw failed", t)
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
        releaseHistoryBuffers()
        pendingSkinMaskBitmap?.recycle()
        pendingSkinMaskBitmap = null
        skinMaskValid = false
        if (skinMaskTexId != 0) {
            GLES20.glDeleteTextures(1, intArrayOf(skinMaskTexId), 0)
            skinMaskTexId = 0
        }
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

    /**
     * Returns 0 when the program could not be built.
     *
     * This used to log the failure and hand back the broken program id anyway.
     * That is a quiet way to produce a black screen on exactly the devices we
     * can't test: GLSL compilers differ per GPU vendor, and a shader this size
     * (the OES one carries the skin mask, surface blur, temporal denoise and the
     * whole retouch block) is a realistic candidate for compiling on one vendor
     * and failing on another. With a broken id the renderer carried on drawing
     * nothing, with no error anywhere but logcat. Now the caller can see it and
     * fall back.
     */
    private fun buildProgram(vertexSource: String, fragmentSource: String): Int {
        val vertexShader = compileShader(GLES20.GL_VERTEX_SHADER, vertexSource)
        val fragmentShader = compileShader(GLES20.GL_FRAGMENT_SHADER, fragmentSource)
        if (vertexShader == 0 || fragmentShader == 0) {
            if (vertexShader != 0) GLES20.glDeleteShader(vertexShader)
            if (fragmentShader != 0) GLES20.glDeleteShader(fragmentShader)
            return 0
        }

        val program = GLES20.glCreateProgram()
        if (program == 0) {
            Log.e(TAG, "glCreateProgram failed")
            GLES20.glDeleteShader(vertexShader)
            GLES20.glDeleteShader(fragmentShader)
            return 0
        }
        GLES20.glAttachShader(program, vertexShader)
        GLES20.glAttachShader(program, fragmentShader)
        GLES20.glLinkProgram(program)

        val linkStatus = IntArray(1)
        GLES20.glGetProgramiv(program, GLES20.GL_LINK_STATUS, linkStatus, 0)
        GLES20.glDeleteShader(vertexShader)
        GLES20.glDeleteShader(fragmentShader)

        if (linkStatus[0] != GLES20.GL_TRUE) {
            Log.e(TAG, "program link failed: ${GLES20.glGetProgramInfoLog(program)}")
            GLES20.glDeleteProgram(program)
            return 0
        }
        return program
    }

    /** Returns 0 when the shader could not be compiled — see [buildProgram]. */
    private fun compileShader(type: Int, source: String): Int {
        val shader = GLES20.glCreateShader(type)
        if (shader == 0) {
            Log.e(TAG, "glCreateShader failed for type $type")
            return 0
        }
        GLES20.glShaderSource(shader, source)
        GLES20.glCompileShader(shader)

        val status = IntArray(1)
        GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, status, 0)
        if (status[0] != GLES20.GL_TRUE) {
            Log.e(
                TAG,
                "shader compile failed (type=$type): ${GLES20.glGetShaderInfoLog(shader)}",
            )
            GLES20.glDeleteShader(shader)
            return 0
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

        /** Consecutive camera-texture update failures before giving up on GL. */
        private const val MAX_OES_UPDATE_FAILURES = 30

        /** glGetError forces a sync, so only probe every Nth frame. */
        private const val GL_ERROR_PROBE_EVERY = 60

        // Skin-smooth strength and lip-tint color/strength are no longer fixed
        // constants — they come from LiveBeautyState, driven by the named
        // filter picker (Soft Glow, Pure, Rosy, Clean, ...) in Dart, defaulting
        // to the same baseline these constants used to hardcode.

        /**
         * Live-preview temporal denoise ceiling (0..1), OES path only — Stage 3.
         * Gated per-pixel in-shader by frame-to-frame color similarity (see
         * [OES_FRAGMENT_SHADER]'s temporal blend in main()), so static areas (most
         * of a static face) blend toward the accumulated history and average out
         * grain, while motion keeps this near zero to avoid ghosting/trails.
         */
        private const val TEMPORAL_STRENGTH = 0.5f

        /**
         * Front camera only — widens the live-preview crop by sampling this much
         * more of the buffer around center (>1.0 = zoom out). The prior fix
         * (Camera2 zoomRatio below 1.0) was a no-op on devices whose front lens
         * can't optically zoom under 1x — this is a software crop change instead:
         * fillCenter() previously cropped the 4:3 buffer tightly to fill a much
         * taller screen; sampling a wider window around center before that fill
         * shows more of the sides without needing hardware support. Kept modest to
         * avoid visible edge softness/distortion from the OES buffer's clamped edges.
         */
        private const val FRONT_WIDE_ZOOM_OUT = 1.15f

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
            uniform vec2 uTexelStep;
            uniform float uSmoothStrength;
            uniform sampler2D uHistory;
            uniform float uHistoryValid;
            uniform float uTemporalStrength;
            uniform float uWideZoom;
            uniform sampler2D uSkinMask;
            uniform float uSkinMaskValid;
            uniform float uIsFrontCamera;
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

            // Soft skin-tone confidence (YCbCr band), no face landmarks needed —
            // excludes near-black (hair/lashes/shadow) and desaturated/non-skin hues,
            // so eyes/eyebrows/hairline naturally resist smoothing even without a
            // face mask.
            float skinConfidence(vec3 c) {
                float y  = dot(c, vec3(0.299, 0.587, 0.114));
                float cb = dot(c, vec3(-0.169, -0.331, 0.500)) + 0.5;
                float cr = dot(c, vec3(0.500, -0.419, -0.081)) + 0.5;
                float cbW = smoothstep(0.28, 0.36, cb) * (1.0 - smoothstep(0.46, 0.54, cb));
                float crW = smoothstep(0.46, 0.54, cr) * (1.0 - smoothstep(0.66, 0.74, cr));
                float yW  = smoothstep(0.05, 0.15, y);
                return cbW * crW * yW;
            }

            // Landmark-rasterized skin mask (see ArCameraController.buildFaceSkinMaskBitmap)
            // — replaces the color guess above when available. Mask was built from
            // a non-mirrored oriented analysis frame and sampled here in st-space,
            // so front camera needs the same x-flip already proven for the
            // nose-warp landmarks (FaceCoordinateMapper.toWarpUv). Alpha channel
            // already IS the skin confidence (0..1), no further processing needed.
            float maskConfidence(vec2 st) {
                vec2 maskUv = st;
                if (uIsFrontCamera > 0.5) {
                    maskUv.x = 1.0 - maskUv.x;
                }
                return texture2D(uSkinMask, maskUv).a;
            }

            // Edge-aware 8-tap ring blur (bilateral-style): neighbors are weighted by
            // color similarity to the center pixel, so real edges (eyes, brows, lips,
            // hairline) keep their weight near zero and stay sharp; only flat, noisy
            // regions (skin, sensor grain) blend in.
            vec3 surfaceBlur(vec2 uv, vec3 center) {
                vec2 t = uTexelStep * 2.5;
                vec3 sum = center;
                float wSum = 1.0;

                vec3 s0 = texture2D(uTexture, uv + vec2( t.x,  0.0)).rgb;
                float w0 = exp(-distance(s0, center) * distance(s0, center) * 50.0);
                sum += s0 * w0; wSum += w0;

                vec3 s1 = texture2D(uTexture, uv + vec2(-t.x,  0.0)).rgb;
                float w1 = exp(-distance(s1, center) * distance(s1, center) * 50.0);
                sum += s1 * w1; wSum += w1;

                vec3 s2 = texture2D(uTexture, uv + vec2( 0.0,  t.y)).rgb;
                float w2 = exp(-distance(s2, center) * distance(s2, center) * 50.0);
                sum += s2 * w2; wSum += w2;

                vec3 s3 = texture2D(uTexture, uv + vec2( 0.0, -t.y)).rgb;
                float w3 = exp(-distance(s3, center) * distance(s3, center) * 50.0);
                sum += s3 * w3; wSum += w3;

                vec3 s4 = texture2D(uTexture, uv + vec2( t.x,  t.y)).rgb;
                float w4 = exp(-distance(s4, center) * distance(s4, center) * 50.0);
                sum += s4 * w4; wSum += w4;

                vec3 s5 = texture2D(uTexture, uv + vec2(-t.x,  t.y)).rgb;
                float w5 = exp(-distance(s5, center) * distance(s5, center) * 50.0);
                sum += s5 * w5; wSum += w5;

                vec3 s6 = texture2D(uTexture, uv + vec2( t.x, -t.y)).rgb;
                float w6 = exp(-distance(s6, center) * distance(s6, center) * 50.0);
                sum += s6 * w6; wSum += w6;

                vec3 s7 = texture2D(uTexture, uv + vec2(-t.x, -t.y)).rgb;
                float w7 = exp(-distance(s7, center) * distance(s7, center) * 50.0);
                sum += s7 * w7; wSum += w7;

                return sum / wSum;
            }

            void main() {
                vec2 d = fillCenter(vTexCoord);
                // Front camera: sample a wider window around center (>1.0 = zoom
                // out) before the texture-space transform, so selfie mode shows
                // more of the sides instead of the tight fill-center crop.
                vec2 dZoomed = (d - 0.5) / uWideZoom + 0.5;
                vec2 uv = (uTexTransform * vec3(dZoomed, 1.0)).xy;
                vec2 st = (uStMatrix * vec4(uv, 0.0, 1.0)).xy;
                st = applyRetouchNoseWarp(st);
                vec3 col = texture2D(uTexture, st).rgb;

                // Skin mask needs its own unzoomed mapping — the mask texture was
                // built from raw (pre-wideZoom) landmark/analysis-frame geometry,
                // so sampling it with the zoomed `st` above would misalign it.
                vec2 uvLandmark = (uTexTransform * vec3(d, 1.0)).xy;
                vec2 stLandmark = (uStMatrix * vec4(uvLandmark, 0.0, 1.0)).xy;
                if (uSmoothStrength > 0.001) {
                    float skinConf = uSkinMaskValid > 0.5 ? maskConfidence(stLandmark) : skinConfidence(col);
                    if (skinConf > 0.001) {
                        vec3 blurred = surfaceBlur(st, col);
                        col = mix(col, blurred, uSmoothStrength * skinConf);
                    }
                }
                // Temporal denoise: blend toward the accumulated history frame when
                // this pixel hasn't moved/changed much since — averages out sensor
                // grain over a few frames of a static scene. History is written in
                // the same screen-space UV (vTexCoord) it's read with here, since
                // both slots are always sized to the current viewport.
                if (uHistoryValid > 0.5 && uTemporalStrength > 0.001) {
                    vec3 hist = texture2D(uHistory, vTexCoord).rgb;
                    float diff = distance(col, hist);
                    float staticWeight = 1.0 - smoothstep(0.03, 0.12, diff);
                    col = mix(col, hist, uTemporalStrength * staticWeight);
                }
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
