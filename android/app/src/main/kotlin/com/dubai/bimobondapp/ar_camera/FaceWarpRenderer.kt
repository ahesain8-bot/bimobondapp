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
    private var uRetouchShape = 0
    private var uJawWingL = 0
    private var uJawWingR = 0
    private var uJawRadius = 0
    private var uRetouchEyes = 0
    private var uEyeL = 0
    private var uEyeR = 0
    private var uEyeRadius = 0
    private var uRetouchMouth = 0
    private var uMouthCenter = 0
    private var uMouthRadius = 0
    private var uRetouchTooth = 0
    private var uToothRegion = 0

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
    private var oesURetouchShape = 0
    private var oesUJawWingL = 0
    private var oesUJawWingR = 0
    private var oesUJawRadius = 0
    private var oesURetouchEyes = 0
    private var oesUEyeL = 0
    private var oesUEyeR = 0
    private var oesUEyeRadius = 0
    private var oesURetouchMouth = 0
    private var oesUMouthCenter = 0
    private var oesUMouthRadius = 0
    private var oesURetouchTooth = 0
    private var oesUToothRegion = 0
    /**
     * Beauty strengths as currently applied, eased toward whatever
     * [LiveBeautyState] holds instead of jumping to it.
     *
     * Switching preset or dragging a slider otherwise changes the look between
     * one frame and the next, which reads as a flicker. It also matters for the
     * later stages of this work, where these values stop being constants and
     * start tracking the scene — a value that reacts to lighting has to move
     * smoothly or the whole image pulses as the light shifts.
     */
    private var smoothedSharpen = SHARPEN_STRENGTH
    private var smoothedAutoLift = 0f
    private var smoothedSmooth = LiveBeautyState.adjustments.smooth
    private var smoothedWhiten = LiveBeautyState.adjustments.whiten
    private var smoothedBrighten = LiveBeautyState.adjustments.brighten

    private var oesUSmoothStrength = 0
    private var oesUWhiten = 0
    private var oesUSkinLuma = 0
    private var oesUSharpen = 0
    private var oesUNoiseFloor = 0
    private var oesUBrighten = 0
    private var oesUBlemish = 0
    private var oesUTexelStep = 0
    private var oesUHistory = 0
    private var oesUHistoryValid = 0
    private var oesUTemporalStrength = 0
    private var oesUWideZoom = 0
    private var oesUSkinMask = 0
    private var oesUSkinMaskValid = 0
    private var oesUSkinFallback = 0
    private var oesUAutoLift = 0
    private var oesUIsFrontCamera = 0
    private var oesUMagicOn = 0
    private var oesUMagicStrength = 0

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
        uRetouchShape = GLES20.glGetUniformLocation(program, "uRetouchShape")
        uJawWingL = GLES20.glGetUniformLocation(program, "uJawWingL")
        uJawWingR = GLES20.glGetUniformLocation(program, "uJawWingR")
        uJawRadius = GLES20.glGetUniformLocation(program, "uJawRadius")
        uRetouchEyes = GLES20.glGetUniformLocation(program, "uRetouchEyes")
        uEyeL = GLES20.glGetUniformLocation(program, "uEyeL")
        uEyeR = GLES20.glGetUniformLocation(program, "uEyeR")
        uEyeRadius = GLES20.glGetUniformLocation(program, "uEyeRadius")
        uRetouchMouth = GLES20.glGetUniformLocation(program, "uRetouchMouth")
        uMouthCenter = GLES20.glGetUniformLocation(program, "uMouthCenter")
        uMouthRadius = GLES20.glGetUniformLocation(program, "uMouthRadius")
        uRetouchTooth = GLES20.glGetUniformLocation(program, "uRetouchTooth")
        uToothRegion = GLES20.glGetUniformLocation(program, "uToothRegion")

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
        oesURetouchShape = GLES20.glGetUniformLocation(oesProgram, "uRetouchShape")
        oesUJawWingL = GLES20.glGetUniformLocation(oesProgram, "uJawWingL")
        oesUJawWingR = GLES20.glGetUniformLocation(oesProgram, "uJawWingR")
        oesUJawRadius = GLES20.glGetUniformLocation(oesProgram, "uJawRadius")
        oesURetouchEyes = GLES20.glGetUniformLocation(oesProgram, "uRetouchEyes")
        oesUEyeL = GLES20.glGetUniformLocation(oesProgram, "uEyeL")
        oesUEyeR = GLES20.glGetUniformLocation(oesProgram, "uEyeR")
        oesUEyeRadius = GLES20.glGetUniformLocation(oesProgram, "uEyeRadius")
        oesURetouchMouth = GLES20.glGetUniformLocation(oesProgram, "uRetouchMouth")
        oesUMouthCenter = GLES20.glGetUniformLocation(oesProgram, "uMouthCenter")
        oesUMouthRadius = GLES20.glGetUniformLocation(oesProgram, "uMouthRadius")
        oesURetouchTooth = GLES20.glGetUniformLocation(oesProgram, "uRetouchTooth")
        oesUToothRegion = GLES20.glGetUniformLocation(oesProgram, "uToothRegion")
        oesUSmoothStrength = GLES20.glGetUniformLocation(oesProgram, "uSmoothStrength")
        oesUWhiten = GLES20.glGetUniformLocation(oesProgram, "uWhiten")
        oesUSkinLuma = GLES20.glGetUniformLocation(oesProgram, "uSkinLuma")
        oesUSharpen = GLES20.glGetUniformLocation(oesProgram, "uSharpen")
        oesUNoiseFloor = GLES20.glGetUniformLocation(oesProgram, "uNoiseFloor")
        oesUBrighten = GLES20.glGetUniformLocation(oesProgram, "uBrighten")
        oesUBlemish = GLES20.glGetUniformLocation(oesProgram, "uBlemish")
        oesUTexelStep = GLES20.glGetUniformLocation(oesProgram, "uTexelStep")
        oesUHistory = GLES20.glGetUniformLocation(oesProgram, "uHistory")
        oesUHistoryValid = GLES20.glGetUniformLocation(oesProgram, "uHistoryValid")
        oesUTemporalStrength = GLES20.glGetUniformLocation(oesProgram, "uTemporalStrength")
        oesUWideZoom = GLES20.glGetUniformLocation(oesProgram, "uWideZoom")
        oesUSkinMask = GLES20.glGetUniformLocation(oesProgram, "uSkinMask")
        oesUSkinMaskValid = GLES20.glGetUniformLocation(oesProgram, "uSkinMaskValid")
        oesUSkinFallback = GLES20.glGetUniformLocation(oesProgram, "uSkinFallback")
        oesUAutoLift = GLES20.glGetUniformLocation(oesProgram, "uAutoLift")
        oesUIsFrontCamera = GLES20.glGetUniformLocation(oesProgram, "uIsFrontCamera")
        oesUMagicOn = GLES20.glGetUniformLocation(oesProgram, "uMagicOn")
        oesUMagicStrength = GLES20.glGetUniformLocation(oesProgram, "uMagicStrength")

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
            // Copy the just-drawn screen into history — same pixels as a second
            // drawOes() into an FBO, without re-running the heavy beauty shader.
            writeHistoryFrame()

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
            uRetouchShape,
            uJawWingL,
            uJawWingR,
            uJawRadius,
            uRetouchEyes,
            uEyeL,
            uEyeR,
            uEyeRadius,
            uRetouchMouth,
            uMouthCenter,
            uMouthRadius,
            uRetouchTooth,
            uToothRegion,
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
        // Adapted to the light first, then eased toward rather than snapped to —
        // so the shader sees a value that moves smoothly even while the scene
        // brightness is changing underneath it. See [sceneAdaptedTargets] and
        // [easeToward]. Large intentional jumps (e.g. Magic Off→On) snap so the
        // toggle is visible immediately instead of easing over many frames.
        val lowLight = lowLightWeight()
        val magic = LiveBeautyState.magicOn
        val magicStrength = LiveBeautyState.magicStrength
        val targetSmooth = if (magic) {
            LiveBeautyAdjustments.smoothFromStrength(magicStrength)
        } else {
            adaptedSmooth(beauty, lowLight)
        }
        if (kotlin.math.abs(targetSmooth - smoothedSmooth) > 0.08f) {
            smoothedSmooth = targetSmooth
        } else {
            smoothedSmooth = easeToward(smoothedSmooth, targetSmooth)
        }
        val targetWhiten = adaptedWhiten(LiveBeautyState.effectiveWhiten(), lowLight)
        smoothedWhiten = easeToward(smoothedWhiten, targetWhiten)
        smoothedBrighten =
            easeToward(smoothedBrighten, adaptedBrighten(beauty, lowLight))
        val targetSharpen = if (magic) {
            LiveBeautyAdjustments.MAGIC_DEFAULT_SHARPEN * (1f - lowLight * 0.65f)
        } else {
            adaptedSharpen(lowLight)
        }
        smoothedSharpen = easeToward(smoothedSharpen, targetSharpen)
        smoothedAutoLift = easeToward(smoothedAutoLift, autoLiftTarget())
        GLES20.glUniform1f(oesUSmoothStrength, smoothedSmooth)
        GLES20.glUniform1f(oesUWhiten, smoothedWhiten)
        GLES20.glUniform1f(oesUSkinLuma, measuredSkinLuma)
        GLES20.glUniform1f(oesUSharpen, smoothedSharpen)
        // Slightly higher noise floor under Magic so speckles count as grain
        // (cut cleanly) instead of surviving as texture on plastic skin.
        GLES20.glUniform1f(
            oesUNoiseFloor,
            noiseFloorFor(lowLight) * if (magic) 1.80f else 1.25f,
        )
        GLES20.glUniform1f(oesUAutoLift, smoothedAutoLift)
        GLES20.glUniform1f(oesUBrighten, smoothedBrighten)
        // Deliberately weaker than the smoothing it rides on: this pass flattens
        // toward a wide blur wherever it acts, so at parity it overwhelms the
        // band split that is doing the careful work. Magic On raises blemish so
        // scars actually clear — strength follows the Smooth slider.
        GLES20.glUniform1f(
            oesUBlemish,
            if (magic) {
                LiveBeautyAdjustments.blemishFromStrength(magicStrength)
            } else {
                smoothedSmooth * BLEMISH_OF_SMOOTH
            },
        )
        GLES20.glUniform1f(
            oesUWideZoom,
            if (ArCameraBridge.isFrontCamera) FRONT_WIDE_ZOOM_OUT else 1f,
        )

        GLES20.glActiveTexture(GLES20.GL_TEXTURE1)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, historyTexId[historyReadIndex])
        GLES20.glUniform1i(oesUHistory, 1)
        GLES20.glUniform1f(oesUHistoryValid, if (historyValid) 1f else 0f)
        // Motion-gated temporal averaging removes grain in normal preview.
        // Magic keeps it off because frame blending softens moving face detail.
        GLES20.glUniform1f(
            oesUTemporalStrength,
            if (magic) MAGIC_TEMPORAL_STRENGTH else TEMPORAL_STRENGTH,
        )

        GLES20.glActiveTexture(GLES20.GL_TEXTURE2)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, skinMaskTexId)
        GLES20.glUniform1i(oesUSkinMask, 2)
        if (oesStartedMs == 0L) oesStartedMs = SystemClock.elapsedRealtime()
        GLES20.glUniform1f(oesUSkinMaskValid, if (skinMaskValid) 1f else 0f)
        GLES20.glUniform1f(oesUSkinFallback, if (colourGateAllowed()) 1f else 0f)
        GLES20.glUniform1f(oesUIsFrontCamera, if (ArCameraBridge.isFrontCamera) 1f else 0f)
        GLES20.glUniform1f(oesUMagicOn, if (magic) 1f else 0f)
        // Mid-band cuts follow the remapped effect (50 → anchor look).
        GLES20.glUniform1f(
            oesUMagicStrength,
            if (magic) {
                LiveBeautyAdjustments.effectFromSlider(magicStrength)
            } else {
                0f
            },
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
            oesURetouchShape,
            oesUJawWingL,
            oesUJawWingR,
            oesUJawRadius,
            oesURetouchEyes,
            oesUEyeL,
            oesUEyeR,
            oesUEyeRadius,
            oesURetouchMouth,
            oesUMouthCenter,
            oesUMouthRadius,
            oesURetouchTooth,
            oesUToothRegion,
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
    /**
     * How dark the scene is, 1 in a dim room and 0 in good light.
     *
     * A single fixed beauty strength cannot serve both ends, which is why this
     * exists. In a dim room the sensor is pushing gain, so the frame carries real
     * noise: smoothing is doing useful work there and sharpening mostly amplifies
     * grain. In good light the opposite holds — the frame has genuine detail worth
     * keeping, and that same smoothing only softens it away.
     *
     * Reacting to the light is also what keeps the effect from reading as a
     * filter. A fixed amount looks applied precisely because it stays put while
     * everything else in the picture changes.
     */
    private fun lowLightWeight(): Float =
        1f - smoothstep(SCENE_DARK, SCENE_BRIGHT, measuredSceneLuma)

    private fun adaptedSmooth(beauty: LiveBeautyAdjustments, lowLight: Float): Float =
        (beauty.smooth * (1f + lowLight * 0.20f)).coerceIn(0f, 1f)

    /**
     * Whitening an underexposed face lifts its noise along with it, so this eases
     * off in the dark rather than fighting the grain.
     */
    private fun adaptedWhiten(amount: Float, lowLight: Float): Float =
        (amount * (1f - lowLight * 0.30f)).coerceIn(0f, 1f)

    private fun adaptedBrighten(beauty: LiveBeautyAdjustments, lowLight: Float): Float =
        (beauty.brighten * (1f + lowLight * 0.25f)).coerceIn(0f, 1f)

    private fun adaptedSharpen(lowLight: Float): Float =
        (SHARPEN_STRENGTH * (1f - lowLight * 0.65f)).coerceAtLeast(0f)

    /**
     * Where the shader should stop calling high-frequency detail "texture" and
     * start calling it grain.
     *
     * It has to move with the light. Sensor grain in good light is a fraction of
     * a level and sits well below pore detail; in a dim room the same sensor is
     * amplifying hard and the grain grows past where that detail used to be. A
     * fixed threshold therefore either leaves grain in the dark or scrubs texture
     * off in the light.
     */
    /**
     * Whether smoothing may fall back to the colour-based skin gate.
     *
     * Only once the landmark mask has clearly failed to turn up. The colour gate
     * matches skin *tones*, not faces, so in a beige room it selects the walls
     * too — using it while the first mask was still on its way softened the
     * entire frame for the half-second before landmarks arrived. Waiting the
     * grace period out costs nothing (there is no face to smooth in that window
     * anyway) and still leaves a working, if coarser, gate on a device where
     * landmark detection never runs.
     */
    private fun colourGateAllowed(): Boolean {
        if (skinMaskValid) return false
        val started = oesStartedMs
        return started != 0L &&
            SystemClock.elapsedRealtime() - started > SKIN_MASK_GRACE_MS
    }

    /**
     * How much exposure the frame is short of, judged by how bright the person's
     * skin actually came out.
     *
     * This is the job face-region AE metering used to do, moved off the sensor.
     * Asking the camera to meter on the face worked, but re-issuing the request
     * made it re-converge in full view — the visible wash-out on open, on
     * movement, and on a face returning to frame. Measuring the result instead
     * and correcting it afterwards reaches the same place with nothing to
     * converge.
     *
     * Zero until a face has actually been measured, so an empty frame is left
     * exactly as the camera produced it.
     */
    private fun autoLiftTarget(): Float {
        val deficit = (SKIN_LUMA_TARGET - measuredSkinLuma) / SKIN_LUMA_TARGET
        return deficit.coerceIn(0f, AUTO_LIFT_MAX)
    }

    private fun noiseFloorFor(lowLight: Float): Float =
        NOISE_FLOOR_BRIGHT + (NOISE_FLOOR_DARK - NOISE_FLOOR_BRIGHT) * lowLight

    /** Same curve as GLSL smoothstep, for the strength maths above. */
    private fun smoothstep(edge0: Float, edge1: Float, x: Float): Float {
        val t = ((x - edge0) / (edge1 - edge0)).coerceIn(0f, 1f)
        return t * t * (3f - 2f * t)
    }

    /**
     * Moves [current] a fixed fraction of the way to [target] each frame — about
     * a fifth of a second to settle at 30fps, fast enough to feel immediate and
     * slow enough that nothing snaps. Jumps the last sliver so a value can
     * actually reach zero.
     */
    private fun easeToward(current: Float, target: Float): Float {
        val next = current + (target - current) * BEAUTY_EASE
        return if (kotlin.math.abs(target - next) < 0.002f) target else next
    }

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
    /** Idle warm readback — rare enough not to stall the live preview. */
    private val captureMinIntervalMs = 320L

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

    /**
     * Drops only frame-to-frame caches after the editor route releases the GL
     * thread. Beauty settings and allocated shader resources remain unchanged.
     */
    fun resetTransientFrameState() {
        historyValid = false
        oesUpdateFailures = 0
        texMatrixReady = false
        clearLastCapturedFrame()
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

    /**
     * When the OES path started drawing, used to decide whether the absence of a
     * skin mask means "not yet" or "not on this device" — see [colourGateAllowed].
     */
    private var oesStartedMs = 0L

    /**
     * Average luminance of this person's skin, measured from the camera each
     * time landmarks are detected. Drives the tone curve — see the shader's
     * toneDeficit. Starts at the neutral target so the first frames behave as if
     * no adjustment were needed rather than over-correcting.
     */
    @Volatile
    private var measuredSkinLuma = SKIN_LUMA_TARGET

    /**
     * Average brightness of the whole frame, as measured from the camera.
     * Drives how hard the beauty pass works — see [sceneAdaptedTargets].
     */
    @Volatile
    private var measuredSceneLuma = 0.35f

    fun updateSceneLuma(luma: Float) {
        if (luma.isNaN() || luma < 0f) return
        measuredSceneLuma = luma.coerceIn(0f, 1f)
    }

    fun updateSkinTone(luma: Float) {
        if (luma.isNaN() || luma <= 0f) return
        measuredSkinLuma = luma.coerceIn(0.02f, 1f)
    }

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

    // ------------------------------------------------------- still rendering

    private var stillProgram = 0
    private var stillAPosition = 0
    private var stillATexCoord = 0
    private var stillUTexture = 0
    private var stillUTexelStep = 0
    private var stillUSmoothStrength = 0
    private var stillUWhiten = 0
    private var stillUBrighten = 0
    private var stillRetouchLocs: IntArray? = null
    private var stillTexId = 0
    private var stillFboId = 0
    private var stillFboTexId = 0

    /**
     * Runs [src] through the beauty shader at its own resolution and returns the
     * result. GL thread only — call it via FaceWarpGlView.renderStillBlocking.
     *
     * Self-contained on purpose: its own program, texture and framebuffer, and it
     * restores the framebuffer binding and viewport before returning, so the live
     * preview is not disturbed by a photo being taken.
     */
    fun renderStill(src: Bitmap): Bitmap? {
        if (src.isRecycled || src.width < 2 || src.height < 2) return null

        val maxTex = IntArray(1)
        GLES20.glGetIntegerv(GLES20.GL_MAX_TEXTURE_SIZE, maxTex, 0)
        val limit = minOf(maxTex[0].takeIf { it > 0 } ?: 2048, STILL_MAX_EDGE)

        // Downscale only if the driver cannot take the full frame — a photo this
        // path exists to improve should not be shrunk for convenience.
        var input = src
        var scaled: Bitmap? = null
        val largest = maxOf(src.width, src.height)
        if (largest > limit) {
            val f = limit.toFloat() / largest
            val w = (src.width * f).toInt().coerceAtLeast(2)
            val h = (src.height * f).toInt().coerceAtLeast(2)
            scaled = try {
                Bitmap.createScaledBitmap(src, w, h, true)
            } catch (t: Throwable) {
                Log.e(TAG, "still downscale failed", t)
                return null
            }
            input = scaled
        }

        val w = input.width
        val h = input.height

        return try {
            if (!ensureStillProgram()) return null
            if (!ensureStillTargets(input, w, h)) return null

            val prevViewport = IntArray(4)
            GLES20.glGetIntegerv(GLES20.GL_VIEWPORT, prevViewport, 0)

            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, stillFboId)
            GLES20.glViewport(0, 0, w, h)
            GLES20.glClearColor(0f, 0f, 0f, 1f)
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)

            GLES20.glUseProgram(stillProgram)
            GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, stillTexId)
            GLES20.glUniform1i(stillUTexture, 0)
            GLES20.glUniform2f(stillUTexelStep, 1f / w, 1f / h)
            GLES20.glUniform1f(stillUSmoothStrength, LiveBeautyState.adjustments.smooth)
            GLES20.glUniform1f(stillUWhiten, LiveBeautyState.effectiveWhiten())
            GLES20.glUniform1f(stillUBrighten, LiveBeautyState.adjustments.brighten)
            stillRetouchLocs?.let { l ->
                bindRetouchUniforms(
                    l[0], l[1], l[2], l[3], l[4], l[5], l[6], l[7], l[8], l[9], l[10],
                    l[11], l[12], l[13], l[14], l[15], l[16], l[17], l[18],
                    l[19], l[20], l[21], l[22], l[23],
                )
            }

            GLES20.glEnableVertexAttribArray(stillAPosition)
            GLES20.glVertexAttribPointer(
                stillAPosition, 2, GLES20.GL_FLOAT, false, 16, vertexBuffer,
            )
            GLES20.glEnableVertexAttribArray(stillATexCoord)
            vertexBuffer.position(2)
            GLES20.glVertexAttribPointer(
                stillATexCoord, 2, GLES20.GL_FLOAT, false, 16, vertexBuffer,
            )
            vertexBuffer.position(0)

            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

            GLES20.glDisableVertexAttribArray(stillAPosition)
            GLES20.glDisableVertexAttribArray(stillATexCoord)

            val out = readStillPixels(w, h)

            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
            GLES20.glViewport(prevViewport[0], prevViewport[1], prevViewport[2], prevViewport[3])
            out
        } catch (t: Throwable) {
            Log.e(TAG, "still render failed", t)
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
            null
        } finally {
            scaled?.takeIf { it !== src && !it.isRecycled }?.recycle()
        }
    }

    private fun ensureStillProgram(): Boolean {
        if (stillProgram != 0) return true
        val p = buildProgram(VERTEX_SHADER, STILL_FRAGMENT_SHADER)
        if (p == 0) {
            Log.e(TAG, "still program unavailable — photo will not be filtered")
            return false
        }
        stillProgram = p
        stillAPosition = GLES20.glGetAttribLocation(p, "aPosition")
        stillATexCoord = GLES20.glGetAttribLocation(p, "aTexCoord")
        stillUTexture = GLES20.glGetUniformLocation(p, "uTexture")
        stillUTexelStep = GLES20.glGetUniformLocation(p, "uTexelStep")
        stillUSmoothStrength = GLES20.glGetUniformLocation(p, "uSmoothStrength")
        stillUWhiten = GLES20.glGetUniformLocation(p, "uWhiten")
        stillUBrighten = GLES20.glGetUniformLocation(p, "uBrighten")
        stillRetouchLocs = intArrayOf(
            GLES20.glGetUniformLocation(p, "uRetouchSaturation"),
            GLES20.glGetUniformLocation(p, "uRetouchBrightness"),
            GLES20.glGetUniformLocation(p, "uRetouchContrast"),
            GLES20.glGetUniformLocation(p, "uRetouchExposure"),
            GLES20.glGetUniformLocation(p, "uRetouchWhiteBalance"),
            GLES20.glGetUniformLocation(p, "uRetouchHighlights"),
            GLES20.glGetUniformLocation(p, "uRetouchShadows"),
            GLES20.glGetUniformLocation(p, "uRetouchNose"),
            GLES20.glGetUniformLocation(p, "uNoseWingL"),
            GLES20.glGetUniformLocation(p, "uNoseWingR"),
            GLES20.glGetUniformLocation(p, "uNoseRadius"),
            GLES20.glGetUniformLocation(p, "uRetouchShape"),
            GLES20.glGetUniformLocation(p, "uJawWingL"),
            GLES20.glGetUniformLocation(p, "uJawWingR"),
            GLES20.glGetUniformLocation(p, "uJawRadius"),
            GLES20.glGetUniformLocation(p, "uRetouchEyes"),
            GLES20.glGetUniformLocation(p, "uEyeL"),
            GLES20.glGetUniformLocation(p, "uEyeR"),
            GLES20.glGetUniformLocation(p, "uEyeRadius"),
            GLES20.glGetUniformLocation(p, "uRetouchMouth"),
            GLES20.glGetUniformLocation(p, "uMouthCenter"),
            GLES20.glGetUniformLocation(p, "uMouthRadius"),
            GLES20.glGetUniformLocation(p, "uRetouchTooth"),
            GLES20.glGetUniformLocation(p, "uToothRegion"),
        )
        return true
    }

    private fun ensureStillTargets(input: Bitmap, w: Int, h: Int): Boolean {
        if (stillTexId == 0) {
            val t = IntArray(1)
            GLES20.glGenTextures(1, t, 0)
            stillTexId = t[0]
        }
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, stillTexId)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, input, 0)

        releaseStillFbo()
        val tex = IntArray(1)
        GLES20.glGenTextures(1, tex, 0)
        stillFboTexId = tex[0]
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, stillFboTexId)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexImage2D(
            GLES20.GL_TEXTURE_2D, 0, GLES20.GL_RGBA, w, h, 0,
            GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, null,
        )

        val fbo = IntArray(1)
        GLES20.glGenFramebuffers(1, fbo, 0)
        stillFboId = fbo[0]
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, stillFboId)
        GLES20.glFramebufferTexture2D(
            GLES20.GL_FRAMEBUFFER, GLES20.GL_COLOR_ATTACHMENT0,
            GLES20.GL_TEXTURE_2D, stillFboTexId, 0,
        )
        val status = GLES20.glCheckFramebufferStatus(GLES20.GL_FRAMEBUFFER)
        if (status != GLES20.GL_FRAMEBUFFER_COMPLETE) {
            Log.e(
                TAG,
                "still framebuffer incomplete (0x" + Integer.toHexString(status) + ") at " + w + "x" + h,
            )
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
            releaseStillFbo()
            return false
        }
        return true
    }

    /** Reads the still framebuffer back, flipping it the right way up. */
    private fun readStillPixels(w: Int, h: Int): Bitmap? {
        val rowBytes = w * 4
        val buf = ByteBuffer.allocateDirect(rowBytes * h).order(ByteOrder.nativeOrder())
        GLES20.glReadPixels(0, 0, w, h, GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, buf)

        val flipped = ByteBuffer.allocateDirect(rowBytes * h).order(ByteOrder.nativeOrder())
        val row = ByteArray(rowBytes)
        for (y in 0 until h) {
            buf.position((h - 1 - y) * rowBytes)
            buf.get(row, 0, rowBytes)
            flipped.put(row)
        }
        flipped.rewind()

        return try {
            Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888).apply {
                copyPixelsFromBuffer(flipped)
            }
        } catch (t: Throwable) {
            Log.e(TAG, "still readback allocation failed", t)
            null
        }
    }

    private fun releaseStillFbo() {
        if (stillFboId != 0) {
            GLES20.glDeleteFramebuffers(1, intArrayOf(stillFboId), 0)
            stillFboId = 0
        }
        if (stillFboTexId != 0) {
            GLES20.glDeleteTextures(1, intArrayOf(stillFboTexId), 0)
            stillFboTexId = 0
        }
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
     * Copies the just-drawn screen frame into the "write" history slot, then
     * flips it to become next frame's "read" slot. Same exponential temporal
     * blend as re-drawing into an FBO (the screen buffer already IS that blend),
     * but without a second full beauty-shader pass every frame.
     */
    private fun writeHistoryFrame() {
        GLES20.glGetIntegerv(GLES20.GL_VIEWPORT, historyRestoreViewport, 0)
        val x = historyRestoreViewport[0]
        val y = historyRestoreViewport[1]
        val w = historyRestoreViewport[2]
        val h = historyRestoreViewport[3]
        if (w <= 1 || h <= 1) return
        ensureHistoryBuffers(w, h)
        val writeIndex = 1 - historyReadIndex
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, historyTexId[writeIndex])
        GLES20.glCopyTexSubImage2D(GLES20.GL_TEXTURE_2D, 0, 0, 0, x, y, w, h)
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
        oesStartedMs = 0L
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
        locShape: Int,
        locJawL: Int,
        locJawR: Int,
        locJawRadius: Int,
        locEyes: Int,
        locEyeL: Int,
        locEyeR: Int,
        locEyeRadius: Int,
        locMouth: Int,
        locMouthCenter: Int,
        locMouthRadius: Int,
        locTooth: Int,
        locToothRegion: Int,
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
        if (locShape >= 0) GLES20.glUniform1f(locShape, adj.shape)
        if (locJawL >= 0) {
            GLES20.glUniform2fv(locJawL, 1, LiveRetouchState.jawWingL, 0)
        }
        if (locJawR >= 0) {
            GLES20.glUniform2fv(locJawR, 1, LiveRetouchState.jawWingR, 0)
        }
        if (locJawRadius >= 0) GLES20.glUniform1f(locJawRadius, LiveRetouchState.jawRadius)
        if (locEyes >= 0) GLES20.glUniform1f(locEyes, adj.eyes)
        if (locEyeL >= 0) {
            GLES20.glUniform2fv(locEyeL, 1, LiveRetouchState.eyeL, 0)
        }
        if (locEyeR >= 0) {
            GLES20.glUniform2fv(locEyeR, 1, LiveRetouchState.eyeR, 0)
        }
        if (locEyeRadius >= 0) GLES20.glUniform1f(locEyeRadius, LiveRetouchState.eyeRadius)
        if (locMouth >= 0) GLES20.glUniform1f(locMouth, adj.mouth)
        if (locMouthCenter >= 0) {
            GLES20.glUniform2fv(locMouthCenter, 1, LiveRetouchState.mouthCenter, 0)
        }
        if (locMouthRadius >= 0) GLES20.glUniform1f(locMouthRadius, LiveRetouchState.mouthRadius)
        if (locTooth >= 0) {
            // Inner-lip landmarks drive visibility: closed mouth = exactly zero,
            // so bright skin/lip highlights can never be mistaken for teeth.
            GLES20.glUniform1f(
                locTooth,
                adj.tooth * LiveRetouchState.toothVisibility,
            )
        }
        if (locToothRegion >= 0) {
            GLES20.glUniform4fv(locToothRegion, 1, LiveRetouchState.toothRegion, 0)
        }
    }

    companion object {
        /**
         * Upper bound for the still render. Bounded by the driver's real limit
         * too — see [renderStill]. A 12MP RGBA texture is already ~48MB, and this
         * path allocates a texture, a framebuffer and a readback buffer.
         */
        private const val STILL_MAX_EDGE = 4096

        /**
         * Sharpen amount applied outside the smoothed skin region.
         *
         * A single constant for now — it exists to restore the clarity the skin
         * blur costs, which is a property of the pipeline rather than something a
         * preset should be dialling independently. If presets ever need their own
         * value it belongs in LiveBeautyAdjustments alongside the rest.
         */
        private const val SHARPEN_STRENGTH = 0.20f

        /** Per-frame easing fraction for beauty strengths — see [easeToward]. */
        private const val BEAUTY_EASE = 0.18f

        /**
         * Frame luminance at or below which the scene counts as fully dark, and
         * at or above which it counts as well lit. Between the two the strengths
         * blend, so walking from a lit room into a dim one has no visible step.
         */
        private const val SCENE_DARK = 0.12f
        private const val SCENE_BRIGHT = 0.42f

        /**
         * Noise-floor endpoints, as high-band amplitude in 0..1 colour — roughly
         * two levels out of 255 in good light and eight in the dark.
         */
        /** How long to wait for a first landmark mask — see colourGateAllowed. */
        private const val SKIN_MASK_GRACE_MS = 2_500L

        /** Blemish strength as a fraction of the smoothing strength. */
        /**
         * Ceiling on the face-driven exposure lift. High enough to open a dim
         * selfie toward TikTok brightness, capped so dark AE HALs do not blow out.
         */
        private const val AUTO_LIFT_MAX = 0.35f

        private const val BLEMISH_OF_SMOOTH = 0.28f

        private const val NOISE_FLOOR_BRIGHT = 0.008f
        private const val NOISE_FLOOR_DARK = 0.032f

        /**
         * Reference skin luminance for a light face auto-lift — not a forced
         * "beauty bright" look.
         */
        const val SKIN_LUMA_TARGET = 0.58f

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
         * Kept light so denoise does not stack with skin smooth into a plastic look.
         */
        private const val TEMPORAL_STRENGTH = 0.52f
        // Magic smooth has its own spatial noise cleanup, so temporal blending is
        // held well below the plain value — enough to keep grain off a still face
        // without softening detail once it moves.
        private const val MAGIC_TEMPORAL_STRENGTH = 0.20f

        /**
         * Front camera only — how far to ease from FILL_CENTER toward FIT_CENTER
         * (1.0 = fill/tight, 2.0 = full fit/widest). Values above 1 zoom out while
         * keeping aspect ratio. Out-of-bounds fit samples draw black (no clamp
         * streak bars, no vertical stretch from single-axis crop hacks).
         */
        private const val FRONT_WIDE_ZOOM_OUT = 2.0f

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
            uniform float uRetouchShape;
            uniform vec2 uJawWingL;
            uniform vec2 uJawWingR;
            uniform float uJawRadius;
            uniform float uRetouchEyes;
            uniform vec2 uEyeL;
            uniform vec2 uEyeR;
            uniform float uEyeRadius;
            uniform float uRetouchMouth;
            uniform vec2 uMouthCenter;
            uniform float uMouthRadius;
            uniform float uRetouchTooth;
            uniform vec4 uToothRegion;
        """

        private const val RETOUCH_FUNCTIONS = """
            float retouchLuma(vec3 c) {
                return dot(c, vec3(0.2126, 0.7152, 0.0722));
            }

            float retouchSkinConfidence(vec3 c) {
                float y  = dot(c, vec3(0.299, 0.587, 0.114));
                float cb = dot(c, vec3(-0.169, -0.331, 0.500)) + 0.5;
                float cr = dot(c, vec3(0.500, -0.419, -0.081)) + 0.5;
                float cbW = smoothstep(0.28, 0.36, cb) *
                    (1.0 - smoothstep(0.46, 0.54, cb));
                float crW = smoothstep(0.46, 0.54, cr) *
                    (1.0 - smoothstep(0.66, 0.74, cr));
                float yW = smoothstep(0.05, 0.15, y);
                return cbW * crW * yW;
            }

            // Brightness is a skin tone curve, not a white RGB layer. Luminance
            // changes preserve pores/shading; a tiny warm-chroma reduction makes
            // positive brightness look fresh rather than yellow or washed out.
            vec3 applyRetouchSkinBrightness(vec3 col, float skinW) {
                float amount = uRetouchBrightness * clamp(skinW, 0.0, 1.0);
                if (abs(amount) < 0.001) return col;

                float lum = retouchLuma(col);
                vec3 chroma = col - lum;
                if (amount > 0.0) {
                    float lifted = pow(
                        clamp(lum, 0.0, 1.0),
                        1.0 - amount * 0.28
                    );
                    float highlightGuard = 1.0 - smoothstep(0.68, 0.98, lum);
                    lum = mix(lum, lifted, highlightGuard);
                    chroma *= 1.0 - amount * 0.10;
                    vec3 fresh = lum + chroma;
                    fresh.r *= 1.0 - amount * 0.018;
                    fresh.b *= 1.0 + amount * 0.035;
                    return clamp(fresh, 0.0, 1.0);
                }

                lum *= 1.0 + amount * 0.24;
                return clamp(lum + chroma, 0.0, 1.0);
            }

            vec3 applyRetouchColor(vec3 col) {
                float ev = uRetouchExposure;
                if (abs(ev) > 0.01) {
                    // Film-like exposure curve: keeps black black and rolls
                    // naturally toward white instead of clipping RGB channels.
                    float lum = max(retouchLuma(col), 0.0001);
                    float exponent = pow(2.0, -ev * 0.55);
                    float exposedLum = pow(clamp(lum, 0.0, 1.0), exponent);
                    // Preserve channel ratios so exposure changes light, not hue.
                    col = clamp(col * (exposedLum / lum), 0.0, 1.0);
                }
                float wb = uRetouchWhiteBalance;
                if (abs(wb) > 0.01) {
                    // Subtle warmth/coolness; the previous ±30% channel shift
                    // was far too strong at the end of the slider.
                    float k = wb * 0.12;
                    col.r *= (1.0 + k);
                    col.b *= (1.0 - k);
                }
                float c = uRetouchContrast;
                if (abs(c) > 0.01) {
                    if (c > 0.0) {
                        // Keep full slider natural; the previous 1.5x maximum
                        // was too aggressive for a live beauty camera.
                        float alpha = 1.0 + c * 0.24;
                        col = (col - 0.5) * alpha + 0.5;
                    } else {
                        // Lower contrast without lifting shadows at all. Any
                        // shadow lift reads as a faint grey overlay, so only
                        // compress mid/high luminance downward.
                        float lum = max(retouchLuma(col), 0.0001);
                        float brightW = smoothstep(0.28, 0.88, lum);
                        float resultLum =
                            lum * (1.0 - (-c) * 0.18 * brightW);
                        col = clamp(col * (resultLum / lum), 0.0, 1.0);
                    }
                }
                float hl = uRetouchHighlights;
                float sh = uRetouchShadows;
                if (abs(hl) > 0.01) {
                    float l = retouchLuma(col);
                    float hlW = l * l;
                    col += hl * (70.0 / 255.0) * hlW;
                }
                if (abs(sh) > 0.01) {
                    // Shadow curve only: black stays black, dark detail
                    // opens/deepens, and highlights smoothly receive no change.
                    float lum = max(retouchLuma(col), 0.0001);
                    float shadowW = 1.0 - smoothstep(0.30, 0.72, lum);
                    float exponent = sh > 0.0
                        ? 1.0 - sh * 0.28
                        : 1.0 + (-sh) * 0.32;
                    float curvedLum = pow(clamp(lum, 0.0, 1.0), exponent);
                    float resultLum = mix(lum, curvedLum, shadowW);
                    // Scale luminance instead of adding grey, preserving colour
                    // and texture with no dark/white overlay.
                    col = clamp(col * (resultLum / lum), 0.0, 1.0);
                }
                float sat = uRetouchSaturation;
                if (abs(sat) > 0.01) {
                    float l = retouchLuma(col);
                    float factor = sat >= 0.0
                        ? (1.0 + sat * 0.35)
                        : max(1.0 + sat, 0.0);
                    col = mix(vec3(l), col, factor);
                }
                return clamp(col, 0.0, 1.0);
            }

            // Horizontal warp around a wing. Gaussian falloff has no finite
            // brush boundary, so it cannot reveal a circle/stamp.
            vec2 retouchWingDisp(vec2 uv, vec2 wing, float shiftX, float radius, float aspectY) {
                if (radius <= 0.001) return uv;
                vec2 d = uv - wing;
                d.y *= aspectY;
                float r2 = dot(d, d) / max(radius * radius, 0.000001);
                float f = exp(-r2 * 4.2);
                return uv - vec2(f * shiftX, 0.0);
            }

            // Nose slim/expand — same wing liquify feel as before, but soft
            // falloff + lower-face Y gate so no upper circular brush shows.
            vec2 applyRetouchNoseWarp(vec2 uv) {
                if (abs(uRetouchNose) < 0.01 || uNoseRadius <= 0.001) return uv;
                // +slim / −expand (same strength feel as the working wing version).
                float k = 0.22 * uRetouchNose;
                float tipX = (uNoseWingL.x + uNoseWingR.x) * 0.5;
                float tipY = (uNoseWingL.y + uNoseWingR.y) * 0.5;
                float shiftL = (tipX - uNoseWingL.x) * k;
                float shiftR = (tipX - uNoseWingR.x) * k;
                // Prefer the lower nose pad; cut anything above the wings so the
                // bridge/forehead never shows a liquify disc.
                float above = tipY - uNoseRadius * 0.55;
                float below = tipY + uNoseRadius * 0.95;
                float yGate = smoothstep(above, tipY - uNoseRadius * 0.05, uv.y) *
                    (1.0 - smoothstep(tipY + uNoseRadius * 0.35, below, uv.y));
                if (yGate < 0.01) return uv;
                shiftL *= yGate;
                shiftR *= yGate;
                // Tall aspect kills the round "stamp" look on top of the nose.
                uv = retouchWingDisp(uv, uNoseWingL, shiftL, uNoseRadius, 1.75);
                uv = retouchWingDisp(uv, uNoseWingR, shiftR, uNoseRadius, 1.75);
                return uv;
            }

            // Shape: cheeks only. Gaussian pads have no visible brush boundary.
            vec2 retouchCheekPad(vec2 uv, vec2 cheek, float midX, float halfW, float halfH, float amount) {
                if (halfW <= 0.001 || halfH <= 0.001 || abs(amount) < 0.001) return uv;
                float ax = abs(uv.x - cheek.x) / max(halfW, 0.001);
                float ay = abs(uv.y - cheek.y) / max(halfH, 0.001);
                // Keep nose/lips (near midline) completely out.
                float towardMid = abs(uv.x - midX) / max(abs(cheek.x - midX), 0.001);
                float centerGate = smoothstep(0.32, 0.62, towardMid);
                float w = exp(-(ax * ax * 2.4 + ay * ay * 2.0)) * centerGate;
                uv.x = midX + (uv.x - midX) * (1.0 - amount * w);
                return uv;
            }

            vec2 applyRetouchJawWarp(vec2 uv) {
                if (abs(uRetouchShape) < 0.01 || uJawRadius <= 0.001) return uv;
                float midX = (uJawWingL.x + uJawWingR.x) * 0.5;
                float halfW = max(uJawRadius * 1.15, abs(uJawWingR.x - uJawWingL.x) * 0.24);
                float halfH = halfW * 1.20;
                // Mild on purpose — full slider should stay natural, not extreme.
                float amount = 0.08 * uRetouchShape;
                uv = retouchCheekPad(uv, uJawWingL, midX, halfW, halfH, amount);
                uv = retouchCheekPad(uv, uJawWingR, midX, halfW, halfH, amount);
                return uv;
            }

            // Full-eye enlarge/shrink: whole eyeball scales from center.
            // Soft box+radial mix so the eye grows open without a circular
            // liquify stamp or angled stretch.
            vec2 retouchEyeScale(vec2 uv, vec2 center, float halfW, float amount) {
                if (halfW <= 0.001 || abs(amount) < 0.001) return uv;
                float halfH = halfW * 0.70;
                vec2 d = uv - center;
                float ax = abs(d.x) / max(halfW, 0.001);
                float ay = abs(d.y) / max(halfH, 0.001);
                float w = exp(-(ax * ax * 3.8 + ay * ay * 3.8));
                // +amount → bigger/more open (sample toward center);
                // −amount → smaller/more closed (sample outward).
                float scale = 1.0 - amount * w;
                return center + d * scale;
            }

            // Eyes: + open & slightly larger eyeball, − closed & smaller.
            vec2 applyRetouchEyesWarp(vec2 uv) {
                if (abs(uRetouchEyes) < 0.01 || uEyeRadius <= 0.001) return uv;
                float amount = 0.16 * uRetouchEyes;
                uv = retouchEyeScale(uv, uEyeL, uEyeRadius, amount);
                uv = retouchEyeScale(uv, uEyeR, uEyeRadius, amount);
                return uv;
            }

            // Mouth: + thicker lips, − thinner. Soft pad, vertical-biased plump.
            vec2 applyRetouchMouthWarp(vec2 uv) {
                if (abs(uRetouchMouth) < 0.01 || uMouthRadius <= 0.001) return uv;
                float halfW = uMouthRadius;
                float halfH = halfW * 0.55;
                vec2 d = uv - uMouthCenter;
                float ax = abs(d.x) / max(halfW, 0.001);
                float ay = abs(d.y) / max(halfH, 0.001);
                if (ax >= 1.0 || ay >= 1.0) return uv;
                float wx = 1.0 - smoothstep(0.40, 1.0, ax);
                float wy = 1.0 - smoothstep(0.30, 1.0, ay);
                float w = wx * wy;
                if (w < 0.01) return uv;
                w = w * w * (3.0 - 2.0 * w);
                float amount = 0.14 * uRetouchMouth;
                // Vertical plump stronger; mild width so lips don't look stretched.
                float sx = 1.0 - amount * w * 0.40;
                float sy = 1.0 - amount * w;
                return uMouthCenter + vec2(d.x * sx, d.y * sy);
            }

            // Tooth: colour only, strictly inside the inner-lip opening supplied
            // by uToothRegion. The lips sit outside that ellipse by construction,
            // so the colour gate below only has to separate teeth from the darker
            // tongue/throat behind them.
            vec3 applyRetouchToothColor(vec3 col, vec2 uv) {
                if (abs(uRetouchTooth) < 0.01) return col;
                if (uToothRegion.z <= 0.0005 || uToothRegion.w <= 0.0005) return col;
                vec2 d = uv - uToothRegion.xy;
                float ax = d.x / uToothRegion.z;
                float ay = d.y / uToothRegion.w;
                float r2 = ax * ax + ay * ay;
                if (r2 >= 1.0) return col;
                float region = 1.0 - smoothstep(0.45, 1.0, r2);

                float hi = max(col.r, max(col.g, col.b));
                float lo = min(col.r, min(col.g, col.b));
                float luma = dot(col, vec3(0.299, 0.587, 0.114));
                float saturation = (hi - lo) / max(hi, 0.001);
                float redExcess = max(0.0, col.r - max(col.g, col.b));
                float greenToRed = col.g / max(col.r, 0.001);
                float blueToGreen = col.b / max(col.g, 0.001);
                // Enamel is substantially brighter than tongue/throat, with
                // green close to red and enough blue even on warm teeth.
                // The old 0.10 luma floor accepted the whole mouth cavity and
                // neutralised it into the visible grey oval.
                float tooth = smoothstep(0.32, 0.56, luma) *
                    (1.0 - smoothstep(0.28, 0.48, saturation)) *
                    smoothstep(0.72, 0.88, greenToRed) *
                    smoothstep(0.48, 0.70, blueToGreen) *
                    (1.0 - smoothstep(0.055, 0.15, redExcess)) *
                    region;
                if (tooth < 0.001) return col;

                if (uRetouchTooth > 0.0) {
                    float k = uRetouchTooth * tooth;
                    float lifted = luma + 0.62 * k * (1.0 - luma);
                    vec3 neutral = vec3(clamp(lifted, 0.0, 1.0));
                    return clamp(mix(col, neutral, min(1.0, 0.95 * k)), 0.0, 1.0);
                }

                float k = (-uRetouchTooth) * tooth;
                vec3 dull = col * vec3(0.88, 0.80, 0.66);
                dull *= 1.0 - 0.28 * k;
                return clamp(mix(col, dull, min(1.0, 0.90 * k)), 0.0, 1.0);
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
            uniform float uWhiten;
            uniform float uSkinLuma;
            uniform float uSharpen;
            // Amplitude below which high-frequency detail is treated as sensor
            // noise rather than skin. Driven from the measured scene brightness,
            // because that is what sets how much the sensor is amplifying.
            uniform float uNoiseFloor;
            // Retouch Off/On — when set, colour skin gate joins the landmark mask
            // so Magic still works if the mask is weak/misaligned.
            uniform float uMagicOn;
            uniform float uMagicStrength;
            const float SKIN_LUMA_TARGET = 0.58;

            // Strength of the exposure lift per unit of deficit. Applied as a
            // gamma, so it opens shadows and midtones far more than highlights.
            const float AUTO_LIFT_GAMMA = 0.55;

            // Mild cool to cut indoor yellow/warm cast. Mostly on skin so walls
            // stay natural; tiny global so the whole frame is not creamy.
            const float BASE_LIFT = 0.12;
            const float BASE_CONTRAST = 0.05;
            const float BASE_COOL = 0.08;
            const float SKIN_COOL = 0.14;
            // Sharpen radius as a fraction of frame height — see detailAt.
            const float SHARPEN_RADIUS_FRAC = 0.0012;

            // High-pass amplitude at which a pixel stops being texture and starts
            // being a hard edge — hair against a wall, a beard against skin. An
            // unsharp mask darkens the dark side of whatever it touches and
            // brightens the light side, which on fine texture reads as detail and
            // on a hard edge reads as a drawn-on outline. Above these levels the
            // sharpen is faded out entirely.
            const float SHARPEN_EDGE_LO = 0.05;
            const float SHARPEN_EDGE_HI = 0.16;

            // The two radii that split skin into frequency bands — see the
            // separation block in main(). Both are frame fractions, not texel
            // counts, for the same device-independence reason as the sharpen
            // radius. The fine one is the previous blur's radius on a 1080-tall
            // buffer, so the smoothing everyone already sees is unchanged.
            const float FINE_RADIUS_FRAC = 0.0023;
            const float BASE_RADIUS_FRAC = 0.0074;

            // How much of each band the smoothing removes at full strength.
            //
            // The mid band is where blotches, uneven tone and blemishes live, so
            // it takes most of the cut — but not so much that skin goes flat.
            //
            // The high band holds two different things that are the same size:
            // skin texture (pores, fine lines) and sensor grain. Keeping the band
            // wholesale keeps the grain with it; cutting it wholesale is what
            // produces the plastic look. So it is split by what the content
            // actually is — see the coring in main().
            const float MID_BAND_CUT = 0.36;
            const float MAGIC_MID_BAND_CUT_MIN = 0.55;
            const float HIGH_NOISE_CUT = 0.95;
            // Zero on purpose. Everything this band holds above the noise floor
            // is pore and fine-line detail, and that detail is the only thing
            // separating smooth skin from moulded plastic. There is nothing in it
            // worth removing, so none of it is removed.
            const float HIGH_TEXTURE_CUT = 0.0;

            // Grain is far worse in colour than in brightness — coloured speckle
            // has no counterpart in real skin at this scale, so none of it is
            // worth keeping.
            const float HIGH_CHROMA_CUT = 0.92;
            uniform float uBrighten;
            uniform float uBlemish;
            uniform sampler2D uHistory;
            uniform float uHistoryValid;
            uniform float uTemporalStrength;
            uniform float uWideZoom;
            uniform sampler2D uSkinMask;
            uniform float uSkinMaskValid;
            uniform float uSkinFallback;
            // How far the measured skin sits below a well-exposed level, 0..1.
            // Drives the exposure lift at the end of main().
            uniform float uAutoLift;
            uniform float uIsFrontCamera;
            $RETOUCH_UNIFORMS
            $RETOUCH_FUNCTIONS

            // FILL_CENTER: cover the view, crop overflow, keep aspect.
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

            // FIT_CENTER: show the whole texture, letterbox the shortfall.
            // UVs can leave 0..1 on the letterboxed axis — caller must draw black.
            vec2 fitCenter(vec2 uv) {
                float viewAspect = uViewSize.x / max(uViewSize.y, 1.0);
                float texAspect = uTexSize.x / max(uTexSize.y, 1.0);
                if (texAspect > viewAspect) {
                    float s = texAspect / viewAspect;
                    return vec2(uv.x, uv.y * s + (1.0 - s) * 0.5);
                } else {
                    float s = viewAspect / texAspect;
                    return vec2(uv.x * s + (1.0 - s) * 0.5, uv.y);
                }
            }

            // Zoom out = blend FILL → FIT. Preserves aspect (no vertical stretch).
            // uWideZoom 1.0 = fill, 2.0 = full fit.
            vec2 framedUv(vec2 uv, float wideZoom) {
                float t = clamp(wideZoom - 1.0, 0.0, 1.0);
                return mix(fillCenter(uv), fitCenter(uv), t);
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
            // a non-mirrored oriented analysis frame and sampled here in the same
            // camera texture space. Alpha already IS skin confidence (0..1).
            float maskConfidence(vec2 st) {
                float direct = texture2D(uSkinMask, st).a;
                float mirrored =
                    texture2D(uSkinMask, vec2(1.0 - st.x, st.y)).a;
                // The analysis mask is never mirrored, while the front-camera
                // preview is. Taking max(direct, mirrored) drew a second ghost
                // face mask on the opposite side; brightness then landed on a
                // shoulder/background when the face moved off-centre.
                return uIsFrontCamera > 0.5 ? mirrored : direct;
            }

            // Converts a radius expressed as a fraction of frame height into a
            // texel step. Texel sizes differ from phone to phone, so a radius in
            // texels blurs a different real-world amount on every device; this
            // keeps the result identical everywhere.
            vec2 radiusStep(float frac) {
                return uTexelStep * (frac / max(uTexelStep.y, 0.00001));
            }

            // Edge-aware 8-tap ring blur (bilateral-style): neighbors are weighted by
            // color similarity to the center pixel, so real edges (eyes, brows, lips,
            // hairline) keep their weight near zero and stay sharp; only flat, noisy
            // regions (skin, sensor grain) blend in.
            vec3 surfaceBlur(vec2 uv, vec3 center, float radiusFrac) {
                vec2 t = radiusStep(radiusFrac);
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

            // The wide base for the frequency split. Four taps rather than eight
            // on purpose: this band is only the broad shading the face is rebuilt
            // on top of, and it is already blurred past the point where extra taps
            // would show. The bands that carry visible detail get the full ring.
            // Doubling the tap count of the whole split would cost far more than
            // it returns.
            vec3 baseBlur(vec2 uv, vec3 center, float radiusFrac) {
                vec2 t = radiusStep(radiusFrac);
                vec3 sum = center;
                float wSum = 1.0;

                vec3 s0 = texture2D(uTexture, uv + vec2( t.x,  t.y)).rgb;
                float w0 = exp(-distance(s0, center) * distance(s0, center) * 24.0);
                sum += s0 * w0; wSum += w0;

                vec3 s1 = texture2D(uTexture, uv + vec2(-t.x,  t.y)).rgb;
                float w1 = exp(-distance(s1, center) * distance(s1, center) * 24.0);
                sum += s1 * w1; wSum += w1;

                vec3 s2 = texture2D(uTexture, uv + vec2( t.x, -t.y)).rgb;
                float w2 = exp(-distance(s2, center) * distance(s2, center) * 24.0);
                sum += s2 * w2; wSum += w2;

                vec3 s3 = texture2D(uTexture, uv + vec2(-t.x, -t.y)).rgb;
                float w3 = exp(-distance(s3, center) * distance(s3, center) * 24.0);
                sum += s3 * w3; wSum += w3;

                return sum / wSum;
            }

            // Cheap 4-tap high-pass for the sharpen. Deliberately not reusing
            // surfaceBlur: that runs eight taps and only where skin was detected,
            // whereas sharpening is wanted on everything EXCEPT skin. Four taps
            // keeps the extra cost small on the pixels that were previously doing
            // no filtering at all.
            vec3 detailAt(vec2 uv, vec3 center) {
                // Radius is expressed as a fraction of the FRAME, not in texels.
                //
                // Texels are device-dependent: camera buffers differ in size from
                // phone to phone, so a fixed texel radius produces a coarse halo
                // on one device and an invisible one on another. Anchoring it to
                // the frame keeps the effect identical everywhere.
                //
                // It also has to be wider than a single texel — the buffer is
                // larger than the area it is drawn into, and a one-texel high-pass
                // is averaged straight back out by the downscale.
                vec2 t = radiusStep(SHARPEN_RADIUS_FRAC);
                vec3 sum =
                    texture2D(uTexture, uv + vec2(t.x, 0.0)).rgb +
                    texture2D(uTexture, uv - vec2(t.x, 0.0)).rgb +
                    texture2D(uTexture, uv + vec2(0.0, t.y)).rgb +
                    texture2D(uTexture, uv - vec2(0.0, t.y)).rgb;
                return center - sum * 0.25;
            }

            void main() {
                // Zoomed sample for the visible frame; fill-only for the landmark
                // skin mask (built in pre-wideZoom analysis space).
                vec2 d = framedUv(vTexCoord, uWideZoom);
                vec2 dLandmark = fillCenter(vTexCoord);
                // Fit blend can leave 0..1 — draw black instead of clamp-smear.
                if (d.x < 0.0 || d.x > 1.0 || d.y < 0.0 || d.y > 1.0) {
                    gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
                    return;
                }
                // Warp in pre-Y-flip space: vTexCoord/framedUv use Android Y
                // (0 = top), same as MediaPipe landmarks. uTexTransform flips Y
                // for GL — warping after that put jaw UVs on the forehead/hair.
                d = applyRetouchNoseWarp(d);
                d = applyRetouchJawWarp(d);
                d = applyRetouchEyesWarp(d);
                d = applyRetouchMouthWarp(d);
                vec2 uv = (uTexTransform * vec3(d, 1.0)).xy;
                vec2 st = (uStMatrix * vec4(uv, 0.0, 1.0)).xy;
                vec3 col = texture2D(uTexture, st).rgb;

                // Skin mask needs its own unzoomed mapping — the mask texture was
                // built from raw (pre-wideZoom) landmark/analysis-frame geometry,
                // so sampling it with the zoomed `st` above would misalign it.
                vec2 uvLandmark = (uTexTransform * vec3(dLandmark, 1.0)).xy;
                vec2 stLandmark = (uStMatrix * vec4(uvLandmark, 0.0, 1.0)).xy;
                // Brightness must follow the exact camera pixel currently on
                // screen. Sampling its mask through fillCenter (stLandmark)
                // leaves the mask behind when the preview is zoomed out, making
                // the face-shaped lift slide onto a shoulder as the user moves.
                vec2 uvBrightnessMask =
                    (uTexTransform * vec3(d, 1.0)).xy;
                vec2 stBrightnessMask =
                    (uStMatrix * vec4(uvBrightnessMask, 0.0, 1.0)).xy;
                // Two different gates on purpose.
                //
                // Smoothing needs the landmark mask: it must avoid eyes, brows and
                // lips, and only the mask knows where those are.
                //
                // Tone must NOT use that mask. It covers the face oval only, so
                // neck, ears and everything else keep their original tone and the
                // face reads as a lighter patch pasted on. The colour-based gate
                // finds skin wherever it appears, which is what makes the result
                // look like a person rather than a cut-out.
                //
                // When neither is available smoothing simply does not run. The
                // colour gate cannot stand in for the mask here: it selects
                // anything skin-COLOURED, which in an ordinary room means the
                // walls, so falling back to it softened the whole frame for the
                // moment before the first mask arrived. It is allowed only after
                // a grace period, once it is clear no mask is coming at all —
                // see uSkinFallback. Magic On stays mask-only too — colour-gate
                // + Magic was blurring walls/hair into a soft patterned haze.
                float maskConf =
                    uSkinMaskValid > 0.5 ? maskConfidence(stLandmark) : 0.0;
                float colourConf =
                    uSkinFallback > 0.5 ? skinConfidence(col) : 0.0;
                float smoothConf = max(maskConf, colourConf);
                float toneConf = skinConfidence(col);
                // Retouch Brightness is face-skin only: landmarks provide the
                // face boundary and the colour gate rejects eyes/hair/background.
                // Never use the colour-only fallback here because it can select
                // skin-coloured walls or shoulders outside the detected face.
                float retouchBrightnessConf =
                    (uSkinMaskValid > 0.5
                        ? maskConfidence(stBrightnessMask)
                        : 0.0) * skinConfidence(col);

                if (smoothConf > 0.001) {
                    // Frequency separation.
                    //
                    // Blending the pixel toward a blur — which is what this used
                    // to do — cannot tell a blemish from a pore, so it removes
                    // both and the face turns to wax. Splitting the skin by
                    // feature SIZE can: two blurs at different radii cut it into
                    // three bands, and each one gets treated on its own terms.
                    //
                    //   base : broad shading and tone. Untouched — this is the
                    //          shape of the face, and softening it is what makes
                    //          a face look flat and pasted-on.
                    //   mid  : blotches, patchiness, spots. Cut hard. Removing
                    //          this band is where smooth skin actually comes from.
                    //   high : pores, fine lines, grain. Mostly kept, because
                    //          this is the band the eye reads as real skin.
                    vec3 fine = surfaceBlur(st, col, FINE_RADIUS_FRAC);
                    vec3 base = baseBlur(st, col, BASE_RADIUS_FRAC);
                    vec3 midBand = fine - base;
                    vec3 highBand = col - fine;

                    float amount = uSmoothStrength * smoothConf;
                    // Magic: mid-band blotch cut for plastic/scar cleanup.
                    // Above the default anchor, remove more uneven-tone band
                    // without increasing the wide blur/blemish pass.
                    float highSlider = smoothstep(0.90, 1.0, uMagicStrength);
                    float midCut = MID_BAND_CUT;
                    if (uMagicOn > 0.5) {
                        float belowAnchor = min(uMagicStrength / 0.90, 1.0);
                        midCut = mix(
                            MAGIC_MID_BAND_CUT_MIN,
                            0.91,
                            belowAnchor
                        );
                        // Full slider cleans the blotch band hardest — this is
                        // what "smooth" actually is. Sharpness is restored by
                        // the high-band gain below rather than by keeping
                        // blotches, so this can stay strong without blurring.
                        midCut = mix(midCut, 0.96, highSlider);
                        amount = min(amount, 0.99);
                    }

                    // The high band is split again before it is weighted, because
                    // grain and skin texture live in it together and a single
                    // gain cannot keep one without the other.
                    //
                    // By colour: speckle in the colour channels is all noise, so
                    // it goes almost entirely.
                    //
                    // By amplitude: grain is the smallest thing in the band, and
                    // pores and fine lines sit above it. Cutting hard below the
                    // noise floor and easing off above it removes the grain and
                    // leaves the texture — the floor itself rises in dim light,
                    // where the sensor is amplifying and the grain is stronger.
                    float highLuma = dot(highBand, vec3(0.299, 0.587, 0.114));
                    vec3 highChroma = highBand - highLuma;
                    float isTexture = smoothstep(
                        uNoiseFloor,
                        uNoiseFloor * 2.5,
                        abs(highLuma)
                    );
                    float lumaCut = mix(HIGH_NOISE_CUT, HIGH_TEXTURE_CUT, isTexture);
                    float chromaCut = HIGH_CHROMA_CUT;
                    if (uMagicOn > 0.5) {
                        // Above default preserve MORE real texture while the
                        // mid/noise bands clean harder. This prevents the high
                        // slider from becoming a patterned blur.
                        float noiseCut = mix(0.92, 1.0, uMagicStrength);
                        float textureCut = mix(
                            mix(0.08, 0.17, min(uMagicStrength / 0.90, 1.0)),
                            0.0,
                            highSlider
                        );
                        lumaCut = mix(noiseCut, textureCut, isTexture);
                        chromaCut = mix(
                            mix(0.92, 1.0, min(uMagicStrength / 0.90, 1.0)),
                            0.85,
                            highSlider
                        );
                    }
                    // Texture gain above the default anchor. The mid band is
                    // cleaned hard there, which on its own reads as soft focus,
                    // so the surviving pore/line detail is pushed back up to
                    // keep the result crisp instead of blurred.
                    float textureGain = 1.0;
                    if (uMagicOn > 0.5) {
                        textureGain = mix(1.0, 1.30, highSlider);
                    }
                    vec3 highKept =
                        highLuma * (1.0 - amount * lumaCut) * textureGain +
                        highChroma * (1.0 - amount * chromaCut);

                    col = clamp(
                        base +
                        midBand * (1.0 - amount * midCut) +
                        highKept,
                        0.0,
                        1.0
                    );

                    // Blemish / scar suppression, on top of the split. A spot is
                    // a patch DARKER than the skin around it, so only pixels below
                    // the local average get pulled toward the base. Targeting the
                    // dark side alone removes marks the band cut left behind
                    // without touching anything that isn't one.
                    //
                    // Measured against the wide base rather than the fine blur:
                    // a scar is wider than the fine radius, so the fine blur
                    // follows it down and barely registers a dip at all.
                    if (uBlemish > 0.001) {
                        float lumaCol = dot(col, vec3(0.299, 0.587, 0.114));
                        float lumaBase = dot(base, vec3(0.299, 0.587, 0.114));
                        float dip = max(0.0, lumaBase - lumaCol);
                        // The threshold has to clear ordinary shading, not just
                        // noise. This pass mixes toward a WIDE blur, so anything
                        // it accepts gets genuinely flattened — set it too low
                        // and every soft gradient on a face qualifies, which is
                        // most of where the waxy look was coming from.
                        float spotLo = uMagicOn > 0.5 ? 0.032 : 0.045;
                        float spotHi = uMagicOn > 0.5 ? 0.13 : 0.16;
                        float spot = smoothstep(spotLo, spotHi, dip);
                        // The wide-base blemish pull is spatial blur, so it is
                        // eased back above the default anchor. It is kept at
                        // half strength rather than dropped, because it is the
                        // only pass that clears marks wider than the mid band.
                        float blemishClarity =
                            uMagicOn > 0.5 ? mix(1.0, 0.5, highSlider) : 1.0;
                        col = mix(
                            col,
                            base,
                            spot * uBlemish * smoothConf * blemishClarity
                        );
                    }

                }

                // Tone, on all skin — see the gate note above.
                //
                // Everything here happens on LUMINANCE ONLY. Colour is split off
                // first as chroma, left untouched, and added back afterwards.
                //
                // This is the whole reason the previous version looked like a
                // white film. Lifting RGB directly — even scaled by a luma ratio —
                // pushes the brighter parts of skin toward 1.0, where all three
                // channels converge and the face flattens into a pale sheet.
                // Curving luminance with a highlight rolloff and re-adding the
                // original chroma keeps skin looking like skin: brighter, but with
                // its own colour and its own shading intact.
                if (toneConf > 0.001) {
                    float l = dot(col, vec3(0.299, 0.587, 0.114));
                    vec3 chroma = col - l;
                    float lum = l;

                    // How far this person's skin sits below a flattering
                    // luminance, measured from the camera rather than assumed.
                    //
                    // A fixed lift is wrong at both ends: on already-bright skin
                    // it blows out, and on dark skin it is too weak to do
                    // anything. Scaling by the measured deficit means everyone
                    // gets the amount their own skin needs.
                    float toneDeficit = clamp(
                        (SKIN_LUMA_TARGET - uSkinLuma) / SKIN_LUMA_TARGET, 0.0, 1.0
                    );
                    float toneScale = 0.45 + toneDeficit * 0.55;

                    // Brighten: shadows and midtones only. The (1-l)^2 weight
                    // means already-bright areas are barely moved, so the lift
                    // opens up a dim face without washing out lit areas.
                    if (uBrighten > 0.001) {
                        lum += uBrighten * toneConf * 0.36 * toneScale *
                            (1.0 - lum) * (1.0 - lum);
                    }

                    // Whiten: a gamma lift with a soft knee. Past the knee the
                    // effect eases off toward zero, so highlights roll off instead
                    // of clipping to flat white — clipping is what reads as a
                    // sheet laid over the face.
                    if (uWhiten > 0.001) {
                        float amount = uWhiten * toneConf * toneScale;
                        float lifted = pow(clamp(lum, 0.0, 1.0), 1.0 - amount * 0.35);
                        float rolloff = 1.0 - smoothstep(0.62, 0.97, lum);
                        lum = mix(lum, lifted, rolloff);
                    }

                    lum = clamp(lum, 0.0, 1.0);

                    // No chroma boost on lift — boosting warm skin chroma was the
                    // orange cast. Leave chroma as-is (ashy risk is low at our
                    // mild brighten amounts).
                    col = clamp(lum + chroma, 0.0, 1.0);
                }

                // Sharpen everything the smoothing did NOT touch — eyes, brows,
                // lashes, hair, the edge of the face.
                //
                // Gating on (1 - smoothConf) is the whole point. Sharpening the
                // skin would simply undo the blur that was just applied, and
                // sharpening uniformly is what makes a filtered face look crunchy.
                // Restricting it to the areas that were left alone is what reads
                // as "smooth skin, sharp features" rather than "blurred photo".
                if (uSharpen > 0.001) {
                    float sharpenGate = 1.0 - clamp(smoothConf, 0.0, 1.0);
                    // Ease off in the darkest areas, where a high-pass mostly
                    // amplifies sensor noise rather than detail.
                    float shadowGuard = smoothstep(0.04, 0.18, dot(col, vec3(0.299, 0.587, 0.114)));
                    vec3 detail = detailAt(st, col);
                    // Sharpen texture, never edges. The strongest high-pass values
                    // in the frame are not detail at all — they are the boundaries
                    // of hair, beard and the hairline, and pushing those further
                    // apart is what draws a hard black outline around them and
                    // makes the whole thing look drawn on rather than filmed.
                    float edgeMag = max(max(abs(detail.r), abs(detail.g)), abs(detail.b));
                    float edgeGuard = 1.0 - smoothstep(SHARPEN_EDGE_LO, SHARPEN_EDGE_HI, edgeMag);
                    col = clamp(
                        col + detail * uSharpen * sharpenGate * shadowGuard * edgeGuard,
                        0.0,
                        1.0
                    );
                }
                // Exposure lift, on the WHOLE frame.
                //
                // This replaces face-region AE metering. Pointing the camera's
                // metering at the face did expose it properly, but every time it
                // was re-issued the sensor visibly re-converged — the image washed
                // out and settled over about a second, on camera open, on every
                // movement, and every time a face came back into frame. Doing the
                // same job after the fact costs no convergence at all.
                //
                // Deliberately not restricted to skin. Brightening only the face
                // leaves it sitting on an unchanged background and reads as a
                // cut-out pasted on — the same mistake the tone block above is
                // written to avoid. Raising exposure moves everything, so this
                // does too.
                //
                // Applied as a multiplicative gain on the original colour, which
                // is what an exposure change actually is: channel ratios are
                // preserved, so nothing shifts hue on the way up. The rolloff
                // holds the highlights, so a lit wall behind a dim face does not
                // blow out while the face is being opened up.
                if (uAutoLift > 0.001) {
                    float lumIn = max(dot(col, vec3(0.299, 0.587, 0.114)), 0.0001);
                    float lifted = pow(lumIn, 1.0 - uAutoLift * AUTO_LIFT_GAMMA);
                    float rolloff = 1.0 - smoothstep(0.65, 1.0, lumIn);
                    col = clamp(col * (mix(lumIn, lifted, rolloff) / lumIn), 0.0, 1.0);
                }

                // Always-on preview polish (lift + contrast). Cool WB is applied
                // LAST after temporal/retouch so history and warmth sliders cannot
                // put the yellow cast back.
                {
                    float lumIn = max(dot(col, vec3(0.299, 0.587, 0.114)), 0.0001);
                    float lifted = pow(lumIn, 1.0 - BASE_LIFT);
                    float rolloff = 1.0 - smoothstep(0.72, 1.0, lumIn);
                    col = clamp(col * (mix(lumIn, lifted, rolloff) / lumIn), 0.0, 1.0);
                    col = clamp((col - 0.5) * (1.0 + BASE_CONTRAST) + 0.5, 0.0, 1.0);
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
                col = applyRetouchSkinBrightness(
                    col,
                    retouchBrightnessConf
                );
                // Cut yellow/warm: light global cool + extra on skin only.
                {
                    float skinW = skinConfidence(col);
                    float coolK = (BASE_COOL + SKIN_COOL * skinW) * 0.35;
                    if (coolK > 0.001) {
                        col.r *= (1.0 - coolK);
                        col.g *= (1.0 - coolK * 0.30);
                        col.b *= (1.0 + coolK);
                        col = clamp(col, 0.0, 1.0);
                    }
                }
                // Last: the band split and the polish blocks above rebuild col
                // from the original texture, which discarded an earlier tooth
                // pass entirely.
                col = applyRetouchToothColor(col, d);
                gl_FragColor = vec4(col, 1.0);
            }
        """

        /**
         * Still-photo shader. Deliberately separate from the preview shaders.
         *
         * Photos used to be saved straight out of the live GL preview buffer,
         * which is capped by the preview stream's resolution — under 3MP on a
         * sensor that can do four times that. This renders a full-resolution
         * capture through the same beauty maths instead, so the photo keeps the
         * look the user saw while being far sharper.
         *
         * Two things from [OES_FRAGMENT_SHADER] are intentionally absent:
         * temporal denoise (meaningless for a single frame — there is no
         * history), and the landmark skin mask. The mask is built in preview
         * framing; a full-sensor still is a wider crop, so the mask would not
         * line up. The colour-based skin gate is framing-independent and is what
         * the preview shader itself falls back to when no mask is available.
         */
        private const val STILL_FRAGMENT_SHADER = """
            precision highp float;
            varying vec2 vTexCoord;
            uniform sampler2D uTexture;
            uniform vec2 uTexelStep;
            uniform float uSmoothStrength;
            uniform float uWhiten;
            uniform float uBrighten;
            // Same always-on polish as the live OES preview — keeps stills from
            // looking darker/duller than what the user just saw in the viewfinder.
            const float BASE_LIFT = 0.12;
            const float BASE_CONTRAST = 0.05;
            const float BASE_COOL = 0.08;
            const float SKIN_COOL = 0.14;
            $RETOUCH_UNIFORMS
            $RETOUCH_FUNCTIONS

            float skinConfidence(vec3 c) {
                float y  = dot(c, vec3(0.299, 0.587, 0.114));
                float cb = dot(c, vec3(-0.169, -0.331, 0.500)) + 0.5;
                float cr = dot(c, vec3(0.500, -0.419, -0.081)) + 0.5;
                float cbW = smoothstep(0.28, 0.36, cb) * (1.0 - smoothstep(0.46, 0.54, cb));
                float crW = smoothstep(0.46, 0.54, cr) * (1.0 - smoothstep(0.66, 0.74, cr));
                float yW  = smoothstep(0.05, 0.15, y);
                return cbW * crW * yW;
            }

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
                vec3 col = texture2D(uTexture, vTexCoord).rgb;
                float toneConf = skinConfidence(col);
                if (uSmoothStrength > 0.001) {
                    float skinConf = toneConf;
                    if (skinConf > 0.001) {
                        vec3 blurred = surfaceBlur(vTexCoord, col);
                        col = mix(col, blurred, uSmoothStrength * skinConf);
                    }
                }
                // Face brighten / whiten — luminance only, mild chroma restore
                // (same idea as live preview; keeps stills from going orange).
                if (toneConf > 0.001 && (uBrighten > 0.001 || uWhiten > 0.001)) {
                    float l = dot(col, vec3(0.299, 0.587, 0.114));
                    vec3 chroma = col - l;
                    float lum = l;
                    if (uBrighten > 0.001) {
                        lum += uBrighten * toneConf * 0.36 * (1.0 - lum) * (1.0 - lum);
                    }
                    if (uWhiten > 0.001) {
                        float lifted = pow(clamp(lum, 0.0, 1.0), 1.0 - uWhiten * toneConf * 0.35);
                        float rolloff = 1.0 - smoothstep(0.62, 0.97, lum);
                        lum = mix(lum, lifted, rolloff);
                    }
                    lum = clamp(lum, 0.0, 1.0);
                    col = clamp(lum + chroma, 0.0, 1.0);
                }
                // Always-on preview polish (matches OES BASE_LIFT / BASE_CONTRAST).
                {
                    float lumIn = max(dot(col, vec3(0.299, 0.587, 0.114)), 0.0001);
                    float lifted = pow(lumIn, 1.0 - BASE_LIFT);
                    float rolloff = 1.0 - smoothstep(0.72, 1.0, lumIn);
                    col = clamp(col * (mix(lumIn, lifted, rolloff) / lumIn), 0.0, 1.0);
                    col = clamp((col - 0.5) * (1.0 + BASE_CONTRAST) + 0.5, 0.0, 1.0);
                }
                col = applyRetouchColor(col);
                col = applyRetouchSkinBrightness(col, toneConf);
                // Cut yellow/warm — same as live OES.
                {
                    float skinW = skinConfidence(col);
                    float coolK = (BASE_COOL + SKIN_COOL * skinW) * 0.35;
                    if (coolK > 0.001) {
                        col.r *= (1.0 - coolK);
                        col.g *= (1.0 - coolK * 0.30);
                        col.b *= (1.0 + coolK);
                        col = clamp(col, 0.0, 1.0);
                    }
                }
                col = applyRetouchToothColor(col, vTexCoord);
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
                tc = applyRetouchJawWarp(tc);
                tc = applyRetouchEyesWarp(tc);
                tc = applyRetouchMouthWarp(tc);

                vec4 sourceColor;
                if (uFilterType == 0) {
                    sourceColor = texture2D(uTexture, tc);
                } else {
                    sourceColor = sharpenSample(tc, uTexSize);
                }

                vec3 col = sourceColor.rgb;
                col = applyRetouchColor(col);
                col = applyRetouchSkinBrightness(col, retouchSkinConfidence(col));
                col = applyRetouchToothColor(col, tc);

                gl_FragColor = vec4(col, sourceColor.a);
            }
        """
    }
}
