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
import java.util.concurrent.atomic.AtomicInteger
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10
import kotlin.math.pow
import android.opengl.EGLConfig as AndroidEglConfig
import android.opengl.EGLSurface as AndroidEglSurface

import com.dubai.bimobondapp.ar_camera.beauty_v3.V3BeautyCompat
import com.dubai.bimobondapp.ar_camera.beauty_v3.V3BeautyConfig
import com.dubai.bimobondapp.ar_camera.beauty_v3.V3BeautyState
import com.dubai.bimobondapp.ar_camera.beauty_v3.V3Diagnostics
import com.dubai.bimobondapp.ar_camera.beauty_v3.V3Pipeline

class FaceWarpRenderer : GLSurfaceView.Renderer {

    private val v3Pipeline = V3Pipeline()
    private val v3ViewportScratch = IntArray(4)

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
    private var uMakeupLip = 0
    private var uMakeupBlush = 0
    private var uMakeupLiner = 0
    private var uMakeupShadow = 0
    private var uMakeupLipColor = 0
    private var uMakeupBlushColor = 0
    private var uMakeupLinerColor = 0
    private var uMakeupShadowColor = 0
    private var uBlushCheekL = 0
    private var uBlushCheekR = 0
    private var uBlushRadius = 0

    private var smoothedBackPersonWeight = 0f
    /** State-transition-only diagnostics for the live face-aware render path. */
    private var lastFacePipelineDiagnosticState = Int.MIN_VALUE

    private var oesTextureId = 0
    private var cameraSurfaceTexture: SurfaceTexture? = null
    private val stMatrix = FloatArray(16)

    private val texMatrixGl = FloatArray(9)
    private var texMatrixReady = false
    private val oesViewport = IntArray(4)
    @Volatile private var androidViewW = 0
    @Volatile private var androidViewH = 0
    private var glSurfaceW = 0
    private var glSurfaceH = 0

    fun setAndroidViewSize(width: Int, height: Int) {
        androidViewW = width
        androidViewH = height
    }

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

    /**
     * True only after CameraX [Preview.SurfaceRequest.TransformationInfoListener]
     * delivered rotation/buffer for the *current* lens. Stale values from the
     * previous camera must not count as ready during a front/back flip.
     */
    @Volatile
    private var cameraTransformationInfoReady = false

    fun setCameraTransform(rotationDegrees: Int, frontMirror: Boolean, bufW: Int, bufH: Int) {
        cameraRotationDegrees = ((rotationDegrees % 360) + 360) % 360
        cameraFrontMirror = frontMirror
        if (bufW > 0) cameraBufW = bufW
        if (bufH > 0) cameraBufH = bufH
    }

    /** Drop previous-lens rotation/buffer so beauty publish cannot resume on stale values. */
    fun invalidateCameraTransformForSwitch() {
        cameraTransformationInfoReady = false
        cameraRotationDegrees = 0
        cameraBufW = 0
        cameraBufH = 0
    }

    /** CameraX TransformationInfo for the lens that just bound — not the speculative initialRot. */
    fun markCameraTransformationInfo(
        rotationDegrees: Int,
        frontMirror: Boolean,
        bufW: Int,
        bufH: Int,
    ) {
        setCameraTransform(rotationDegrees, frontMirror, bufW, bufH)
        cameraTransformationInfoReady = true
        Log.i(
            "ArLiveBeautyPub",
            "SWITCH_TRANSFORM_READY rotation=$cameraRotationDegrees " +
                "buf=${cameraBufW}x$cameraBufH frontMirror=$frontMirror",
        )
    }

    fun isCameraTransformationInfoReady(): Boolean = cameraTransformationInfoReady

    fun cameraRotationDegrees(): Int = cameraRotationDegrees

    /**
     * Display-oriented camera buffer size (after 90/270 swap) — same aspect the
     * OES shader uses for FIT/FILL. Used so recorded MP4s match preview FOV
     * without baking letterbox bars.
     */
    fun orientedCameraSize(): Pair<Int, Int> {
        val rot = cameraRotationDegrees
        val w = cameraBufW.coerceAtLeast(1)
        val h = cameraBufH.coerceAtLeast(1)
        return if (rot == 90 || rot == 270) h to w else w to h
    }

    fun updateTexture(bitmap: Bitmap) {
        pendingBitmap?.recycle()
        pendingBitmap = bitmap
    }

    fun setWarpParams(params: FaceWarpParams) {
        warpParams = params
    }

    /**
     * Replaces the camera OES producer after Android destroys/recreates the
     * Activity surfaces while backgrounded. Reusing the old SurfaceTexture can
     * bind successfully in CameraX but never deliver another GL frame.
     * Must run on the GL thread.
     */
    fun recreateCameraSurfaceTexture() {
        try {
            cameraSurfaceTexture?.release()
        } catch (_: Throwable) {
        }
        cameraSurfaceTexture = null
        if (oesTextureId != 0) {
            GLES20.glDeleteTextures(1, intArrayOf(oesTextureId), 0)
        }

        val texture = IntArray(1)
        GLES20.glGenTextures(1, texture, 0)
        oesTextureId = texture[0]
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

        oesUpdateFailures = 0
        texMatrixReady = false
        val st = SurfaceTexture(oesTextureId)
        cameraSurfaceTexture = st
        onCameraSurfaceReady?.invoke(st)
    }

    /**
     * Zeroes (not deletes — the names belong to the dead context) every cached GL
     * handle on a new EGL context, so stale ensure* guards don't hand back
     * framebuffers from the destroyed one (caused the intermittent black preview
     * after returning from another app).
     */
    private fun forgetGlObjectsForNewContext() {
        captureFboId = 0
        captureFboTexId = 0
        captureFboW = 0
        captureFboH = 0

        encoderFboId = 0
        encoderFboTexId = 0
        encoderFboW = 0
        encoderFboH = 0

        stillProgram = 0
        stillTexId = 0
        stillFboId = 0
        stillFboTexId = 0
        stillFboW = 0
        stillFboH = 0

        blitProgram = 0
        // Same reasoning for the encoder's window surface: it was created
        // against the old context/display, so the handle must be dropped rather
        // than eglDestroySurface'd. presentToEncoder recreates it on demand.
        encoderEglSurface = null
        lastEncoderSwapMs = 0L

        v3Pipeline.forgetHandles()
    }

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        forgetGlObjectsForNewContext()
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
        uMakeupLip = GLES20.glGetUniformLocation(program, "uMakeupLip")
        uMakeupBlush = GLES20.glGetUniformLocation(program, "uMakeupBlush")
        uMakeupLiner = GLES20.glGetUniformLocation(program, "uMakeupLiner")
        uMakeupShadow = GLES20.glGetUniformLocation(program, "uMakeupShadow")
        uMakeupLipColor = GLES20.glGetUniformLocation(program, "uMakeupLipColor")
        uMakeupBlushColor = GLES20.glGetUniformLocation(program, "uMakeupBlushColor")
        uMakeupLinerColor = GLES20.glGetUniformLocation(program, "uMakeupLinerColor")
        uMakeupShadowColor = GLES20.glGetUniformLocation(program, "uMakeupShadowColor")
        uBlushCheekL = GLES20.glGetUniformLocation(program, "uBlushCheekL")
        uBlushCheekR = GLES20.glGetUniformLocation(program, "uBlushCheekR")
        uBlushRadius = GLES20.glGetUniformLocation(program, "uBlushRadius")

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

        // CameraX OES producer for the V3 live path. Must be created here — without
        // this SurfaceTexture, preferOes/bindOes can never succeed and the UI falls
        // back to plain PreviewView (beauty controls appear to do nothing).
        val st = SurfaceTexture(oesTextureId)
        cameraSurfaceTexture = st
        onCameraSurfaceReady?.invoke(st)

        texMatrixReady = false

        blitProgram = buildProgram(BLIT_VERTEX_SHADER, BLIT_FRAGMENT_SHADER)
        if (blitProgram == 0) reportGlUnusable("blit program")
        blitAPosition = GLES20.glGetAttribLocation(blitProgram, "aPosition")
        blitATexCoord = GLES20.glGetAttribLocation(blitProgram, "aTexCoord")
        blitUTexture = GLES20.glGetUniformLocation(blitProgram, "uTexture")
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        glSurfaceW = width
        glSurfaceH = height
        GLES20.glViewport(0, 0, width, height)
    }

    override fun onDrawFrame(gl: GL10?) {
        val drawStartNs = System.nanoTime()
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
            V3BeautyCompat.syncFromLegacy()
            V3Diagnostics.logActiveRenderPath("V3_RAW")
            logV3RouteAndState(drawV3RawReached = true)
            drawV3Raw()
            render360EffectIfActive()
            presentToEncoder { drawV3Raw() }
            if (captureEnabled) captureFrontBuffer { drawV3Raw() }
            onFramePresented?.invoke()
            val passThroughDiag = !V3BeautyConfig.anyActive()
            reportDiagnosticDraw(
                drawNs = System.nanoTime() - drawStartNs,
                passThrough = passThroughDiag,
                sceneGrainCleanActive = false,
            )
            return
        }

        uploadPendingBitmap()
        if (textureWidth <= 0 || textureHeight <= 0) return

        drawBitmapFrame()
        presentToEncoder { drawBitmapFrame() }
        if (captureEnabled) captureFrontBuffer { drawBitmapFrame() }
        onFramePresented?.invoke()
    }

    /** The production B path: one OES lookup plus required transforms/framing. */

    /**
     * Active filters only — Magic / makeup / retouch / named beauty values.
     * When false, [drawRawOes] is the entire live preview (true B pass-through).
     */


    private fun drawV3Raw() {
        if (oesTextureId == 0) return
        if (cameraBufW < 2 || cameraBufH < 2) return
        GLES20.glGetIntegerv(GLES20.GL_VIEWPORT, v3ViewportScratch, 0)
        val ts = try {
            cameraSurfaceTexture?.timestamp ?: System.nanoTime()
        } catch (_: Throwable) {
            System.nanoTime()
        }
        val contract = v3Pipeline.updateContract(
            sourceWidth = cameraBufW,
            sourceHeight = cameraBufH,
            rotationDegrees = cameraRotationDegrees,
            mirrorX = cameraFrontMirror,
            stMatrix = stMatrix,
            viewWidth = v3ViewportScratch[2],
            viewHeight = v3ViewportScratch[3],
            wideZoom = if (ArCameraBridge.isFrontCamera) {
                FRONT_WIDE_ZOOM_OUT
            } else {
                BACK_WIDE_ZOOM_OUT
            },
            timestampNs = ts,
        )
        v3Pipeline.drawFrame(oesTextureId, contract, vertexBuffer)
        probeGlError("V3 raw draw")
    }

    /** Temporary low-frequency routing/state proof — remove after device verification. */
    private fun logV3RouteAndState(drawV3RawReached: Boolean) {
        val now = SystemClock.elapsedRealtime()
        if (now - lastV3RouteLogMs < 1_000L) return
        lastV3RouteLogMs = now
        Log.i(
            "V3_ROUTE",
            "glSurface=${cameraSurfaceTexture != null} " +
                "preferOes=${ArCameraController.preferOesBindingForDiag()} " +
                "boundOes=${ArCameraController.isBoundToOes()} " +
                "drawV3RawReached=$drawV3RawReached",
        )
        val snap = V3BeautyState.snapshot
        Log.i(
            "V3_STATE",
            "saturation=${snap.saturation} eyes=${snap.eyes} " +
                "lipstick=${snap.lipstick} blush=${snap.blush} " +
                "foundation=${snap.foundation} " +
                "foundationRGB=${"%.2f".format(snap.foundationR)}," +
                "${"%.2f".format(snap.foundationG)}," +
                "${"%.2f".format(snap.foundationB)}",
        )
    }

    private var lastV3RouteLogMs = 0L

    private fun reportDiagnosticDraw(
        drawNs: Long,
        passThrough: Boolean,
        sceneGrainCleanActive: Boolean,
    ) {
        GLES20.glGetIntegerv(GLES20.GL_VIEWPORT, oesViewport, 0)
        ArCameraDiagnostics.onGlDraw(
            drawNs = drawNs,
            bufferW = cameraBufW,
            bufferH = cameraBufH,
            viewW = androidViewW,
            viewH = androidViewH,
            surfaceW = glSurfaceW,
            surfaceH = glSurfaceH,
            viewport = oesViewport.copyOf(),
            fbos = "capture=${captureFboW}x$captureFboH, encoder=${encoderFboW}x$encoderFboH, " +
                "still=${stillFboW}x$stillFboH",
            sharpen = 0f,
            blemish = 0f,
            passThrough = passThrough,
            sceneGrainCleanActive = sceneGrainCleanActive,
        )
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
        bindMakeupUniforms(
            uMakeupLip,
            uMakeupBlush,
            uMakeupLiner,
            uMakeupShadow,
            uMakeupLipColor,
            uMakeupBlushColor,
            uMakeupLinerColor,
            uMakeupShadowColor,
            uBlushCheekL,
            uBlushCheekR,
            uBlushRadius,
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


    private fun render360EffectIfActive() {
        val effect = ArCameraBridge.engine360Effect ?: return
        if (effect.getState().status == com.dubai.bimobondapp.effect360.Engine360Status.IDLE) return
        val proj = FloatArray(16)
        val view = FloatArray(16)
        effect.update(System.nanoTime())
        effect.render(
            cameraOesTextureId = oesTextureId,
            width = if (oesViewport[2] > 0) oesViewport[2] else 1080,
            height = if (oesViewport[3] > 0) oesViewport[3] else 1920,
            projectionMatrixIn = proj,
            viewMatrixIn = view
        )
    }

    @Volatile
    var captureEnabled: Boolean = false

    /**
     * Why GPU front-buffer capture is running. Still photos must preserve preview
     * aspect; live/video may use a legacy 9:16 fallback only for tiny invalid viewports.
     */
    @Volatile
    var capturePurpose: CapturePurpose = CapturePurpose.STILL_PHOTO

    enum class CapturePurpose {
        STILL_PHOTO,
        LIVE_PUBLISH,
        VIDEO,
    }

    private val captureGeneration = AtomicInteger(0)

    fun captureGeneration(): Int = captureGeneration.get()

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

    /** Consecutive [android.graphics.SurfaceTexture.updateTexImage] failures. */
    private var oesUpdateFailures = 0


    private fun mix(a: Float, b: Float, t: Float): Float = a + (b - a) * t.coerceIn(0f, 1f)

    /** Same curve as GLSL smoothstep, for the strength maths above. */
    private fun smoothstep(edge0: Float, edge1: Float, x: Float): Float {
        val t = ((x - edge0) / (edge1 - edge0)).coerceIn(0f, 1f)
        return t * t * (3f - 2f * t)
    }

    private fun easeToward(current: Float, target: Float): Float {
        val next = current + (target - current) * BEAUTY_EASE
        return if (kotlin.math.abs(target - next) < 0.002f) target else next
    }

    private fun easeTowardSlow(current: Float, target: Float): Float {
        val rate = if (target > current) BRIGHTNESS_EASE_UP else BRIGHTNESS_EASE_DOWN
        val next = current + (target - current) * rate
        return if (kotlin.math.abs(target - next) < 0.0015f) target else next
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

    private var glErrorProbeCounter = 0

    /** How dark the scene is (1 = dim room, 0 = good light) — drives smooth/sharpen balance. */

    /**
     * Renders [draw] (the full beauty shader) at a reduced internal size and
     * returns the FBO texture holding the result, or 0 on failure.
     *
     * Recording at genuine 1080x1920 (see [ArCameraController]'s
     * startGlSurfaceRecording) meant this same per-pixel-expensive shader was
     * suddenly running on ~27% more pixels than the previous screen-cropped
     * recording size, which measured out as visible lag during recording.
     * Rendering the shader itself at a capped budget and blitting the result up
     * to the real encoder size in [presentToEncoder] keeps the OUTPUT file at
     * full 1080x1920 — same as [FaceWarpGlView]'s live-preview render cap, which
     * uses the same trade for the same reason (see its doc for the fetch-count
     * math this is working around).
     */
    private fun renderShaderAtBudget(draw: () -> Unit, fullW: Int, fullH: Int): Int {
        val pixels = fullW.toLong() * fullH.toLong()
        val scale = kotlin.math.sqrt(
            (ENCODER_RENDER_MAX_PIXELS.toDouble() / pixels.toDouble()).coerceAtMost(1.0),
        )
        val renderW = ((fullW * scale).toInt() and 1.inv()).coerceAtLeast(2)
        val renderH = ((fullH * scale).toInt() and 1.inv()).coerceAtLeast(2)

        if (!ensureEncoderFbo(renderW, renderH)) return 0
        val prevViewport = IntArray(4)
        GLES20.glGetIntegerv(GLES20.GL_VIEWPORT, prevViewport, 0)
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, encoderFboId)
        GLES20.glViewport(0, 0, renderW, renderH)
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        draw()
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
        GLES20.glViewport(prevViewport[0], prevViewport[1], prevViewport[2], prevViewport[3])
        return encoderFboTexId
    }

    private fun blitFullScreen(texId: Int) {
        GLES20.glUseProgram(blitProgram)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texId)
        GLES20.glUniform1i(blitUTexture, 0)

        GLES20.glEnableVertexAttribArray(blitAPosition)
        GLES20.glVertexAttribPointer(blitAPosition, 2, GLES20.GL_FLOAT, false, 16, vertexBuffer)

        GLES20.glEnableVertexAttribArray(blitATexCoord)
        vertexBuffer.position(2)
        GLES20.glVertexAttribPointer(blitATexCoord, 2, GLES20.GL_FLOAT, false, 16, vertexBuffer)
        vertexBuffer.position(0)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

        GLES20.glDisableVertexAttribArray(blitAPosition)
        GLES20.glDisableVertexAttribArray(blitATexCoord)
    }

    private fun presentToEncoder(draw: () -> Unit) {
        val androidSurface = encoderAndroidSurface ?: return
        if (!androidSurface.isValid) return
        val encW = encoderWidth
        val encH = encoderHeight
        if (encW < 2 || encH < 2) return

        val now = SystemClock.elapsedRealtime()
        if (now - lastEncoderSwapMs < encoderMinIntervalMs) return

        // Rendered before touching the encoder's own EGL surface — this is plain
        // FBO rendering, unrelated to which window surface happens to be current.
        val renderedTex = renderShaderAtBudget(draw, encW, encH)
        if (renderedTex == 0) return

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
            blitFullScreen(renderedTex)
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
    /** Last allocated CPU readback size — keyed by width AND height, not byte count. */
    private var captureReadW = 0
    private var captureReadH = 0
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
        oesUpdateFailures = 0
        texMatrixReady = false
        clearLastCapturedFrame()
    }

    /**
     * CPU readback scratch for [width]×[height] RGBA.
     *
     * Must NOT reuse a buffer just because `width*height*4` matches — 1280×720
     * and 720×1280 have the same byte count and that is what packed landscape
     * pixels into a portrait LiveKit track (horizontal static on viewers).
     */
    private fun ensureCaptureBuffers(width: Int, height: Int) {
        val w = width.coerceAtLeast(2)
        val h = height.coerceAtLeast(2)
        val rowBytes = w * 4
        val bytes = rowBytes * h
        if (captureReadW == w &&
            captureReadH == h &&
            captureReadBuf != null &&
            captureFlipBuf != null &&
            captureRowBuf != null &&
            captureRowBuf!!.size >= rowBytes
        ) {
            captureReadBuf!!.clear()
            captureFlipBuf!!.clear()
            return
        }
        captureReadBuf = ByteBuffer.allocateDirect(bytes).order(ByteOrder.nativeOrder())
        captureFlipBuf = ByteBuffer.allocateDirect(bytes).order(ByteOrder.nativeOrder())
        captureRowBuf = ByteArray(rowBytes)
        captureReadW = w
        captureReadH = h
    }

    private var captureScratchBitmap: Bitmap? = null
    private val captureViewport = IntArray(4)

    private var captureFboId = 0
    private var captureFboTexId = 0
    private var captureFboW = 0
    private var captureFboH = 0

    
    private var encoderFboId = 0
    private var encoderFboTexId = 0
    private var encoderFboW = 0
    private var encoderFboH = 0

   
    private var blitProgram = 0
    private var blitAPosition = 0
    private var blitATexCoord = 0
    private var blitUTexture = 0

   
    private var oesStartedMs = 0L

   
    @Volatile
    private var measuredSkinLuma = SKIN_LUMA_TARGET

   
    @Volatile
    private var measuredSceneLuma = 0.35f

   
    @Volatile
    private var measuredFaceFill = 0f


    fun updateSceneLuma(luma: Float) {
        if (luma.isNaN() || luma < 0f) return
        measuredSceneLuma = luma.coerceIn(0f, 1f)
    }

    fun updateSkinTone(luma: Float) {
        if (luma.isNaN() || luma <= 0f) return
        measuredSkinLuma = luma.coerceIn(0.02f, 1f)
    }

    fun updateFaceFill(fill: Float) {
        if (fill.isNaN() || fill < 0f) return
        val f = fill.coerceIn(0f, 1f)
        measuredFaceFill = fill.coerceIn(0f, 1f)
    }





   
    private fun ensureCaptureFbo(w: Int, h: Int): Boolean {
        if (captureFboId != 0 && captureFboW == w && captureFboH == h) return true
        releaseCaptureFbo()

       
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
    private var stillMakeupLocs: IntArray? = null
    private var stillTexId = 0
    private var stillFboId = 0
    private var stillFboTexId = 0
    private var stillFboW = 0
    private var stillFboH = 0

   
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
            stillMakeupLocs?.let { m ->
                bindMakeupUniforms(
                    m[0], m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9], m[10],
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
        stillMakeupLocs = intArrayOf(
            GLES20.glGetUniformLocation(p, "uMakeupLip"),
            GLES20.glGetUniformLocation(p, "uMakeupBlush"),
            GLES20.glGetUniformLocation(p, "uMakeupLiner"),
            GLES20.glGetUniformLocation(p, "uMakeupShadow"),
            GLES20.glGetUniformLocation(p, "uMakeupLipColor"),
            GLES20.glGetUniformLocation(p, "uMakeupBlushColor"),
            GLES20.glGetUniformLocation(p, "uMakeupLinerColor"),
            GLES20.glGetUniformLocation(p, "uMakeupShadowColor"),
            GLES20.glGetUniformLocation(p, "uBlushCheekL"),
            GLES20.glGetUniformLocation(p, "uBlushCheekR"),
            GLES20.glGetUniformLocation(p, "uBlushRadius"),
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
        stillFboW = w
        stillFboH = h
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
        stillFboW = 0
        stillFboH = 0
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

    private fun ensureEncoderFbo(w: Int, h: Int): Boolean {
        if (encoderFboId != 0 && encoderFboW == w && encoderFboH == h) return true
        releaseEncoderFbo()

        val maxTex = IntArray(1)
        GLES20.glGetIntegerv(GLES20.GL_MAX_TEXTURE_SIZE, maxTex, 0)
        val limit = maxTex[0].takeIf { it > 0 } ?: 2048
        if (w > limit || h > limit) {
            Log.e(TAG, "encoder render size ${w}x$h exceeds GL_MAX_TEXTURE_SIZE ($limit)")
            return false
        }

        val tex = IntArray(1)
        GLES20.glGenTextures(1, tex, 0)
        encoderFboTexId = tex[0]
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, encoderFboTexId)
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
        encoderFboId = fbo[0]
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, encoderFboId)
        GLES20.glFramebufferTexture2D(
            GLES20.GL_FRAMEBUFFER,
            GLES20.GL_COLOR_ATTACHMENT0,
            GLES20.GL_TEXTURE_2D,
            encoderFboTexId,
            0,
        )
        val status = GLES20.glCheckFramebufferStatus(GLES20.GL_FRAMEBUFFER)
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
        if (status != GLES20.GL_FRAMEBUFFER_COMPLETE) {
            Log.e(
                TAG,
                "encoder framebuffer incomplete (0x${Integer.toHexString(status)}) " +
                    "at ${w}x$h",
            )
            releaseEncoderFbo()
            return false
        }

        encoderFboW = w
        encoderFboH = h
        return true
    }

    private fun releaseEncoderFbo() {
        if (encoderFboId != 0) {
            GLES20.glDeleteFramebuffers(1, intArrayOf(encoderFboId), 0)
            encoderFboId = 0
        }
        if (encoderFboTexId != 0) {
            GLES20.glDeleteTextures(1, intArrayOf(encoderFboTexId), 0)
            encoderFboTexId = 0
        }
        encoderFboW = 0
        encoderFboH = 0
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

        val useFbo = redraw != null
        val readW: Int
        val readH: Int
        var usedLegacy916Fallback = false
        if (useFbo) {
            val maxEdge = captureMaxEdge.coerceAtLeast(2)
            val largest = maxOf(screenW, screenH)
            val previewAspect = screenW.toFloat() / screenH.toFloat()
            // Tiny PlatformView / virtual-display viewports (live publish) can be
            // ~320px wide — only then allow a 9:16 FBO. Never treat a valid tall
            // phone preview (e.g. 1080×2356, aspect ≈ 0.46) as broken from aspect alone.
            val tinyInvalidViewport = screenW < 480 || screenH < 480
            val allowLegacy916 =
                capturePurpose != CapturePurpose.STILL_PHOTO && tinyInvalidViewport
            if (allowLegacy916) {
                usedLegacy916Fallback = true
                readH = maxEdge and 1.inv()
                readW = ((readH * 9f / 16f).toInt() and 1.inv()).coerceAtLeast(2)
            } else {
                // Still photo (and healthy live/video viewports): scale resolution only;
                // preserve preview aspect so V3PresentPass framing matches shutter FOV.
                val s = maxEdge.toFloat() / largest
                readW = ((screenW * s).toInt() and 1.inv()).coerceAtLeast(2)
                readH = ((screenH * s).toInt() and 1.inv()).coerceAtLeast(2)
            }
            if (capturePurpose == CapturePurpose.STILL_PHOTO) {
                val captureAspect = readW.toFloat() / readH.toFloat()
                val wideZoom = if (ArCameraBridge.isFrontCamera) {
                    FRONT_WIDE_ZOOM_OUT
                } else {
                    BACK_WIDE_ZOOM_OUT
                }
                Log.i(
                    "V3_STILL_FRAME",
                    "preview=${screenW}x$screenH " +
                        "previewAspect=${"%.4f".format(previewAspect)} " +
                        "captureFbo=${readW}x$readH " +
                        "captureAspect=${"%.4f".format(captureAspect)} " +
                        "wideZoom=$wideZoom " +
                        "rotation=$cameraRotationDegrees " +
                        "mirror=$cameraFrontMirror " +
                        "fallback916=$usedLegacy916Fallback " +
                        "purpose=$capturePurpose",
                )
            }
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
        ensureCaptureBuffers(readW, readH)
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

        val maxEdge = captureMaxEdge.coerceAtLeast(2)
        val largest = maxOf(screenW, screenH)
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
            captureGeneration.incrementAndGet()
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
        cameraTransformationInfoReady = false
        captureScratchBitmap?.recycle()
        captureScratchBitmap = null
        captureReadBuf = null
        captureFlipBuf = null
        captureRowBuf = null
        captureReadW = 0
        captureReadH = 0
        releaseCaptureFbo()
        releaseEncoderFbo()
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
        diagnoseLivePath: Boolean = false,
    ) {
        val adj = LiveRetouchState.adjustments
        if (diagnoseLivePath) {
            val noseValid = kotlin.math.abs(adj.nose) >= 0.01f &&
                LiveRetouchState.noseRadius > 0.001f
            val shapeValid = kotlin.math.abs(adj.shape) >= 0.01f &&
                LiveRetouchState.jawRadius > 0.001f
            val eyesSelected = kotlin.math.abs(adj.eyes) >= 0.01f
            val eyeUniformsBound = locEyes >= 0 && locEyeL >= 0 && locEyeR >= 0 &&
                locEyeRadius >= 0
            val eyeBranchExecutes = eyesSelected && LiveRetouchState.eyeRadius > 0.001f &&
                eyeUniformsBound
            val mouthValid = kotlin.math.abs(adj.mouth) >= 0.01f &&
                LiveRetouchState.mouthRadius > 0.001f
            val toothValid = kotlin.math.abs(adj.tooth) >= 0.01f &&
                LiveRetouchState.toothVisibility > 0f
            val faceEffectActive = kotlin.math.abs(adj.nose) >= 0.01f ||
                kotlin.math.abs(adj.shape) >= 0.01f || eyesSelected ||
                kotlin.math.abs(adj.mouth) >= 0.01f || kotlin.math.abs(adj.tooth) >= 0.01f
            val rendererFaceValid = noseValid || shapeValid || eyeBranchExecutes ||
                mouthValid || toothValid
            val diagnosticState =
                (if (faceEffectActive) 1 else 0) or
                    (if (rendererFaceValid) 2 else 0) or
                    (if (eyesSelected) 4 else 0) or
                    (if (eyeBranchExecutes) 8 else 0)
            if (diagnosticState != lastFacePipelineDiagnosticState) {
                lastFacePipelineDiagnosticState = diagnosticState
                Log.i(
                    FACE_PIPELINE_TAG,
                    "Stages 10-11 renderer: path=OES faceEffectActive=$faceEffectActive " +
                        "faceValid=$rendererFaceValid eyesSlider=${adj.eyes} " +
                        "eyeStrength=${eyeWarpStrength(adj.eyes)} eyeRadius=${LiveRetouchState.eyeRadius} " +
                        "eyeUniformsBound=$eyeUniformsBound eyeBranchExecutes=$eyeBranchExecutes",
                )
            }
        }
        // Live color baseline applies whenever Magic/Beauty is On (both cameras).
        // Only suppress the baseline on front when Beauty is Off so selfies stay
        // ungraded until the user enables Beauty.
        val color = if (
            ArCameraBridge.isFrontCamera &&
            !LiveBeautyState.magicOn &&
            adj.matchesLiveBaselineColors()
        ) {
            LiveRetouchAdjustments.neutral().copy(
                nose = adj.nose,
                shape = adj.shape,
                eyes = adj.eyes,
                tooth = adj.tooth,
                mouth = adj.mouth,
            )
        } else if (LiveBeautyState.magicOn && !adj.hasColor) {
            // Beauty On with unset colors → apply natural beauty color grade.
            LiveRetouchAdjustments.liveBaseline().copy(
                nose = adj.nose,
                shape = adj.shape,
                eyes = adj.eyes,
                tooth = adj.tooth,
                mouth = adj.mouth,
            )
        } else {
            adj
        }
     
        val isFrontCamera = ArCameraBridge.isFrontCamera
        val personMixBase = if (isFrontCamera) {
            0f
        } else {
            smoothstep(0.30f, 0.55f, smoothedBackPersonWeight.coerceIn(0f, 1f))
        }
        // Back camera: softer contrast/sat/WB; lighting stays full strength.
        val backGrade = if (!isFrontCamera && LiveBeautyState.magicOn) {
            BACK_BEAUTY_GRADE_SCALE
        } else {
            1f
        }
        val backMorph = if (!isFrontCamera && LiveBeautyState.magicOn) {
            BACK_BEAUTY_MORPH_SCALE
        } else {
            1f
        }
        
        fun fieldMix(
            value: Float,
            default: Float,
            backTarget: Float,
            frontTarget: Float,
            scale: Float = backGrade,
        ): Float {
            val untouched = kotlin.math.abs(value - default) < 0.005f
            val raw = if (!untouched) {
                value
            } else if (isFrontCamera) {
                frontTarget
            } else {
                mix(value, backTarget, personMixBase)
            }
            return raw * scale
        }
        if (locSaturation >= 0) {
            GLES20.glUniform1f(
                locSaturation,
                fieldMix(
                    color.saturation,
                    LiveRetouchAdjustments.DEFAULT_SATURATION,
                    LiveRetouchAdjustments.DEFAULT_SATURATION,
                    LiveRetouchAdjustments.DEFAULT_SATURATION,
                ),
            )
        }
        if (locBrightness >= 0) {
            GLES20.glUniform1f(
                locBrightness,
                fieldMix(
                    color.brightness,
                    LiveRetouchAdjustments.DEFAULT_BRIGHTNESS,
                    0.08f,
                    LiveRetouchAdjustments.DEFAULT_BRIGHTNESS,
                    scale = 1f,
                ),
            )
        }
        if (locContrast >= 0) {
            GLES20.glUniform1f(
                locContrast,
                fieldMix(
                    color.contrast,
                    LiveRetouchAdjustments.DEFAULT_CONTRAST,
                    LiveRetouchAdjustments.DEFAULT_CONTRAST,
                    LiveRetouchAdjustments.DEFAULT_CONTRAST,
                ),
            )
        }
        if (locExposure >= 0) {
            GLES20.glUniform1f(
                locExposure,
                fieldMix(
                    color.exposure,
                    LiveRetouchAdjustments.DEFAULT_EXPOSURE,
                    0.06f,
                    LiveRetouchAdjustments.DEFAULT_EXPOSURE,
                    scale = 1f,
                ),
            )
        }
        if (locWhiteBalance >= 0) {
            GLES20.glUniform1f(
                locWhiteBalance,
                fieldMix(
                    color.whiteBalance,
                    LiveRetouchAdjustments.DEFAULT_WHITE_BALANCE,
                    LiveRetouchAdjustments.DEFAULT_WHITE_BALANCE,
                    LiveRetouchAdjustments.DEFAULT_WHITE_BALANCE,
                ),
            )
        }
        if (locHighlights >= 0) {
            GLES20.glUniform1f(
                locHighlights,
                fieldMix(
                    color.highlights,
                    LiveRetouchAdjustments.DEFAULT_HIGHLIGHTS,
                    -0.06f,
                    LiveRetouchAdjustments.DEFAULT_HIGHLIGHTS,
                    scale = 1f,
                ),
            )
        }
        if (locShadows >= 0) {
            GLES20.glUniform1f(
                locShadows,
                fieldMix(
                    color.shadows,
                    LiveRetouchAdjustments.DEFAULT_SHADOWS,
                    -0.12f,
                    LiveRetouchAdjustments.DEFAULT_SHADOWS,
                    scale = 1f,
                ),
            )
        }
        if (locNose >= 0) GLES20.glUniform1f(locNose, color.nose * backMorph)
        if (locWingL >= 0) {
            GLES20.glUniform2fv(locWingL, 1, LiveRetouchState.noseWingL, 0)
        }
        if (locWingR >= 0) {
            GLES20.glUniform2fv(locWingR, 1, LiveRetouchState.noseWingR, 0)
        }
        if (locRadius >= 0) GLES20.glUniform1f(locRadius, LiveRetouchState.noseRadius)
        if (locShape >= 0) GLES20.glUniform1f(locShape, adj.shape * backMorph)
        if (locJawL >= 0) {
            GLES20.glUniform2fv(locJawL, 1, LiveRetouchState.jawWingL, 0)
        }
        if (locJawR >= 0) {
            GLES20.glUniform2fv(locJawR, 1, LiveRetouchState.jawWingR, 0)
        }
        if (locJawRadius >= 0) GLES20.glUniform1f(locJawRadius, LiveRetouchState.jawRadius)
        if (locEyes >= 0) GLES20.glUniform1f(locEyes, eyeWarpStrength(adj.eyes) * backMorph)
        if (locEyeL >= 0) {
            GLES20.glUniform2fv(locEyeL, 1, LiveRetouchState.eyeL, 0)
        }
        if (locEyeR >= 0) {
            GLES20.glUniform2fv(locEyeR, 1, LiveRetouchState.eyeR, 0)
        }
        if (locEyeRadius >= 0) GLES20.glUniform1f(locEyeRadius, LiveRetouchState.eyeRadius)
        if (locMouth >= 0) GLES20.glUniform1f(locMouth, adj.mouth * backMorph)
        if (locMouthCenter >= 0) {
            GLES20.glUniform2fv(locMouthCenter, 1, LiveRetouchState.mouthCenter, 0)
        }
        if (locMouthRadius >= 0) GLES20.glUniform1f(locMouthRadius, LiveRetouchState.mouthRadius)
        if (locTooth >= 0) {
            
            GLES20.glUniform1f(
                locTooth,
                adj.tooth * LiveRetouchState.toothVisibility * backMorph,
            )
        }
        if (locToothRegion >= 0) {
            GLES20.glUniform4fv(locToothRegion, 1, LiveRetouchState.toothRegion, 0)
        }
    }

    private fun bindMakeupUniforms(
        locLip: Int,
        locBlush: Int,
        locLiner: Int,
        locShadow: Int,
        locLipColor: Int,
        locBlushColor: Int,
        locLinerColor: Int,
        locShadowColor: Int,
        locCheekL: Int,
        locCheekR: Int,
        locBlushRadius: Int,
    ) {
        val adj = LiveBeautyState.adjustments
        if (locLip >= 0) GLES20.glUniform1f(locLip, adj.lipStrength)
        if (locBlush >= 0) GLES20.glUniform1f(locBlush, adj.blush)
        if (locLiner >= 0) GLES20.glUniform1f(locLiner, adj.eyeliner)
        if (locShadow >= 0) GLES20.glUniform1f(locShadow, adj.eyeshadow)
        if (locLipColor >= 0) {
            GLES20.glUniform3fv(locLipColor, 1, adj.lipTintColor, 0)
        }
        if (locBlushColor >= 0) {
            GLES20.glUniform3fv(locBlushColor, 1, adj.blushColor, 0)
        }
        if (locLinerColor >= 0) {
            GLES20.glUniform3fv(locLinerColor, 1, adj.eyelinerColor, 0)
        }
        if (locShadowColor >= 0) {
            GLES20.glUniform3fv(locShadowColor, 1, adj.eyeshadowColor, 0)
        }
        if (locCheekL >= 0) {
            GLES20.glUniform2fv(locCheekL, 1, LiveRetouchState.blushCheekL, 0)
        }
        if (locCheekR >= 0) {
            GLES20.glUniform2fv(locCheekR, 1, LiveRetouchState.blushCheekR, 0)
        }
        if (locBlushRadius >= 0) {
            GLES20.glUniform1f(locBlushRadius, LiveRetouchState.blushRadius)
        }
        // Extra TikTok makeup floats — resolve on the active program each frame.
        val prog = IntArray(1)
        GLES20.glGetIntegerv(GLES20.GL_CURRENT_PROGRAM, prog, 0)
        val p = prog[0]
        if (p != 0) {
            fun setF(name: String, value: Float) {
                val loc = GLES20.glGetUniformLocation(p, name)
                if (loc >= 0) GLES20.glUniform1f(loc, value)
            }
            setF("uMakeupFoundation", adj.foundation)
            setF("uMakeupContour", adj.contour)
            setF("uMakeupUnderEye", adj.underEye)
            setF("uMakeupBrightEye", adj.brightenEye)
        }
    }

    private fun eyeWarpStrength(slider: Float): Float {
        // Stronger TikTok-like eye open range (±1.5 → ~0.62 peak).
        val value = slider.coerceIn(-1.5f, 1.5f)
        return 0.55f * kotlin.math.sign(value) * kotlin.math.abs(value).pow(1.25f)
    }

    companion object {
       
        private const val STILL_MAX_EDGE = 4096

       
        private const val SHARPEN_STRENGTH = 0.0f

        private const val BEAUTY_EASE = 0.18f
       
        private const val BRIGHTNESS_EASE_UP = 0.20f
        private const val BRIGHTNESS_EASE_DOWN = 0.04f
        private const val SCENE_BRIGHTNESS_EASE = 0.035f

        private const val SCENE_DARK = 0.12f
        private const val SCENE_BRIGHT = 0.42f

        
        private const val SKIN_MASK_GRACE_MS = 2_500L

        
        private const val AUTO_LIFT_MAX = 0.42f

        private const val BLEMISH_OF_SMOOTH = 0.28f

        private const val NOISE_FLOOR_BRIGHT = 0.008f
        private const val NOISE_FLOOR_DARK = 0.032f

        /** Target skin luminance for auto-lift (TikTok-open midtones). */
        const val SKIN_LUMA_TARGET = 0.64f

        
        private const val BACK_PERSON_SMOOTH_NORMAL = 0.20f

        /** Soft cap — back beauty stays light, not plastic. */
        private const val BACK_PERSON_SMOOTH_MAX = 0.38f

        
        private const val FRONT_SMOOTH_NORMAL = 0.80f
        private const val FRONT_SMOOTH_MAX = 0.80f

        /** Scales retouch color + morph strength on the rear camera (Beauty On). */
        private const val BACK_BEAUTY_GRADE_SCALE = 0.55f
        private const val BACK_BEAUTY_MORPH_SCALE = 0.50f

        
        private const val ENCODER_RENDER_MAX_PIXELS = 1_200_000L

        private const val TAG = "FaceWarpRenderer"
        private const val FACE_PIPELINE_TAG = "ArFacePipeline"

        /** Consecutive camera-texture update failures before giving up on GL. */
        private const val MAX_OES_UPDATE_FAILURES = 30

        /** glGetError forces a sync, so only probe every Nth frame. */
        private const val GL_ERROR_PROBE_EVERY = 60

       
        private const val TEMPORAL_STRENGTH = 0.48f
        // Below plain temporal so Magic spatial cleanup + frames do not wax the face.
        private const val MAGIC_TEMPORAL_STRENGTH = 0.22f

    
        private const val FRONT_WIDE_ZOOM_OUT = 2.0f

        /** Back camera — TikTok-like wide (near full FIT_CENTER). */
        private const val BACK_WIDE_ZOOM_OUT = 2.0f

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

       
        private const val BLIT_VERTEX_SHADER = VERTEX_SHADER

        private const val BLIT_FRAGMENT_SHADER = """
            precision mediump float;
            varying vec2 vTexCoord;
            uniform sampler2D uTexture;
            void main() {
                // FBO-attached textures read back Y-flipped relative to a normal
                // window-surface draw — encoder path renders into encoderFboTexId
                // with the same UVs used for on-screen output, so this flip is
                // only needed here when that texture is sampled back out.
                gl_FragColor = texture2D(uTexture, vec2(vTexCoord.x, 1.0 - vTexCoord.y));
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
            // Back-camera person look (0 = empty grade, 1 = person soften/bright).
            uniform float uBackPersonWeight;
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
            uniform float uMakeupLip;
            uniform float uMakeupBlush;
            uniform float uMakeupLiner;
            uniform float uMakeupShadow;
            uniform float uMakeupFoundation;
            uniform float uMakeupContour;
            uniform float uMakeupUnderEye;
            uniform float uMakeupBrightEye;
            uniform vec3 uMakeupLipColor;
            uniform vec3 uMakeupBlushColor;
            uniform vec3 uMakeupLinerColor;
            uniform vec3 uMakeupShadowColor;
            uniform vec2 uBlushCheekL;
            uniform vec2 uBlushCheekR;
            uniform float uBlushRadius;
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

            // skinW / personBrightConf / lightScale are accepted for call-site
            // compatibility (front camera and stills still pass a skin
            // confidence in) but are otherwise unused now — the back-camera
            // person case is handled entirely by bindRetouchUniforms feeding
            // this function neutral-grade + brightness≈0.70 values, the same
            // uRetouchBrightness path every other case already uses. No
            // separate per-pixel person branch here anymore.
            vec3 applyRetouchSkinBrightness(
                vec3 col,
                float skinW,
                float personBrightConf,
                float lightScale
            ) {
                float w = clamp(skinW, 0.0, 1.0);
                float amount = uRetouchBrightness * w;
                if (abs(amount) < 0.001) return col;
                float lum = retouchLuma(col);
                vec3 chroma = col - lum;
                lum *= 1.0 + amount * 0.24;
                return clamp(lum + chroma, 0.0, 1.0);
            }

            // Full-frame grade. Back-camera person case: bindRetouchUniforms
            // already blends the retouch values (saturation/contrast/
            // exposure/whiteBalance/highlights/shadows toward 0, brightness
            // toward ~0.70) by personMix before they ever reach this
            // uniform, so this function does not need its own per-pixel
            // person branch — it runs the same for every case.
            vec3 applyRetouchColor(vec3 col, float skinW) {
                float ev = uRetouchExposure;
                if (abs(ev) > 0.01) {
                    float lum = max(retouchLuma(col), 0.0001);
                    float exponent = pow(2.0, -ev * 0.55);
                    float exposedLum = pow(clamp(lum, 0.0, 1.0), exponent);
                    col = clamp(col * (exposedLum / lum), 0.0, 1.0);
                }
                float wb = uRetouchWhiteBalance;
                if (abs(wb) > 0.01) {
                    float k = wb * 0.12;
                    col.r *= (1.0 + k);
                    col.b *= (1.0 - k);
                }
                float c = uRetouchContrast;
                if (abs(c) > 0.01) {
                    if (c > 0.0) {
                        float alpha = 1.0 + c * 0.24;
                        col = (col - 0.5) * alpha + 0.5;
                    } else {
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
                    float lum = max(retouchLuma(col), 0.0001);
                    float shadowW = 1.0 - smoothstep(0.30, 0.72, lum);
                    float exponent = sh > 0.0
                        ? 1.0 - sh * 0.28
                        : 1.0 + (-sh) * 0.32;
                    float curvedLum = pow(clamp(lum, 0.0, 1.0), exponent);
                    float resultLum = mix(lum, curvedLum, shadowW);
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
                uv = retouchEyeScale(uv, uEyeL, uEyeRadius, uRetouchEyes);
                uv = retouchEyeScale(uv, uEyeR, uEyeRadius, uRetouchEyes);
                return uv;
            }

            // Mouth: + fuller & more open lips, − thinner. Soft pad, vertical-biased.
            vec2 applyRetouchMouthWarp(vec2 uv) {
                if (abs(uRetouchMouth) < 0.01 || uMouthRadius <= 0.001) return uv;
                float halfW = uMouthRadius;
                float halfH = halfW * 0.62;
                vec2 d = uv - uMouthCenter;
                float ax = abs(d.x) / max(halfW, 0.001);
                float ay = abs(d.y) / max(halfH, 0.001);
                if (ax >= 1.0 || ay >= 1.0) return uv;
                float wx = 1.0 - smoothstep(0.40, 1.0, ax);
                float wy = 1.0 - smoothstep(0.28, 1.0, ay);
                float w = wx * wy;
                if (w < 0.01) return uv;
                w = w * w * (3.0 - 2.0 * w);
                // Stronger TikTok-like lip plump / open (was 0.14).
                float amount = 0.32 * uRetouchMouth;
                // Vertical open stronger; mild width so lips stay natural.
                float sx = 1.0 - amount * w * 0.35;
                float sy = 1.0 - amount * w * 1.25;
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
                float region = 1.0 - smoothstep(0.72, 1.0, r2);

                float hi = max(col.r, max(col.g, col.b));
                float lo = min(col.r, min(col.g, col.b));
                float luma = dot(col, vec3(0.299, 0.587, 0.114));
                float saturation = (hi - lo) / max(hi, 0.001);
                float redExcess = max(0.0, col.r - max(col.g, col.b));
                float greenToRed = col.g / max(col.r, 0.001);
                float blueToGreen = col.b / max(col.g, 0.001);
                // Enamel is substantially brighter than tongue/throat, with
                // green close to red and enough blue even on warm teeth.
                float tooth = smoothstep(0.20, 0.44, luma) *
                    (1.0 - smoothstep(0.38, 0.62, saturation)) *
                    smoothstep(0.62, 0.82, greenToRed) *
                    smoothstep(0.40, 0.62, blueToGreen) *
                    (1.0 - smoothstep(0.09, 0.22, redExcess)) *
                    region;
                if (tooth < 0.001) return col;

                if (uRetouchTooth > 0.0) {
                    float k = uRetouchTooth * tooth;
                    // Cleaner / brighter enamel (was 0.62 lift).
                    float lifted = luma + 0.78 * k * (1.0 - luma);
                    vec3 neutral = vec3(clamp(lifted, 0.0, 1.0));
                    return clamp(mix(col, neutral, min(1.0, 0.98 * k)), 0.0, 1.0);
                }

                float k = (-uRetouchTooth) * tooth;
                vec3 dull = col * vec3(0.88, 0.80, 0.66);
                dull *= 1.0 - 0.28 * k;
                return clamp(mix(col, dull, min(1.0, 0.90 * k)), 0.0, 1.0);
            }

            // TikTok-style makeup: lipstick / foundation / shadow / contour /
            // blush / under-eye / brighten eye (+ optional liner).
            float makeupSoftCircle(vec2 uv, vec2 c, float r) {
                float d = length(uv - c) / max(r, 0.001);
                return 1.0 - smoothstep(0.45, 1.15, d);
            }

            float makeupLidPad(vec2 uv, vec2 c, float r) {
                vec2 d = uv - (c + vec2(0.0, -r * 0.35));
                float ax = abs(d.x) / max(r * 1.15, 0.001);
                float ay = abs(d.y) / max(r * 0.85, 0.001);
                return 1.0 - smoothstep(0.40, 1.05, max(ax, ay));
            }

            float makeupEyeRing(vec2 uv, vec2 c, float r) {
                float outer = length(uv - c) / max(r * 1.20, 0.001);
                float inner = length(uv - c) / max(r * 0.78, 0.001);
                float o = 1.0 - smoothstep(0.75, 1.15, outer);
                float i = 1.0 - smoothstep(0.55, 1.05, inner);
                return clamp(o - i, 0.0, 1.0);
            }

            float makeupUnderEyePad(vec2 uv, vec2 c, float r) {
                vec2 d = uv - (c + vec2(0.0, r * 0.72));
                float ax = abs(d.x) / max(r * 1.25, 0.001);
                float ay = abs(d.y) / max(r * 0.70, 0.001);
                return 1.0 - smoothstep(0.35, 1.05, max(ax, ay));
            }

            float makeupFaceOval(vec2 uv) {
                vec2 midEyes = (uEyeL + uEyeR) * 0.5;
                vec2 midCheeks = (uBlushCheekL + uBlushCheekR) * 0.5;
                vec2 faceC = mix(midEyes, uMouthCenter, 0.42);
                faceC = mix(faceC, midCheeks, 0.35);
                float rx = max(length(uBlushCheekR - uBlushCheekL) * 0.62, uBlushRadius * 2.2);
                float ry = max(rx * 1.22, distance(midEyes, uMouthCenter) * 1.35);
                vec2 d = (uv - faceC) / max(vec2(rx, ry), vec2(0.001));
                float r2 = dot(d, d);
                return 1.0 - smoothstep(0.55, 1.12, r2);
            }

            vec3 applyMakeupColor(vec3 col, vec2 uv) {
                if (uMakeupLip < 0.01 && uMakeupBlush < 0.01 &&
                    uMakeupLiner < 0.01 && uMakeupShadow < 0.01 &&
                    uMakeupFoundation < 0.01 && uMakeupContour < 0.01 &&
                    uMakeupUnderEye < 0.01 && uMakeupBrightEye < 0.01) {
                    return col;
                }
                vec3 outC = col;
                float skin = retouchSkinConfidence(col);

                // Foundation — even tone over face oval (skin-gated).
                if (uMakeupFoundation > 0.01 && uBlushRadius > 0.001) {
                    float face = makeupFaceOval(uv) * mix(0.35, 1.0, skin);
                    float k = uMakeupFoundation * face * 0.62;
                    vec3 even = mix(outC, vec3(dot(outC, vec3(0.33))), 0.28);
                    even = mix(even, outC * vec3(1.04, 1.01, 0.98), 0.55);
                    outC = mix(outC, even, k);
                }

                // Contour — soft hollows under outer cheeks + mild nose sides.
                if (uMakeupContour > 0.01 && uBlushRadius > 0.001) {
                    vec2 mid = (uBlushCheekL + uBlushCheekR) * 0.5;
                    vec2 hollowL = mix(uBlushCheekL, mid, -0.18) + vec2(0.0, uBlushRadius * 0.55);
                    vec2 hollowR = mix(uBlushCheekR, mid, -0.18) + vec2(0.0, uBlushRadius * 0.55);
                    float hollow = max(
                        makeupSoftCircle(uv, hollowL, uBlushRadius * 1.05),
                        makeupSoftCircle(uv, hollowR, uBlushRadius * 1.05)
                    );
                    float noseSide = 0.0;
                    if (uNoseRadius > 0.001) {
                        noseSide = max(
                            makeupSoftCircle(uv, uNoseWingL, uNoseRadius * 0.55),
                            makeupSoftCircle(uv, uNoseWingR, uNoseRadius * 0.55)
                        );
                    }
                    float k = uMakeupContour * max(hollow, noseSide * 0.65) * 0.72;
                    vec3 shade = outC * vec3(0.68, 0.58, 0.54);
                    outC = mix(outC, shade, k);
                }

                if (uMakeupLip > 0.01 && uMouthRadius > 0.001) {
                    // Tight lip ellipse only (not cheeks / chin / teeth).
                    vec2 d = uv - uMouthCenter;
                    float halfW = uMouthRadius * 0.88;
                    float halfH = uMouthRadius * 0.38;
                    float ax = abs(d.x) / max(halfW, 0.001);
                    float ay = abs(d.y) / max(halfH, 0.001);
                    float ell = length(vec2(ax, ay));
                    float lipShape = 1.0 - smoothstep(0.72, 1.0, ell);
                    lipShape = lipShape * lipShape;
                    // Punch out the open inner mouth so teeth stay unpainted.
                    float inner = 0.0;
                    if (uToothRegion.z > 0.0005 && uToothRegion.w > 0.0005) {
                        vec2 ti = (uv - uToothRegion.xy) / uToothRegion.zw;
                        float r2 = dot(ti, ti);
                        inner = 1.0 - smoothstep(0.50, 1.0, r2);
                    }
                    // Prefer real lip chroma; keep a soft floor so pale lips still tint.
                    float hi = max(outC.r, max(outC.g, outC.b));
                    float lo = min(outC.r, min(outC.g, outC.b));
                    float sat = (hi - lo) / max(hi, 0.001);
                    float redBias = outC.r - max(outC.g, outC.b);
                    float lipCol = clamp(
                        smoothstep(0.010, 0.08, redBias) * smoothstep(0.08, 0.28, sat),
                        0.0,
                        1.0
                    );
                    float lip = lipShape * (1.0 - inner) * mix(0.45, 1.0, lipCol);
                    float k = uMakeupLip * lip;
                    // Rich saturated lip color (brilliant, not flat matte).
                    vec3 vivid = clamp(uMakeupLipColor * 1.18, 0.0, 1.0);
                    vec3 tinted = mix(outC, vivid, 0.88);
                    float tl = dot(tinted, vec3(0.299, 0.587, 0.114));
                    tinted = clamp(mix(vec3(tl), tinted, 1.35) * 1.08, 0.0, 1.0);
                    outC = mix(outC, tinted, k * 0.92);
                    // Gloss / wet highlight along the lip center for brilliance.
                    float glossBand = exp(-pow((ay - 0.08) / 0.28, 2.0) * 2.4) *
                        (1.0 - smoothstep(0.35, 0.95, ax));
                    float gloss = glossBand * lip * uMakeupLip * 0.55;
                    outC = mix(outC, vec3(1.0), gloss * 0.42);
                    outC = clamp(outC + vivid * gloss * 0.18, 0.0, 1.0);
                }
                if (uMakeupBlush > 0.01 && uBlushRadius > 0.001) {
                    float cheek = max(
                        makeupSoftCircle(uv, uBlushCheekL, uBlushRadius),
                        makeupSoftCircle(uv, uBlushCheekR, uBlushRadius)
                    );
                    float k = uMakeupBlush * cheek * 0.72;
                    outC = mix(outC, mix(outC, uMakeupBlushColor, 0.70), k);
                }
                if (uMakeupShadow > 0.01 && uEyeRadius > 0.001) {
                    float sh = max(
                        makeupLidPad(uv, uEyeL, uEyeRadius),
                        makeupLidPad(uv, uEyeR, uEyeRadius)
                    );
                    float k = uMakeupShadow * sh * 0.68;
                    outC = mix(outC, mix(outC, uMakeupShadowColor, 0.78), k);
                }
                if (uMakeupLiner > 0.01 && uEyeRadius > 0.001) {
                    float ln = max(
                        makeupEyeRing(uv, uEyeL, uEyeRadius),
                        makeupEyeRing(uv, uEyeR, uEyeRadius)
                    );
                    float k = uMakeupLiner * ln * 0.90;
                    outC = mix(outC, uMakeupLinerColor, k);
                }

                // Under-eye — soft conceal / brighten bags.
                if (uMakeupUnderEye > 0.01 && uEyeRadius > 0.001) {
                    float bag = max(
                        makeupUnderEyePad(uv, uEyeL, uEyeRadius),
                        makeupUnderEyePad(uv, uEyeR, uEyeRadius)
                    );
                    float k = uMakeupUnderEye * bag * 0.75;
                    vec3 lift = mix(outC, vec3(1.0), 0.22);
                    lift = mix(lift, outC * vec3(1.12, 1.08, 1.04), 0.55);
                    outC = mix(outC, lift, k);
                }

                // Brighten eye — open / lighten the eye socket whites.
                if (uMakeupBrightEye > 0.01 && uEyeRadius > 0.001) {
                    float el = makeupSoftCircle(uv, uEyeL, uEyeRadius * 0.92);
                    float er = makeupSoftCircle(uv, uEyeR, uEyeRadius * 0.92);
                    float eye = max(el, er);
                    float k = uMakeupBrightEye * eye * 0.58;
                    outC = mix(outC, clamp(outC * vec3(1.18, 1.15, 1.12) + 0.05, 0.0, 1.0), k);
                }
                return clamp(outC, 0.0, 1.0);
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
         * Two things from the legacy live OES preview shader are intentionally absent:
         * temporal denoise (meaningless for a single frame — there is no
         * history), and the landmark skin mask. The mask is built in preview
         * framing; a full-sensor still is a wider crop, so the mask would not
         * line up. The colour-based skin gate is framing-independent and is what
         * the preview shader itself falls back to when no mask is available.
         */
        private val STILL_FRAGMENT_SHADER = """
            precision highp float;
            varying vec2 vTexCoord;
            uniform sampler2D uTexture;
            uniform vec2 uTexelStep;
            uniform float uSmoothStrength;
            uniform float uWhiten;
            uniform float uBrighten;
            // Same always-on polish as the live OES preview — keeps stills from
            // looking darker/duller than what the user just saw in the viewfinder.
            const float BASE_LIFT = 0.04;
            const float BASE_CONTRAST = 0.01;
            const float BASE_COOL = 0.0;
            const float SKIN_COOL = 0.0;
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

            // Same feathering as the live OES preview — averages the colour
            // mask over a small neighbourhood so brighten ramps in across a
            // hairline/jaw instead of cutting hard.
            float featheredSkinConf(vec2 uv, vec3 center) {
                vec2 t = uTexelStep * (0.020 / max(uTexelStep.y, 0.00001));
                float sum = skinConfidence(center);
                sum += skinConfidence(texture2D(uTexture, uv + vec2( t.x,  0.0)).rgb);
                sum += skinConfidence(texture2D(uTexture, uv + vec2(-t.x,  0.0)).rgb);
                sum += skinConfidence(texture2D(uTexture, uv + vec2( 0.0,  t.y)).rgb);
                sum += skinConfidence(texture2D(uTexture, uv + vec2( 0.0, -t.y)).rgb);
                return sum * 0.2;
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

            // Still has no temporal history — spatial grain clean only.
            // Edge-aware chroma + micro-luma; stronger in shadows.
            vec3 stillGrainClean(vec2 uv, vec3 center) {
                const float NOISE_FLOOR = 0.022;
                vec2 t = uTexelStep * 2.0;
                float cLum = dot(center, vec3(0.299, 0.587, 0.114));
                vec3 cChroma = center - cLum;
                vec3 chromaSum = cChroma;
                float lumSum = cLum;
                float wSum = 1.0;
                vec2 offs[8];
                offs[0] = vec2( t.x,  0.0);
                offs[1] = vec2(-t.x,  0.0);
                offs[2] = vec2( 0.0,  t.y);
                offs[3] = vec2( 0.0, -t.y);
                offs[4] = vec2( t.x,  t.y);
                offs[5] = vec2(-t.x,  t.y);
                offs[6] = vec2( t.x, -t.y);
                offs[7] = vec2(-t.x, -t.y);
                for (int i = 0; i < 8; i++) {
                    vec3 s = texture2D(uTexture, uv + offs[i]).rgb;
                    float sLum = dot(s, vec3(0.299, 0.587, 0.114));
                    float dl = sLum - cLum;
                    float w = exp(-dl * dl * 200.0);
                    chromaSum += (s - sLum) * w;
                    lumSum += sLum * w;
                    wSum += w;
                }
                float invW = 1.0 / max(wSum, 0.001);
                float avgLum = lumSum * invW;
                vec3 cleanChroma = chromaSum * invW;
                float darkAmt = mix(0.90, 0.35, smoothstep(0.07, 0.55, cLum));
                float grain = cLum - avgLum;
                float isGrain = 1.0 - smoothstep(
                    NOISE_FLOOR * 0.5,
                    NOISE_FLOOR * 3.2,
                    abs(grain)
                );
                float cleanLum = mix(cLum, avgLum, isGrain * darkAmt);
                return clamp(
                    cleanLum + mix(cChroma, cleanChroma, darkAmt),
                    0.0,
                    1.0
                );
            }

            void main() {
                vec3 col = texture2D(uTexture, vTexCoord).rgb;
                col = stillGrainClean(vTexCoord, col);
                // Computed once and reused below instead of twice per pixel.
                float feathSkinConf = featheredSkinConf(vTexCoord, col);
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
                        float brightConf = feathSkinConf;
                        float personMixEarly = smoothstep(
                            0.30, 0.55, clamp(uBackPersonWeight, 0.0, 1.0)
                        );
                        float gain = 1.0 + uBrighten * brightConf * 0.45 *
                            (1.0 - personMixEarly);
                        lum *= gain;
                        chroma *= gain;
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
                float feathBrightConfStill = feathSkinConf;
                col = applyRetouchColor(col, feathBrightConfStill);
                col = applyRetouchSkinBrightness(
                    col, toneConf, feathBrightConfStill, 1.0
                );
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
                col = applyMakeupColor(col, vTexCoord);
                gl_FragColor = vec4(col, 1.0);
            }
        """


        private val FRAGMENT_SHADER = """
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
            // Needed by applyRetouchSkinBrightness (RETOUCH_FUNCTIONS) even
            // though this program never binds it — an unbound uniform
            // defaults to 0, so the person-brighten branch there simply
            // never fires here. Missing the declaration entirely made the
            // whole shader fail to compile/link (this is the program this
            // filter/front path runs on), which is why every retouch effect
            // stopped applying.
            uniform float uBrighten;
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
                float stillSkinW = retouchSkinConfidence(col);
                col = applyRetouchColor(col, stillSkinW);
                col = applyRetouchSkinBrightness(col, stillSkinW, stillSkinW, 1.0);
                col = applyRetouchToothColor(col, tc);
                col = applyMakeupColor(col, tc);

                gl_FragColor = vec4(col, sourceColor.a);
            }
        """
    }
}
