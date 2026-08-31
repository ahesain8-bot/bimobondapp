package com.dubai.bimobondapp.ar_camera

import android.app.ActivityManager
import android.content.Context
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaFormat
import android.os.Build
import android.util.Log

/**
 * Decides whether this handset may publish a live broadcast at 1080p.
 *
 * The host pipeline is not just an encoder: every frame also goes through the
 * AR face-warp shader before it reaches WebRTC, and 1080p simulcast runs three
 * encoders at once (1080p + 720p + 480p) rather than two. A chip can advertise
 * 1080p H.264 and still be nowhere near able to sustain that combination.
 *
 * An HONOR LGN-LX2 (Snapdragon SM6225 / Adreno 610, 8 cores, 8GB) is the
 * device this exists for: it reports plenty of RAM and enough cores to pass any
 * naive check, and it advertises 1080p encoding — but measured live it sat at
 * 90% CPU with a 101ms median frame (~10fps), 94% janky frames, 1.1GB RSS
 * against 125MB free, and was then killed by the low-memory killer. So core
 * count and total RAM are deliberately *not* the test. The test is what the
 * encoder claims it can sustain, plus the memory actually free right now.
 */
object LiveCaptureCapability {
    private const val TAG = "LiveCaptureCapability"

    /** Free system memory required before 1080p is even considered. */
    private const val REQUIRED_FREE_BYTES = 1200L * 1024 * 1024

    /**
     * Publishing 1080p from a 720p panel only upscales the already-rendered
     * AR frame. It adds GPU pixels and a third simulcast encoder without any
     * source detail for viewers, so keep that whole class of phones at 720p.
     */
    private fun hasFullHdDisplay(context: Context): Boolean {
        val metrics = context.resources.displayMetrics
        val shortEdge = minOf(metrics.widthPixels, metrics.heightPixels)
        val longEdge = maxOf(metrics.widthPixels, metrics.heightPixels)
        return shortEdge >= 1080 && longEdge >= 1920
    }

    /** Below this the platform tells us outright it cannot afford big buffers. */
    private fun isLowRam(context: Context): Boolean {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            ?: return true
        return am.isLowRamDevice
    }

    private fun freeBytes(context: Context): Long {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            ?: return 0
        val info = ActivityManager.MemoryInfo()
        am.getMemoryInfo(info)
        return info.availMem
    }

    /**
     * True when a hardware H.264 encoder lists 1080p60 as a *performance point*.
     *
     * [MediaCodecInfo.VideoCapabilities.getSupportedPerformancePoints] is the
     * only API that reports a sustainable rate rather than a merely accepted
     * size — `areSizeAndRateSupported` answers "will I configure this", which
     * is exactly the over-claim that made the SM6225 look capable. Where the
     * API is unavailable (below Android 10) we answer no and stay at 720p,
     * because an old platform is not the place to gamble on this.
     */
    private fun encoderHasFullHdHeadroom(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        return try {
            val codecs = MediaCodecList(MediaCodecList.REGULAR_CODECS)
            codecs.codecInfos.any { info ->
                if (!info.isEncoder) return@any false
                if (!info.isHardwareAccelerated) return@any false
                if (!info.supportedTypes.any { it.equals(MediaFormat.MIMETYPE_VIDEO_AVC, true) }) {
                    return@any false
                }
                val video = info
                    .getCapabilitiesForType(MediaFormat.MIMETYPE_VIDEO_AVC)
                    .videoCapabilities ?: return@any false
                val points = video.supportedPerformancePoints ?: return@any false
                // FHD_30 only proves that an *unfiltered single* encode may
                // configure. The live pipeline also renders AR and simulcast,
                // so require FHD_60 headroom before allowing a 1080p layer.
                points.any { it.covers(MediaCodecInfo.VideoCapabilities.PerformancePoint.FHD_60) }
            }
        } catch (t: Throwable) {
            Log.w(TAG, "encoder capability probe failed; assuming 720p", t)
            false
        }
    }

    /**
     * Cached SoC-tier answer, so the preview bind does not re-probe MediaCodec.
     *
     * Separate from [allowsFullHd] on purpose: that one also weighs free
     * memory, which moves minute to minute, and a preview resolution that
     * flapped with memory pressure would rebind the camera mid-broadcast.
     */
    private var sustainsFullHdCache: Boolean? = null

    /**
     * Preview size the AR pipeline should bind, in portrait orientation.
     *
     * Every frame goes through the face-warp shader before it reaches either
     * the screen or WebRTC, so this is the single biggest lever on how smooth
     * a broadcast feels: 1080x1920 is 2.25x the fragment work of 720x1280.
     * On an Adreno 610 that difference is the gap between a broadcast that
     * moves and one measured at a 101ms median frame — and since the publish
     * ladder starts at 720p on exactly those devices, the extra pixels were
     * being rendered and then discarded by the scaler.
     *
     * Devices that pass the tier check keep 1080p, where the ceiling on
     * recording and photo quality still matters.
     */
    fun previewTargetPortrait(context: Context): Pair<Int, Int> {
        val encoderHasHeadroom = sustainsFullHdCache ?: encoderHasFullHdHeadroom().also {
            sustainsFullHdCache = it
            Log.i(TAG, "preview tier probe: encoderHasFullHdHeadroom=$it")
        }
        val fullHd = encoderHasHeadroom && hasFullHdDisplay(context)
        return if (fullHd) 1080 to 1920 else 720 to 1280
    }

    /**
     * Whether the host may *start* at 1080p.
     *
     * A false answer is not a failure: the publish ladder starts at 720p and
     * the broadcast is otherwise identical. A true answer is still only a
     * ceiling — `_waitForOutboundVideo` and the ladder walk on the Dart side
     * remain the thing that proves frames are actually leaving the handset.
     */
    fun allowsFullHd(context: Context): Boolean {
        val lowRam = isLowRam(context)
        val free = freeBytes(context)
        val encoder = sustainsFullHdCache ?: encoderHasFullHdHeadroom().also {
            sustainsFullHdCache = it
        }
        val display = hasFullHdDisplay(context)
        val allowed = !lowRam && free >= REQUIRED_FREE_BYTES && encoder && display
        Log.i(
            TAG,
            "1080p allowed=$allowed (lowRam=$lowRam " +
                "freeMB=${free / (1024 * 1024)} " +
                "needMB=${REQUIRED_FREE_BYTES / (1024 * 1024)} " +
                "encoderFhd60=$encoder displayFhd=$display)",
        )
        return allowed
    }
}
