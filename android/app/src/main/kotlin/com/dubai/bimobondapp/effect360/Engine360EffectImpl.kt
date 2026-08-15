package com.dubai.bimobondapp.effect360

import android.content.Context
import android.opengl.Matrix
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class Engine360EffectImpl(private val context: Context) : Engine360EffectInterface {

    companion object {
        private const val TAG = "Engine360EffectImpl"
        private const val DEFAULT_FOV_Y = 60.0f
    }

    private val engineScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    private val cache = Effect360Cache(context)
    private val orientationTracker = OrientationTracker(context)
    private val sphereRenderer = EquirectangularSphereRenderer()

    private var videoDecoder: Video360Decoder? = null
    private var alphaDecoder: Video360Decoder? = null

    private var state = Engine360State()

    private val projectionMatrix = FloatArray(16)
    private val viewMatrix = FloatArray(16)
    private val stMatrixVideo = FloatArray(16).apply { Matrix.setIdentityM(this, 0) }
    private val stMatrixAlpha = FloatArray(16).apply { Matrix.setIdentityM(this, 0) }

    private var isGlInitialized = false

    var manualYaw: Float = 0.0f
    var manualPitch: Float = 0.0f
    var useGyroscopeSensor: Boolean = false

    fun setManualOrientation(yaw: Float, pitch: Float) {
        manualYaw = yaw
        manualPitch = pitch
        useGyroscopeSensor = false
        Log.i("ORIENT_360", "Manual Orientation Set: yaw=$yaw° pitch=$pitch°")
    }

    override fun initialize() {
        if (useGyroscopeSensor) {
            orientationTracker.startTracking()
        }
        Log.i(TAG, "Engine360EffectImpl initialized. useGyroscopeSensor=$useGyroscopeSensor")
    }

    fun ensureGlInitialized() {
        if (isGlInitialized) return
        sphereRenderer.initializeGl()

        videoDecoder = Video360Decoder(context, isAlphaChannel = false).apply {
            initializeGlTexture()
        }

        alphaDecoder = Video360Decoder(context, isAlphaChannel = true).apply {
            initializeGlTexture()
        }

        isGlInitialized = true
        Log.i(TAG, "Engine360EffectImpl GL resources initialized on GL thread.")
    }

    override fun load360Effect(videoUrl: String, alphaUrl: String?) {
        state = state.copy(
            status = Engine360Status.LOADING,
            videoUrl = videoUrl,
            alphaUrl = alphaUrl
        )

        Log.i("VIDEO_360_FORMAT", "Requested 360 Video URL: $videoUrl | Alpha URL: $alphaUrl")

        engineScope.launch {
            try {
                val videoFile = cache.getOrFetchAsset(videoUrl)
                val okVideo = if (videoFile != null && videoFile.exists()) {
                    videoDecoder?.startDecoding(videoFile, loopPlayback = true) ?: false
                } else {
                    videoDecoder?.startDecodingUrl(videoUrl, loopPlayback = true) ?: false
                }
                var okAlpha = false

                if (!alphaUrl.isNullOrEmpty()) {
                    val alphaFile = cache.getOrFetchAsset(alphaUrl)
                    if (alphaFile != null && alphaFile.exists()) {
                        okAlpha = alphaDecoder?.startDecoding(alphaFile, loopPlayback = true) ?: false
                    } else {
                        okAlpha = alphaDecoder?.startDecodingUrl(alphaUrl, loopPlayback = true) ?: false
                    }
                }

                if (okVideo) {
                    state = state.copy(
                        status = Engine360Status.PLAYING,
                        durationMs = (videoDecoder?.durationUs ?: 0L) / 1000L
                    )
                    Log.i(TAG, "360 Effect loaded and playing successfully.")
                } else {
                    state = state.copy(
                        status = Engine360Status.ERROR,
                        errorMessage = "MediaCodec failed to decode video $videoUrl"
                    )
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error loading 360 effect", e)
                state = state.copy(
                    status = Engine360Status.ERROR,
                    errorMessage = e.message
                )
            }
        }
    }

    override fun remove360Effect() {
        videoDecoder?.stopDecoding()
        alphaDecoder?.stopDecoding()
        state = Engine360State(status = Engine360Status.IDLE)
        Log.i(TAG, "360 Effect removed.")
    }

    override fun set360EffectOpacity(opacity: Float) {
        state = state.copy(opacity = opacity.coerceIn(0.0f, 1.0f))
    }

    override fun set360EffectTransform(matrix: FloatArray) {
        // Reserved for external orientation offsets
    }

    override fun update(presentationTimeNs: Long) {
        if (state.status != Engine360Status.PLAYING && state.status != Engine360Status.LOADING) return
        videoDecoder?.updateFrame(stMatrixVideo)
        if (!state.alphaUrl.isNullOrEmpty()) {
            alphaDecoder?.updateFrame(stMatrixAlpha)
        }
    }

    override fun render(
        cameraOesTextureId: Int,
        width: Int,
        height: Int,
        projectionMatrixIn: FloatArray,
        viewMatrixIn: FloatArray
    ) {
        ensureGlInitialized()
        if (state.status == Engine360Status.IDLE) return
        val rgbTexture = videoDecoder?.oesTextureId ?: 0

        val aspect = if (height > 0) width.toFloat() / height.toFloat() else 1.0f
        Matrix.perspectiveM(projectionMatrix, 0, DEFAULT_FOV_Y, aspect, 0.1f, 100.0f)

        if (useGyroscopeSensor) {
            orientationTracker.getViewMatrix(viewMatrix)
        } else {
            Matrix.setIdentityM(viewMatrix, 0)
            Matrix.rotateM(viewMatrix, 0, manualPitch, 1.0f, 0.0f, 0.0f)
            Matrix.rotateM(viewMatrix, 0, manualYaw, 0.0f, 1.0f, 0.0f)
        }

        val alphaTexture = if (!state.alphaUrl.isNullOrEmpty()) alphaDecoder?.oesTextureId else null
        sphereRenderer.renderSphere(
            videoOesTextureId = rgbTexture,
            alphaOesTextureId = alphaTexture,
            stMatrixIn = stMatrixVideo,
            projectionMatrix = projectionMatrix,
            viewMatrix = viewMatrix,
            opacity = state.opacity
        )
    }

    override fun getState(): Engine360State = state
}
