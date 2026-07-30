package com.dubai.bimobondapp.ar_camera

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.Rect
import android.graphics.RectF
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.Process
import android.util.Log
import androidx.camera.core.CameraEffect
import androidx.camera.effects.OverlayEffect
import com.airbnb.lottie.LottieComposition
import com.airbnb.lottie.LottieDrawable
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.max
import kotlin.math.min

/**
 * Hardware-pipeline compositor for the full-screen Lottie filters
 * (Confetti/Keywords/Snowfall/Snow White), mirroring what
 * [StickerCameraOverlay] does for PNG stickers.
 *
 * Why this exists: these filters used to be baked into video by screenshotting
 * the live [androidx.camera.view.PreviewView] every tick and compositing on the
 * CPU (see ArCameraController's confetti frame pump). That approach could only
 * ever pick one of two bad outcomes — a synchronous `previewView.bitmap` read
 * blocks the main thread (jank), while every async capture alternative either
 * copies pre-transform pixels (stretched output) or forces the preview onto the
 * costlier TextureView path. Compositing here instead removes the dilemma
 * outright: CameraX hands us the video buffer, so nothing is read back to the
 * CPU and the main thread is never touched.
 *
 * ## Threading
 *
 * CameraX invokes the draw listener on its **video GL thread**, and then blocks
 * that thread until the overlay canvas post round-trips. Rasterizing vector art
 * inline there is therefore paid twice: once in GL-thread time and again in
 * frames handed to the encoder at uneven intervals. Throttling the whole
 * composite was tried and traded one artifact for another — the recording went
 * smooth but the baked animation itself visibly stepped, since it was then only
 * refreshing at half the video's frame rate.
 *
 * So the rasterization runs on its own thread instead, into a small rotating
 * pool of bitmaps, and the GL thread only ever does a clear plus one scaled
 * bitmap blit against whichever raster is finished. The animation updates at
 * full frame rate, and if the raster thread ever falls behind, the GL thread
 * simply finds nothing new and skips the canvas entirely (see the
 * `isOverlayDirty` note in the listener) rather than waiting on it.
 */
class ScreenOverlayCameraEffect {

    private companion object {
        /**
         * Raster cadence, deliberately FASTER than the recorder's ~33ms frame
         * interval. At exactly 33ms the two clocks beat against each other: some
         * encoded frames find a fresh raster, some reuse the previous one, and
         * the baked animation stutters even though the camera footage under it
         * is perfectly smooth. Running ahead means a new raster is essentially
         * always ready when a frame is drawn.
         */
        const val RASTER_IDLE_MS = 4L

        /**
         * How far ahead of the encoder the raster runs. Exactly one, on purpose:
         * only the newest raster is published (`readyBitmap` is overwritten, not
         * queued), so allowing two in flight would let one be skipped and the
         * animation would jump two frames at once — the very unevenness this
         * lock-step is meant to remove. A lead of one still gives the raster a
         * full frame interval of head start.
         */
        const val RASTER_LEAD_FRAMES = 1L

        /**
         * Starting guess for how much animation time one encoded frame is worth.
         * Replaced by the real, measured interval as soon as frames start
         * arriving — see [measuredFrameDeltaMs].
         */
        const val NOMINAL_FRAME_DELTA_MS = 1000f / ArFilteredVideoRecorder.FRAME_RATE

        /** Sanity bounds for a measured frame interval (about 100fps..8fps). */
        const val MIN_FRAME_DELTA_MS = 10f
        const val MAX_FRAME_DELTA_MS = 125f

        /** Weight of each new measurement; low so the pace can't jitter. */
        const val FRAME_DELTA_SMOOTHING = 0.15f

        /**
         * Frame interval above which the device is considered to be struggling.
         * The recorder targets 30fps (33ms); past this the pipeline is clearly
         * not keeping up.
         */
        const val SLOW_FRAME_THRESHOLD_MS = 45f

        /** Interval below which it is comfortably keeping up again. */
        const val FAST_FRAME_THRESHOLD_MS = 36f

        /**
         * How many encoded frames to skip between overlay updates, per level.
         * 0 = update every frame (best looking), 2 = every third frame.
         *
         * Updating the overlay means handing CameraX a fresh canvas, and CameraX
         * blocks its video GL thread until that canvas round-trips (up to 30ms).
         * On a capable phone that is affordable every frame; on a slower one the
         * same cost stalls camera frame delivery outright, which is what showed
         * up as the preview freezing during overlay recording. Backing off trades
         * a little overlay smoothness for a pipeline that keeps moving.
         */
        val SKIP_LEVELS = intArrayOf(0, 1, 2)

        /** Consecutive slow/fast frames before changing level — avoids flapping. */
        const val LEVEL_CHANGE_STREAK = 12

        const val TAG = "ArScreenOverlay"

        /**
         * Long-edge cap for the offscreen Lottie raster.
         *
         * Was briefly raised to 1080 to match FHD recording, but rasterizing
         * layer-heavy vector art at that size cannot finish inside the frame
         * budget — the raster thread fell behind the encoder and the baked
         * animation visibly stuttered. Smooth motion matters far more than
         * sharpness for soft particle effects, so this stays at 720 and gets
         * scaled up on the GPU.
         */
        const val RASTER_MAX_EDGE = 720

        /**
         * Bitmaps rotated through by the raster thread. The GL thread's blit is
         * only *recorded* during the draw listener — the pixels are read later,
         * when CameraX posts the canvas — so a buffer must not be reused for a
         * few cycles after it is handed over. Three gives ~100ms of slack.
         */
        const val BUFFER_COUNT = 3

        /** Grace period before quitting the effect thread — see [release]. */
        const val THREAD_QUIT_DELAY_MS = 3_000L
    }

    private val blitPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)

    private var handlerThread: HandlerThread? = null

    @Volatile
    private var overlayEffect: OverlayEffect? = null

    @Volatile
    private var composition: LottieComposition? = null

    // --- Raster thread state (touched only from the raster thread) ---
    private var rasterThread: HandlerThread? = null
    private var rasterHandler: Handler? = null
    private var drawable: LottieDrawable? = null
    private var buffers: Array<Bitmap>? = null
    private var bufferCanvases: Array<Canvas>? = null
    private var bufferIndex = 0

    /** Rastered frames produced so far — paces the loop against the encoder. */
    private var producedFrames = 0L

    /** Animation position, in composition milliseconds. Raster thread only. */
    private var animationTimeMs = 0f

    /**
     * How much animation time one encoded frame is worth, measured from the
     * frames CameraX actually delivers rather than assumed.
     *
     * This was the last piece of the stutter. The recorder is nominally 30fps,
     * but AE is allowed to drop the capture rate in dim light (see
     * ArCameraController.bestPreviewFpsRange, whose floor is 20fps), and the
     * interval varies frame to frame regardless. Advancing the animation by a
     * fixed 1/30s while the video ran at some other rate made the overlay drift
     * against the footage — smooth in isolation, subtly wrong next to it.
     */
    @Volatile
    private var measuredFrameDeltaMs = NOMINAL_FRAME_DELTA_MS

    /** Timestamp of the previous encoded frame, for measuring the interval. */
    private var lastFrameTimestampNs = 0L

    /** Index into [SKIP_LEVELS]; raised when the device can't keep up. */
    private var skipLevel = 0
    private var slowStreak = 0
    private var fastStreak = 0

    /** Frames seen since the last overlay update, for the current skip level. */
    private var framesSinceUpdate = 0

    /** Rastered frames the encoder has actually blitted. */
    private val consumedSeq = AtomicLong(0)

    @Volatile
    private var rasterRunning = false

    /** Output size the raster should target, published by the GL thread. */
    @Volatile
    private var rasterTargetW = 0

    @Volatile
    private var rasterTargetH = 0

    // --- Handoff between the raster thread and the GL thread ---
    private val bufferLock = Any()
    private var readyBitmap: Bitmap? = null
    private var readySeq = 0L

    /** GL thread only. */
    private var blittedSeq = -1L

    /**
     * The animation to bake. No progress supplier any more — the raster drives
     * itself from a clock, see [animationProgress].
     */
    fun setSource(composition: LottieComposition?) {
        this.composition = composition
    }

    fun clear() {
        composition = null
    }

    fun ensureEffect(): OverlayEffect {
        closeEffectOnly()
        // One long-lived thread for the whole object, deliberately NOT recreated
        // per effect. CameraX keeps posting to this executor while it tears an
        // effect down — quitting the thread alongside close() meant a late
        // onOutputSurface callback hit a dead Looper and threw
        // RejectedExecutionException on the main thread, killing the app.
        val thread = handlerThread ?: HandlerThread("ar-screen-overlay")
            .also { it.start(); handlerThread = it }
        val effect = OverlayEffect(
            CameraEffect.VIDEO_CAPTURE,
            // queueDepth 2, not 1: with no slack in the queue, the time this
            // listener spends (plus CameraX's blocking canvas post afterwards)
            // lands directly on camera frame delivery, so the BASE video picks
            // up the overlay's jitter too. One buffered frame lets the pipeline
            // absorb that at the cost of a frame of latency, which nothing here
            // is sensitive to — the preview is a separate stream.
            /* queueDepth */ 2,
            Handler(thread.looper),
        ) { /* draw errors are non-fatal */ }
        effect.setOnDrawListener { frame ->
            // Always true: the return value decides whether CameraX keeps the
            // VIDEO FRAME, not whether the overlay was updated. Returning false
            // would drop the frame outright and stutter the recording.
            if (composition == null) return@setOnDrawListener true
            val cropRect = frame.cropRect
            val rotation = normalizeRotation(frame.rotationDegrees)
            val quarterTurn = rotation == 90 || rotation == 270
            val outW = if (quarterTurn) cropRect.height() else cropRect.width()
            val outH = if (quarterTurn) cropRect.width() else cropRect.height()
            if (outW <= 0 || outH <= 0) return@setOnDrawListener true

            observeFrameInterval(frame.timestampNanos)
            startRaster(outW, outH)

            var bitmap: Bitmap?
            var seq: Long
            synchronized(bufferLock) {
                bitmap = readyBitmap
                seq = readySeq
            }
            // Skip level: leave the canvas alone on skipped frames so CameraX
            // reuses the last overlay texture and does no blocking post at all.
            val skip = SKIP_LEVELS[skipLevel]
            if (skip > 0) {
                if (framesSinceUpdate < skip) {
                    framesSinceUpdate++
                    return@setOnDrawListener true
                }
                framesSinceUpdate = 0
            }

            val ready = bitmap
            if (ready == null || ready.isRecycled || seq == blittedSeq) {
                // Nothing new to show. Deliberately does NOT touch
                // frame.overlayCanvas: CameraX only does its blocking canvas
                // round-trip when the canvas was requested, so leaving it alone
                // makes it reuse the last overlay texture for free.
                return@setOnDrawListener true
            }
            blittedSeq = seq
            // Tells the raster thread that one encoded frame consumed one
            // rastered frame; it advances the animation by exactly one frame's
            // worth in response. See [rasterTick].
            consumedSeq.incrementAndGet()

            val canvas = frame.overlayCanvas
            canvas.drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR)
            canvas.save()
            try {
                applyOutputToBufferTransform(canvas, cropRect, rotation, frame.isMirroring)
                canvas.drawBitmap(
                    ready,
                    null,
                    RectF(0f, 0f, outW.toFloat(), outH.toFloat()),
                    blitPaint,
                )
            } finally {
                canvas.restore()
            }
            true
        }
        blittedSeq = -1L
        overlayEffect = effect
        return effect
    }

    /**
     * GL thread. Tracks the real spacing of encoded frames so the raster can
     * advance the animation by exactly that much — see [measuredFrameDeltaMs].
     */
    private fun observeFrameInterval(timestampNs: Long) {
        val previous = lastFrameTimestampNs
        lastFrameTimestampNs = timestampNs
        if (previous <= 0L || timestampNs <= previous) return
        val deltaMs = (timestampNs - previous) / 1_000_000f
        // A dropped frame or a pipeline hiccup shows up as a huge gap; ignore
        // those rather than letting one spike distort the pace.
        if (deltaMs < MIN_FRAME_DELTA_MS || deltaMs > MAX_FRAME_DELTA_MS) return
        measuredFrameDeltaMs +=
            (deltaMs - measuredFrameDeltaMs) * FRAME_DELTA_SMOOTHING
        adaptSkipLevel(measuredFrameDeltaMs)
    }

    /**
     * Raises or lowers how often the overlay is refreshed based on how fast
     * frames are actually arriving. Both directions need a streak so a couple of
     * slow frames don't visibly change the overlay's pace.
     */
    private fun adaptSkipLevel(avgDeltaMs: Float) {
        if (avgDeltaMs > SLOW_FRAME_THRESHOLD_MS) {
            fastStreak = 0
            slowStreak++
            if (slowStreak >= LEVEL_CHANGE_STREAK && skipLevel < SKIP_LEVELS.lastIndex) {
                skipLevel++
                slowStreak = 0
                Log.i(TAG, "overlay backing off: skip=${SKIP_LEVELS[skipLevel]} avg=${avgDeltaMs}ms")
            }
        } else if (avgDeltaMs < FAST_FRAME_THRESHOLD_MS) {
            slowStreak = 0
            fastStreak++
            if (fastStreak >= LEVEL_CHANGE_STREAK && skipLevel > 0) {
                skipLevel--
                fastStreak = 0
                Log.i(TAG, "overlay recovering: skip=${SKIP_LEVELS[skipLevel]} avg=${avgDeltaMs}ms")
            }
        } else {
            slowStreak = 0
            fastStreak = 0
        }
    }

    // ---------------------------------------------------------------- raster

    private fun startRaster(targetW: Int, targetH: Int) {
        rasterTargetW = targetW
        rasterTargetH = targetH
        if (rasterRunning) return
        rasterRunning = true
        val thread = HandlerThread("ar-overlay-raster", Process.THREAD_PRIORITY_DEFAULT)
            .also { it.start() }
        rasterThread = thread
        val handler = Handler(thread.looper)
        rasterHandler = handler
        handler.post(rasterTick)
    }

    /**
     * Produces rastered frames in lock-step with what the encoder consumes.
     *
     * A free-running raster on a wall clock is still not smooth enough: each
     * encoded frame takes whichever raster happened to be newest, so the
     * animation advances by an amount that varies with how the two cadences
     * drift against each other. Instead the loop stays a fixed number of frames
     * ahead of the encoder and advances the animation by exactly one frame's
     * worth per frame consumed, which makes the baked motion perfectly even.
     *
     * If a raster ever takes longer than a frame the encoder simply reuses the
     * previous one — the animation holds briefly, but never jumps.
     */
    private val rasterTick = object : Runnable {
        override fun run() {
            if (!rasterRunning) return
            val comp = composition
            val w = rasterTargetW
            val h = rasterTargetH
            val lead = producedFrames - consumedSeq.get()
            if (comp != null && w > 0 && h > 0 && lead < RASTER_LEAD_FRAMES) {
                try {
                    renderNext(comp, w, h)
                    producedFrames++
                } catch (_: Throwable) {
                    // A bad frame is not worth killing the loop over.
                }
                rasterHandler?.post(this)
                return
            }
            // Far enough ahead (or nothing to draw yet) — idle briefly instead
            // of spinning the thread.
            rasterHandler?.postDelayed(this, RASTER_IDLE_MS)
        }
    }

    /**
     * Animation position for the next raster, derived from a monotonic clock
     * rather than sampled from the on-screen LottieAnimationView.
     *
     * Sampling the view was the other half of the stutter: that view advances on
     * the UI thread's vsync, and the UI thread is busy driving the camera preview
     * while recording, so its progress moves in uneven jumps. Reading it from a
     * different thread on a different cadence baked those jumps into the video.
     * A clock here makes every rastered frame advance by exactly the elapsed
     * time, which is what the encoder wants. The live preview keeps animating off
     * the view as before — this only governs what is written to the file.
     */
    private fun animationProgress(composition: LottieComposition): Float {
        val durationMs = composition.duration.takeIf { it > 0f } ?: return 0f
        animationTimeMs += measuredFrameDeltaMs
        if (animationTimeMs >= durationMs) animationTimeMs %= durationMs
        return animationTimeMs / durationMs
    }

    /** Raster thread. Draws the current animation position into the next buffer. */
    private fun renderNext(composition: LottieComposition, targetW: Int, targetH: Int) {
        val scale = min(1f, RASTER_MAX_EDGE.toFloat() / max(targetW, targetH))
        val bw = max(2, (targetW * scale).toInt())
        val bh = max(2, (targetH * scale).toInt())

        var pool = buffers
        var canvases = bufferCanvases
        if (pool == null || canvases == null || pool[0].width != bw || pool[0].height != bh) {
            pool = try {
                Array(BUFFER_COUNT) { Bitmap.createBitmap(bw, bh, Bitmap.Config.ARGB_8888) }
            } catch (_: Throwable) {
                return
            }
            canvases = Array(BUFFER_COUNT) { Canvas(pool[it]) }
            buffers = pool
            bufferCanvases = canvases
            bufferIndex = 0
            synchronized(bufferLock) { readyBitmap = null }
        }

        val index = bufferIndex
        bufferIndex = (bufferIndex + 1) % BUFFER_COUNT
        val target = pool[index]
        val canvas = canvases[index]
        target.eraseColor(Color.TRANSPARENT)

        val drw = drawable?.takeIf { it.composition === composition }
            ?: LottieDrawable().apply { setComposition(composition) }.also { drawable = it }
        drw.progress = animationProgress(composition)

        // Center-crop fit, matching the on-screen LottieAnimationView's
        // android:scaleType="centerCrop" (ar_camera_platform_view.xml).
        // LottieDrawable stretches the composition to whatever bounds it is given,
        // so the crop is expressed as an oversized, negatively offset rect.
        val srcW = composition.bounds.width().toFloat().coerceAtLeast(1f)
        val srcH = composition.bounds.height().toFloat().coerceAtLeast(1f)
        val fit = max(bw / srcW, bh / srcH)
        val scaledW = (srcW * fit).toInt()
        val scaledH = (srcH * fit).toInt()
        val left = (bw - scaledW) / 2
        val top = (bh - scaledH) / 2
        drw.setBounds(left, top, left + scaledW, top + scaledH)
        drw.draw(canvas)

        synchronized(bufferLock) {
            readyBitmap = target
            readySeq++
        }
    }

    private fun stopRaster() {
        rasterRunning = false
        rasterHandler?.removeCallbacksAndMessages(null)
        rasterHandler = null
        try {
            rasterThread?.quitSafely()
        } catch (_: Exception) {
        }
        rasterThread = null
        rasterTargetW = 0
        rasterTargetH = 0
        producedFrames = 0L
        consumedSeq.set(0)
        animationTimeMs = 0f
        measuredFrameDeltaMs = NOMINAL_FRAME_DELTA_MS
        lastFrameTimestampNs = 0L
        skipLevel = 0
        slowStreak = 0
        fastStreak = 0
        framesSinceUpdate = 0
        // Dropped rather than recycled: quitSafely() is asynchronous and the GL
        // thread may still hold a blit against one of these. GC is the safe owner.
        drawable = null
        buffers = null
        bufferCanvases = null
        bufferIndex = 0
        synchronized(bufferLock) {
            readyBitmap = null
            readySeq = 0L
        }
    }

    // ------------------------------------------------------------- geometry

    /**
     * Moves the canvas from *output* space (what the finished video looks like)
     * into the *input buffer* space the overlay canvas actually uses.
     *
     * This is what keeps the recorded overlay from coming out sideways. CameraX's
     * overlay fragment shader samples the overlay texture with the exact same
     * transformed coordinates as the camera texture, so the crop, rotation and
     * mirroring in [androidx.camera.effects.Frame] are applied to whatever we
     * draw here just as they are to the camera image — the canvas is the raw,
     * sensor-oriented buffer, not the upright frame. Drawing a full-screen
     * animation straight into it left it rotated by the buffer's own rotation
     * (snow drifting sideways instead of falling). Pre-applying the inverse here
     * cancels that out for any rotation, and pre-mirroring cancels the
     * front-camera mirror so text-bearing overlays stay readable.
     *
     * Order matches CameraX's own `TransformUtils.getRectToRect`: rotate first,
     * then mirror horizontally in output space.
     */
    private fun applyOutputToBufferTransform(
        canvas: Canvas,
        cropRect: Rect,
        rotation: Int,
        mirroring: Boolean,
    ) {
        val quarterTurn = rotation == 90 || rotation == 270
        val outW = (if (quarterTurn) cropRect.height() else cropRect.width()).toFloat()
        val outH = (if (quarterTurn) cropRect.width() else cropRect.height()).toFloat()

        // Canvas concatenation is pre-multiplying: the LAST op listed here is the
        // first one applied to the drawn geometry, so this reads bottom-up —
        // un-mirror, then un-rotate, then shift into the crop's place.
        canvas.translate(cropRect.left.toFloat(), cropRect.top.toFloat())
        if (rotation != 0) {
            val m = Matrix()
            m.postRotate(-rotation.toFloat())
            // Rotating about the origin throws the rect into negative space; pull
            // it back so the output rect lands exactly on the crop rect.
            val bounds = RectF(0f, 0f, outW, outH)
            m.mapRect(bounds)
            m.postTranslate(-bounds.left, -bounds.top)
            canvas.concat(m)
        }
        if (mirroring) {
            canvas.translate(outW, 0f)
            canvas.scale(-1f, 1f)
        }
    }

    private fun normalizeRotation(degrees: Int): Int = ((degrees % 360) + 360) % 360

    // -------------------------------------------------------------- lifecycle

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
        // Thread intentionally left running — see ensureEffect. It is torn down
        // in release(), and even then only after a delay.
        stopRaster()
        blittedSeq = -1L
    }

    fun release() {
        closeEffectOnly()
        clear()
        // Delayed so callbacks CameraX has already queued still land on a live
        // Looper. Quitting immediately is what crashed the app.
        val thread = handlerThread
        handlerThread = null
        if (thread != null) {
            Handler(Looper.getMainLooper()).postDelayed(
                { runCatching { thread.quitSafely() } },
                THREAD_QUIT_DELAY_MS,
            )
        }
    }
}
