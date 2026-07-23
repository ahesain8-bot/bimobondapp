package com.dubai.bimobondapp.ar_camera

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.RectF
import android.os.Handler
import android.os.HandlerThread
import android.util.Size
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
        val thread = HandlerThread("ar-sticker-overlay").also { it.start() }
        handlerThread = thread
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
                return@setOnDrawListener false
            }
            val canvas = frame.overlayCanvas
            canvas.drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR)
            val size: Size = frame.size
            // Match live FaceOverlayView: front-camera selfie is X-mirrored.
            // Baking without this flip puts glasses/moustache on the opposite side
            // of the face in the file (live OK, editor playback wrong).
            val mirrorX = isFrontCamera
            drawStickers(
                canvas = canvas,
                snapshot = snap,
                filter = filter,
                destW = size.width,
                destH = size.height,
                imgW = imgW,
                imgH = imgH,
                mirrorX = mirrorX,
            )
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
        try {
            handlerThread?.quitSafely()
        } catch (_: Exception) {
        }
        handlerThread = null
    }

    fun release() {
        closeEffectOnly()
        clear()
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
