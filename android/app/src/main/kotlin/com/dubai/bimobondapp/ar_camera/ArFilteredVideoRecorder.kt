package com.dubai.bimobondapp.ar_camera

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Rect
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaRecorder
import android.os.Handler
import android.os.HandlerThread
import android.os.SystemClock
import android.util.Log
import android.view.Surface
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max
import kotlin.math.min

class ArFilteredVideoRecorder {

    private val lock = Any()
    private var codec: MediaCodec? = null
    private var muxer: MediaMuxer? = null
    private var inputSurface: Surface? = null
    private var trackIndex = -1
    private var muxerStarted = false
    private var frameIndex = 0L
    private var width = 0
    private var height = 0

    private var finalOutputFile: File? = null
    private var videoTempFile: File? = null
    private var audioTempFile: File? = null
    private var mediaRecorder: MediaRecorder? = null
    private var audioRecording = false

    private val armed = AtomicBoolean(false)
    private val running = AtomicBoolean(false)
    private var drainThread: HandlerThread? = null
    private var drainHandler: Handler? = null

    /**
     * Set by [stop] between clearing [running] and signalling end-of-stream, so
     * [drainLoop] keeps polling for the encoder's final samples instead of
     * exiting the moment `running` goes false.
     */
    @Volatile
    private var awaitingEos = false

    /** Counted down when [drainLoop] exits, so [stop] can wait for the real
     *  end of the encoded stream rather than sleeping a fixed guess. */
    @Volatile
    private var drainDone: CountDownLatch? = null

    @Volatile
    private var surfaceSession = false

    fun isRecording(): Boolean = armed.get() || running.get()

    fun arm(output: File) {
        synchronized(lock) {
            abortInternal()
            finalOutputFile = output
            val parent = output.parentFile ?: output.absoluteFile.parentFile
            val base = output.nameWithoutExtension
            videoTempFile = File(parent, "${base}_v.mp4")
            audioTempFile = File(parent, "${base}_a.m4a")
            videoTempFile?.delete()
            audioTempFile?.delete()
            armed.set(true)
            frameIndex = 0
            surfaceSession = false
        }
    }

    fun startSurfaceSession(output: File, width: Int, height: Int): Surface? {
        synchronized(lock) {
            abortInternal()
            finalOutputFile = output
            val parent = output.parentFile ?: output.absoluteFile.parentFile
            val base = output.nameWithoutExtension
            videoTempFile = File(parent, "${base}_v.mp4")
            audioTempFile = File(parent, "${base}_a.m4a")
            videoTempFile?.delete()
            audioTempFile?.delete()
            armed.set(false)
            frameIndex = 0
            surfaceSession = true
            val out = videoTempFile ?: return null
            return try {
                // width/height here are already scaled by the caller (ArCameraController)
                // to match exactly what it configures the GL viewport/encoder target to —
                // do NOT rescale again with this class's own MAX_EDGE, or the encoder's
                // actual Surface buffer ends up a different size than what GL renders
                // into, which crops/zooms the encoded output relative to the live view.
                startEncoder(out, width, height, rescale = false)
                inputSurface
            } catch (e: Exception) {
                Log.e(TAG, "startSurfaceSession failed", e)
                abortInternal()
                null
            }
        }
    }

    fun isSurfaceSession(): Boolean = surfaceSession

    fun offerFrame(bitmap: Bitmap) {
        if (surfaceSession) return
        if (!armed.get() && !running.get()) return
        synchronized(lock) {
            if (!running.get()) {
                if (!armed.get()) return
                val out = videoTempFile ?: return
                startEncoder(out, bitmap.width, bitmap.height)
            }
        }
        if (!running.get()) return
        val surface = inputSurface ?: return
        try {
            val canvas = surface.lockHardwareCanvas()
            try {
                canvas.drawColor(Color.BLACK)
                drawCenterCrop(canvas, bitmap, width, height)
            } finally {
                surface.unlockCanvasAndPost(canvas)
            }
            frameIndex++
        } catch (e: Exception) {
            Log.w(TAG, "offerFrame failed", e)
        }
    }

    fun stop(): File? {
        synchronized(lock) {
            val tStop = SystemClock.elapsedRealtime()
            armed.set(false)
            val hadVideo = running.getAndSet(false)
            if (hadVideo) {
                // Wait for the encoder's actual end-of-stream instead of sleeping
                // a fixed 150ms guess. The drain loop already recognises
                // BUFFER_FLAG_END_OF_STREAM and exits on it, so the fixed sleep
                // was both slower than needed in the common case (the encoder
                // typically drains in a few tens of ms — that difference is dead
                // time in the post-record "Processing..." state) and no guarantee
                // in the rare slow case. The timeout keeps the old worst-case
                // behaviour of giving up rather than hanging.
                awaitingEos = true
                try {
                    codec?.signalEndOfInputStream()
                } catch (_: Exception) {
                }
                try {
                    drainDone?.await(EOS_DRAIN_TIMEOUT_MS, TimeUnit.MILLISECONDS)
                } catch (_: InterruptedException) {
                }
                awaitingEos = false
            }
            val tDrained = SystemClock.elapsedRealtime()
            releaseVideoEncoder()
            stopMicRecorder()
            surfaceSession = false

            val video = videoTempFile
            val audio = audioTempFile
            val finalOut = finalOutputFile
            Log.i(
                TAG,
                "recording stopped frames=$frameIndex " +
                    "videoBytes=${video?.length() ?: 0} audioBytes=${audio?.length() ?: 0}",
            )

            var result = when {
                finalOut == null -> null
                video != null && video.exists() && video.length() > 0L -> {
                    muxAv(video, audio, finalOut)
                }
                else -> null
            }
            val tMuxed = SystemClock.elapsedRealtime()

            // A non-empty file is not the same as a playable one. On devices whose
            // encoder quietly produced a stream it couldn't actually encode, the
            // file exists with a sensible size but has no readable video track —
            // and the editor then sits on a spinner forever waiting for a player
            // that will never initialise. Better to report failure here, where the
            // caller can show a real error.
            if (result != null && !isPlayable(result)) {
                Log.e(TAG, "recorded file has no readable video track — discarding")
                try {
                    result.delete()
                } catch (_: Exception) {
                }
                result = null
            }

            cleanupTemps()
            finalOutputFile = null
            val tEnd = SystemClock.elapsedRealtime()
            Log.i(
                TAG,
                "stop timing: drain=${tDrained - tStop}ms " +
                    "release+mux=${tMuxed - tDrained}ms " +
                    "verify+cleanup=${tEnd - tMuxed}ms total=${tEnd - tStop}ms",
            )
            return result
        }
    }

    /**
     * True when [file] has a video track a player can actually read. Cheap: opens
     * the container and reads track metadata only, no decoding.
     */
    private fun isPlayable(file: File): Boolean {
        val extractor = MediaExtractor()
        return try {
            extractor.setDataSource(file.absolutePath)
            var hasVideo = false
            for (i in 0 until extractor.trackCount) {
                val mime = extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME)
                if (mime?.startsWith("video/") == true) {
                    hasVideo = true
                    break
                }
            }
            hasVideo
        } catch (t: Throwable) {
            Log.w(TAG, "playability check failed for ${file.name}", t)
            false
        } finally {
            try {
                extractor.release()
            } catch (_: Exception) {
            }
        }
    }

    fun abort() {
        synchronized(lock) {
            armed.set(false)
            running.set(false)
            releaseVideoEncoder()
            stopMicRecorder()
            cleanupTemps()
            finalOutputFile = null
        }
    }

    private fun startMicRecorder() {
        val audioFile = audioTempFile ?: return
        try {
            @Suppress("DEPRECATION")
            val recorder = MediaRecorder()
            recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
            recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            recorder.setAudioSamplingRate(44_100)
            recorder.setAudioEncodingBitRate(128_000)
            recorder.setAudioChannels(1)
            recorder.setOutputFile(audioFile.absolutePath)
            recorder.prepare()
            recorder.start()
            mediaRecorder = recorder
            audioRecording = true
            Log.i(TAG, "mic recorder started ${audioFile.name}")
        } catch (e: SecurityException) {
            Log.e(TAG, "mic permission missing — video will be silent", e)
            releaseMicOnly()
        } catch (e: Exception) {
            Log.e(TAG, "mic recorder failed — video will be silent", e)
            releaseMicOnly()
        }
    }

    private fun stopMicRecorder() {
        val recorder = mediaRecorder ?: return
        try {
            if (audioRecording) {
                recorder.stop()
            }
        } catch (e: Exception) {
            Log.w(TAG, "mic stop failed", e)
        }
        audioRecording = false
        try {
            recorder.release()
        } catch (_: Exception) {
        }
        mediaRecorder = null
    }

    private fun releaseMicOnly() {
        audioRecording = false
        try {
            mediaRecorder?.release()
        } catch (_: Exception) {
        }
        mediaRecorder = null
    }

    private fun startEncoder(output: File, srcW: Int, srcH: Int, rescale: Boolean = true) {
        if (rescale) {
            val maxEdge = MAX_EDGE
            val scale = min(1f, maxEdge.toFloat() / max(srcW, srcH))
            width = ((srcW * scale).toInt() and 1.inv()).coerceAtLeast(2)
            height = ((srcH * scale).toInt() and 1.inv()).coerceAtLeast(2)
        } else {
            width = (srcW and 1.inv()).coerceAtLeast(2)
            height = (srcH and 1.inv()).coerceAtLeast(2)
        }
        trackIndex = -1
        muxerStarted = false

        val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        // Ask the device's encoder what it can actually do instead of assuming.
        // Hardcoded settings (High profile, up to 24Mbps) worked on capable
        // phones and produced an unplayable file on weaker ones — which showed
        // up much later as the editor sitting on a spinner forever.
        val encoder1 = encoder
        var configured = false
        try {
            encoder1.configure(
                buildTunedFormat(encoder1, width, height),
                null,
                null,
                MediaCodec.CONFIGURE_FLAG_ENCODE,
            )
            configured = true
        } catch (t: Throwable) {
            Log.w(TAG, "tuned encoder config rejected — falling back", t)
        }
        if (!configured) {
            // Last resort: the plainest format that any AVC encoder must accept.
            // No profile/level, conservative bitrate. Recording at lower quality
            // beats not recording, and beats writing a file that won't play.
            encoder1.reset()
            encoder1.configure(
                buildSafeFormat(width, height),
                null,
                null,
                MediaCodec.CONFIGURE_FLAG_ENCODE,
            )
        }
        inputSurface = encoder.createInputSurface()
        encoder.start()
        codec = encoder
        muxer = MediaMuxer(output.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

        val thread = HandlerThread("ar-video-drain").also { it.start() }
        drainThread = thread
        drainHandler = Handler(thread.looper)
        awaitingEos = false
        drainDone = CountDownLatch(1)
        running.set(true)
        armed.set(false)
        startMicRecorder()
        drainHandler?.post { drainLoop() }
        Log.i(TAG, "encoder started ${output.name} ${width}x$height (src ${srcW}x$srcH)")
    }

    private fun drawCenterCrop(canvas: Canvas, bitmap: Bitmap, dstW: Int, dstH: Int) {
        val srcW = bitmap.width.toFloat()
        val srcH = bitmap.height.toFloat()
        if (srcW <= 0f || srcH <= 0f) return

        val srcAspect = srcW / srcH
        val dstAspect = dstW.toFloat() / dstH.toFloat()
        val srcRect: Rect
        if (srcAspect > dstAspect) {
            val newW = srcH * dstAspect
            val left = (srcW - newW) * 0.5f
            srcRect = Rect(left.toInt(), 0, (left + newW).toInt(), srcH.toInt())
        } else {
            val newH = srcW / dstAspect
            val top = (srcH - newH) * 0.5f
            srcRect = Rect(0, top.toInt(), srcW.toInt(), (top + newH).toInt())
        }
        val paint = android.graphics.Paint(android.graphics.Paint.FILTER_BITMAP_FLAG)
        canvas.drawBitmap(bitmap, srcRect, Rect(0, 0, dstW, dstH), paint)
    }

    private fun abortInternal() {
        running.set(false)
        armed.set(false)
        // Must clear before releasing the encoder: a drain loop still parked on
        // dequeueOutputBuffer would otherwise keep polling for an end-of-stream
        // that an aborted session never sends.
        awaitingEos = false
        drainDone?.countDown()
        surfaceSession = false
        releaseVideoEncoder()
        stopMicRecorder()
        cleanupTemps()
        finalOutputFile = null
    }

    private fun drainLoop() {
        try {
            drainLoopInner()
        } finally {
            drainDone?.countDown()
        }
    }

    private fun drainLoopInner() {
        val bufferInfo = MediaCodec.BufferInfo()
        while (running.get() || muxerStarted) {
            val encoder = codec ?: break
            val outIndex = try {
                encoder.dequeueOutputBuffer(bufferInfo, 10_000)
            } catch (_: Exception) {
                break
            }
            when {
                outIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    // While stopping, keep polling: the end-of-stream buffer has
                    // been requested but has not arrived yet, and breaking here
                    // would drop the clip's final samples.
                    if (!running.get() && !awaitingEos) break
                }
                outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    val mux = muxer ?: break
                    if (muxerStarted) continue
                    trackIndex = mux.addTrack(encoder.outputFormat)
                    mux.start()
                    muxerStarted = true
                }
                outIndex >= 0 -> {
                    val encoded = encoder.getOutputBuffer(outIndex)
                    if (encoded != null && bufferInfo.size > 0 && muxerStarted) {
                        encoded.position(bufferInfo.offset)
                        encoded.limit(bufferInfo.offset + bufferInfo.size)
                        muxer?.writeSampleData(trackIndex, encoded, bufferInfo)
                    }
                    encoder.releaseOutputBuffer(outIndex, false)
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        break
                    }
                }
            }
        }
    }

    private fun releaseVideoEncoder() {
        try {
            inputSurface?.release()
        } catch (_: Exception) {
        }
        inputSurface = null
        try {
            codec?.stop()
            codec?.release()
        } catch (_: Exception) {
        }
        codec = null
        try {
            if (muxerStarted) muxer?.stop()
            muxer?.release()
        } catch (_: Exception) {
        }
        muxer = null
        muxerStarted = false
        drainThread?.quitSafely()
        drainThread = null
        drainHandler = null
        width = 0
        height = 0
    }

    private fun cleanupTemps() {
        try {
            videoTempFile?.delete()
        } catch (_: Exception) {
        }
        try {
            audioTempFile?.delete()
        } catch (_: Exception) {
        }
        videoTempFile = null
        audioTempFile = null
    }

    private fun muxAv(videoFile: File, audioFile: File?, outFile: File): File {
        outFile.delete()
        val hasAudio = audioFile != null && audioFile.exists() && audioFile.length() > 512L
        if (!hasAudio) {
            Log.w(TAG, "mux: no usable audio, copying video only")
            videoFile.copyTo(outFile, overwrite = true)
            return outFile
        }

        val videoExtractor = MediaExtractor()
        val audioExtractor = MediaExtractor()
        var muxer: MediaMuxer? = null
        try {
            videoExtractor.setDataSource(videoFile.absolutePath)
            audioExtractor.setDataSource(audioFile!!.absolutePath)

            val videoTrack = findTrack(videoExtractor, "video/")
            val audioTrack = findTrack(audioExtractor, "audio/")
            if (videoTrack < 0) {
                Log.e(TAG, "mux: video track missing")
                videoFile.copyTo(outFile, overwrite = true)
                return outFile
            }

            muxer = MediaMuxer(outFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            videoExtractor.selectTrack(videoTrack)
            val outVideo = muxer.addTrack(videoExtractor.getTrackFormat(videoTrack))
            var outAudio = -1
            if (audioTrack >= 0) {
                audioExtractor.selectTrack(audioTrack)
                outAudio = muxer.addTrack(audioExtractor.getTrackFormat(audioTrack))
            }
            muxer.start()

            copySamples(videoExtractor, muxer, outVideo)
            if (outAudio >= 0) {
                copySamples(audioExtractor, muxer, outAudio)
            }

            Log.i(
                TAG,
                "mux ok out=${outFile.length()}b videoIn=${videoFile.length()}b audioIn=${audioFile.length()}b",
            )
            return outFile
        } catch (e: Exception) {
            Log.e(TAG, "mux failed — returning video only", e)
            try {
                outFile.delete()
            } catch (_: Exception) {
            }
            videoFile.copyTo(outFile, overwrite = true)
            return outFile
        } finally {
            try {
                videoExtractor.release()
            } catch (_: Exception) {
            }
            try {
                audioExtractor.release()
            } catch (_: Exception) {
            }
            try {
                muxer?.stop()
            } catch (_: Exception) {
            }
            try {
                muxer?.release()
            } catch (_: Exception) {
            }
        }
    }

    private fun findTrack(extractor: MediaExtractor, mimePrefix: String): Int {
        for (i in 0 until extractor.trackCount) {
            val mime = extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME) ?: continue
            if (mime.startsWith(mimePrefix)) return i
        }
        return -1
    }

    private fun copySamples(extractor: MediaExtractor, muxer: MediaMuxer, trackIndex: Int) {
        val buffer = ByteBuffer.allocate(1024 * 1024)
        val info = MediaCodec.BufferInfo()
        extractor.seekTo(0, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
        while (true) {
            val sampleSize = extractor.readSampleData(buffer, 0)
            if (sampleSize < 0) break
            info.offset = 0
            info.size = sampleSize
            info.presentationTimeUs = extractor.sampleTime.coerceAtLeast(0L)
            info.flags = extractor.sampleFlags
            muxer.writeSampleData(trackIndex, buffer, info)
            if (!extractor.advance()) break
        }
    }

    /**
     * Encoder format tuned to what THIS device's encoder reports it can handle.
     *
     * Everything here used to be hardcoded, which is how a file that plays fine
     * on one phone came out unplayable on another. Now every value is clamped to
     * the codec's own advertised capabilities.
     */
    private fun buildTunedFormat(encoder: MediaCodec, width: Int, height: Int): MediaFormat {
        val caps = try {
            encoder.codecInfo.getCapabilitiesForType(MediaFormat.MIMETYPE_VIDEO_AVC)
        } catch (t: Throwable) {
            Log.w(TAG, "codec capabilities unavailable", t)
            return buildSafeFormat(width, height)
        }
        val video = caps.videoCapabilities

        // Frame rate the encoder will actually sustain at this size.
        val frameRate = try {
            video?.getSupportedFrameRatesFor(width, height)
                ?.let { FRAME_RATE.coerceAtMost(it.upper.toInt()) }
                ?: FRAME_RATE
        } catch (_: Throwable) {
            FRAME_RATE
        }.coerceAtLeast(1)

        // ~0.3 bits per pixel per frame keeps gradients, skin texture and
        // high-frequency beauty output clean through a later social upload.
        // Clamp into the encoder's own supported bitrate range —
        // asking for more than it advertises is what corrupted the output.
        val desired = width.toLong() * height.toLong() * frameRate * 3 / 10
        val bitRate = try {
            val range = video?.bitrateRange
            if (range != null) {
                desired.coerceIn(range.lower.toLong(), range.upper.toLong())
            } else {
                desired.coerceIn(4_000_000L, 20_000_000L)
            }
        } catch (_: Throwable) {
            desired.coerceIn(4_000_000L, 20_000_000L)
        }.toInt()

        val format = MediaFormat.createVideoFormat(
            MediaFormat.MIMETYPE_VIDEO_AVC,
            width,
            height,
        ).apply {
            setInteger(
                MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface,
            )
            setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
            setInteger(MediaFormat.KEY_FRAME_RATE, frameRate)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }

        // Highest High-profile level the encoder lists, not the first one found.
        // profileLevels has no defined order, so firstOrNull could pick a level
        // far too low for the resolution/bitrate above — the encoder then either
        // rejects the config or silently writes a broken stream.
        try {
            val highestLevel = caps.profileLevels
                .filter { it.profile == MediaCodecInfo.CodecProfileLevel.AVCProfileHigh }
                .maxOfOrNull { it.level }
            if (highestLevel != null) {
                format.setInteger(
                    MediaFormat.KEY_PROFILE,
                    MediaCodecInfo.CodecProfileLevel.AVCProfileHigh,
                )
                format.setInteger(MediaFormat.KEY_LEVEL, highestLevel)
            }
        } catch (t: Throwable) {
            Log.w(TAG, "profile/level not applied", t)
        }

        Log.i(
            TAG,
            "encoder tuned ${width}x$height @${frameRate}fps ${bitRate / 1000}kbps",
        )
        return format
    }

    /** Plainest format any AVC encoder must accept — the fallback path. */
    private fun buildSafeFormat(width: Int, height: Int): MediaFormat {
        return MediaFormat.createVideoFormat(
            MediaFormat.MIMETYPE_VIDEO_AVC,
            width,
            height,
        ).apply {
            setInteger(
                MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface,
            )
            setInteger(MediaFormat.KEY_BIT_RATE, 10_000_000)
            setInteger(MediaFormat.KEY_FRAME_RATE, FRAME_RATE)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }
    }

    companion object {
        private const val TAG = "ArFilteredVideoRecorder"

        /** Upper bound on waiting for the encoder's end-of-stream in [stop].
         *  Generous on purpose — it is a safety net, not the expected path;
         *  a healthy encoder drains in far less and [stop] returns immediately. */
        private const val EOS_DRAIN_TIMEOUT_MS = 600L
        const val MAX_EDGE = 1280
        const val FRAME_RATE = 30
    }
}
