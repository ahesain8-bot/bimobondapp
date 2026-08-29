package com.dubai.bimobondapp.live_beauty

import android.graphics.Matrix
import android.opengl.GLES20
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.cloudwebrtc.webrtc.video.LocalVideoTrack
import com.dubai.bimobondapp.camera_engine.BeautyEffect
import com.dubai.bimobondapp.camera_engine.BeautyFaceMask
import com.dubai.bimobondapp.camera_engine.BeautyParameters
import org.webrtc.GlRectDrawer
import org.webrtc.GlTextureFrameBuffer
import org.webrtc.TextureBufferImpl
import org.webrtc.VideoFrame
import org.webrtc.VideoFrameDrawer
import org.webrtc.YuvConverter

/**
 * Runs the live-camera beauty shader on the frames LiveKit actually publishes.
 *
 * The live host used to draw its "effects" as Flutter widgets stacked over the
 * preview, so only the host ever saw them — the SFU received the raw sensor
 * frame. flutter_webrtc exposes [LocalVideoTrack.ExternalVideoFrameProcessing]
 * on the very track LiveKit encodes, which is the one place a change reaches
 * viewers too, so the beauty pass lives here rather than in the widget tree.
 *
 * Every callback arrives on the capturer's texture thread with its EGL context
 * already current, which is why all GL objects are created lazily inside
 * [onFrame] and never from the Flutter or main thread.
 */
object LiveBeautyFrameProcessor : LocalVideoTrack.ExternalVideoFrameProcessing {

    private const val TAG = "LiveBeautyFrameProcessor"

    /** Output slots. Three covers an encoder holding a frame or two in flight. */
    private const val POOL_SIZE = 3

    @Volatile
    private var params: BeautyParameters = BeautyParameters(enabled = false)

    /**
     * Skin-gated whole-frame mask.
     *
     * [BeautyEffect]'s shader multiplies every regional term by a face ellipse,
     * so an empty mask leaves nothing but a weak global brightness. Landmarks
     * would cost a per-frame readback on the capture thread; a frame-filling
     * ellipse instead lets the shader's own YCbCr skin probability decide where
     * to smooth, which is what the effect is gated on anyway.
     */
    private val fullFrameMask: BeautyFaceMask = BeautyFaceMask(
        faceCount = 1,
        faces = floatArrayOf(0.5f, 0.45f, 0.55f, 0.70f, 0f, 0f, 0f, 0f),
        eyes = FloatArray(BeautyFaceMask.MAX_FACES * 6),
    )

    private val lock = Any()

    private var beauty: BeautyEffect? = null
    private var drawer: GlRectDrawer? = null
    private var frameDrawer: VideoFrameDrawer? = null
    private var sourceFbo: GlTextureFrameBuffer? = null
    private var pool: Array<GlTextureFrameBuffer?> = arrayOfNulls(POOL_SIZE)
    private val inUse = BooleanArray(POOL_SIZE)
    private var ownConverter: YuvConverter? = null
    private var ownHandler: Handler? = null

    /**
     * Bumped whenever a new capture session attaches. The GL objects above
     * belong to the previous session's EGL context and must not be reused or
     * deleted from the new one, so [onFrame] drops them by identity instead.
     */
    private var generation = 0
    private var resourceGeneration = -1

    fun setParameters(next: BeautyParameters) {
        params = next.clamped()
    }

    fun currentParameters(): BeautyParameters = params

    fun disable() {
        params = params.copy(enabled = false)
    }

    /** Marks the GL state stale; the next frame rebuilds it in its own context. */
    fun invalidateResources() {
        synchronized(lock) { generation++ }
    }

    override fun onFrame(frame: VideoFrame): VideoFrame {
        val p = params
        if (!p.enabled || !p.isVisuallyActive()) return frame

        return try {
            process(frame, p) ?: frame
        } catch (t: Throwable) {
            // A shader or pool failure must never take the broadcast down: the
            // host stays live with an unfiltered frame.
            Log.w(TAG, "beauty pass failed, publishing source frame", t)
            frame
        }
    }

    private fun process(frame: VideoFrame, p: BeautyParameters): VideoFrame? {
        val width = frame.rotatedWidth
        val height = frame.rotatedHeight
        if (width <= 0 || height <= 0) return null

        val slot: Int
        val target: GlTextureFrameBuffer
        val source: GlTextureFrameBuffer
        val effect: BeautyEffect
        val rectDrawer: GlRectDrawer
        val videoDrawer: VideoFrameDrawer

        synchronized(lock) {
            if (resourceGeneration != generation) {
                // Previous context is gone with its objects; start clean.
                beauty = null
                drawer = null
                frameDrawer = null
                sourceFbo = null
                pool = arrayOfNulls(POOL_SIZE)
                inUse.fill(false)
                ownConverter = null
                ownHandler = null
                resourceGeneration = generation
            }

            slot = inUse.indexOfFirst { !it }
            // Every slot still held downstream — skip the effect for this frame
            // rather than stalling the capture thread.
            if (slot < 0) return null
            inUse[slot] = true

            effect = beauty ?: BeautyEffect().also { beauty = it }
            rectDrawer = drawer ?: GlRectDrawer().also { drawer = it }
            videoDrawer = frameDrawer ?: VideoFrameDrawer().also { frameDrawer = it }
            source = sourceFbo ?: GlTextureFrameBuffer(GLES20.GL_RGBA).also { sourceFbo = it }
            target = pool[slot] ?: GlTextureFrameBuffer(GLES20.GL_RGBA).also { pool[slot] = it }
        }

        val frameGeneration = synchronized(lock) { generation }

        try {
            source.setSize(width, height)
            target.setSize(width, height)

            // Pass 1 — buffer (OES texture, RGB texture or I420) to a plain 2D
            // texture, with the frame's own rotation and transform baked in.
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, source.frameBufferId)
            videoDrawer.drawFrame(frame, rectDrawer, null, 0, 0, width, height)

            // Pass 2 — the beauty shader.
            effect.setParameters(p)
            effect.setFaceMask(fullFrameMask)
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, target.frameBufferId)
            effect.drawFromTexture(source.textureId, width, height)
        } catch (t: Throwable) {
            synchronized(lock) { inUse[slot] = false }
            throw t
        } finally {
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
        }

        // Anything that throws from here on still owns the slot, and three
        // lost slots would stop the effect for the rest of the broadcast with
        // no error to show for it.
        val processed = try {
            val buffer = frame.buffer
            val handler =
                (buffer as? TextureBufferImpl)?.toI420Handler ?: ownHandler()
            val converter =
                (buffer as? TextureBufferImpl)?.yuvConverter ?: ownConverter()

            TextureBufferImpl(
                width,
                height,
                VideoFrame.TextureBuffer.Type.RGB,
                target.textureId,
                Matrix(),
                handler,
                converter,
            ) {
                synchronized(lock) {
                    // A slot from a retired context must not be handed back out.
                    if (frameGeneration == generation) inUse[slot] = false
                }
            }
        } catch (t: Throwable) {
            synchronized(lock) { inUse[slot] = false }
            throw t
        }

        // Rotation is already applied by pass 1, so the published frame is
        // upright and must not be rotated again downstream.
        return VideoFrame(processed, 0, frame.timestampNs)
    }

    private fun ownHandler(): Handler {
        ownHandler?.let { return it }
        val looper = Looper.myLooper() ?: Looper.getMainLooper()
        return Handler(looper).also { ownHandler = it }
    }

    private fun ownConverter(): YuvConverter {
        ownConverter?.let { return it }
        return YuvConverter().also { ownConverter = it }
    }
}
