package com.dubai.bimobondapp.camera_engine

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaRecorder
import android.os.Handler
import android.os.HandlerThread
import android.os.StatFs
import android.util.Log
import android.view.Surface
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Phase 9–10: hardware H.264 encoding via MediaCodec input Surface + AAC mic,
 * with optional music mix (video track copied — no video re-encode).
 *
 * Video frames are fed by GL (no Bitmap). Audio is captured with MediaRecorder
 * to a sidecar, then muxed / mixed into the final MP4 on stop.
 */
class HardwareVideoRecorder {
    companion object {
        private const val TAG = "HwVideoRecorder"
        private const val MIME = MediaFormat.MIMETYPE_VIDEO_AVC
        private const val FRAME_RATE = 30
        private const val I_FRAME_INTERVAL = 1
        private const val BITRATE = 8_000_000
        private const val MIN_FREE_BYTES = 80L * 1024L * 1024L
        const val MAX_WIDTH = 1080
        const val MAX_HEIGHT = 1920
    }

    private val lock = Any()
    private var codec: MediaCodec? = null
    private var muxer: MediaMuxer? = null
    private var inputSurface: Surface? = null
    private var trackIndex = -1
    private var muxerStarted = false

    private var finalOutputFile: File? = null
    private var videoTempFile: File? = null
    private var audioTempFile: File? = null
    private var mediaRecorder: MediaRecorder? = null
    private var audioRecording = false
    private var musicConfig: AudioMusicMixer.Config = AudioMusicMixer.Config()

    private val running = AtomicBoolean(false)
    private var drainThread: HandlerThread? = null
    private var drainHandler: Handler? = null

    @Volatile
    private var awaitingEos = false

    @Volatile
    private var drainDone: CountDownLatch? = null

    @Volatile
    private var startedAtMs: Long = 0L

    var width: Int = 0
        private set
    var height: Int = 0
        private set

    fun isRecording(): Boolean = running.get()

    fun durationMs(): Long {
        if (!running.get() || startedAtMs == 0L) return 0L
        return (System.currentTimeMillis() - startedAtMs).coerceAtLeast(0L)
    }

    fun inputSurface(): Surface? = synchronized(lock) { inputSurface }

    /** Returns null on success, or an error code string. */
    fun checkStorage(dir: File): String? {
        return try {
            val path = if (dir.exists()) dir else dir.parentFile ?: dir
            val stat = StatFs(path.absolutePath)
            val free = stat.availableBlocksLong * stat.blockSizeLong
            if (free < MIN_FREE_BYTES) "low_storage" else null
        } catch (t: Throwable) {
            Log.w(TAG, "storage check", t)
            null
        }
    }

    /**
     * Start hardware encoding into [output] (final muxed path after stop).
     * Returns the MediaCodec input [Surface] for GL presentation.
     */
    fun start(
        output: File,
        encodeWidth: Int,
        encodeHeight: Int,
        orientationHint: Int,
        withAudio: Boolean,
        music: AudioMusicMixer.Config = AudioMusicMixer.Config(),
    ): Surface {
        synchronized(lock) {
            // Tear prior session without awaiting drain under this lock —
            // start() is only called when not recording; force-clean leftovers.
            running.set(false)
            awaitingEos = false
            stopMicRecorder()
            releaseVideoEncoder()
            cleanupTemps()
            finalOutputFile?.delete()
            finalOutputFile = null
            musicConfig = music
            val w = (encodeWidth.coerceAtMost(MAX_WIDTH) and 1.inv()).coerceAtLeast(2)
            val h = (encodeHeight.coerceAtMost(MAX_HEIGHT) and 1.inv()).coerceAtLeast(2)
            width = w
            height = h

            finalOutputFile = output
            val parent = output.parentFile ?: throw IllegalStateException("no_parent_dir")
            if (!parent.exists()) parent.mkdirs()
            checkStorage(parent)?.let { throw IllegalStateException(it) }

            val base = output.nameWithoutExtension
            videoTempFile = File(parent, "${base}_v.mp4").also { it.delete() }
            audioTempFile = File(parent, "${base}_a.m4a").also { it.delete() }
            output.delete()

            val videoOut = videoTempFile ?: throw IllegalStateException("video_temp_missing")
            startEncoder(videoOut, w, h, orientationHint)
            // Capture mic when original volume is needed (or no music mix requested).
            val captureMic = withAudio && music.keepOriginal
            if (captureMic) {
                startMicRecorder()
            }
            startedAtMs = System.currentTimeMillis()
            running.set(true)
            return inputSurface ?: throw IllegalStateException("encoder_surface_missing")
        }
    }

    /**
     * Finish encoding and mux A/V. Returns final file path or null on failure.
     * Audio mix runs outside the encoder lock to avoid blocking cancel/dispose.
     */
    fun stop(): File? {
        val finalOut: File?
        val video: File?
        val audio: File?
        val music: AudioMusicMixer.Config

        synchronized(lock) {
            if (!running.get() && codec == null) {
                return finalOutputFile?.takeIf { it.exists() && it.length() > 0 }
            }
            running.set(false)
            awaitingEos = true
            try {
                codec?.signalEndOfInputStream()
            } catch (t: Throwable) {
                Log.w(TAG, "signalEos", t)
            }
        }

        val done = drainDone
        try {
            done?.await(5, TimeUnit.SECONDS)
        } catch (_: InterruptedException) {
        }
        awaitingEos = false

        stopMicRecorder()

        synchronized(lock) {
            releaseVideoEncoder()
            finalOut = finalOutputFile
            video = videoTempFile
            audio = audioTempFile
            music = musicConfig
            // Transfer file ownership out of temps so cleanupTemps won't delete mid-mix.
            videoTempFile = null
            audioTempFile = null
            finalOutputFile = null
            startedAtMs = 0L
            musicConfig = AudioMusicMixer.Config()
        }

        if (finalOut == null || video == null || !video.exists() || video.length() < 512L) {
            try {
                video?.delete()
            } catch (_: Exception) {
            }
            try {
                audio?.delete()
            } catch (_: Exception) {
            }
            return null
        }

        return try {
            val ok = if (music.hasMusic || (music.keepOriginal && audio != null)) {
                AudioMusicMixer.mixToMp4(
                    videoFile = video,
                    micFile = audio,
                    config = music,
                    outFile = finalOut,
                )
            } else {
                video.copyTo(finalOut, overwrite = true)
                finalOut.exists()
            }
            if (ok && finalOut.exists() && finalOut.length() > 0) finalOut else null
        } catch (t: Throwable) {
            Log.e(TAG, "mux failed", t)
            null
        } finally {
            try {
                video.delete()
            } catch (_: Exception) {
            }
            try {
                audio?.delete()
            } catch (_: Exception) {
            }
        }
    }

    /** Abort and delete partial files. */
    fun cancel() {
        synchronized(lock) {
            if (!running.get() && codec == null) {
                cleanupTemps()
                finalOutputFile?.delete()
                finalOutputFile = null
                return
            }
            running.set(false)
            awaitingEos = true
            try {
                codec?.signalEndOfInputStream()
            } catch (_: Exception) {
            }
        }
        val done = drainDone
        try {
            done?.await(2, TimeUnit.SECONDS)
        } catch (_: InterruptedException) {
        }
        awaitingEos = false
        stopMicRecorder()
        synchronized(lock) {
            releaseVideoEncoder()
            cleanupTemps()
            finalOutputFile?.delete()
            finalOutputFile = null
            startedAtMs = 0L
            width = 0
            height = 0
            musicConfig = AudioMusicMixer.Config()
        }
    }

    fun release() {
        cancel()
    }

    private fun startEncoder(output: File, w: Int, h: Int, orientationHint: Int) {
        trackIndex = -1
        muxerStarted = false
        awaitingEos = false

        val encoder = MediaCodec.createEncoderByType(MIME)
        var configured = false
        try {
            encoder.configure(
                buildTunedFormat(w, h),
                null,
                null,
                MediaCodec.CONFIGURE_FLAG_ENCODE,
            )
            configured = true
        } catch (t: Throwable) {
            Log.w(TAG, "tuned config rejected", t)
        }
        if (!configured) {
            encoder.reset()
            encoder.configure(
                buildSafeFormat(w, h),
                null,
                null,
                MediaCodec.CONFIGURE_FLAG_ENCODE,
            )
        }
        inputSurface = encoder.createInputSurface()
        encoder.start()
        codec = encoder

        val mux = MediaMuxer(output.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        try {
            mux.setOrientationHint(orientationHint)
        } catch (_: Throwable) {
        }
        muxer = mux

        val thread = HandlerThread("native-camera-encode-drain").also { it.start() }
        drainThread = thread
        drainHandler = Handler(thread.looper)
        drainDone = CountDownLatch(1)
        drainHandler?.post { drainLoop() }
        Log.i(TAG, "encoder ${w}x$h @${FRAME_RATE}fps → ${output.name}")
    }

    private fun buildTunedFormat(w: Int, h: Int): MediaFormat {
        return MediaFormat.createVideoFormat(MIME, w, h).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, BITRATE)
            setInteger(MediaFormat.KEY_FRAME_RATE, FRAME_RATE)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, I_FRAME_INTERVAL)
            setInteger(MediaFormat.KEY_BITRATE_MODE, MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_VBR)
            try {
                setInteger(MediaFormat.KEY_PROFILE, MediaCodecInfo.CodecProfileLevel.AVCProfileBaseline)
                setInteger(MediaFormat.KEY_LEVEL, MediaCodecInfo.CodecProfileLevel.AVCLevel31)
            } catch (_: Throwable) {
            }
        }
    }

    private fun buildSafeFormat(w: Int, h: Int): MediaFormat {
        return MediaFormat.createVideoFormat(MIME, w, h).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, 4_000_000)
            setInteger(MediaFormat.KEY_FRAME_RATE, FRAME_RATE)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, I_FRAME_INTERVAL)
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
            recorder.setAudioEncodingBitRate(128_000)
            recorder.setAudioSamplingRate(44_100)
            recorder.setAudioChannels(1)
            recorder.setOutputFile(audioFile.absolutePath)
            recorder.prepare()
            recorder.start()
            mediaRecorder = recorder
            audioRecording = true
        } catch (t: Throwable) {
            Log.w(TAG, "mic start failed — video-only", t)
            audioRecording = false
            try {
                mediaRecorder?.release()
            } catch (_: Exception) {
            }
            mediaRecorder = null
        }
    }

    private fun stopMicRecorder() {
        if (!audioRecording) {
            try {
                mediaRecorder?.release()
            } catch (_: Exception) {
            }
            mediaRecorder = null
            return
        }
        audioRecording = false
        try {
            mediaRecorder?.stop()
        } catch (t: Throwable) {
            Log.w(TAG, "mic stop", t)
        }
        try {
            mediaRecorder?.release()
        } catch (_: Exception) {
        }
        mediaRecorder = null
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
        // Do not keep looping solely because muxerStarted — that races releaseVideoEncoder.
        while (running.get() || awaitingEos) {
            val encoder = codec ?: break
            val outIndex = try {
                encoder.dequeueOutputBuffer(bufferInfo, 10_000)
            } catch (_: Exception) {
                break
            }
            when {
                outIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> {
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
                        try {
                            muxer?.writeSampleData(trackIndex, encoded, bufferInfo)
                        } catch (t: Throwable) {
                            Log.w(TAG, "writeSampleData after release?", t)
                        }
                    }
                    try {
                        encoder.releaseOutputBuffer(outIndex, false)
                    } catch (_: Exception) {
                    }
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        awaitingEos = false
                        break
                    }
                }
            }
        }
    }

    private fun releaseVideoEncoder() {
        // Prefer drain exit before stopping codec; then join the drain thread.
        val done = drainDone
        try {
            done?.await(500, TimeUnit.MILLISECONDS)
        } catch (_: InterruptedException) {
        }
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
        trackIndex = -1
        val thread = drainThread
        drainThread = null
        drainHandler = null
        thread?.quitSafely()
        try {
            thread?.join(1500)
        } catch (_: InterruptedException) {
        }
        drainDone = null
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
        musicConfig = AudioMusicMixer.Config()
    }

    // Kept for reference / tests — primary path uses [AudioMusicMixer].
    @Suppress("unused")
    private fun muxAv(videoFile: File, audioFile: File?, outFile: File): File {
        return if (AudioMusicMixer.mixToMp4(
                videoFile,
                audioFile,
                AudioMusicMixer.Config(originalVolume = 1f, musicVolume = 0f),
                outFile,
            )
        ) {
            outFile
        } else {
            videoFile.copyTo(outFile, overwrite = true)
            outFile
        }
    }
}
