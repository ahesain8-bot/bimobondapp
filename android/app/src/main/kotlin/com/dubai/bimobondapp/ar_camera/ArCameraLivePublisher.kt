package com.dubai.bimobondapp.ar_camera

import android.util.Log
import android.view.Surface
import com.cloudwebrtc.webrtc.FlutterWebRTCPlugin
import com.cloudwebrtc.webrtc.StateProvider
import com.cloudwebrtc.webrtc.video.LocalVideoTrack
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.webrtc.CapturerObserver
import com.cloudwebrtc.webrtc.utils.EglUtils
import org.webrtc.MediaStream
import org.webrtc.SurfaceTextureHelper
import org.webrtc.VideoSource
import org.webrtc.VideoTrack
import java.util.UUID

/**
 * Sends the output of the existing AR-camera renderer to WebRTC.
 *
 * This does not open or configure a camera. [ArCameraController] remains the
 * single owner of CameraX and [FaceWarpGlView] remains the single renderer.
 * Its already-filtered output is rendered into a WebRTC SurfaceTexture, so the
 * host preview and the frame published to LiveKit are the same frame.
 */
object ArCameraLivePublisher {
    private const val TAG = "ArCameraLivePublisher"
    private const val CHANNEL = "com.dubai.bimobondapp/ar_camera_live"

    private var flutterWebRtcPlugin: FlutterWebRTCPlugin? = null
    private var renderer: FaceWarpGlView? = null

    private var stream: MediaStream? = null
    private var source: VideoSource? = null
    private var track: VideoTrack? = null
    private var observer: CapturerObserver? = null
    private var textureHelper: SurfaceTextureHelper? = null
    private var outputSurface: Surface? = null
    private var activeTrackId: String? = null
    private var outputWidth = 0
    private var outputHeight = 0

    fun register(flutterEngine: FlutterEngine) {
        flutterWebRtcPlugin = flutterEngine.plugins
            .get(FlutterWebRTCPlugin::class.java) as? FlutterWebRTCPlugin

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "attach" -> {
                    val streamId = call.argument<String>("streamId")
                    val width = (call.argument<Number>("width")?.toInt() ?: 720)
                        .coerceAtLeast(2)
                    val height = (call.argument<Number>("height")?.toInt() ?: 1280)
                        .coerceAtLeast(2)
                    val fps = (call.argument<Number>("fps")?.toInt() ?: 30)
                        .coerceIn(1, 30)
                    try {
                        result.success(attach(streamId, width, height, fps))
                    } catch (t: Throwable) {
                        Log.e(TAG, "attach failed", t)
                        detach()
                        result.error("attach_failed", t.message ?: "unknown", null)
                    }
                }

                "detach" -> {
                    detach()
                    result.success(null)
                }

                "isAvailable" -> result.success(
                    renderer != null || ArCameraBridge.warpGlView != null,
                )
                "isAttached" -> result.success(activeTrackId != null)
                else -> result.notImplemented()
            }
        }
    }

    /** Called by the existing platform view whenever its renderer is mounted. */
    fun bindRenderer(next: FaceWarpGlView) {
        // A route transition can keep the start-live PlatformView alive for a
        // few frames after the live-room PlatformView has mounted. Only the
        // view currently owned by ArCameraBridge may become the publisher;
        // otherwise WebRTC is attached to the hidden, stale GL thread and sees
        // zero frames while the visible Kotlin preview keeps drawing normally.
        if (ArCameraBridge.warpGlView !== next) {
            Log.i(TAG, "ignored stale renderer bind id=${System.identityHashCode(next)}")
            return
        }
        renderer = next
        Log.i(TAG, "bound active renderer id=${System.identityHashCode(next)}")
        bindOutputSurface()
    }

    /** Called before the existing platform view releases its EGL resources. */
    fun unbindRenderer(current: FaceWarpGlView) {
        if (renderer !== current) return
        current.clearEncoderSurface()
        renderer = null
    }

    private fun attach(
        streamId: String?,
        width: Int,
        height: Int,
        fps: Int,
    ): Map<String, Any> {
        require(!streamId.isNullOrBlank()) { "streamId is required" }
        detach()

        val plugin = flutterWebRtcPlugin
            ?: FlutterWebRTCPlugin.sharedSingleton
            ?: error("flutter_webrtc plugin is unavailable")
        val factory = plugin.peerConnectionFactory
            ?: error("WebRTC PeerConnectionFactory is not initialized")
        val mediaStream = plugin.getStreamForId(streamId, "")
            ?: error("WebRTC media stream not found: $streamId")
        val provider = stateProvider(plugin)
            ?: error("flutter_webrtc state provider is unavailable")

        val videoSource = factory.createVideoSource(false)
        videoSource.adaptOutputFormat(width, height, fps)
        val capturerObserver = videoSource.capturerObserver
        val trackId = "ar_camera_live_${UUID.randomUUID()}"
        val videoTrack = factory.createVideoTrack(trackId, videoSource)
        val localTrack = LocalVideoTrack(videoTrack)
        videoSource.setVideoProcessor(localTrack)

        check(provider.putLocalTrack(trackId, localTrack)) {
            "could not register the AR camera WebRTC track"
        }
        check(mediaStream.addTrack(videoTrack)) {
            "could not add the AR camera track to its media stream"
        }

        val helper = SurfaceTextureHelper.create(
            "ar_camera_live_texture",
            EglUtils.getRootEglBaseContext(),
        ) ?: error("could not create the WebRTC output texture")
        helper.setTextureSize(width, height)
        helper.setFrameRotation(0)
        helper.startListening { frame -> capturerObserver.onFrameCaptured(frame) }
        val surface = Surface(helper.surfaceTexture)

        stream = mediaStream
        source = videoSource
        track = videoTrack
        observer = capturerObserver
        textureHelper = helper
        outputSurface = surface
        activeTrackId = trackId
        outputWidth = width
        outputHeight = height

        capturerObserver.onCapturerStarted(true)
        bindOutputSurface()
        Log.i(TAG, "attached existing AR camera to WebRTC track=$trackId ${width}x$height@$fps")

        return mapOf(
            "trackId" to trackId,
            "width" to width,
            "height" to height,
            "fps" to fps,
        )
    }

    private fun bindOutputSurface() {
        // The bridge is the source of truth for PlatformView ownership. The
        // cached renderer can briefly refer to the setup route during the
        // setup -> room hand-off.
        val gl = ArCameraBridge.warpGlView ?: renderer ?: return
        val surface = outputSurface ?: return
        if (!surface.isValid || outputWidth < 2 || outputHeight < 2) return
        renderer = gl
        Log.i(
            TAG,
            "binding WebRTC surface to active renderer " +
                "id=${System.identityHashCode(gl)} ${outputWidth}x$outputHeight",
        )
        gl.setEncoderSurface(surface, outputWidth, outputHeight)
    }

    private fun detach() {
        val oldTrackId = activeTrackId
        activeTrackId = null

        renderer?.clearEncoderSurface()
        try {
            observer?.onCapturerStopped()
        } catch (_: Throwable) {
        }
        try {
            textureHelper?.stopListening()
        } catch (_: Throwable) {
        }
        try {
            outputSurface?.release()
        } catch (_: Throwable) {
        }
        try {
            textureHelper?.dispose()
        } catch (_: Throwable) {
        }
        try {
            track?.let { stream?.removeTrack(it) }
        } catch (_: Throwable) {
        }
        try {
            track?.dispose()
        } catch (_: Throwable) {
        }
        try {
            source?.dispose()
        } catch (_: Throwable) {
        }

        stream = null
        source = null
        track = null
        observer = null
        textureHelper = null
        outputSurface = null
        outputWidth = 0
        outputHeight = 0
        if (oldTrackId != null) Log.i(TAG, "detached WebRTC track=$oldTrackId")
    }

    private fun stateProvider(plugin: FlutterWebRTCPlugin): StateProvider? {
        return try {
            val field = FlutterWebRTCPlugin::class.java
                .getDeclaredField("methodCallHandler")
            field.isAccessible = true
            field.get(plugin) as? StateProvider
        } catch (t: Throwable) {
            Log.e(TAG, "could not access flutter_webrtc state provider", t)
            null
        }
    }
}
