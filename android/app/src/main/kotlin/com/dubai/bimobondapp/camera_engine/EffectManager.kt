package com.dubai.bimobondapp.camera_engine

import android.content.Context
import android.util.Log
import java.util.concurrent.ConcurrentHashMap

/**
 * Phase 4: modular 2D face-effect orchestrator.
 *
 * - Catalog + dynamic register/load
 * - Landmark → [EffectTransform] on analyzer thread
 * - GPU draw via [FaceStickerEffect] on GL thread
 */
class EffectManager {
    private val lock = Any()

    private val assets = ConcurrentHashMap<String, EffectAsset>()
    private val definitions = LinkedHashMap<String, FaceEffectDefinition>()
    private val smoothPrev = HashMap<String, EffectTransform>()

    private val stickerEffect = FaceStickerEffect()

    @Volatile
    private var activeId: String? = null

    @Volatile
    private var glReady = false

    val renderer: FaceStickerEffect get() = stickerEffect

    fun activeEffectId(): String? = activeId

    fun listEffects(): List<FaceEffectInfo> = synchronized(lock) {
        definitions.values.map {
            FaceEffectInfo(
                id = it.id,
                name = it.name,
                version = it.version,
                remote = it.remote,
            )
        }
    }

    /** Registers bundled procedural assets + definitions. Safe from any thread. */
    fun bootstrapBundled(context: Context) {
        synchronized(lock) {
            // Keep bundled presets available as nativePreset fallbacks even after remote installs.
            if (assets.keys.any { it.startsWith("asset_") } &&
                definitions.values.any { !it.remote }
            ) {
                return
            }
            for ((id, asset) in ProceduralFaceAssets.buildBundled()) {
                if (!assets.containsKey(id)) {
                    assets[id] = asset
                }
            }
            for (def in FaceEffectCatalog.bundled) {
                if (!definitions.containsKey(def.id)) {
                    definitions[def.id] = def
                }
            }
            glReady = false
            Log.i(TAG, "bundled ${FaceEffectCatalog.bundled.size} face effects")
        }
        context.applicationContext
    }

    /** Dynamically register an effect definition (assets must already be loaded). */
    fun registerEffect(definition: FaceEffectDefinition) {
        synchronized(lock) {
            definitions[definition.id] = definition
        }
    }

    /**
     * Phase 8: install/replace a remote effect from absolute file paths.
     * Validates [version] — skips asset reload when already at same/newer version unless [force].
     */
    fun installRemoteEffect(
        definition: FaceEffectDefinition,
        layerFiles: Map<String, String>,
        force: Boolean,
    ): Boolean {
        synchronized(lock) {
            val existing = definitions[definition.id]
            if (!force &&
                existing != null &&
                existing.version >= definition.version &&
                existing.layers.all { assets.containsKey(it.assetId) }
            ) {
                Log.i(TAG, "install skip ${definition.id} v${definition.version} (current=${existing.version})")
                return true
            }

            // Release previous remote assets for this effect id.
            if (existing != null) {
                for (layer in existing.layers) {
                    if (layer.assetId.startsWith("${definition.id}_")) {
                        assets.remove(layer.assetId)?.release()
                    }
                }
            }

            for ((assetId, path) in layerFiles) {
                val loaded = EffectAsset.fromFile(assetId, path)
                if (loaded == null) {
                    Log.w(TAG, "failed to load asset $assetId from $path")
                    return false
                }
                assets[assetId]?.release()
                assets[assetId] = loaded
            }
            definitions[definition.id] = definition.copy(remote = true)
            glReady = false
            Log.i(TAG, "installed remote ${definition.id} v${definition.version}")
            return true
        }
    }

    /** Unload remote effects by id and release their textures/bitmaps. */
    fun unloadEffects(ids: Collection<String>) {
        synchronized(lock) {
            for (id in ids) {
                val def = definitions[id] ?: continue
                if (!def.remote) continue
                if (activeId == id) {
                    activeId = null
                    stickerEffect.enabled = false
                    stickerEffect.clearCommands()
                }
                for (layer in def.layers) {
                    assets.remove(layer.assetId)?.release()
                }
                definitions.remove(id)
                smoothPrev.keys.filter { it.startsWith("$id:") }.forEach { smoothPrev.remove(it) }
            }
            glReady = false
        }
    }

    /** Dynamically load an asset from app assets/ (e.g. face_effects/foo.png). */
    fun loadAssetFromPath(context: Context, assetId: String, assetPath: String): Boolean {
        val loaded = EffectAsset.fromAssetPath(context, assetId, assetPath) ?: return false
        synchronized(lock) {
            assets[assetId]?.release()
            assets[assetId] = loaded
            glReady = false
        }
        return true
    }

    /** Dynamically load an asset from an absolute file path. */
    fun loadAssetFromFile(assetId: String, filePath: String): Boolean {
        val loaded = EffectAsset.fromFile(assetId, filePath) ?: return false
        synchronized(lock) {
            assets[assetId]?.release()
            assets[assetId] = loaded
            glReady = false
        }
        return true
    }

    fun setActiveEffect(effectId: String?) {
        val id = effectId?.takeIf { it.isNotBlank() && it != "none" }
        synchronized(lock) {
            if (id != null && !definitions.containsKey(id)) {
                Log.w(TAG, "unknown effect id=$id")
                activeId = null
                stickerEffect.enabled = false
                stickerEffect.clearCommands()
                smoothPrev.clear()
                return
            }
            activeId = id
            stickerEffect.enabled = id != null
            if (id == null) {
                stickerEffect.clearCommands()
                smoothPrev.clear()
            }
        }
    }

    /**
     * Analyzer thread: resolve transforms from landmarks.
     * Does not touch GL — only updates draw commands.
     */
    fun updateFromFaces(faces: List<FaceLandmarks>, mirrorX: Boolean) {
        val id = activeId
        if (id == null) {
            stickerEffect.clearCommands()
            return
        }
        val def: FaceEffectDefinition
        val assetSnap: Map<String, EffectAsset>
        synchronized(lock) {
            def = definitions[id] ?: run {
                stickerEffect.clearCommands()
                return
            }
            assetSnap = HashMap(assets)
        }

        if (faces.isEmpty()) {
            stickerEffect.clearCommands()
            synchronized(lock) { smoothPrev.clear() }
            return
        }

        val commands = ArrayList<FaceStickerDrawCommand>(def.layers.size * faces.size)
        for ((faceIndex, face) in faces.withIndex()) {
            for ((layerIndex, layer) in def.layers.withIndex()) {
                val asset = assetSnap[layer.assetId] ?: continue
                if (!asset.isReady()) continue
                val raw = EffectTransformResolver.resolve(
                    layer = layer,
                    face = face,
                    assetAspect = asset.aspect,
                    mirrorX = mirrorX,
                ) ?: continue
                val key = "$id:$faceIndex:$layerIndex"
                val smoothed = synchronized(lock) {
                    val next = EffectTransformResolver.smooth(smoothPrev[key], raw)
                    smoothPrev[key] = next
                    next
                }
                commands.add(FaceStickerDrawCommand(asset, smoothed))
            }
        }
        stickerEffect.setCommands(commands)
    }

    fun clearTransforms() {
        stickerEffect.clearCommands()
        synchronized(lock) { smoothPrev.clear() }
    }

    /** GL thread: upload textures + compile shader. */
    fun ensureGlReady() {
        if (glReady) {
            stickerEffect.ensureProgram()
            return
        }
        synchronized(lock) {
            for (asset in assets.values) {
                asset.uploadToGl()
            }
            glReady = true
        }
        stickerEffect.ensureProgram()
    }

    fun draw(
        oesTextureId: Int,
        width: Int,
        height: Int,
        transformMatrix: FloatArray,
    ) {
        if (!stickerEffect.enabled) return
        ensureGlReady()
        stickerEffect.draw(oesTextureId, width, height, transformMatrix)
    }

    fun releaseGl() {
        synchronized(lock) {
            for (asset in assets.values) {
                asset.releaseGl()
            }
            glReady = false
        }
        stickerEffect.release()
    }

    fun release() {
        synchronized(lock) {
            for (asset in assets.values) {
                asset.release()
            }
            assets.clear()
            definitions.clear()
            smoothPrev.clear()
            activeId = null
            glReady = false
        }
        stickerEffect.release()
    }

    companion object {
        private const val TAG = "EffectManager"
    }
}
