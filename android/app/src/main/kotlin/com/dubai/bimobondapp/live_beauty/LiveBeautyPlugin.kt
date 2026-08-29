package com.dubai.bimobondapp.live_beauty

import android.util.Log
import com.cloudwebrtc.webrtc.FlutterWebRTCPlugin
import com.cloudwebrtc.webrtc.video.LocalVideoTrack
import com.dubai.bimobondapp.camera_engine.BeautyParameters
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Attaches [LiveBeautyFrameProcessor] to the LiveKit camera track.
 *
 * Dart owns the effect catalogue and hands down plain numbers; the only thing
 * native needs from it is the WebRTC track id of the track being published.
 */
object LiveBeautyPlugin {

    private const val TAG = "LiveBeautyPlugin"
    const val CHANNEL = "com.dubai.bimobondapp/live_beauty"

    private var channel: MethodChannel? = null

    /** Track the processor is currently installed on, so flips can hand over. */
    private var attachedTrackId: String? = null

    fun register(flutterEngine: FlutterEngine) {
        val methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        )
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "attach" -> result.success(attach(call.argument<String>("trackId")))
                "detach" -> {
                    detach()
                    result.success(null)
                }
                "setBeauty" -> {
                    LiveBeautyFrameProcessor.setParameters(call.toBeautyParameters())
                    result.success(null)
                }
                "clearBeauty" -> {
                    LiveBeautyFrameProcessor.disable()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        channel = methodChannel
    }

    private fun attach(trackId: String?): Boolean {
        if (trackId.isNullOrEmpty()) return false
        if (attachedTrackId == trackId) return true

        // A camera flip publishes a brand new track on a new capture session,
        // so the old registration goes first and the GL objects tied to the
        // retired EGL context are dropped rather than reused.
        detach()

        val track = localVideoTrack(trackId)
        if (track == null) {
            Log.w(TAG, "attach: no local video track for id=$trackId")
            return false
        }
        LiveBeautyFrameProcessor.invalidateResources()
        track.addProcessor(LiveBeautyFrameProcessor)
        attachedTrackId = trackId
        Log.i(TAG, "beauty processor attached to track=$trackId")
        return true
    }

    private fun detach() {
        val trackId = attachedTrackId ?: return
        attachedTrackId = null
        val track = localVideoTrack(trackId)
        if (track == null) {
            // The track is already gone (unpublished or disposed); the
            // processor went with it.
            LiveBeautyFrameProcessor.invalidateResources()
            return
        }
        track.removeProcessor(LiveBeautyFrameProcessor)
        LiveBeautyFrameProcessor.invalidateResources()
        Log.i(TAG, "beauty processor detached from track=$trackId")
    }

    private fun localVideoTrack(trackId: String): LocalVideoTrack? {
        val plugin = FlutterWebRTCPlugin.sharedSingleton ?: return null
        return plugin.getLocalTrack(trackId) as? LocalVideoTrack
    }

    private fun io.flutter.plugin.common.MethodCall.level(name: String): Float {
        val value = argument<Double>(name) ?: return 0f
        return value.toFloat().coerceIn(0f, 1f)
    }

    private fun io.flutter.plugin.common.MethodCall.toBeautyParameters(): BeautyParameters {
        val intensity = (argument<Double>("intensity") ?: 1.0).toFloat().coerceIn(0f, 1f)
        return BeautyParameters(
            skinSmooth = level("smooth") * intensity,
            brightness = level("brighten") * intensity,
            skinTone = level("tone") * intensity,
            sharpen = level("sharpen") * intensity,
            eyeEnhancement = level("eyes") * intensity,
            enabled = argument<Boolean>("enabled") ?: true,
        )
    }
}
