package com.dubai.bimobondapp.camera_engine

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.util.Log
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.max
import kotlin.math.min

/**
 * Phase 10: mix camera mic + app music into AAC while **copying** the H.264
 * video track (no video re-encode).
 */
object AudioMusicMixer {
    private const val TAG = "AudioMusicMixer"
    private const val SAMPLE_RATE = 44100
    private const val CHANNEL_COUNT = 1
    private const val AAC_BITRATE = 128_000
    private const val TIMEOUT_US = 10_000L

    data class Config(
        val musicPath: String? = null,
        val musicOffsetMs: Long = 0L,
        val musicVolume: Float = 0.8f,
        val originalVolume: Float = 0.2f,
    ) {
        val hasMusic: Boolean
            get() = !musicPath.isNullOrBlank() && musicVolume > 0.001f

        val keepOriginal: Boolean
            get() = originalVolume > 0.001f
    }

    /**
     * Mux [videoFile] (video track) with mixed audio from [micFile] and/or music.
     * Returns true when [outFile] is written successfully.
     */
    fun mixToMp4(
        videoFile: File,
        micFile: File?,
        config: Config,
        outFile: File,
    ): Boolean {
        outFile.delete()
        val durationUs = videoDurationUs(videoFile).coerceAtLeast(1_000_000L / 30)
        val wantMic = config.keepOriginal &&
            micFile != null &&
            micFile.exists() &&
            micFile.length() > 512L
        val wantMusic = config.hasMusic &&
            config.musicPath != null &&
            File(config.musicPath).exists()

        if (!wantMic && !wantMusic) {
            // Video-only passthrough.
            return try {
                videoFile.copyTo(outFile, overwrite = true)
                outFile.exists() && outFile.length() > 0
            } catch (t: Throwable) {
                Log.e(TAG, "video copy", t)
                false
            }
        }

        // Fast path: mic only, full volume — copy tracks without PCM decode.
        if (wantMic && !wantMusic && config.originalVolume >= 0.99f) {
            return muxVideoPlusAudio(videoFile, micFile!!, outFile)
        }

        // Fast path: music only, replace mic — copy video + trimmed music AAC if possible.
        if (!wantMic && wantMusic && config.musicVolume >= 0.99f) {
            val music = File(config.musicPath!!)
            if (tryMuxVideoPlusTrimmedMusic(videoFile, music, config.musicOffsetMs, durationUs, outFile)) {
                return true
            }
            // Fall through to PCM mix (re-encode audio only).
        }

        return try {
            val micPcm = if (wantMic) {
                decodeToPcm(micFile!!, 0L, durationUs, config.originalVolume)
            } else {
                ShortArray(0)
            }
            val musicPcm = if (wantMusic) {
                decodeToPcm(
                    File(config.musicPath!!),
                    config.musicOffsetMs * 1000L,
                    durationUs,
                    config.musicVolume,
                )
            } else {
                ShortArray(0)
            }
            val mixed = mixPcm(micPcm, musicPcm, durationUs)
            val aacFile = File(outFile.parentFile, "${outFile.nameWithoutExtension}_mix.m4a")
            aacFile.delete()
            if (!encodeAac(mixed, aacFile)) {
                Log.e(TAG, "aac encode failed")
                return false
            }
            val ok = muxVideoPlusAudio(videoFile, aacFile, outFile)
            aacFile.delete()
            ok
        } catch (t: Throwable) {
            Log.e(TAG, "mixToMp4", t)
            false
        }
    }

    private fun mixPcm(a: ShortArray, b: ShortArray, durationUs: Long): ShortArray {
        val samples = ((durationUs / 1_000_000.0) * SAMPLE_RATE).toInt().coerceAtLeast(1)
        val out = ShortArray(samples)
        for (i in 0 until samples) {
            val sa = if (i < a.size) a[i].toInt() else 0
            val sb = if (i < b.size) b[i].toInt() else 0
            out[i] = (sa + sb).coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
        }
        return out
    }

    private fun videoDurationUs(videoFile: File): Long {
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(videoFile.absolutePath)
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                if (!mime.startsWith("video/")) continue
                if (format.containsKey(MediaFormat.KEY_DURATION)) {
                    return format.getLong(MediaFormat.KEY_DURATION)
                }
            }
            // Fallback: walk samples.
            val track = findTrack(extractor, "video/")
            if (track < 0) return 0L
            extractor.selectTrack(track)
            var last = 0L
            while (true) {
                val t = extractor.sampleTime
                if (t < 0) break
                last = t
                extractor.advance()
            }
            return last
        } catch (t: Throwable) {
            Log.w(TAG, "duration", t)
            return 0L
        } finally {
            extractor.release()
        }
    }

    private fun decodeToPcm(
        file: File,
        startUs: Long,
        maxDurationUs: Long,
        volume: Float,
    ): ShortArray {
        val extractor = MediaExtractor()
        val pcm = ArrayList<Short>(SAMPLE_RATE * 8)
        var codec: MediaCodec? = null
        try {
            extractor.setDataSource(file.absolutePath)
            val track = findTrack(extractor, "audio/")
            if (track < 0) return ShortArray(0)
            extractor.selectTrack(track)
            val format = extractor.getTrackFormat(track)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: return ShortArray(0)
            val inRate = if (format.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            } else {
                SAMPLE_RATE
            }
            val inChannels = if (format.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            } else {
                1
            }

            if (startUs > 0) {
                extractor.seekTo(startUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
            }

            codec = MediaCodec.createDecoderByType(mime)
            codec.configure(format, null, null, 0)
            codec.start()

            val info = MediaCodec.BufferInfo()
            var inputDone = false
            var outputDone = false
            val endUs = startUs + maxDurationUs
            val vol = volume.coerceIn(0f, 1f)

            while (!outputDone) {
                if (!inputDone) {
                    val inIndex = codec.dequeueInputBuffer(TIMEOUT_US)
                    if (inIndex >= 0) {
                        val buf = codec.getInputBuffer(inIndex)
                        if (buf == null) {
                            codec.queueInputBuffer(inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            buf.clear()
                            val sample = extractor.readSampleData(buf, 0)
                            if (sample < 0 || extractor.sampleTime > endUs) {
                                codec.queueInputBuffer(
                                    inIndex,
                                    0,
                                    0,
                                    0,
                                    MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                                )
                                inputDone = true
                            } else {
                                val pts = extractor.sampleTime
                                codec.queueInputBuffer(inIndex, 0, sample, pts, 0)
                                extractor.advance()
                            }
                        }
                    }
                }

                val outIndex = codec.dequeueOutputBuffer(info, TIMEOUT_US)
                when {
                    outIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> Unit
                    outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> Unit
                    outIndex >= 0 -> {
                        if (info.size > 0 && info.presentationTimeUs >= startUs) {
                            val outBuf = codec.getOutputBuffer(outIndex)
                            if (outBuf != null) {
                                outBuf.position(info.offset)
                                outBuf.limit(info.offset + info.size)
                                val shorts = ShortArray(info.size / 2)
                                outBuf.order(ByteOrder.LITTLE_ENDIAN).asShortBuffer().get(shorts)
                                appendResampled(pcm, shorts, inRate, inChannels, vol)
                            }
                        }
                        codec.releaseOutputBuffer(outIndex, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            outputDone = true
                        }
                        if (info.presentationTimeUs >= endUs) {
                            outputDone = true
                        }
                    }
                }
            }
        } catch (t: Throwable) {
            Log.e(TAG, "decode ${file.name}", t)
        } finally {
            try {
                codec?.stop()
                codec?.release()
            } catch (_: Exception) {
            }
            extractor.release()
        }
        return pcm.toShortArray()
    }

    private fun appendResampled(
        dest: ArrayList<Short>,
        src: ShortArray,
        inRate: Int,
        inChannels: Int,
        volume: Float,
    ) {
        if (src.isEmpty()) return
        val mono = ShortArray(src.size / max(1, inChannels))
        var mi = 0
        var i = 0
        while (i + inChannels - 1 < src.size && mi < mono.size) {
            var sum = 0
            for (c in 0 until inChannels) {
                sum += src[i + c].toInt()
            }
            mono[mi++] = (sum / inChannels).toShort()
            i += inChannels
        }
        if (inRate == SAMPLE_RATE) {
            for (s in 0 until mi) {
                dest.add((mono[s] * volume).toInt().coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort())
            }
            return
        }
        // Linear resample to 44.1k.
        val outLen = ((mi.toLong() * SAMPLE_RATE) / inRate).toInt().coerceAtLeast(0)
        for (o in 0 until outLen) {
            val srcPos = o.toDouble() * inRate / SAMPLE_RATE
            val idx = srcPos.toInt()
            val frac = srcPos - idx
            val s0 = mono[min(idx, mi - 1)].toInt()
            val s1 = mono[min(idx + 1, mi - 1)].toInt()
            val sample = (s0 + (s1 - s0) * frac) * volume
            dest.add(sample.toInt().coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort())
        }
    }

    private fun encodeAac(pcm: ShortArray, outFile: File): Boolean {
        if (pcm.isEmpty()) return false
        var encoder: MediaCodec? = null
        var muxer: MediaMuxer? = null
        try {
            val format = MediaFormat.createAudioFormat(
                MediaFormat.MIMETYPE_AUDIO_AAC,
                SAMPLE_RATE,
                CHANNEL_COUNT,
            )
            format.setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            format.setInteger(MediaFormat.KEY_BIT_RATE, AAC_BITRATE)
            format.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384)

            encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
            encoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            encoder.start()

            muxer = MediaMuxer(outFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            var track = -1
            var muxerStarted = false
            val info = MediaCodec.BufferInfo()

            var pcmIndex = 0
            var inputDone = false
            var outputDone = false
            val frameSamples = 1024
            var ptsUs = 0L

            while (!outputDone) {
                if (!inputDone) {
                    val inIndex = encoder.dequeueInputBuffer(TIMEOUT_US)
                    if (inIndex >= 0) {
                        val buf = encoder.getInputBuffer(inIndex)!!
                        buf.clear()
                        if (pcmIndex >= pcm.size) {
                            encoder.queueInputBuffer(
                                inIndex,
                                0,
                                0,
                                ptsUs,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                            )
                            inputDone = true
                        } else {
                            val remaining = pcm.size - pcmIndex
                            val count = min(frameSamples, remaining)
                            for (i in 0 until count) {
                                buf.putShort(pcm[pcmIndex + i])
                            }
                            val bytes = count * 2
                            encoder.queueInputBuffer(inIndex, 0, bytes, ptsUs, 0)
                            pcmIndex += count
                            ptsUs += (count * 1_000_000L) / SAMPLE_RATE
                        }
                    }
                }

                val outIndex = encoder.dequeueOutputBuffer(info, TIMEOUT_US)
                when {
                    outIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> Unit
                    outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        if (!muxerStarted) {
                            track = muxer.addTrack(encoder.outputFormat)
                            muxer.start()
                            muxerStarted = true
                        }
                    }
                    outIndex >= 0 -> {
                        val outBuf = encoder.getOutputBuffer(outIndex)
                        if (outBuf != null && info.size > 0 && muxerStarted && track >= 0) {
                            outBuf.position(info.offset)
                            outBuf.limit(info.offset + info.size)
                            muxer.writeSampleData(track, outBuf, info)
                        }
                        encoder.releaseOutputBuffer(outIndex, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            outputDone = true
                        }
                    }
                }
            }
            if (muxerStarted) {
                muxer.stop()
            }
            muxer.release()
            muxer = null
            encoder.stop()
            encoder.release()
            encoder = null
            return outFile.exists() && outFile.length() > 0
        } catch (t: Throwable) {
            Log.e(TAG, "encodeAac", t)
            try {
                muxer?.release()
            } catch (_: Exception) {
            }
            try {
                encoder?.release()
            } catch (_: Exception) {
            }
            return false
        }
    }

    private fun muxVideoPlusAudio(videoFile: File, audioFile: File, outFile: File): Boolean {
        outFile.delete()
        val videoExtractor = MediaExtractor()
        val audioExtractor = MediaExtractor()
        var mux: MediaMuxer? = null
        try {
            videoExtractor.setDataSource(videoFile.absolutePath)
            audioExtractor.setDataSource(audioFile.absolutePath)
            val videoTrack = findTrack(videoExtractor, "video/")
            val audioTrack = findTrack(audioExtractor, "audio/")
            if (videoTrack < 0) {
                videoFile.copyTo(outFile, overwrite = true)
                return outFile.exists()
            }
            mux = MediaMuxer(outFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            videoExtractor.selectTrack(videoTrack)
            val outVideo = mux.addTrack(videoExtractor.getTrackFormat(videoTrack))
            var outAudio = -1
            if (audioTrack >= 0) {
                audioExtractor.selectTrack(audioTrack)
                outAudio = mux.addTrack(audioExtractor.getTrackFormat(audioTrack))
            }
            mux.start()
            val buffer = ByteBuffer.allocate(1 * 1024 * 1024)
            val info = MediaCodec.BufferInfo()
            copyAll(videoExtractor, mux, outVideo, buffer, info)
            if (outAudio >= 0) {
                buffer.clear()
                copyAll(audioExtractor, mux, outAudio, buffer, info)
            }
            mux.stop()
            mux.release()
            mux = null
            return outFile.exists() && outFile.length() > 0
        } catch (t: Throwable) {
            Log.e(TAG, "muxVideoPlusAudio", t)
            return false
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
                mux?.release()
            } catch (_: Exception) {
            }
        }
    }

    /** Copy video + music audio without decode when formats allow (offset via seek). */
    private fun tryMuxVideoPlusTrimmedMusic(
        videoFile: File,
        musicFile: File,
        offsetMs: Long,
        durationUs: Long,
        outFile: File,
    ): Boolean {
        outFile.delete()
        val videoExtractor = MediaExtractor()
        val audioExtractor = MediaExtractor()
        var mux: MediaMuxer? = null
        try {
            videoExtractor.setDataSource(videoFile.absolutePath)
            audioExtractor.setDataSource(musicFile.absolutePath)
            val videoTrack = findTrack(videoExtractor, "video/")
            val audioTrack = findTrack(audioExtractor, "audio/")
            if (videoTrack < 0 || audioTrack < 0) return false
            val audioFormat = audioExtractor.getTrackFormat(audioTrack)
            val mime = audioFormat.getString(MediaFormat.KEY_MIME) ?: return false
            // Only passthrough AAC-family into MP4.
            if (!mime.contains("mp4a") && mime != MediaFormat.MIMETYPE_AUDIO_AAC) {
                return false
            }
            mux = MediaMuxer(outFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            videoExtractor.selectTrack(videoTrack)
            audioExtractor.selectTrack(audioTrack)
            val outVideo = mux.addTrack(videoExtractor.getTrackFormat(videoTrack))
            val outAudio = mux.addTrack(audioFormat)
            mux.start()
            val buffer = ByteBuffer.allocate(1 * 1024 * 1024)
            val info = MediaCodec.BufferInfo()
            copyAll(videoExtractor, mux, outVideo, buffer, info)

            val startUs = offsetMs * 1000L
            audioExtractor.seekTo(startUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
            val endUs = startUs + durationUs
            var firstPts = -1L
            while (true) {
                buffer.clear()
                val size = audioExtractor.readSampleData(buffer, 0)
                if (size < 0) break
                val pts = audioExtractor.sampleTime
                if (pts > endUs) break
                if (firstPts < 0) firstPts = pts
                info.offset = 0
                info.size = size
                info.presentationTimeUs = (pts - firstPts).coerceAtLeast(0L)
                info.flags = audioExtractor.sampleFlags
                mux.writeSampleData(outAudio, buffer, info)
                audioExtractor.advance()
            }
            mux.stop()
            mux.release()
            mux = null
            return outFile.exists() && outFile.length() > 0
        } catch (t: Throwable) {
            Log.w(TAG, "trimmed music passthrough failed", t)
            outFile.delete()
            return false
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
                mux?.release()
            } catch (_: Exception) {
            }
        }
    }

    private fun copyAll(
        extractor: MediaExtractor,
        muxer: MediaMuxer,
        track: Int,
        buffer: ByteBuffer,
        info: MediaCodec.BufferInfo,
    ) {
        while (true) {
            buffer.clear()
            val size = extractor.readSampleData(buffer, 0)
            if (size < 0) break
            info.offset = 0
            info.size = size
            info.presentationTimeUs = extractor.sampleTime.coerceAtLeast(0L)
            info.flags = extractor.sampleFlags
            muxer.writeSampleData(track, buffer, info)
            extractor.advance()
        }
    }

    private fun findTrack(extractor: MediaExtractor, mimePrefix: String): Int {
        for (i in 0 until extractor.trackCount) {
            val mime = extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME) ?: continue
            if (mime.startsWith(mimePrefix)) return i
        }
        return -1
    }
}
