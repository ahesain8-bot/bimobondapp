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
    private const val REQUIRED_FREE_BYTES = 900L * 1024 * 1024

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
     * True when a hardware H.264 encoder lists 1080p30 as a *performance point*.
     *
     * [MediaCodecInfo.VideoCapabilities.getSupportedPerformancePoints] is the
     * only API that reports a sustainable rate rather than a merely accepted
     * size — `areSizeAndRateSupported` answers "will I configure this", which
     * is exactly the over-claim that made the SM6225 look capable. Where the
     * API is unavailable (below Android 10) we answer no and stay at 720p,
     * because an old platform is not the place to gamble on this.
     */
    private fun encoderSustains1080p30(): Boolean {
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
                points.any { it.covers(MediaCodecInfo.VideoCapabilities.PerformancePoint.FHD_30) }
            }
        } catch (t: Throwable) {
            Log.w(TAG, "encoder capability probe failed; assuming 720p", t)
            false
        }
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
        val encoder = encoderSustains1080p30()
        val allowed = !lowRam && free >= REQUIRED_FREE_BYTES && encoder
        Log.i(
            TAG,
            "1080p allowed=$allowed (lowRam=$lowRam " +
                "freeMB=${free / (1024 * 1024)} " +
                "needMB=${REQUIRED_FREE_BYTES / (1024 * 1024)} " +
                "encoderFhd30=$encoder)",
        )
        return allowed
    }
}
