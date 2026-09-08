package com.dubai.bimobondapp.ar_camera.beauty_v3

import android.opengl.GLES20
import android.os.SystemClock
import java.nio.FloatBuffer
import java.util.concurrent.atomic.AtomicLong

/**
 * Beauty V3 pipeline: OES → canonical → [beauty] → [reshape] → [color+makeup] → present.
 *
 * Production live path for preview, capture, and encoder. Legacy FaceWarp OES
 * beauty shaders are not used.
 */
class V3Pipeline {
    private val inputPass = V3InputPass()
    private val beautyPass = V3BeautyPass()
    private val reshapePass = V3ReshapePass()
    private val colorMakeupPass = V3ColorMakeupPass()
    private val presentPass = V3PresentPass()
    private val canonical = V3CanonicalTarget()
    /** Ping-pong scratch for beauty/reshape/color (same size as canonical). */
    private val effectScratch = V3CanonicalTarget()
    private val contract = V3FrameContract()

    private val generation = AtomicLong(0L)
    private val restoreViewport = IntArray(4)
    private val restoreFbo = IntArray(1)
    private var programsReady = false
    private var framesSinceInit = 0

    /** Last filled contract (same instance each frame — do not retain across frames). */
    val lastContract: V3FrameContract
        get() = contract

    fun ensureGl(): Boolean {
        if (programsReady) return true
        val ok = inputPass.ensureProgram() &&
            beautyPass.ensureProgram() &&
            reshapePass.ensureProgram() &&
            colorMakeupPass.ensureProgram() &&
            presentPass.ensureProgram()
        programsReady = ok
        return ok
    }

    /**
     * Fills the reusable [V3FrameContract] for this frame and returns it.
     */
    fun updateContract(
        sourceWidth: Int,
        sourceHeight: Int,
        rotationDegrees: Int,
        mirrorX: Boolean,
        stMatrix: FloatArray,
        viewWidth: Int,
        viewHeight: Int,
        wideZoom: Float,
        timestampNs: Long,
    ): V3FrameContract {
        return contract.update(
            sourceWidth = sourceWidth,
            sourceHeight = sourceHeight,
            rotationDegrees = rotationDegrees,
            mirrorX = mirrorX,
            stMatrixIn = stMatrix,
            viewWidth = viewWidth,
            viewHeight = viewHeight,
            wideZoom = wideZoom,
            timestampNs = timestampNs,
            frameGeneration = generation.incrementAndGet(),
        )
    }

    /**
     * Full V3 frame into the currently bound framebuffer (window / capture / encoder).
     */
    fun drawFrame(
        oesTextureId: Int,
        contract: V3FrameContract,
        vertexBuffer: FloatBuffer,
    ): Boolean {
        val startNs = SystemClock.elapsedRealtimeNanos()
        if (!ensureGl()) return false
        if (oesTextureId == 0) return false
        if (contract.sourceWidth < 2 || contract.sourceHeight < 2) return false

        GLES20.glGetIntegerv(GLES20.GL_VIEWPORT, restoreViewport, 0)
        GLES20.glGetIntegerv(GLES20.GL_FRAMEBUFFER_BINDING, restoreFbo, 0)

        if (!inputPass.draw(oesTextureId, contract, canonical, vertexBuffer)) {
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, restoreFbo[0])
            GLES20.glViewport(
                restoreViewport[0],
                restoreViewport[1],
                restoreViewport[2],
                restoreViewport[3],
            )
            return false
        }

        // Beauty stack on canonical (shared by preview/capture/encoder).
        // Advance shared display-time face state once per GL frame before any effect,
        // targeting the SurfaceTexture / camera frame timestamp (not callback time).
        val displayTimeMs = V3CameraClock.nsToElapsedMs(contract.timestampNs)
        V3TrackedFaceState.advance(
            frameGeneration = contract.frameGeneration,
            displayTimeMs = displayTimeMs,
        )
        var presentTex = canonical.textureId
        val wantBeauty = V3BeautyConfig.beautyActive()
        val wantReshape = V3BeautyConfig.reshapeActive()
        val wantColorMakeup = V3BeautyConfig.colorMakeupActive()
        logV3Pass(wantBeauty, wantReshape, wantColorMakeup)
        if (wantBeauty || wantReshape || wantColorMakeup) {
            effectScratch.ensure(contract.canonicalWidth, contract.canonicalHeight)
        }
        if (wantBeauty && effectScratch.textureId != 0) {
            if (beautyPass.draw(presentTex, effectScratch, contract)) {
                presentTex = effectScratch.textureId
            }
        }
        if (wantReshape) {
            val reshapeSrc = presentTex
            val reshapeDest = if (reshapeSrc == canonical.textureId) effectScratch else canonical
            if (reshapeDest.ensure(contract.canonicalWidth, contract.canonicalHeight) &&
                reshapePass.draw(reshapeSrc, reshapeDest, contract)
            ) {
                presentTex = reshapeDest.textureId
            }
        }
        if (wantColorMakeup) {
            val src = presentTex
            val dest = if (src == canonical.textureId) effectScratch else canonical
            if (dest.ensure(contract.canonicalWidth, contract.canonicalHeight) &&
                colorMakeupPass.draw(src, dest, contract)
            ) {
                presentTex = dest.textureId
            }
        }

        // Present into the framebuffer that was bound when we entered.
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, restoreFbo[0])
        GLES20.glViewport(
            restoreViewport[0],
            restoreViewport[1],
            restoreViewport[2],
            restoreViewport[3],
        )
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)

        contract.setPresentViewport(restoreViewport[2], restoreViewport[3])

        val presented = presentPass.draw(presentTex, contract, vertexBuffer)


        if (restoreFbo[0] == 0) {
            framesSinceInit++
            if (framesSinceInit == WARMUP_FRAMES) {
                V3Diagnostics.markWarmupComplete()
            }
            val frameMs = (SystemClock.elapsedRealtimeNanos() - startNs) / 1_000_000f
            V3Diagnostics.onFrame(contract, frameMs)
        }
        return presented
    }

    fun release() {
        inputPass.release()
        beautyPass.release()
        reshapePass.release()
        colorMakeupPass.release()
        presentPass.release()
        canonical.release()
        effectScratch.release()
        programsReady = false
        framesSinceInit = 0
        V3AnalysisToCanonicalTransform.invalidateLandmarksOnly(
            V3AnalysisToCanonicalTransform.Reason.INVALIDATED_ON_EGL,
        )
        V3Diagnostics.reset()
    }

    /** EGL context lost — zero handles without glDelete. */
    fun forgetHandles() {
        inputPass.forgetHandles()
        beautyPass.forgetHandles()
        reshapePass.forgetHandles()
        colorMakeupPass.forgetHandles()
        presentPass.forgetHandles()
        canonical.forgetHandles()
        effectScratch.forgetHandles()
        programsReady = false
        framesSinceInit = 0
        V3AnalysisToCanonicalTransform.invalidateLandmarksOnly(
            V3AnalysisToCanonicalTransform.Reason.INVALIDATED_ON_EGL,
        )
        V3Diagnostics.reset()
    }

    companion object {
        private const val WARMUP_FRAMES = 3
        const val PRODUCTION_WIDE_ZOOM = 2.0f

        @Volatile
        private var lastV3PassLogMs = 0L

        /** Temporary low-frequency pass activation proof — remove after verification. */
        private fun logV3Pass(beauty: Boolean, reshape: Boolean, colorMakeup: Boolean) {
            val now = SystemClock.elapsedRealtime()
            if (now - lastV3PassLogMs < 1_000L) return
            lastV3PassLogMs = now
            android.util.Log.i(
                "V3_PASS",
                "beauty=$beauty reshape=$reshape colorMakeup=$colorMakeup",
            )
        }
    }
}
