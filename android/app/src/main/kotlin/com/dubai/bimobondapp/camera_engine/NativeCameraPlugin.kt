package com.dubai.bimobondapp.camera_engine

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel bridge for [NativeCameraEngine] (Phase 1–11).
 * Commands/state only — never camera frames or per-frame landmarks.
 */
object NativeCameraPlugin {
    private const val TAG = "NativeCameraPlugin"

    @Volatile
    private var engine: NativeCameraEngine? = null

    fun register(flutterEngine: FlutterEngine, activity: FlutterActivity) {
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, NativeCameraConstants.CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val cam = ensureEngine(flutterEngine, activity)
                        cam.start { res ->
                            activity.runOnUiThread {
                                if (res.ok) {
                                    result.success(res.toMap())
                                } else {
                                    result.error("start_failed", res.error, null)
                                }
                            }
                        }
                    }
                    "stop" -> {
                        val cam = engine
                        if (cam == null) {
                            result.success(mapOf("ok" to true))
                            return@setMethodCallHandler
                        }
                        cam.stop { res ->
                            activity.runOnUiThread {
                                if (res.ok) {
                                    result.success(res.toMap())
                                } else {
                                    result.error("stop_failed", res.error, null)
                                }
                            }
                        }
                    }
                    "switchCamera" -> {
                        val cam = engine
                        if (cam == null) {
                            result.error("not_started", "Call start first", null)
                            return@setMethodCallHandler
                        }
                        cam.switchCamera { res ->
                            activity.runOnUiThread {
                                if (res.ok) {
                                    result.success(res.toMap())
                                } else {
                                    result.error("switch_failed", res.error, null)
                                }
                            }
                        }
                    }
                    "setFlash" -> {
                        val cam = engine
                        if (cam == null) {
                            result.error("not_started", "Call start first", null)
                            return@setMethodCallHandler
                        }
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        cam.setFlash(enabled) { res ->
                            activity.runOnUiThread {
                                if (res.ok) {
                                    result.success(res.toMap())
                                } else {
                                    result.error("flash_failed", res.error, null)
                                }
                            }
                        }
                    }
                    "setColorFilter" -> {
                        val cam = engine
                        if (cam == null) {
                            result.error("not_started", "Call start first", null)
                            return@setMethodCallHandler
                        }
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        val intensity = when (val raw = call.argument<Any>("intensity")) {
                            is Double -> raw.toFloat()
                            is Int -> raw.toFloat()
                            is Long -> raw.toFloat()
                            is Float -> raw
                            else -> 0.55f
                        }
                        cam.setColorFilter(enabled, intensity) { res ->
                            activity.runOnUiThread {
                                if (res.ok) {
                                    result.success(res.toMap())
                                } else {
                                    result.error("filter_failed", res.error, null)
                                }
                            }
                        }
                    }
                    "setFaceTracking" -> {
                        val cam = engine
                        if (cam == null) {
                            result.error("not_started", "Call start first", null)
                            return@setMethodCallHandler
                        }
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val landmarkDebug = call.argument<Boolean>("landmarkDebug") ?: false
                        cam.setFaceTracking(enabled, landmarkDebug) { res ->
                            activity.runOnUiThread {
                                if (res.ok) {
                                    result.success(res.toMap())
                                } else {
                                    result.error("face_tracking_failed", res.error, null)
                                }
                            }
                        }
                    }
                    "setFaceEffect" -> {
                        val cam = engine
                        if (cam == null) {
                            result.error("not_started", "Call start first", null)
                            return@setMethodCallHandler
                        }
                        val effectId = call.argument<String>("effectId")
                        cam.setFaceEffect(effectId) { res ->
                            activity.runOnUiThread {
                                if (res.ok) {
                                    result.success(res.toMap())
                                } else {
                                    result.error("face_effect_failed", res.error, null)
                                }
                            }
                        }
                    }
                    "listFaceEffects" -> {
                        val cam = engine
                        val list = (cam?.listFaceEffects() ?: FaceEffectCatalog.infoList())
                            .map {
                                mapOf(
                                    "id" to it.id,
                                    "name" to it.name,
                                    "version" to it.version,
                                    "remote" to it.remote,
                                )
                            }
                        result.success(list)
                    }
                    "installFaceEffect" -> {
                        val cam = engine
                        if (cam == null) {
                            result.error("not_started", "Call start first", null)
                            return@setMethodCallHandler
                        }
                        val id = call.argument<String>("id") ?: ""
                        val name = call.argument<String>("name") ?: id
                        val version = when (val v = call.argument<Any>("version")) {
                            is Int -> v
                            is Long -> v.toInt()
                            is Double -> v.toInt()
                            else -> 1
                        }
                        val force = call.argument<Boolean>("force") ?: false
                        val layersRaw = mutableListOf<Map<String, Any?>>()
                        val layersArg = call.argument<List<*>>("layers") ?: emptyList<Any?>()
                        for (item in layersArg) {
                            if (item is Map<*, *>) {
                                val mapped = HashMap<String, Any?>()
                                for ((k, v) in item) {
                                    if (k != null) mapped[k.toString()] = v
                                }
                                layersRaw.add(mapped)
                            }
                        }
                        cam.installFaceEffect(id, name, version, layersRaw, force) { res ->
                            activity.runOnUiThread {
                                if (res.ok) {
                                    result.success(res.toMap())
                                } else {
                                    result.error("install_failed", res.error, null)
                                }
                            }
                        }
                    }
                    "unloadFaceEffects" -> {
                        val cam = engine
                        if (cam == null) {
                            result.success(mapOf("ok" to true))
                            return@setMethodCallHandler
                        }
                        val idsArg = call.argument<List<*>>("ids") ?: emptyList<Any?>()
                        val ids = idsArg.mapNotNull { it?.toString() }.filter { it.isNotEmpty() }
                        cam.unloadFaceEffects(ids) { res ->
                            activity.runOnUiThread {
                                result.success(res.toMap())
                            }
                        }
                    }
                    "startRecording" -> {
                        val cam = engine
                        if (cam == null) {
                            result.error("not_started", "Call start first", null)
                            return@setMethodCallHandler
                        }
                        val withAudio = call.argument<Boolean>("withAudio") ?: true
                        cam.startRecording(withAudio = withAudio) { res ->
                            activity.runOnUiThread {
                                if (res.ok) {
                                    result.success(res.toMap())
                                } else {
                                    result.error("start_recording_failed", res.error, null)
                                }
                            }
                        }
                    }
                    "stopRecording" -> {
                        val cam = engine
                        if (cam == null) {
                            result.error("not_started", "Call start first", null)
                            return@setMethodCallHandler
                        }
                        cam.stopRecording { res ->
                            activity.runOnUiThread {
                                if (res.ok) {
                                    result.success(res.toMap())
                                } else {
                                    result.error("stop_recording_failed", res.error, null)
                                }
                            }
                        }
                    }
                    "cancelRecording" -> {
                        val cam = engine
                        if (cam == null) {
                            result.success(mapOf("ok" to true, "recording" to false))
                            return@setMethodCallHandler
                        }
                        cam.cancelRecording { res ->
                            activity.runOnUiThread {
                                result.success(res.toMap())
                            }
                        }
                    }
                    "setMusic" -> {
                        val cam = engine
                        if (cam == null) {
                            result.error("not_started", "Call start first", null)
                            return@setMethodCallHandler
                        }
                        val path = call.argument<String>("path")
                        val offsetMs = when (val v = call.argument<Any>("offsetMs")) {
                            is Int -> v.toLong()
                            is Long -> v
                            is Double -> v.toLong()
                            else -> 0L
                        }
                        fun floatArg(key: String, default: Float): Float {
                            return when (val raw = call.argument<Any>(key)) {
                                is Double -> raw.toFloat()
                                is Float -> raw
                                is Int -> raw.toFloat()
                                is Long -> raw.toFloat()
                                else -> default
                            }
                        }
                        cam.setMusic(
                            path = path,
                            offsetMs = offsetMs,
                            musicVolume = floatArg("musicVolume", 0.8f),
                            originalVolume = floatArg("originalVolume", 0.2f),
                        ) { res ->
                            activity.runOnUiThread {
                                result.success(res.toMap())
                            }
                        }
                    }
                    "clearMusic" -> {
                        val cam = engine
                        if (cam == null) {
                            result.success(
                                mapOf(
                                    "ok" to true,
                                    "musicPath" to null,
                                ),
                            )
                            return@setMethodCallHandler
                        }
                        cam.clearMusic { res ->
                            activity.runOnUiThread {
                                result.success(res.toMap())
                            }
                        }
                    }
                    "exportVideo" -> {
                        val cam = engine
                        if (cam == null) {
                            result.error("not_started", "Call start first", null)
                            return@setMethodCallHandler
                        }
                        val path = call.argument<String>("path")
                        val force = call.argument<Boolean>("force") ?: false
                        cam.exportVideo(inputPath = path, force = force) { res ->
                            activity.runOnUiThread {
                                if (res.ok) {
                                    result.success(res.toMap())
                                } else {
                                    result.error("export_failed", res.error, null)
                                }
                            }
                        }
                    }
                    "cancelExport" -> {
                        val cam = engine
                        if (cam == null) {
                            result.success(mapOf("ok" to true, "exporting" to false))
                            return@setMethodCallHandler
                        }
                        cam.cancelExport { res ->
                            activity.runOnUiThread {
                                result.success(res.toMap())
                            }
                        }
                    }
                    "setBeauty" -> {
                        val cam = engine
                        if (cam == null) {
                            result.error("not_started", "Call start first", null)
                            return@setMethodCallHandler
                        }
                        fun floatArg(key: String, default: Float = 0f): Float {
                            return when (val raw = call.argument<Any>(key)) {
                                is Double -> raw.toFloat()
                                is Float -> raw
                                is Int -> raw.toFloat()
                                is Long -> raw.toFloat()
                                else -> default
                            }
                        }
                        val params = BeautyParameters(
                            skinSmooth = floatArg("skinSmooth"),
                            brightness = floatArg("brightness"),
                            skinTone = floatArg("skinTone"),
                            sharpen = floatArg("sharpen"),
                            eyeEnhancement = floatArg("eyeEnhancement"),
                            enabled = call.argument<Boolean>("enabled") ?: true,
                        )
                        cam.setBeauty(params) { res ->
                            activity.runOnUiThread {
                                if (res.ok) {
                                    result.success(res.toMap())
                                } else {
                                    result.error("beauty_failed", res.error, null)
                                }
                            }
                        }
                    }
                    "setWarp" -> {
                        val cam = engine
                        if (cam == null) {
                            result.error("not_started", "Call start first", null)
                            return@setMethodCallHandler
                        }
                        fun floatArg(key: String, default: Float = 0f): Float {
                            return when (val raw = call.argument<Any>(key)) {
                                is Double -> raw.toFloat()
                                is Float -> raw
                                is Int -> raw.toFloat()
                                is Long -> raw.toFloat()
                                else -> default
                            }
                        }
                        val params = WarpParameters(
                            faceSlim = floatArg("faceSlim"),
                            bigEyes = floatArg("bigEyes"),
                            smallNose = floatArg("smallNose"),
                            bigLips = floatArg("bigLips"),
                            jaw = floatArg("jaw"),
                            chin = floatArg("chin"),
                            enabled = call.argument<Boolean>("enabled") ?: true,
                        )
                        cam.setWarp(params) { res ->
                            activity.runOnUiThread {
                                if (res.ok) {
                                    result.success(res.toMap())
                                } else {
                                    result.error("warp_failed", res.error, null)
                                }
                            }
                        }
                    }
                    "setMakeup" -> {
                        val cam = engine
                        if (cam == null) {
                            result.error("not_started", "Call start first", null)
                            return@setMethodCallHandler
                        }
                        fun floatArg(key: String, default: Float = 0f): Float {
                            return when (val raw = call.argument<Any>(key)) {
                                is Double -> raw.toFloat()
                                is Float -> raw
                                is Int -> raw.toFloat()
                                is Long -> raw.toFloat()
                                else -> default
                            }
                        }
                        fun rgbArg(key: String, fallback: FloatArray): FloatArray {
                            val list = call.argument<List<*>>(key) ?: return fallback
                            if (list.size < 3) return fallback
                            fun n(i: Int): Float = when (val v = list[i]) {
                                is Double -> v.toFloat()
                                is Float -> v
                                is Int -> v.toFloat()
                                is Long -> v.toFloat()
                                else -> fallback[i]
                            }
                            return floatArrayOf(n(0), n(1), n(2))
                        }
                        val params = MakeupParameters(
                            lipstick = floatArg("lipstick"),
                            blush = floatArg("blush"),
                            eyeliner = floatArg("eyeliner"),
                            eyeshadow = floatArg("eyeshadow"),
                            lipstickColor = rgbArg(
                                "lipstickColor",
                                floatArrayOf(0.78f, 0.18f, 0.28f),
                            ),
                            blushColor = rgbArg(
                                "blushColor",
                                floatArrayOf(0.95f, 0.48f, 0.52f),
                            ),
                            eyelinerColor = rgbArg(
                                "eyelinerColor",
                                floatArrayOf(0.06f, 0.05f, 0.08f),
                            ),
                            eyeshadowColor = rgbArg(
                                "eyeshadowColor",
                                floatArrayOf(0.42f, 0.28f, 0.55f),
                            ),
                            enabled = call.argument<Boolean>("enabled") ?: true,
                        )
                        cam.setMakeup(params) { res ->
                            activity.runOnUiThread {
                                if (res.ok) {
                                    result.success(res.toMap())
                                } else {
                                    result.error("makeup_failed", res.error, null)
                                }
                            }
                        }
                    }
                    "getState" -> {
                        val cam = engine
                        if (cam == null) {
                            result.success(
                                mapOf(
                                    "ok" to false,
                                    "bound" to false,
                                ),
                            )
                        } else {
                            result.success(cam.getState().toMap())
                        }
                    }
                    "dispose" -> {
                        try {
                            engine?.dispose()
                        } catch (t: Throwable) {
                            Log.w(TAG, "dispose", t)
                        }
                        engine = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    fun onPermissionResult(requestCode: Int, granted: Boolean) {
        if (requestCode != NativeCameraConstants.PERMISSION_REQUEST_CODE) return
        engine?.onPermissionResult(granted)
    }

    fun dispose() {
        try {
            engine?.dispose()
        } catch (_: Throwable) {
        }
        engine = null
    }

    private fun ensureEngine(
        flutterEngine: FlutterEngine,
        activity: FlutterActivity,
    ): NativeCameraEngine {
        engine?.let { return it }
        return NativeCameraEngine(
            activity = activity,
            textureRegistry = flutterEngine.renderer,
        ).also { engine = it }
    }

    private fun NativeCameraEngine.Result.toMap(): Map<String, Any?> = mapOf(
        "ok" to ok,
        "textureId" to textureId,
        "width" to width,
        "height" to height,
        "isFront" to isFront,
        "torchEnabled" to torchEnabled,
        "torchAvailable" to torchAvailable,
        "filterEnabled" to filterEnabled,
        "filterIntensity" to filterIntensity.toDouble(),
        "faceTrackingEnabled" to faceTrackingEnabled,
        "landmarkDebugEnabled" to landmarkDebugEnabled,
        "faceCount" to faceCount,
        "pitchDeg" to pitchDeg.toDouble(),
        "yawDeg" to yawDeg.toDouble(),
        "rollDeg" to rollDeg.toDouble(),
        "activeFaceEffectId" to activeFaceEffectId,
        "beautyEnabled" to beautyEnabled,
        "beautySkinSmooth" to beautySkinSmooth.toDouble(),
        "beautyBrightness" to beautyBrightness.toDouble(),
        "beautySkinTone" to beautySkinTone.toDouble(),
        "beautySharpen" to beautySharpen.toDouble(),
        "beautyEyeEnhancement" to beautyEyeEnhancement.toDouble(),
        "warpEnabled" to warpEnabled,
        "warpFaceSlim" to warpFaceSlim.toDouble(),
        "warpBigEyes" to warpBigEyes.toDouble(),
        "warpSmallNose" to warpSmallNose.toDouble(),
        "warpBigLips" to warpBigLips.toDouble(),
        "warpJaw" to warpJaw.toDouble(),
        "warpChin" to warpChin.toDouble(),
        "makeupEnabled" to makeupEnabled,
        "makeupLipstick" to makeupLipstick.toDouble(),
        "makeupBlush" to makeupBlush.toDouble(),
        "makeupEyeliner" to makeupEyeliner.toDouble(),
        "makeupEyeshadow" to makeupEyeshadow.toDouble(),
        "recording" to recording,
        "recordingPath" to recordingPath,
        "recordingDurationMs" to recordingDurationMs,
        "musicPath" to musicPath,
        "musicOffsetMs" to musicOffsetMs,
        "musicVolume" to musicVolume.toDouble(),
        "originalVolume" to originalVolume.toDouble(),
        "exporting" to exporting,
        "exportPath" to exportPath,
        "exportProgress" to exportProgress,
        "exportPassthrough" to exportPassthrough,
        "bound" to (textureId != null && ok),
        "error" to error,
    )
}
