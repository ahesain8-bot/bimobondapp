package com.dubai.bimobondapp.ar_camera

import android.os.Handler
import android.os.Looper
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

    /**
     * Retry plumbing for [bindOutputSurface].
     *
     * `attach()` runs when Dart decides to publish, which is not necessarily
     * after the live-room PlatformView has mounted its GL view. When it ran
     * first, every guard in [bindOutputSurface] returned silently and nothing
     * ever tried again: the track existed, `onCapturerStarted` had been called
     * and `getSenderStats()` answered with real stats — reporting framesSent=0
     * forever, because the renderer had never been handed a surface to draw
     * into. That is the "camera opened but produced no video frames" failure.
     * The bind is now retried until a renderer appears or the attach is torn
     * down, and every failure says which guard rejected it.
     */
    private val bindHandler = Handler(Looper.getMainLooper())
    private var bindAttempts = 0
    private var surfaceBound = false
    private const val BIND_RETRY_MS = 150L
    private const val BIND_MAX_ATTEMPTS = 80

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

                // Per-stage state of the native half of the pipeline, so a
                // frameless publish can name the stage that broke instead of
                // only reporting framesSent=0 from the far end.
                "diagnostics" -> result.success(diagnostics())
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
        if (!bindOutputSurface() && activeTrackId != null) scheduleSurfaceBind()
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
        // The renderer may not be mounted yet; keep trying rather than
        // publishing a track that can never carry a frame.
        if (!bindOutputSurface()) scheduleSurfaceBind()
        Log.i(TAG, "attached existing AR camera to WebRTC track=$trackId ${width}x$height@$fps")

        return mapOf(
            "trackId" to trackId,
            "width" to width,
            "height" to height,
            "fps" to fps,
        )
    }

    /**
     * Hands the WebRTC output surface to the live renderer.
     *
     * Returns true once the renderer has actually been given the surface. A
     * false answer is not fatal on its own — the GL view may simply not be
     * mounted yet — but it must never be silent, because until this succeeds
     * the published track produces no frames at all.
     */
    private fun bindOutputSurface(): Boolean {
        // The bridge is the source of truth for PlatformView ownership. The
        // cached renderer can briefly refer to the setup route during the
        // setup -> room hand-off.
        val gl = ArCameraBridge.warpGlView ?: renderer
        val surface = outputSurface
        val reason = when {
            activeTrackId == null -> "no active attach"
            gl == null -> "no GL renderer mounted yet"
            surface == null -> "no output surface"
            !surface.isValid -> "output surface is not valid"
            outputWidth < 2 || outputHeight < 2 ->
                "output size not set (${outputWidth}x$outputHeight)"
            else -> null
        }
        if (reason != null || gl == null || surface == null) {
            Log.w(TAG, "surface bind deferred (attempt $bindAttempts): $reason")
            return false
        }
        renderer = gl
        surfaceBound = true
        Log.i(
            TAG,
            "binding WebRTC surface to active renderer " +
                "id=${System.identityHashCode(gl)} ${outputWidth}x$outputHeight",
        )
        gl.setEncoderSurface(surface, outputWidth, outputHeight)
        return true
    }

    /**
     * Keeps retrying [bindOutputSurface] until a renderer shows up.
     *
     * The window that used to lose broadcasts is short — a route transition
     * between the start-live and live-room PlatformViews — so a fast poll for
     * a bounded time covers it without leaving a timer running for the life of
     * the app. It stops on success, on detach, or when the budget runs out,
     * and the exhausted case is logged as an error because at that point the
     * broadcast genuinely cannot produce frames.
     */
    private fun scheduleSurfaceBind() {
        bindHandler.removeCallbacksAndMessages(null)
        if (surfaceBound || activeTrackId == null) return
        if (bindAttempts >= BIND_MAX_ATTEMPTS) {
            Log.e(
                TAG,
                "surface never bound after $BIND_MAX_ATTEMPTS attempts — " +
                    "the published track will not produce frames",
            )
            return
        }
        bindAttempts++
        bindHandler.postDelayed({
            if (surfaceBound || activeTrackId == null) return@postDelayed
            if (!bindOutputSurface()) scheduleSurfaceBind()
        }, BIND_RETRY_MS)
    }

    private fun detach() {
        val oldTrackId = activeTrackId
        activeTrackId = null
        bindHandler.removeCallbacksAndMessages(null)
        bindAttempts = 0
        surfaceBound = false

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

    /**
     * Native-side view of the frame path, stage by stage.
     *
     * Camera -> renderer -> encoder surface -> SurfaceTexture -> WebRTC track.
     * `surfaceBound` is the one that used to fail silently; if it is false
     * while `trackId` is set, the renderer never received the surface and no
     * amount of waiting on sender stats will help.
     */
    private fun diagnostics(): Map<String, Any?> {
        val gl = ArCameraBridge.warpGlView ?: renderer
        return mapOf(
            "trackId" to activeTrackId,
            "rendererMounted" to (ArCameraBridge.warpGlView != null),
            "rendererBound" to (renderer != null),
            "rendererIsActive" to (gl != null && ArCameraBridge.warpGlView === gl),
            "surfaceBound" to surfaceBound,
            "surfaceValid" to (outputSurface?.isValid == true),
            "bindAttempts" to bindAttempts,
            "outputWidth" to outputWidth,
            "outputHeight" to outputHeight,
            "hasVideoSource" to (source != null),
            "hasVideoTrack" to (track != null),
            "hasTextureHelper" to (textureHelper != null),
            "hasStream" to (stream != null),
        )
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
