package com.dubai.bimobondapp.camera_engine

import android.graphics.SurfaceTexture
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLExt
import android.opengl.EGLSurface
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.os.Handler
import android.os.HandlerThread
import android.os.SystemClock
import android.util.Log
import android.view.Surface
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Phase 2–9 GPU preview + optional hardware encoder present:
 * CameraX → OES → ColorFilter → Beauty → FaceWarp → Makeup → stickers → debug
 * → Flutter Texture (+ MediaCodec Surface when recording).
 *
 * Intermediate passes ping-pong between FBOs. Makeup uses landmark region masks + GPU blend.
 * Recording never uses Bitmap — same GL compose is presented to the encoder Surface.
 */
class GpuPreviewPipeline(
    private val flutterSurfaceTexture: SurfaceTexture,
    private val outputWidth: Int,
    private val outputHeight: Int,
) {
    companion object {
        private const val TAG = "GpuPreviewPipeline"

        private const val PASS_BEAUTY = 1
        private const val PASS_WARP = 2
        private const val PASS_MAKEUP = 3

        /** EGL_RECORDABLE_ANDROID — required for MediaCodec window surfaces on many devices. */
        private const val EGL_RECORDABLE_ANDROID = 0x3142

        private fun linkProgram(vertexSrc: String, fragmentSrc: String): Int {
            val vs = compileShader(GLES20.GL_VERTEX_SHADER, vertexSrc)
            val fs = compileShader(GLES20.GL_FRAGMENT_SHADER, fragmentSrc)
            val program = GLES20.glCreateProgram()
            GLES20.glAttachShader(program, vs)
            GLES20.glAttachShader(program, fs)
            GLES20.glLinkProgram(program)
            GLES20.glDeleteShader(vs)
            GLES20.glDeleteShader(fs)
            val link = IntArray(1)
            GLES20.glGetProgramiv(program, GLES20.GL_LINK_STATUS, link, 0)
            if (link[0] == 0) {
                val log = GLES20.glGetProgramInfoLog(program)
                GLES20.glDeleteProgram(program)
                throw IllegalStateException("program link failed: $log")
            }
            return program
        }

        private fun compileShader(type: Int, source: String): Int {
            val shader = GLES20.glCreateShader(type)
            GLES20.glShaderSource(shader, source)
            GLES20.glCompileShader(shader)
            val compiled = IntArray(1)
            GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, compiled, 0)
            if (compiled[0] == 0) {
                val log = GLES20.glGetShaderInfoLog(shader)
                GLES20.glDeleteShader(shader)
                throw IllegalStateException("shader compile failed: $log")
            }
            return shader
        }
    }

    private val colorFilter = ColorFilterEffect()
    val filterEffect: FilterEffect get() = colorFilter

    private val beautyEngine = BeautyEngine()
    private val warpEngine = FaceWarpEngine()
    private val makeupEngine = MakeupEngine()
    private val processFboA = GlFramebuffer()
    private val processFboB = GlFramebuffer()

    private val effectManager = EffectManager()
    private val landmarkOverlay = LandmarkDebugOverlay()

    val faceEffects: EffectManager get() = effectManager
    val beauty: BeautyEngine get() = beautyEngine
    val warp: FaceWarpEngine get() = warpEngine
    val makeup: MakeupEngine get() = makeupEngine

    private var glThread: HandlerThread? = null
    private var glHandler: Handler? = null

    private var eglDisplay: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var eglContext: EGLContext = EGL14.EGL_NO_CONTEXT
    private var eglSurface: EGLSurface = EGL14.EGL_NO_SURFACE
    private var eglConfig: EGLConfig? = null

    private var oesTextureId = 0
    private var cameraSurfaceTexture: SurfaceTexture? = null
    @Volatile
    private var cameraSurface: Surface? = null

    private val transformMatrix = FloatArray(16)
    private val frameAvailable = AtomicBoolean(false)
    private val running = AtomicBoolean(false)
    private val drawScheduled = AtomicBoolean(false)

    // Phase 9 — encoder present (GL thread only).
    private val composeFbo = GlFramebuffer()
    private var encoderAndroidSurface: Surface? = null
    private var encoderEglSurface: EGLSurface = EGL14.EGL_NO_SURFACE
    private var encoderWidth = 0
    private var encoderHeight = 0
    private var encoderMirrorX = false
    private var recordingStartNs = 0L
    private var lastEncoderSwapMs = 0L
    private val encoderMinIntervalMs = 33L // ~30 FPS cap

    /** CameraX Preview target — owned by this pipeline; do not release externally. */
    fun cameraOutputSurface(): Surface {
        return cameraSurface ?: throw IllegalStateException("camera surface not ready")
    }

    @Volatile
    private var viewportW = outputWidth.coerceAtLeast(2)

    @Volatile
    private var viewportH = outputHeight.coerceAtLeast(2)

    /**
     * Starts the GL thread, creates the camera OES surface, and returns it for CameraX.
     * On failure/timeout the GL thread and EGL resources are always torn down.
     */
    fun startAndCreateCameraSurface(): Surface {
        val thread = HandlerThread("native-camera-gl").also { it.start() }
        glThread = thread
        val handler = Handler(thread.looper)
        glHandler = handler

        var surfaceResult: Surface? = null
        var error: Throwable? = null
        val latch = CountDownLatch(1)
        handler.post {
            try {
                initEgl()
                initOesCameraTexture()
                colorFilter.ensureProgram()
                beautyEngine.ensureGl()
                warpEngine.ensureGl()
                makeupEngine.ensureGl()
                processFboA.ensure(viewportW, viewportH)
                effectManager.ensureGlReady()
                landmarkOverlay.ensureProgram()
                surfaceResult = cameraSurface
                running.set(true)
            } catch (t: Throwable) {
                error = t
                Log.e(TAG, "GL init failed", t)
                running.set(false)
                releaseGlResourcesLocked()
            } finally {
                latch.countDown()
            }
        }
        val ok = try {
            latch.await(3, TimeUnit.SECONDS)
        } catch (_: InterruptedException) {
            false
        }
        if (!ok) {
            Log.e(TAG, "GL init timeout — tearing down orphan GL thread")
            running.set(false)
            // Best-effort: post cleanup then quit; release() joins.
            try {
                release()
            } catch (t: Throwable) {
                Log.w(TAG, "GL timeout cleanup", t)
                try {
                    thread.quitSafely()
                } catch (_: Throwable) {
                }
                glHandler = null
                glThread = null
            }
            throw IllegalStateException("GL init timeout")
        }
        if (error != null || surfaceResult == null) {
            try {
                release()
            } catch (t: Throwable) {
                Log.w(TAG, "GL init error cleanup", t)
            }
            throw (error ?: IllegalStateException("camera surface missing"))
        }
        return surfaceResult!!
    }

    fun setOutputSize(width: Int, height: Int) {
        viewportW = width.coerceAtLeast(2)
        viewportH = height.coerceAtLeast(2)
        glHandler?.post {
            try {
                flutterSurfaceTexture.setDefaultBufferSize(viewportW, viewportH)
                if (beautyEngine.isActive() || warpEngine.isActive() || makeupEngine.isActive()) {
                    processFboA.ensure(viewportW, viewportH)
                }
            } catch (t: Throwable) {
                Log.w(TAG, "setDefaultBufferSize", t)
            }
        }
    }

    fun setFilterEnabled(enabled: Boolean) {
        colorFilter.enabled = enabled
        requestDraw()
    }

    fun setFilterIntensity(intensity: Float) {
        colorFilter.intensity = intensity
        requestDraw()
    }

    fun setLandmarkDebugEnabled(enabled: Boolean) {
        landmarkOverlay.enabled = enabled
        if (!enabled) landmarkOverlay.clear()
        requestDraw()
    }

    /** Called from analyzer thread with packed UV landmarks (all faces concatenated). */
    fun updateLandmarkDebugPoints(normalizedXy: FloatArray) {
        landmarkOverlay.updatePoints(normalizedXy)
        requestDraw()
    }

    fun bootstrapFaceEffects(context: android.content.Context) {
        effectManager.bootstrapBundled(context)
    }

    fun setFaceEffect(effectId: String?) {
        effectManager.setActiveEffect(effectId)
        if (effectId == null) effectManager.clearTransforms()
        requestDraw()
    }

    fun activeFaceEffectId(): String? = effectManager.activeEffectId()

    fun listFaceEffects(): List<FaceEffectInfo> = effectManager.listEffects()

    fun updateFaceEffectLandmarks(faces: List<FaceLandmarks>, mirrorX: Boolean) {
        effectManager.updateFromFaces(faces, mirrorX)
        requestDraw()
    }

    fun clearFaceEffectTransforms() {
        effectManager.clearTransforms()
        requestDraw()
    }

    fun loadFaceEffectAssetFromPath(
        context: android.content.Context,
        assetId: String,
        assetPath: String,
    ): Boolean = effectManager.loadAssetFromPath(context, assetId, assetPath)

    fun loadFaceEffectAssetFromFile(assetId: String, filePath: String): Boolean =
        effectManager.loadAssetFromFile(assetId, filePath)

    fun registerFaceEffect(definition: FaceEffectDefinition) {
        effectManager.registerEffect(definition)
    }

    fun installRemoteFaceEffect(
        definition: FaceEffectDefinition,
        layerFiles: Map<String, String>,
        force: Boolean,
    ): Boolean {
        val handler = glHandler ?: return effectManager.installRemoteEffect(definition, layerFiles, force)
        var ok = false
        val latch = CountDownLatch(1)
        handler.post {
            try {
                // Must run on GL thread — EffectAsset.release() deletes textures.
                ok = effectManager.installRemoteEffect(definition, layerFiles, force)
                if (ok) {
                    effectManager.ensureGlReady()
                    requestDraw()
                }
            } finally {
                latch.countDown()
            }
        }
        latch.await(2, TimeUnit.SECONDS)
        return ok
    }

    fun unloadFaceEffects(ids: Collection<String>) {
        val handler = glHandler
        if (handler == null) {
            effectManager.unloadEffects(ids)
            return
        }
        val latch = CountDownLatch(1)
        handler.post {
            try {
                effectManager.unloadEffects(ids)
                requestDraw()
            } finally {
                latch.countDown()
            }
        }
        latch.await(2, TimeUnit.SECONDS)
    }

    /**
     * Phase 9: attach MediaCodec input Surface. Must be called before frames are presented.
     * [mirrorX] flips horizontally for front-camera selfie recordings.
     */
    fun setEncoderTarget(surface: Surface?, width: Int, height: Int, mirrorX: Boolean) {
        val latch = CountDownLatch(1)
        glHandler?.post {
            try {
                destroyEncoderEglSurfaceLocked()
                encoderAndroidSurface = surface
                encoderWidth = width.coerceAtLeast(2)
                encoderHeight = height.coerceAtLeast(2)
                encoderMirrorX = mirrorX
                recordingStartNs = System.nanoTime()
                lastEncoderSwapMs = 0L
                if (surface != null) {
                    composeFbo.ensure(viewportW, viewportH)
                }
            } finally {
                latch.countDown()
            }
        } ?: latch.countDown()
        latch.await(1, TimeUnit.SECONDS)
    }

    fun clearEncoderTarget() {
        setEncoderTarget(null, 0, 0, false)
    }

    fun setBeauty(params: BeautyParameters) {
        beautyEngine.setParameters(params)
        requestDraw()
    }

    fun getBeauty(): BeautyParameters = beautyEngine.getParameters()

    fun updateBeautyFaceMask(faces: List<FaceLandmarks>) {
        beautyEngine.updateMask(faces)
        requestDraw()
    }

    fun clearBeautyFaceMask() {
        beautyEngine.clearMask()
        requestDraw()
    }

    fun setWarp(params: WarpParameters) {
        warpEngine.setParameters(params)
        requestDraw()
    }

    fun getWarp(): WarpParameters = warpEngine.getParameters()

    fun updateWarpFromFaces(faces: List<FaceLandmarks>) {
        warpEngine.updateFromFaces(faces)
        requestDraw()
    }

    fun clearWarpFace() {
        warpEngine.clearFace()
        requestDraw()
    }

    fun setMakeup(params: MakeupParameters) {
        makeupEngine.setParameters(params)
        requestDraw()
    }

    fun getMakeup(): MakeupParameters = makeupEngine.getParameters()

    fun updateMakeupRegions(faces: List<FaceLandmarks>) {
        makeupEngine.updateRegions(faces)
        requestDraw()
    }

    fun clearMakeupRegions() {
        makeupEngine.clearRegions()
        requestDraw()
    }

    fun release() {
        running.set(false)
        val handler = glHandler
        val thread = glThread
        if (handler == null || thread == null) return
        val latch = CountDownLatch(1)
        val posted = handler.post {
            try {
                releaseGlResourcesLocked()
            } finally {
                latch.countDown()
            }
        }
        if (posted) {
            try {
                if (!latch.await(3, TimeUnit.SECONDS)) {
                    Log.w(TAG, "GL release timed out — quitting thread anyway")
                    latch.countDown()
                }
            } catch (_: InterruptedException) {
            }
        } else {
            latch.countDown()
        }
        thread.quitSafely()
        try {
            thread.join(1000)
        } catch (_: InterruptedException) {
        }
        glHandler = null
        glThread = null
    }

    private fun initEgl() {
        flutterSurfaceTexture.setDefaultBufferSize(viewportW, viewportH)

        eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        if (eglDisplay == EGL14.EGL_NO_DISPLAY) {
            throw IllegalStateException("eglGetDisplay failed")
        }
        val version = IntArray(2)
        if (!EGL14.eglInitialize(eglDisplay, version, 0, version, 1)) {
            throw IllegalStateException("eglInitialize failed")
        }

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
        val numConfig = IntArray(1)
        var config: EGLConfig? = null
        if (EGL14.eglChooseConfig(eglDisplay, attribList, 0, configs, 0, 1, numConfig, 0) &&
            numConfig[0] > 0 &&
            configs[0] != null
        ) {
            config = configs[0]
        } else {
            // Fallback without recordable bit (still works for preview; encoder may share context config).
            val fallback = intArrayOf(
                EGL14.EGL_RED_SIZE, 8,
                EGL14.EGL_GREEN_SIZE, 8,
                EGL14.EGL_BLUE_SIZE, 8,
                EGL14.EGL_ALPHA_SIZE, 8,
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL14.EGL_SURFACE_TYPE, EGL14.EGL_WINDOW_BIT,
                EGL14.EGL_NONE,
            )
            if (!EGL14.eglChooseConfig(eglDisplay, fallback, 0, configs, 0, 1, numConfig, 0) ||
                numConfig[0] <= 0 ||
                configs[0] == null
            ) {
                throw IllegalStateException("eglChooseConfig failed")
            }
            config = configs[0]
        }
        eglConfig = config

        val ctxAttribs = intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE)
        eglContext = EGL14.eglCreateContext(
            eglDisplay,
            config,
            EGL14.EGL_NO_CONTEXT,
            ctxAttribs,
            0,
        )
        if (eglContext == EGL14.EGL_NO_CONTEXT) {
            throw IllegalStateException("eglCreateContext failed")
        }

        val surfaceAttribs = intArrayOf(EGL14.EGL_NONE)
        eglSurface = EGL14.eglCreateWindowSurface(
            eglDisplay,
            config,
            flutterSurfaceTexture,
            surfaceAttribs,
            0,
        )
        if (eglSurface == EGL14.EGL_NO_SURFACE) {
            throw IllegalStateException("eglCreateWindowSurface failed")
        }
        if (!EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)) {
            throw IllegalStateException("eglMakeCurrent failed")
        }
        Log.i(TAG, "EGL ready ${viewportW}x${viewportH}")
    }

    private fun initOesCameraTexture() {
        val textures = IntArray(1)
        GLES20.glGenTextures(1, textures, 0)
        oesTextureId = textures[0]
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, oesTextureId)
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_MIN_FILTER,
            GLES20.GL_LINEAR,
        )
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_MAG_FILTER,
            GLES20.GL_LINEAR,
        )
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_WRAP_S,
            GLES20.GL_CLAMP_TO_EDGE,
        )
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_WRAP_T,
            GLES20.GL_CLAMP_TO_EDGE,
        )

        val st = SurfaceTexture(oesTextureId)
        st.setDefaultBufferSize(viewportW, viewportH)
        st.setOnFrameAvailableListener({
            frameAvailable.set(true)
            requestDraw()
        }, glHandler)
        cameraSurfaceTexture = st
        cameraSurface = Surface(st)
    }

    private fun requestDraw() {
        if (!running.get()) return
        if (!drawScheduled.compareAndSet(false, true)) return
        glHandler?.post {
            drawScheduled.set(false)
            drawFrame()
        }
    }

    private fun drawFrame() {
        if (!running.get()) return
        if (eglDisplay == EGL14.EGL_NO_DISPLAY) return
        val st = cameraSurfaceTexture ?: return
        try {
            if (frameAvailable.compareAndSet(true, false)) {
                st.updateTexImage()
                st.getTransformMatrix(transformMatrix)
            }
            if (!EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)) {
                Log.w(TAG, "eglMakeCurrent failed during draw")
                return
            }

            val recording = encoderAndroidSurface != null
            if (recording) {
                composeFbo.ensure(viewportW, viewportH)
                composeFbo.bind()
                renderSceneToCurrentFb()
                composeFbo.unbind()

                // Preview
                GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
                GLES20.glViewport(0, 0, viewportW, viewportH)
                GLES20.glClearColor(0f, 0f, 0f, 1f)
                GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
                beautyEngine.effect.drawPassthrough(composeFbo.textureId, viewportW, viewportH)
                EGL14.eglSwapBuffers(eglDisplay, eglSurface)

                presentComposeToEncoder(composeFbo.textureId)
            } else {
                renderSceneToCurrentFb()
                EGL14.eglSwapBuffers(eglDisplay, eglSurface)
            }
        } catch (t: Throwable) {
            Log.e(TAG, "drawFrame", t)
        }
    }

    /** Draws color → beauty/warp/makeup → stickers → landmarks into the current framebuffer. */
    private fun renderSceneToCurrentFb() {
        val passes = ArrayList<Int>(3)
        if (beautyEngine.isActive()) passes.add(PASS_BEAUTY)
        if (warpEngine.isActive()) passes.add(PASS_WARP)
        if (makeupEngine.isActive()) passes.add(PASS_MAKEUP)

        if (passes.isEmpty()) {
            colorFilter.draw(oesTextureId, viewportW, viewportH, transformMatrix)
        } else {
            processFboA.ensure(viewportW, viewportH)
            if (passes.size > 1) {
                processFboB.ensure(viewportW, viewportH)
            }

            // Color grade into A.
            processFboA.bind()
            colorFilter.draw(oesTextureId, viewportW, viewportH, transformMatrix)
            processFboA.unbind()

            var readFromA = true
            for (i in passes.indices) {
                val pass = passes[i]
                val isLast = i == passes.lastIndex
                val srcTex = if (readFromA) processFboA.textureId else processFboB.textureId

                if (isLast) {
                    if (encoderAndroidSurface != null) {
                        composeFbo.bind()
                    } else {
                        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
                    }
                    GLES20.glViewport(0, 0, viewportW, viewportH)
                    drawProcessPass(pass, srcTex)
                } else {
                    val dst = if (readFromA) processFboB else processFboA
                    dst.bind()
                    drawProcessPass(pass, srcTex)
                    dst.unbind()
                    readFromA = !readFromA
                }
            }
        }

        effectManager.draw(oesTextureId, viewportW, viewportH, transformMatrix)
        landmarkOverlay.draw(oesTextureId, viewportW, viewportH, transformMatrix)
    }

    private fun presentComposeToEncoder(textureId: Int) {
        val androidSurface = encoderAndroidSurface ?: return
        if (!androidSurface.isValid) return
        val encW = encoderWidth
        val encH = encoderHeight
        if (encW < 2 || encH < 2) return

        val now = SystemClock.elapsedRealtime()
        if (now - lastEncoderSwapMs < encoderMinIntervalMs) return

        var eglSurf = encoderEglSurface
        if (eglSurf == EGL14.EGL_NO_SURFACE) {
            val config = eglConfig ?: return
            eglSurf = EGL14.eglCreateWindowSurface(
                eglDisplay,
                config,
                androidSurface,
                intArrayOf(EGL14.EGL_NONE),
                0,
            )
            if (eglSurf == EGL14.EGL_NO_SURFACE) {
                Log.e(TAG, "encoder eglCreateWindowSurface failed")
                return
            }
            encoderEglSurface = eglSurf
        }

        if (!EGL14.eglMakeCurrent(eglDisplay, eglSurf, eglSurf, eglContext)) {
            Log.e(
                TAG,
                "encoder eglMakeCurrent failed 0x${Integer.toHexString(EGL14.eglGetError())}",
            )
            destroyEncoderEglSurfaceLocked()
            return
        }
        try {
            GLES20.glViewport(0, 0, encW, encH)
            GLES20.glClearColor(0f, 0f, 0f, 1f)
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
            if (encoderMirrorX) {
                drawMirroredPassthrough(textureId, encW, encH)
            } else {
                beautyEngine.effect.drawPassthrough(textureId, encW, encH)
            }
            val pts = System.nanoTime() - recordingStartNs
            EGLExt.eglPresentationTimeANDROID(eglDisplay, eglSurf, pts)
            EGL14.eglSwapBuffers(eglDisplay, eglSurf)
            lastEncoderSwapMs = now
        } finally {
            EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)
        }
    }

    /** Horizontal flip blit for front-camera recordings. */
    private fun drawMirroredPassthrough(textureId: Int, width: Int, height: Int) {
        drawFlippedPassthrough(textureId, width, height)
    }

    private var flipProgram = 0
    private var flipPos = -1
    private var flipUv = -1
    private var flipTex = -1
    private val flipVertexBuffer = java.nio.ByteBuffer
        .allocateDirect(8 * 4)
        .order(java.nio.ByteOrder.nativeOrder())
        .asFloatBuffer()
        .apply {
            // Mirrored X positions: swap left/right
            put(floatArrayOf(1f, -1f, -1f, -1f, 1f, 1f, -1f, 1f))
            position(0)
        }
    private val flipTexBuffer = java.nio.ByteBuffer
        .allocateDirect(8 * 4)
        .order(java.nio.ByteOrder.nativeOrder())
        .asFloatBuffer()
        .apply {
            put(floatArrayOf(0f, 0f, 1f, 0f, 0f, 1f, 1f, 1f))
            position(0)
        }

    private fun drawFlippedPassthrough(textureId: Int, width: Int, height: Int) {
        if (flipProgram == 0) {
            val vs = """
                attribute vec4 aPosition;
                attribute vec2 aTexCoord;
                varying vec2 vUv;
                void main() {
                  gl_Position = aPosition;
                  vUv = aTexCoord;
                }
            """.trimIndent()
            val fs = """
                precision mediump float;
                uniform sampler2D uTexture;
                varying vec2 vUv;
                void main() {
                  gl_FragColor = texture2D(uTexture, vUv);
                }
            """.trimIndent()
            flipProgram = linkProgram(vs, fs)
            flipPos = GLES20.glGetAttribLocation(flipProgram, "aPosition")
            flipUv = GLES20.glGetAttribLocation(flipProgram, "aTexCoord")
            flipTex = GLES20.glGetUniformLocation(flipProgram, "uTexture")
        }
        GLES20.glViewport(0, 0, width, height)
        GLES20.glUseProgram(flipProgram)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureId)
        GLES20.glUniform1i(flipTex, 0)
        GLES20.glEnableVertexAttribArray(flipPos)
        GLES20.glVertexAttribPointer(flipPos, 2, GLES20.GL_FLOAT, false, 0, flipVertexBuffer)
        GLES20.glEnableVertexAttribArray(flipUv)
        GLES20.glVertexAttribPointer(flipUv, 2, GLES20.GL_FLOAT, false, 0, flipTexBuffer)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(flipPos)
        GLES20.glDisableVertexAttribArray(flipUv)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
    }

    private fun destroyEncoderEglSurfaceLocked() {
        if (encoderEglSurface != EGL14.EGL_NO_SURFACE && eglDisplay != EGL14.EGL_NO_DISPLAY) {
            try {
                EGL14.eglDestroySurface(eglDisplay, encoderEglSurface)
            } catch (_: Throwable) {
            }
        }
        encoderEglSurface = EGL14.EGL_NO_SURFACE
        encoderAndroidSurface = null
        encoderWidth = 0
        encoderHeight = 0
        encoderMirrorX = false
    }

    private fun drawProcessPass(pass: Int, srcTex: Int) {
        when (pass) {
            PASS_BEAUTY -> beautyEngine.effect.drawFromTexture(srcTex, viewportW, viewportH)
            PASS_WARP -> warpEngine.effect.drawFromTexture(srcTex, viewportW, viewportH)
            PASS_MAKEUP -> makeupEngine.effect.drawFromTexture(srcTex, viewportW, viewportH)
        }
    }

    private fun releaseGlResourcesLocked() {
        try {
            destroyEncoderEglSurfaceLocked()
        } catch (_: Throwable) {
        }
        try {
            cameraSurface?.release()
        } catch (_: Throwable) {
        }
        cameraSurface = null
        try {
            cameraSurfaceTexture?.setOnFrameAvailableListener(null)
            cameraSurfaceTexture?.release()
        } catch (_: Throwable) {
        }
        cameraSurfaceTexture = null

        colorFilter.release()
        beautyEngine.release()
        warpEngine.release()
        makeupEngine.release()
        processFboA.release()
        processFboB.release()
        composeFbo.release()
        effectManager.release()
        landmarkOverlay.release()

        if (flipProgram != 0) {
            GLES20.glDeleteProgram(flipProgram)
            flipProgram = 0
        }

        if (oesTextureId != 0) {
            GLES20.glDeleteTextures(1, intArrayOf(oesTextureId), 0)
            oesTextureId = 0
        }

        if (eglDisplay != EGL14.EGL_NO_DISPLAY) {
            EGL14.eglMakeCurrent(
                eglDisplay,
                EGL14.EGL_NO_SURFACE,
                EGL14.EGL_NO_SURFACE,
                EGL14.EGL_NO_CONTEXT,
            )
            if (eglSurface != EGL14.EGL_NO_SURFACE) {
                EGL14.eglDestroySurface(eglDisplay, eglSurface)
                eglSurface = EGL14.EGL_NO_SURFACE
            }
            if (eglContext != EGL14.EGL_NO_CONTEXT) {
                EGL14.eglDestroyContext(eglDisplay, eglContext)
                eglContext = EGL14.EGL_NO_CONTEXT
            }
            EGL14.eglTerminate(eglDisplay)
            eglDisplay = EGL14.EGL_NO_DISPLAY
        }
        eglConfig = null
    }
}
