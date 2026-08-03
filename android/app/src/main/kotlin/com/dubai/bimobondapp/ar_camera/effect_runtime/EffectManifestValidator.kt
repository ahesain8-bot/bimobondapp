package com.dubai.bimobondapp.ar_camera.effect_runtime

import java.io.File

object EffectManifestValidator {
    private val effectIdPattern = Regex("^[a-z0-9][a-z0-9._-]{2,79}$")
    private val semanticVersionPattern = Regex("^\\d+\\.\\d+\\.\\d+(?:[-+][0-9A-Za-z.-]+)?$")

    fun validate(manifest: EffectManifest): List<EffectError> = buildList {
        if (manifest.schemaVersion != EffectContract.SCHEMA_VERSION) {
            add(
                EffectError(
                    code = EffectErrorCode.UNSUPPORTED_SCHEMA_VERSION,
                    message = "Unsupported schemaVersion '${manifest.schemaVersion}'. " +
                        "Expected '${EffectContract.SCHEMA_VERSION}'.",
                    field = "schemaVersion",
                ),
            )
        }

        if (!effectIdPattern.matches(manifest.effectId)) {
            add(
                EffectError(
                    code = EffectErrorCode.INVALID_EFFECT_ID,
                    message = "effectId must be 3-80 characters using lowercase letters, " +
                        "numbers, dots, underscores or hyphens.",
                    field = "effectId",
                ),
            )
        }

        if (!semanticVersionPattern.matches(manifest.effectVersion)) {
            add(
                EffectError(
                    code = EffectErrorCode.INVALID_EFFECT_VERSION,
                    message = "effectVersion must use semantic version format, for example 1.0.0.",
                    field = "effectVersion",
                ),
            )
        }

        if (!semanticVersionPattern.matches(manifest.minimumEngineVersion)) {
            add(
                EffectError(
                    code = EffectErrorCode.INVALID_EFFECT_VERSION,
                    message = "minimumEngineVersion must use semantic version format.",
                    field = "minimumEngineVersion",
                ),
            )
        }

        if (manifest.maxFaces !in 1..2) {
            add(
                EffectError(
                    code = EffectErrorCode.INVALID_MAX_FACES,
                    message = "maxFaces must be 1 or 2.",
                    field = "maxFaces",
                ),
            )
        }

        if (manifest.graph.nodes.isEmpty()) {
            add(
                EffectError(
                    code = EffectErrorCode.EMPTY_GRAPH,
                    message = "graph.nodes must contain at least one node.",
                    field = "graph.nodes",
                ),
            )
        }

        val seenNodeIds = mutableSetOf<String>()
        for (node in manifest.graph.nodes) {
            if (!seenNodeIds.add(node.id)) {
                add(
                    EffectError(
                        code = EffectErrorCode.DUPLICATE_NODE_ID,
                        message = "Duplicate node id '${node.id}'.",
                        field = "graph.nodes.id",
                        nodeId = node.id,
                    ),
                )
            }

            when (node) {
                is Sticker2DNodeDefinition -> validateSticker(node, this)
            }
        }
    }

    private fun validateSticker(
        node: Sticker2DNodeDefinition,
        errors: MutableList<EffectError>,
    ) {
        if (!isSafeRelativePath(node.asset)) {
            errors += EffectError(
                code = EffectErrorCode.INVALID_ASSET_PATH,
                message = "Sticker asset must be a safe relative path inside the effect package.",
                field = "asset",
                nodeId = node.id,
            )
        }

        if (node.opacity !in 0f..1f) {
            errors += EffectError(
                code = EffectErrorCode.INVALID_OPACITY,
                message = "opacity must be between 0 and 1.",
                field = "opacity",
                nodeId = node.id,
            )
        }

        val landmarks = listOf(
            node.anchor.leftLandmark,
            node.anchor.rightLandmark,
            node.anchor.anchorLandmark,
            node.anchor.secondaryAnchorLandmark,
            node.transform.heightAnchorTopLandmark,
            node.transform.heightAnchorBottomLandmark,
        )
        if (landmarks.any { it < -1 || it > 467 }) {
            errors += EffectError(
                code = EffectErrorCode.INVALID_LANDMARK,
                message = "MediaPipe landmark indices must be -1 or between 0 and 467.",
                field = "anchor",
                nodeId = node.id,
            )
        }

        val t = node.transform
        val finiteValues = listOf(
            t.offsetXFaceFrac,
            t.offsetYFaceFrac,
            t.widthScreenMult,
            t.widthFaceFrac,
            t.widthMinFaceFrac,
            t.maxFaceWidthFrac,
            t.pivotU,
            t.pivotV,
            t.rotationOffsetDeg,
            t.yawSqueeze,
            t.heightSpanFrac,
        )
        if (finiteValues.any { !it.isFinite() }) {
            errors += EffectError(
                code = EffectErrorCode.INVALID_TRANSFORM,
                message = "Transform values must be finite numbers.",
                field = "transform",
                nodeId = node.id,
            )
        }

        if (t.pivotU !in 0f..1f || t.pivotV !in 0f..1f) {
            errors += EffectError(
                code = EffectErrorCode.INVALID_TRANSFORM,
                message = "pivotU and pivotV must be between 0 and 1.",
                field = "transform.pivot",
                nodeId = node.id,
            )
        }

        if (
            t.widthScreenMult < 0f ||
            t.widthFaceFrac < 0f ||
            t.widthMinFaceFrac < 0f ||
            t.maxFaceWidthFrac < 0f ||
            t.heightSpanFrac < 0f
        ) {
            errors += EffectError(
                code = EffectErrorCode.INVALID_TRANSFORM,
                message = "Sticker size values must not be negative.",
                field = "transform",
                nodeId = node.id,
            )
        }
    }

    private fun isSafeRelativePath(path: String): Boolean {
        if (path.isBlank()) return false
        val normalized = path.replace('\\', '/')
        if (normalized.startsWith('/') || normalized.contains(':')) return false
        val parts = normalized.split('/').filter { it.isNotEmpty() }
        if (parts.isEmpty() || parts.any { it == "." || it == ".." }) return false
        return !File(normalized).isAbsolute && normalized.lowercase().endsWith(".png")
    }
}
