package com.dubai.bimobondapp.ar_camera.effect_runtime

import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

/** Parses effect.json and performs contract validation before runtime use. */
object EffectManifestParser {

    fun parse(jsonText: String): EffectManifestResult {
        val root = try {
            JSONObject(jsonText)
        } catch (error: JSONException) {
            return EffectManifestResult.Failure(
                listOf(
                    EffectError(
                        code = EffectErrorCode.INVALID_JSON,
                        message = error.message ?: "effect.json is not valid JSON.",
                    ),
                ),
            )
        }

        return try {
            val manifest = parseManifest(root)
            val errors = EffectManifestValidator.validate(manifest)
            if (errors.isEmpty()) {
                EffectManifestResult.Success(manifest)
            } else {
                EffectManifestResult.Failure(errors)
            }
        } catch (error: ManifestReadException) {
            EffectManifestResult.Failure(listOf(error.effectError))
        } catch (error: JSONException) {
            EffectManifestResult.Failure(
                listOf(
                    EffectError(
                        code = EffectErrorCode.INVALID_FIELD_TYPE,
                        message = error.message ?: "effect.json contains an invalid value.",
                    ),
                ),
            )
        }
    }

    private fun parseManifest(root: JSONObject): EffectManifest {
        val graphObject = requiredObject(root, "graph")
        val nodesArray = requiredArray(graphObject, "nodes")
        val nodes = buildList {
            for (index in 0 until nodesArray.length()) {
                val nodeObject = nodesArray.optJSONObject(index)
                    ?: fail(
                        EffectErrorCode.INVALID_FIELD_TYPE,
                        "Each graph.nodes item must be an object.",
                        "graph.nodes[$index]",
                    )
                add(parseNode(nodeObject, index))
            }
        }

        return EffectManifest(
            schemaVersion = requiredString(root, "schemaVersion"),
            effectId = requiredString(root, "effectId"),
            effectVersion = requiredString(root, "effectVersion"),
            minimumEngineVersion = requiredString(root, "minimumEngineVersion"),
            displayName = optionalString(root, "displayName"),
            maxFaces = root.optInt("maxFaces", 1),
            graph = EffectGraphDefinition(nodes = nodes),
        )
    }

    private fun parseNode(node: JSONObject, index: Int): EffectNodeDefinition {
        val id = requiredString(node, "id", "graph.nodes[$index].id")
        val type = requiredString(node, "type", "graph.nodes[$index].type")
        val enabled = node.optBoolean("enabled", true)
        val faceTargetRaw = node.optString("faceTarget", EffectFaceTarget.ALL.wireValue)
        val faceTarget = EffectFaceTarget.fromWire(faceTargetRaw)
            ?: fail(
                EffectErrorCode.INVALID_FACE_TARGET,
                "Unsupported faceTarget '$faceTargetRaw'.",
                "graph.nodes[$index].faceTarget",
                id,
            )

        return when (type.lowercase()) {
            EffectContract.NODE_STICKER_2D -> parseStickerNode(
                node = node,
                index = index,
                id = id,
                enabled = enabled,
                faceTarget = faceTarget,
            )

            else -> fail(
                EffectErrorCode.UNSUPPORTED_NODE_TYPE,
                "Unsupported node type '$type'.",
                "graph.nodes[$index].type",
                id,
            )
        }
    }

    private fun parseStickerNode(
        node: JSONObject,
        index: Int,
        id: String,
        enabled: Boolean,
        faceTarget: EffectFaceTarget,
    ): Sticker2DNodeDefinition {
        val anchor = requiredObject(node, "anchor", "graph.nodes[$index].anchor")
        val transform = node.optJSONObject("transform") ?: JSONObject()

        val pinXRaw = anchor.optString("pinX", EffectStickerPinX.REF_MIDPOINT.wireValue)
        val pinYRaw = anchor.optString("pinY", EffectStickerPinY.ANCHOR.wireValue)
        val blendModeRaw = node.optString("blendMode", EffectBlendMode.NORMAL.wireValue)

        val pinX = EffectStickerPinX.fromWire(pinXRaw)
            ?: fail(
                EffectErrorCode.INVALID_PIN,
                "Unsupported pinX '$pinXRaw'.",
                "graph.nodes[$index].anchor.pinX",
                id,
            )
        val pinY = EffectStickerPinY.fromWire(pinYRaw)
            ?: fail(
                EffectErrorCode.INVALID_PIN,
                "Unsupported pinY '$pinYRaw'.",
                "graph.nodes[$index].anchor.pinY",
                id,
            )
        val blendMode = EffectBlendMode.fromWire(blendModeRaw)
            ?: fail(
                EffectErrorCode.INVALID_BLEND_MODE,
                "Unsupported blendMode '$blendModeRaw'.",
                "graph.nodes[$index].blendMode",
                id,
            )

        return Sticker2DNodeDefinition(
            id = id,
            enabled = enabled,
            faceTarget = faceTarget,
            asset = requiredString(node, "asset", "graph.nodes[$index].asset"),
            opacity = node.optDouble("opacity", 1.0).toFloat(),
            zIndex = node.optInt("zIndex", 0),
            blendMode = blendMode,
            anchor = StickerAnchorDefinition(
                leftLandmark = requiredInt(
                    anchor,
                    "leftLandmark",
                    "graph.nodes[$index].anchor.leftLandmark",
                ),
                rightLandmark = requiredInt(
                    anchor,
                    "rightLandmark",
                    "graph.nodes[$index].anchor.rightLandmark",
                ),
                anchorLandmark = requiredInt(
                    anchor,
                    "anchorLandmark",
                    "graph.nodes[$index].anchor.anchorLandmark",
                ),
                secondaryAnchorLandmark = anchor.optInt("secondaryAnchorLandmark", -1),
                secondaryBlendY = anchor.optDouble("secondaryBlendY", 0.0).toFloat(),
                pinX = pinX,
                pinY = pinY,
                useAveragedEyes = anchor.optBoolean("useAveragedEyes", false),
            ),
            transform = StickerTransformDefinition(
                offsetXFaceFrac = transform.optDouble("offsetXFaceFrac", 0.0).toFloat(),
                offsetYFaceFrac = transform.optDouble("offsetYFaceFrac", 0.0).toFloat(),
                widthScreenMult = transform.optDouble("widthScreenMult", 0.0).toFloat(),
                widthFaceFrac = transform.optDouble("widthFaceFrac", 0.0).toFloat(),
                widthMinFaceFrac = transform.optDouble("widthMinFaceFrac", 0.0).toFloat(),
                maxFaceWidthFrac = transform.optDouble("maxFaceWidthFrac", 0.0).toFloat(),
                pivotU = transform.optDouble("pivotU", 0.5).toFloat(),
                pivotV = transform.optDouble("pivotV", 0.5).toFloat(),
                rotationOffsetDeg = transform.optDouble("rotationOffsetDeg", 0.0).toFloat(),
                yawSqueeze = transform.optDouble("yawSqueeze", 0.0).toFloat(),
                scaleFromFaceBox = transform.optBoolean("scaleFromFaceBox", false),
                heightSpanFrac = transform.optDouble("heightSpanFrac", 0.0).toFloat(),
                heightAnchorTopLandmark = transform.optInt("heightAnchorTopLandmark", -1),
                heightAnchorBottomLandmark = transform.optInt("heightAnchorBottomLandmark", -1),
            ),
        )
    }

    private fun requiredString(
        objectValue: JSONObject,
        key: String,
        field: String = key,
    ): String {
        if (!objectValue.has(key) || objectValue.isNull(key)) {
            fail(
                EffectErrorCode.MISSING_REQUIRED_FIELD,
                "Missing required field '$field'.",
                field,
            )
        }
        val value = objectValue.optString(key, "").trim()
        if (value.isEmpty()) {
            fail(
                EffectErrorCode.MISSING_REQUIRED_FIELD,
                "Field '$field' must not be empty.",
                field,
            )
        }
        return value
    }

    private fun optionalString(objectValue: JSONObject, key: String): String? {
        if (!objectValue.has(key) || objectValue.isNull(key)) return null
        return objectValue.optString(key).trim().ifEmpty { null }
    }

    private fun requiredInt(objectValue: JSONObject, key: String, field: String): Int {
        if (!objectValue.has(key) || objectValue.isNull(key)) {
            fail(
                EffectErrorCode.MISSING_REQUIRED_FIELD,
                "Missing required field '$field'.",
                field,
            )
        }
        return try {
            objectValue.getInt(key)
        } catch (_: JSONException) {
            fail(
                EffectErrorCode.INVALID_FIELD_TYPE,
                "Field '$field' must be an integer.",
                field,
            )
        }
    }

    private fun requiredObject(
        objectValue: JSONObject,
        key: String,
        field: String = key,
    ): JSONObject {
        return objectValue.optJSONObject(key)
            ?: fail(
                EffectErrorCode.MISSING_REQUIRED_FIELD,
                "Field '$field' must be an object.",
                field,
            )
    }

    private fun requiredArray(
        objectValue: JSONObject,
        key: String,
        field: String = key,
    ): JSONArray {
        return objectValue.optJSONArray(key)
            ?: fail(
                EffectErrorCode.MISSING_REQUIRED_FIELD,
                "Field '$field' must be an array.",
                field,
            )
    }

    private fun fail(
        code: EffectErrorCode,
        message: String,
        field: String? = null,
        nodeId: String? = null,
    ): Nothing {
        throw ManifestReadException(
            EffectError(
                code = code,
                message = message,
                field = field,
                nodeId = nodeId,
            ),
        )
    }

    private class ManifestReadException(
        val effectError: EffectError,
    ) : RuntimeException(effectError.message)
}
