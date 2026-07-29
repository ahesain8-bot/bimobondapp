package com.dubai.bimobondapp.ar_camera

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.RectF
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.util.SparseArray
import androidx.camera.core.CameraEffect
import androidx.camera.effects.OverlayEffect
import kotlin.math.max

/**
 * Hardware-pipeline sticker overlay for [VideoCapture] (CameraX OverlayEffect).
 * Preview stickers stay on [FaceOverlayView]; this only bakes into the recorded stream
 * so PNG recording can use the same zero-lag hardware path as normal camera.
 */
class StickerCameraOverlay(private val appContext: Context) {
    private val bitmapPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val stickerBitmaps = SparseArray<Bitmap>()

    private var handlerThread: HandlerThread? = null

    @Volatile
    private var overlayEffect: OverlayEffect? = null

    @Volatile
    private var currentFilter: FilterType = FilterType.NONE

    @Volatile
    private var snapshot: FaceLandmarkSnapshot? = null

    @Volatile
    private var imageWidth: Int = 0

    @Volatile
    private var imageHeight: Int = 0

    @Volatile
    private var isFrontCamera: Boolean = true

    fun updateLandmarks(
        filter: FilterType,
        snapshots: List<FaceLandmarkSnapshot>,
        imageWidth: Int,
        imageHeight: Int,
        isFrontCamera: Boolean,
    ) {
        currentFilter = filter
        snapshot = snapshots.firstOrNull()
        this.imageWidth = imageWidth
        this.imageHeight = imageHeight
        this.isFrontCamera = isFrontCamera
    }

    fun clear() {
        currentFilter = FilterType.NONE
        snapshot = null
        imageWidth = 0
        imageHeight = 0
    }

    fun ensureEffect(): OverlayEffect {
        closeEffectOnly()
        // Long-lived thread, not recreated per effect — CameraX posts to this
        // executor while tearing an effect down, and a dead Looper there throws
        // RejectedExecutionException on the main thread. Same fix as
        // ScreenOverlayCameraEffect.
        val thread = handlerThread ?: HandlerThread("ar-sticker-overlay")
            .also { it.start(); handlerThread = it }
        val effect = OverlayEffect(
            CameraEffect.VIDEO_CAPTURE,
            /* queueDepth */ 1,
            Handler(thread.looper),
        ) { /* draw errors are non-fatal */ }
        effect.setOnDrawListener { frame ->
            val filter = currentFilter
            val snap = snapshot
            val imgW = imageWidth
            val imgH = imageHeight
            if (!filter.isPngOverlay() || snap == null || imgW <= 0 || imgH <= 0) {
                // TRUE, not false. The return value tells CameraX whether to keep
                // the VIDEO FRAME — returning false here dropped a frame from the
                // recording every time a face wasn't detected, so any moment the
                // subject looked away came out stuttering. Nothing needs to be
                // drawn; leaving the canvas untouched makes CameraX reuse the last
                // overlay texture, which is what "no update" should mean.
                return@setOnDrawListener true
            }
            val canvas = frame.overlayCanvas
            canvas.drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR)

            // The overlay canvas is the raw camera buffer: crop, rotation and
            // mirroring are applied downstream to the composite, so stickers have
            // to be drawn pre-transformed or they come out rotated relative to the
            // footage. Same reasoning (and the same geometry) as
            // ScreenOverlayCameraEffect.applyOutputToBufferTransform.
            val cropRect = frame.cropRect
            val rotation = ((frame.rotationDegrees % 360) + 360) % 360
            val quarterTurn = rotation == 90 || rotation == 270
            val outW = if (quarterTurn) cropRect.height() else cropRect.width()
            val outH = if (quarterTurn) cropRect.width() else cropRect.height()
            if (outW <= 0 || outH <= 0) return@setOnDrawListener true

            canvas.save()
            canvas.translate(cropRect.left.toFloat(), cropRect.top.toFloat())
            if (rotation != 0) {
                val m = Matrix()
                m.postRotate(-rotation.toFloat())
                val bounds = RectF(0f, 0f, outW.toFloat(), outH.toFloat())
                m.mapRect(bounds)
                m.postTranslate(-bounds.left, -bounds.top)
                canvas.concat(m)
            }
            drawStickers(
                canvas = canvas,
                snapshot = snap,
                filter = filter,
                destW = outW,
                destH = outH,
                imgW = imgW,
                imgH = imgH,
                // Confirmed on-device: the sticker ends up moving opposite to the
                // face in the saved recording — i.e. VideoCapture's
                // MIRROR_MODE_ON_FRONT_ONLY mirrors the buffer BEFORE this overlay
                // is composited (not after, as originally assumed), so drawing in
                // raw analysis space here left the sticker unmirrored relative to
                // the already-mirrored base frame. Mirroring it here too aligns
                // both.
                // Mirroring is applied downstream too, so pre-mirror here to
                // cancel it — confirmed on-device when this effect was written.
                mirrorX = frame.isMirroring,
            )
            canvas.restore()
            true
        }
        overlayEffect = effect
        return effect
    }

    private fun closeEffectOnly() {
        try {
            overlayEffect?.clearOnDrawListener()
        } catch (_: Exception) {
        }
        try {
            overlayEffect?.close()
        } catch (_: Exception) {
        }
        overlayEffect = null
        // Thread intentionally left running — torn down in release().
    }

    fun release() {
        closeEffectOnly()
        clear()
        val thread = handlerThread
        handlerThread = null
        if (thread != null) {
            // Delayed so already-queued CameraX callbacks land on a live Looper.
            Handler(Looper.getMainLooper()).postDelayed(
                { runCatching { thread.quitSafely() } },
                THREAD_QUIT_DELAY_MS,
            )
        }
        for (i in 0 until stickerBitmaps.size()) {
            stickerBitmaps.valueAt(i)?.takeIf { !it.isRecycled }?.recycle()
        }
        stickerBitmaps.clear()
    }

    private fun drawStickers(
        canvas: Canvas,
        snapshot: FaceLandmarkSnapshot,
        filter: FilterType,
        destW: Int,
        destH: Int,
        imgW: Int,
        imgH: Int,
        mirrorX: Boolean,
    ) {
        if (destW <= 0 || destH <= 0) return
        val scale = max(destW.toFloat() / imgW, destH.toFloat() / imgH)
        val offsetX = (destW - imgW * scale) / 2f
        val offsetY = (destH - imgH * scale) / 2f

        fun mapPoint(x: Float, y: Float): FloatArray {
            val mx = if (mirrorX) (imgW - x) * scale + offsetX else x * scale + offsetX
            return floatArrayOf(mx, y * scale + offsetY)
        }

        for (config in StickerCatalog.configsFor(filter)) {
            val bitmap = bitmapFor(config.drawableRes) ?: continue
            val pose = StickerScreenPoseResolver.resolve(config, snapshot, ::mapPoint) ?: continue
            drawIntactSticker(canvas, bitmap, pose)
        }
    }

    private fun drawIntactSticker(canvas: Canvas, bitmap: Bitmap, pose: StickerPose) {
        if (pose.width <= 0f) return
        val targetWidth = pose.width
        val targetHeight = if (pose.height > 0f) {
            pose.height
        } else {
            val aspect = bitmap.height.toFloat() / bitmap.width.toFloat().coerceAtLeast(1f)
            targetWidth * aspect
        }
        val dest = RectF(0f, 0f, targetWidth, targetHeight)
        canvas.save()
        canvas.translate(pose.centerX, pose.centerY)
        canvas.rotate(pose.rollDeg)
        canvas.scale(pose.yawScaleX, 1f)
        canvas.translate(-targetWidth * pose.pivotU, -targetHeight * pose.pivotV)
        canvas.drawBitmap(bitmap, null, dest, bitmapPaint)
        canvas.restore()
    }

    private companion object {
        /** Grace period before quitting the effect thread — see [release]. */
        const val THREAD_QUIT_DELAY_MS = 3_000L
    }

    private fun bitmapFor(resId: Int): Bitmap? {
        stickerBitmaps.get(resId)?.let { return it }
        val options = BitmapFactory.Options().apply {
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val loaded = BitmapFactory.decodeResource(appContext.resources, resId, options)
            ?: return null
        stickerBitmaps.put(resId, loaded)
        return loaded
    }
}
