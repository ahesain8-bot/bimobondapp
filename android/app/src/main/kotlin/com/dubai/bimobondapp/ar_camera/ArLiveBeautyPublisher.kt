package com.dubai.bimobondapp.ar_camera

import android.content.Context
import android.util.Log
import com.cloudwebrtc.webrtc.FlutterWebRTCPlugin
import com.cloudwebrtc.webrtc.MethodCallHandlerImpl
import com.cloudwebrtc.webrtc.utils.EglUtils
import com.cloudwebrtc.webrtc.video.LocalVideoTrack as WebrtcLocalVideoTrack
import io.flutter.embedding.engine.FlutterEngine
import org.webrtc.EglBase
import org.webrtc.Logging
import org.webrtc.MediaStream
import org.webrtc.PeerConnectionFactory
import org.webrtc.SurfaceTextureHelper
import org.webrtc.VideoCapturer
import org.webrtc.VideoSource
import org.webrtc.VideoTrack
import java.util.UUID

/**
 * Builds a flutter_webrtc local video track fed by [ArBeautyVideoCapturer]
 * (FaceWarp beautified frames) and attaches it to an existing local MediaStream.
 */
object ArLiveBeautyPublisher {
    private const val TAG = "ArLiveBeautyPub"

    private var capturer: VideoCapturer? = null
    private var videoSource: VideoSource? = null
    private var surfaceHelper: SurfaceTextureHelper? = null
    private var videoTrack: VideoTrack? = null
    private var attachedStreamId: String? = null

    @Volatile
    private var exclusiveFlag = false

    /**
     * When true, CameraX must not be stopped/rebound for a Flutter/LiveKit
     * camera open — FaceWarp owns the lens for beauty live publish.
     */
    @JvmStatic
    fun setLivePublishingExclusive(exclusive: Boolean) {
        exclusiveFlag = exclusive
        Log.i(TAG, "livePublishingExclusive=$exclusive")
    }

    @JvmStatic
    fun isLivePublishingExclusive(): Boolean = exclusiveFlag

    @JvmStatic
    fun pushedFrameCount(): Int {
        val c = capturer as? ArBeautyVideoCapturer ?: return 0
        return c.pushedFrameCount()
    }

    /** Pause beauty frames during CameraX front/back rebind. */
    @JvmStatic
    fun pauseForCameraSwitch() {
        (capturer as? ArBeautyVideoCapturer)?.setPausedForCameraSwitch(true)
    }

    /**
     * Resume only after the new camera transform looks settled and we have a
     * usable capture — otherwise viewers get horizontal-static YUV garbage.
     */
    @JvmStatic
    fun resumeAfterCameraSwitch(delayMs: Long = 700L) {
        val c = capturer as? ArBeautyVideoCapturer ?: return
        val main = android.os.Handler(android.os.Looper.getMainLooper())
        fun attempt(n: Int) {
            val gl = ArCameraBridge.warpGlView
            try {
                gl?.requestCaptureNow()
            } catch (_: Throwable) {
            }
            val rot = gl?.cameraRotationDegrees() ?: 0
            val snap = try {
                gl?.copyLastFilteredFrame()
            } catch (_: Throwable) {
                null
            }
            val portraitOk = snap != null &&
                !snap.isRecycled &&
                snap.width >= 2 &&
                snap.height >= 2 &&
                snap.height >= snap.width
            try {
                snap?.recycle()
            } catch (_: Throwable) {
            }
            val rotOk = rot == 90 || rot == 270 || rot == 0 || rot == 180
            if ((portraitOk && rotOk) || n >= 10) {
                try {
                    gl?.resetAfterRouteResume()
                    gl?.clearLastCapturedFrame()
                    gl?.requestCaptureNow()
                } catch (_: Throwable) {
                }
                // One more beat so the first pumped frame is a fresh capture.
                main.postDelayed({
                    c.setPausedForCameraSwitch(false)
                    Log.i(TAG, "beauty publish resumed after flip (attempt=$n rot=$rot)")
                }, 120L)
            } else {
                main.postDelayed({ attempt(n + 1) }, 120L)
            }
        }
        main.postDelayed({ attempt(0) }, delayMs.coerceIn(400L, 1500L))
    }

    /**
     * @return map with trackId / streamId / width / height, or null on failure
     */
    @JvmStatic
    fun attachBeautyTrack(
        context: Context,
        streamId: String,
        width: Int,
        height: Int,
        fps: Int,
        flutterEngine: FlutterEngine? = null,
    ): Map<String, Any>? {
        release()

        val plugin = resolvePlugin(flutterEngine)
            ?: run {
                Log.e(TAG, "FlutterWebRTCPlugin not ready")
                return null
            }

        val factory = ensurePeerConnectionFactory(plugin)
            ?: run {
                Log.e(TAG, "PeerConnectionFactory still null after initialize")
                return null
            }

        val stream: MediaStream = try {
            plugin.getStreamForId(streamId, "")
        } catch (t: Throwable) {
            Log.e(TAG, "getStreamForId threw", t)
            null
        } ?: run {
            Log.e(TAG, "local stream not found: $streamId")
            return null
        }

        // Keep beauty publish modest — high simulcast ladders + bitmap readback
        // often yield "published but no frames" / audio-only viewers.
        val w = width.coerceIn(240, 1280)
        val h = height.coerceIn(320, 1280)
        val rate = fps.coerceIn(12, 24)

        val eglContext: EglBase.Context? = try {
            EglUtils.getRootEglBaseContext()
        } catch (t: Throwable) {
            Log.e(TAG, "EglUtils.getRootEglBaseContext failed", t)
            null
        }
        if (eglContext == null) {
            Log.e(TAG, "EGL root context null")
            return null
        }

        val helper = SurfaceTextureHelper.create("ArBeautyCaptureThread", eglContext)
            ?: run {
                Log.e(TAG, "SurfaceTextureHelper.create failed")
                return null
            }

        return try {
            val beautyCapturer = ArBeautyVideoCapturer()
            val source = factory.createVideoSource(/* isScreencast = */ false)
            beautyCapturer.initialize(helper, context.applicationContext, source.capturerObserver)
            beautyCapturer.startCapture(w, h, rate)

            val trackId = UUID.randomUUID().toString()
            val track = factory.createVideoTrack(trackId, source)
            track.setEnabled(true)
            stream.addTrack(track)

            // Register with flutter_webrtc for Dart track lookup / dispose.
            // Do NOT setVideoProcessor(LocalVideoTrack): that drops frames while
            // sink is null and breaks LiveKit publish (audio-only viewers).
            try {
                val handler = methodHandler(plugin)
                if (handler != null) {
                    handler.putLocalTrack(trackId, WebrtcLocalVideoTrack(track))
                } else {
                    Log.w(TAG, "MethodCallHandlerImpl unavailable — track still on MediaStream")
                }
            } catch (t: Throwable) {
                Log.w(TAG, "putLocalTrack skipped", t)
            }

            capturer = beautyCapturer
            videoSource = source
            surfaceHelper = helper
            videoTrack = track
            attachedStreamId = streamId

            Log.i(TAG, "beauty track attached stream=$streamId track=$trackId ${w}x$h@$rate")
            mapOf(
                "streamId" to streamId,
                "trackId" to trackId,
                "width" to w,
                "height" to h,
                "fps" to rate,
            )
        } catch (t: Throwable) {
            Log.e(TAG, "attachBeautyTrack failed", t)
            try {
                helper.dispose()
            } catch (_: Throwable) {
            }
            release()
            null
        }
    }

    @JvmStatic
    fun release() {
        try {
            capturer?.stopCapture()
        } catch (t: Throwable) {
            Log.w(TAG, "stopCapture", t)
        }
        try {
            capturer?.dispose()
        } catch (_: Throwable) {
        }
        capturer = null

        // Track / VideoSource are owned by flutter_webrtc + LiveKit LocalVideoTrack.
        videoTrack = null
        videoSource = null

        try {
            surfaceHelper?.dispose()
        } catch (_: Throwable) {
        }
        surfaceHelper = null
        attachedStreamId = null
    }

    private fun resolvePlugin(flutterEngine: FlutterEngine?): FlutterWebRTCPlugin? {
        try {
            val fromEngine = flutterEngine
                ?.plugins
                ?.get(FlutterWebRTCPlugin::class.java) as? FlutterWebRTCPlugin
            if (fromEngine != null) {
                Log.i(TAG, "using FlutterWebRTCPlugin from FlutterEngine")
                return fromEngine
            }
        } catch (t: Throwable) {
            Log.w(TAG, "engine plugin lookup failed", t)
        }
        return FlutterWebRTCPlugin.sharedSingleton
    }

    private fun ensurePeerConnectionFactory(plugin: FlutterWebRTCPlugin): PeerConnectionFactory? {
        readFactory(plugin)?.let { return it }

        val handler = methodHandler(plugin)
        if (handler == null) {
            Log.e(TAG, "MethodCallHandlerImpl null — cannot initialize factory")
            return null
        }

        Log.w(TAG, "PeerConnectionFactory null — forcing flutter_webrtc initialize()")
        try {
            forceInitialize(handler)
        } catch (t: Throwable) {
            Log.e(TAG, "forceInitialize failed", t)
        }

        val after = readFactory(plugin)
        Log.i(TAG, "PeerConnectionFactory after forceInit=${after != null}")
        return after
    }

    private fun readFactory(plugin: FlutterWebRTCPlugin): PeerConnectionFactory? {
        return try {
            plugin.peerConnectionFactory
        } catch (t: Throwable) {
            Log.e(TAG, "peerConnectionFactory threw", t)
            null
        }
    }

    /**
     * Mirrors flutter_webrtc's lazy [MethodCallHandlerImpl.initialize] defaults
     * so custom capturers can create tracks even if Dart has not yet hit a
     * WebRTC method that initializes the factory on this plugin instance.
     */
    private fun forceInitialize(handler: MethodCallHandlerImpl) {
        val method = MethodCallHandlerImpl::class.java.declaredMethods.firstOrNull { m ->
            m.name == "initialize" && m.parameterTypes.size >= 7
        } ?: throw IllegalStateException("initialize method not found")
        method.isAccessible = true

        val params = method.parameterTypes
        val args = arrayOfNulls<Any?>(params.size)
        // boolean bypassVoiceProcessing
        args[0] = false
        // boolean androidUseHardwareAudioProcessing
        args[1] = true
        // int networkIgnoreMask
        args[2] = 0
        // boolean forceSWCodec
        args[3] = false
        // List forceSWCodecList
        args[4] = emptyList<String>()
        // ConstraintsMap androidAudioConfiguration (nullable)
        if (params.size > 5) {
            args[5] = null
        }
        // Severity logSeverity
        if (params.size > 6) {
            args[6] = Logging.Severity.LS_NONE
        }
        // Integer audioSampleRate / audioOutputSampleRate
        if (params.size > 7) args[7] = null
        if (params.size > 8) args[8] = null

        method.invoke(handler, *args)
    }

    private fun methodHandler(plugin: FlutterWebRTCPlugin): MethodCallHandlerImpl? {
        return try {
            val field = FlutterWebRTCPlugin::class.java.getDeclaredField("methodCallHandler")
            field.isAccessible = true
            field.get(plugin) as? MethodCallHandlerImpl
        } catch (t: Throwable) {
            Log.e(TAG, "reflect methodCallHandler failed", t)
            null
        }
    }
}
