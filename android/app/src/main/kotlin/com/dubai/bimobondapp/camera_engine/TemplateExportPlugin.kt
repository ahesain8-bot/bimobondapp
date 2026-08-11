package com.dubai.bimobondapp.camera_engine

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.io.File
import java.util.concurrent.Executors

/**
 * MethodChannel for shared GPU template composer + export.
 *
 * Channel: [CHANNEL]
 * Methods: composeTimeline, openPreview, setRecipe, seek, play, pause,
 * disposePreview, exportSession
 */
object TemplateExportPlugin {
    const val CHANNEL = "com.dubai.bimobondapp/template_export"
    private const val TAG = "TemplateExportPlugin"

    private val executor = Executors.newSingleThreadExecutor { r ->
        Thread(r, "template-export").apply { isDaemon = true }
    }

    @Volatile
    private var textureRegistry: TextureRegistry? = null

    @Volatile
    private var sessionComposer: TemplateGpuComposer? = null

    @Volatile
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null

    fun register(flutterEngine: FlutterEngine, activity: FlutterActivity) {
        textureRegistry = flutterEngine.renderer
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "composeTimeline" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as? Map<String, Any?>
                        if (args == null) {
                            result.error("invalid_args", "map required", null)
                            return@setMethodCallHandler
                        }
                        executor.execute {
                            try {
                                val request = parseGpuRequest(args)
                                val cacheDir = File(
                                    activity.applicationContext.cacheDir,
                                    "template_export",
                                ).apply { mkdirs() }
                                val out = File(
                                    cacheDir,
                                    "tpl_gpu_${System.currentTimeMillis()}.mp4",
                                )
                                val composer = TemplateGpuComposer(activity.applicationContext)
                                composer.configure(request)
                                val gpuOutcome = composer.export(out)
                                composer.release()

                                var ok = gpuOutcome.ok
                                var path = gpuOutcome.path
                                var error = gpuOutcome.error
                                var engine = "gpu"

                                // Fallback: Media3 Transformer path.
                                if (!ok) {
                                    Log.w(TAG, "GPU export failed ($error) — Media3 fallback")
                                    val media3 = TemplateCompositionEncoder(activity.applicationContext)
                                        .compose(parseMedia3Request(args))
                                    ok = media3.ok
                                    path = media3.path
                                    error = media3.error
                                    engine = "media3"
                                }

                                activity.runOnUiThread {
                                    if (ok && !path.isNullOrBlank()) {
                                        result.success(
                                            mapOf(
                                                "path" to path,
                                                "engine" to engine,
                                            ),
                                        )
                                    } else {
                                        result.error(
                                            "compose_failed",
                                            error ?: "compose_failed",
                                            null,
                                        )
                                    }
                                }
                            } catch (t: Throwable) {
                                Log.e(TAG, "composeTimeline", t)
                                activity.runOnUiThread {
                                    result.error(
                                        "compose_failed",
                                        t.message ?: "compose_failed",
                                        null,
                                    )
                                }
                            }
                        }
                    }

                    "openPreview" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                        activity.runOnUiThread {
                            try {
                                disposeSessionLocked()
                                val registry = textureRegistry
                                    ?: throw IllegalStateException("no_texture_registry")
                                val entry = registry.createSurfaceTexture()
                                textureEntry = entry
                                val composer = TemplateGpuComposer(activity.applicationContext)
                                composer.configure(parseGpuRequest(args))
                                composer.attachPreview(entry.surfaceTexture())
                                sessionComposer = composer
                                result.success(
                                    mapOf(
                                        "textureId" to entry.id(),
                                        "width" to asInt(args["width"], 1080),
                                        "height" to asInt(args["height"], 1920),
                                        "durationMs" to composer.totalDurationMs(),
                                    ),
                                )
                            } catch (t: Throwable) {
                                Log.e(TAG, "openPreview", t)
                                disposeSessionLocked()
                                result.error("preview_failed", t.message, null)
                            }
                        }
                    }

                    "setRecipe" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as? Map<String, Any?>
                        val composer = sessionComposer
                        if (args == null || composer == null) {
                            result.error("no_session", "openPreview first", null)
                            return@setMethodCallHandler
                        }
                        executor.execute {
                            try {
                                composer.configure(parseGpuRequest(args))
                                composer.seekMs(0L)
                                activity.runOnUiThread {
                                    result.success(
                                        mapOf("durationMs" to composer.totalDurationMs()),
                                    )
                                }
                            } catch (t: Throwable) {
                                activity.runOnUiThread {
                                    result.error("set_recipe_failed", t.message, null)
                                }
                            }
                        }
                    }

                    "seek" -> {
                        val ms = when (val raw = call.argument<Any>("ms")) {
                            is Int -> raw.toLong()
                            is Long -> raw
                            is Double -> raw.toLong()
                            else -> 0L
                        }
                        sessionComposer?.seekMs(ms)
                        result.success(null)
                    }

                    "play" -> {
                        sessionComposer?.play()
                        result.success(null)
                    }

                    "pause" -> {
                        sessionComposer?.pause()
                        result.success(null)
                    }

                    "exportSession" -> {
                        val quality = call.argument<String>("quality")?.lowercase() ?: "draft"
                        val composer = sessionComposer
                        if (composer == null) {
                            result.error("no_session", "openPreview first", null)
                            return@setMethodCallHandler
                        }
                        executor.execute {
                            try {
                                // Adjust bitrate/size for draft vs standard via reconfigure width if needed.
                                val cacheDir = File(
                                    activity.applicationContext.cacheDir,
                                    "template_export",
                                ).apply { mkdirs() }
                                val out = File(
                                    cacheDir,
                                    "tpl_session_${quality}_${System.currentTimeMillis()}.mp4",
                                )
                                val outcome = composer.export(out)
                                activity.runOnUiThread {
                                    if (outcome.ok && !outcome.path.isNullOrBlank()) {
                                        result.success(
                                            mapOf(
                                                "path" to outcome.path,
                                                "engine" to "gpu",
                                            ),
                                        )
                                    } else {
                                        result.error(
                                            "export_failed",
                                            outcome.error ?: "export_failed",
                                            null,
                                        )
                                    }
                                }
                            } catch (t: Throwable) {
                                activity.runOnUiThread {
                                    result.error("export_failed", t.message, null)
                                }
                            }
                        }
                    }

                    "disposePreview" -> {
                        activity.runOnUiThread {
                            disposeSessionLocked()
                            result.success(null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    fun dispose() {
        disposeSessionLocked()
    }

    private fun disposeSessionLocked() {
        try {
            sessionComposer?.release()
        } catch (_: Throwable) {
        }
        sessionComposer = null
        try {
            textureEntry?.release()
        } catch (_: Throwable) {
        }
        textureEntry = null
    }

    private fun parseGpuRequest(args: Map<String, Any?>): TemplateGpuComposer.Request {
        val width = asInt(args["width"], 1080)
        val height = asInt(args["height"], 1920)
        val fps = asInt(args["fps"], 30)
        val bitrate = asInt(args["bitrate"], 8_000_000)
        val clips = parseClips(args["clips"]).map {
            TemplateGpuComposer.Clip(
                type = it.type,
                path = it.path,
                durationMs = it.durationMs,
                trimStartMs = it.trimStartMs,
                trimEndMs = it.trimEndMs,
            )
        }
        val audioMap = args["audio"] as? Map<*, *>
        val audioPath = audioMap?.get("path")?.toString()?.trim()?.takeIf { it.isNotEmpty() }
        val audioStart = asLong(audioMap?.get("startMs"), 0L)
        val audioVol = asFloat(audioMap?.get("volume"), 1f)

        val matrixRaw = args["colorMatrix"] as? List<*>
        val colorMatrix = if (matrixRaw != null && matrixRaw.size >= 20) {
            FloatArray(20) { i ->
                asFloat(
                    matrixRaw[i],
                    when (i) {
                        0, 6, 12, 18 -> 1f
                        else -> 0f
                    },
                )
            }
        } else {
            null
        }

        val overlaysRaw = args["overlays"] as? List<*> ?: emptyList<Any>()
        val overlays = overlaysRaw.mapNotNull { raw ->
            val map = raw as? Map<*, *> ?: return@mapNotNull null
            val path = map["path"]?.toString()?.trim().orEmpty()
            if (path.isEmpty()) return@mapNotNull null
            TemplateGpuComposer.Overlay(
                path = path,
                startMs = asLong(map["startMs"], 0L),
                endMs = asLong(map["endMs"], Long.MAX_VALUE),
                opacity = asFloat(map["opacity"], 1f),
            )
        }

        return TemplateGpuComposer.Request(
            width = width,
            height = height,
            fps = fps,
            bitrate = bitrate,
            clips = clips,
            audioPath = audioPath,
            audioStartMs = audioStart,
            audioVolume = audioVol,
            colorMatrix = colorMatrix,
            overlays = overlays,
        )
    }

    private fun parseMedia3Request(args: Map<String, Any?>): TemplateCompositionEncoder.Request {
        val clips = parseClips(args["clips"])
        val audioMap = args["audio"] as? Map<*, *>
        val audio = if (audioMap != null) {
            val path = audioMap["path"]?.toString()?.trim().orEmpty()
            if (path.isEmpty()) {
                null
            } else {
                TemplateCompositionEncoder.AudioTrack(
                    path = path,
                    startMs = asLong(audioMap["startMs"], 0L),
                    endMs = asLongOrNull(audioMap["endMs"]),
                    volume = asFloat(audioMap["volume"], 1f),
                )
            }
        } else {
            null
        }
        return TemplateCompositionEncoder.Request(
            width = asInt(args["width"], 1080),
            height = asInt(args["height"], 1920),
            fps = asInt(args["fps"], 30),
            bitrate = asInt(args["bitrate"], 8_000_000),
            clips = clips.map {
                TemplateCompositionEncoder.Clip(
                    type = it.type,
                    path = it.path,
                    durationMs = it.durationMs,
                    trimStartMs = it.trimStartMs,
                    trimEndMs = it.trimEndMs,
                    volume = it.volume,
                )
            },
            audio = audio,
        )
    }

    private data class ParsedClip(
        val type: String,
        val path: String,
        val durationMs: Long,
        val trimStartMs: Long?,
        val trimEndMs: Long?,
        val volume: Float,
    )

    private fun parseClips(rawClips: Any?): List<ParsedClip> {
        val list = rawClips as? List<*> ?: return emptyList()
        return list.mapNotNull { raw ->
            val map = raw as? Map<*, *> ?: return@mapNotNull null
            val path = map["path"]?.toString()?.trim().orEmpty()
            if (path.isEmpty()) return@mapNotNull null
            ParsedClip(
                type = map["type"]?.toString() ?: "video",
                path = path,
                durationMs = asLong(map["durationMs"], 1000L),
                trimStartMs = asLongOrNull(map["trimStartMs"]),
                trimEndMs = asLongOrNull(map["trimEndMs"]),
                volume = asFloat(map["volume"], 1f),
            )
        }
    }

    private fun asInt(raw: Any?, default: Int): Int = when (raw) {
        is Int -> raw
        is Long -> raw.toInt()
        is Double -> raw.toInt()
        is Float -> raw.toInt()
        is String -> raw.toIntOrNull() ?: default
        else -> default
    }

    private fun asLong(raw: Any?, default: Long): Long = when (raw) {
        is Long -> raw
        is Int -> raw.toLong()
        is Double -> raw.toLong()
        is Float -> raw.toLong()
        is String -> raw.toLongOrNull() ?: default
        else -> default
    }

    private fun asLongOrNull(raw: Any?): Long? = when (raw) {
        null -> null
        is Long -> raw
        is Int -> raw.toLong()
        is Double -> raw.toLong()
        is Float -> raw.toLong()
        is String -> raw.toLongOrNull()
        else -> null
    }

    private fun asFloat(raw: Any?, default: Float): Float = when (raw) {
        is Float -> raw
        is Double -> raw.toFloat()
        is Int -> raw.toFloat()
        is Long -> raw.toFloat()
        is String -> raw.toFloatOrNull() ?: default
        else -> default
    }
}
