package com.dubai.bimobondapp.camera_engine

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.min

/** One sticker layer within a face effect (may share assets across layers). */
data class FaceStickerLayer(
    val assetId: String,
    val leftLandmark: Int,
    val rightLandmark: Int,
    val anchorLandmark: Int,
    val pinX: EffectPinX = EffectPinX.REF_MIDPOINT,
    val pinY: EffectPinY = EffectPinY.ANCHOR,
    val widthOverRef: Float = 2.4f,
    val widthFaceFrac: Float = 0f,
    val offsetXFaceFrac: Float = 0f,
    val offsetYFaceFrac: Float = 0f,
    val rotationOffsetDeg: Float = 0f,
    val yawSqueeze: Float = 0.2f,
    val pivotU: Float = 0.5f,
    val pivotV: Float = 0.5f,
    val opacity: Float = 1f,
)

data class FaceEffectDefinition(
    val id: String,
    val name: String,
    val layers: List<FaceStickerLayer>,
    val version: Int = 1,
    val remote: Boolean = false,
)

data class FaceEffectInfo(
    val id: String,
    val name: String,
    val version: Int = 1,
    val remote: Boolean = false,
)

/** Resolved draw command for one sticker on one face. */
data class FaceStickerDrawCommand(
    val asset: EffectAsset,
    val transform: EffectTransform,
)

object FaceEffectCatalog {
    // MediaPipe Face Mesh indices
    private const val L_EYE = 33
    private const val R_EYE = 263
    private const val NOSE_TIP = 1
    private const val NOSE_BRIDGE = 168
    private const val FOREHEAD = 10
    private const val CHIN = 152
    private const val MOUTH_L = 61
    private const val MOUTH_R = 291
    private const val L_CHEEK = 234
    private const val R_CHEEK = 454

    val bundled: List<FaceEffectDefinition> = listOf(
        FaceEffectDefinition(
            id = "glasses",
            name = "Glasses",
            layers = listOf(
                FaceStickerLayer(
                    assetId = "asset_glasses",
                    leftLandmark = L_EYE,
                    rightLandmark = R_EYE,
                    anchorLandmark = NOSE_BRIDGE,
                    pinX = EffectPinX.REF_MIDPOINT,
                    pinY = EffectPinY.REF_MIDLINE,
                    widthOverRef = 2.65f,
                    yawSqueeze = 0.15f,
                    pivotV = 0.5f,
                ),
            ),
        ),
        FaceEffectDefinition(
            id = "dog_ears",
            name = "Dog ears",
            layers = listOf(
                FaceStickerLayer(
                    assetId = "asset_dog_ears",
                    leftLandmark = L_EYE,
                    rightLandmark = R_EYE,
                    anchorLandmark = FOREHEAD,
                    pinX = EffectPinX.REF_MIDPOINT,
                    pinY = EffectPinY.ABOVE_REF,
                    widthOverRef = 3.2f,
                    offsetYFaceFrac = -0.22f,
                    yawSqueeze = 0.18f,
                    pivotV = 0.85f,
                ),
                FaceStickerLayer(
                    assetId = "asset_dog_nose",
                    leftLandmark = L_EYE,
                    rightLandmark = R_EYE,
                    anchorLandmark = NOSE_TIP,
                    pinX = EffectPinX.ANCHOR,
                    pinY = EffectPinY.ANCHOR,
                    widthOverRef = 0.95f,
                    yawSqueeze = 0.12f,
                ),
            ),
        ),
        FaceEffectDefinition(
            id = "cat_ears",
            name = "Cat ears",
            layers = listOf(
                FaceStickerLayer(
                    assetId = "asset_cat_ears",
                    leftLandmark = L_EYE,
                    rightLandmark = R_EYE,
                    anchorLandmark = FOREHEAD,
                    pinX = EffectPinX.REF_MIDPOINT,
                    pinY = EffectPinY.ABOVE_REF,
                    widthOverRef = 2.9f,
                    offsetYFaceFrac = -0.2f,
                    yawSqueeze = 0.16f,
                    pivotV = 0.9f,
                ),
            ),
        ),
        FaceEffectDefinition(
            id = "hat",
            name = "Hat",
            layers = listOf(
                FaceStickerLayer(
                    assetId = "asset_hat",
                    leftLandmark = L_EYE,
                    rightLandmark = R_EYE,
                    anchorLandmark = FOREHEAD,
                    pinX = EffectPinX.REF_MIDPOINT,
                    pinY = EffectPinY.ABOVE_REF,
                    widthOverRef = 3.4f,
                    offsetYFaceFrac = -0.28f,
                    yawSqueeze = 0.2f,
                    pivotV = 0.85f,
                ),
            ),
        ),
        FaceEffectDefinition(
            id = "nose",
            name = "Clown nose",
            layers = listOf(
                FaceStickerLayer(
                    assetId = "asset_clown_nose",
                    leftLandmark = L_EYE,
                    rightLandmark = R_EYE,
                    anchorLandmark = NOSE_TIP,
                    pinX = EffectPinX.ANCHOR,
                    pinY = EffectPinY.ANCHOR,
                    widthOverRef = 0.85f,
                    yawSqueeze = 0.1f,
                ),
            ),
        ),
        FaceEffectDefinition(
            id = "mask",
            name = "Mask",
            layers = listOf(
                FaceStickerLayer(
                    assetId = "asset_mask",
                    leftLandmark = L_CHEEK,
                    rightLandmark = R_CHEEK,
                    anchorLandmark = NOSE_TIP,
                    pinX = EffectPinX.REF_MIDPOINT,
                    pinY = EffectPinY.ANCHOR,
                    widthOverRef = 1.35f,
                    offsetYFaceFrac = 0.02f,
                    yawSqueeze = 0.22f,
                    pivotV = 0.35f,
                    opacity = 0.92f,
                ),
            ),
        ),
        FaceEffectDefinition(
            id = "sticker",
            name = "Face sticker",
            layers = listOf(
                FaceStickerLayer(
                    assetId = "asset_sticker",
                    leftLandmark = MOUTH_L,
                    rightLandmark = MOUTH_R,
                    anchorLandmark = CHIN,
                    pinX = EffectPinX.REF_MIDPOINT,
                    pinY = EffectPinY.ANCHOR,
                    widthOverRef = 1.6f,
                    offsetYFaceFrac = 0.08f,
                    yawSqueeze = 0.1f,
                ),
            ),
        ),
    )

    fun infoList(): List<FaceEffectInfo> =
        bundled.map { FaceEffectInfo(it.id, it.name, it.version, it.remote) }

    fun find(id: String): FaceEffectDefinition? =
        bundled.firstOrNull { it.id == id }
}

object ProceduralFaceAssets {
    fun buildBundled(): Map<String, EffectAsset> {
        val map = LinkedHashMap<String, EffectAsset>()
        map["asset_glasses"] = EffectAsset.fromBitmap("asset_glasses", glasses())
        map["asset_dog_ears"] = EffectAsset.fromBitmap("asset_dog_ears", dogEars())
        map["asset_dog_nose"] = EffectAsset.fromBitmap("asset_dog_nose", dogNose())
        map["asset_cat_ears"] = EffectAsset.fromBitmap("asset_cat_ears", catEars())
        map["asset_hat"] = EffectAsset.fromBitmap("asset_hat", hat())
        map["asset_clown_nose"] = EffectAsset.fromBitmap("asset_clown_nose", clownNose())
        map["asset_mask"] = EffectAsset.fromBitmap("asset_mask", mask())
        map["asset_sticker"] = EffectAsset.fromBitmap("asset_sticker", faceSticker())
        return map
    }

    private fun glasses(): Bitmap {
        val w = 512
        val h = 220
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(20, 20, 24)
            style = Paint.Style.STROKE
            strokeWidth = 18f
        }
        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(40, 180, 220, 255)
            style = Paint.Style.FILL
        }
        val bridge = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(20, 20, 24)
            strokeWidth = 14f
            style = Paint.Style.STROKE
        }
        val left = RectF(40f, 40f, 230f, 180f)
        val right = RectF(282f, 40f, 472f, 180f)
        c.drawOval(left, fill)
        c.drawOval(right, fill)
        c.drawOval(left, stroke)
        c.drawOval(right, stroke)
        c.drawLine(230f, 110f, 282f, 110f, bridge)
        return bmp
    }

    private fun dogEars(): Bitmap {
        val w = 512
        val h = 280
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val outer = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(140, 90, 40) }
        val inner = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(230, 170, 150) }
        fun ear(cx: Float, flip: Boolean) {
            val path = Path()
            val s = if (flip) -1f else 1f
            path.moveTo(cx, 240f)
            path.quadTo(cx + s * 90f, 40f, cx + s * 20f, 20f)
            path.quadTo(cx - s * 10f, 100f, cx, 240f)
            c.drawPath(path, outer)
            val innerPath = Path()
            innerPath.moveTo(cx, 220f)
            innerPath.quadTo(cx + s * 50f, 70f, cx + s * 12f, 50f)
            innerPath.quadTo(cx - s * 4f, 110f, cx, 220f)
            c.drawPath(innerPath, inner)
        }
        ear(140f, flip = false)
        ear(372f, flip = true)
        return bmp
    }

    private fun dogNose(): Bitmap {
        val size = 180
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(30, 20, 18) }
        c.drawOval(RectF(20f, 40f, 160f, 150f), paint)
        val highlight = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(120, 255, 255, 255) }
        c.drawCircle(70f, 75f, 14f, highlight)
        return bmp
    }

    private fun catEars(): Bitmap {
        val w = 512
        val h = 260
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val outer = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(240, 170, 60) }
        val inner = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(255, 140, 170) }
        fun ear(baseX: Float, tipX: Float) {
            val path = Path()
            path.moveTo(baseX - 55f, 240f)
            path.lineTo(tipX, 18f)
            path.lineTo(baseX + 55f, 240f)
            path.close()
            c.drawPath(path, outer)
            val innerPath = Path()
            innerPath.moveTo(baseX - 28f, 220f)
            innerPath.lineTo(tipX, 70f)
            innerPath.lineTo(baseX + 28f, 220f)
            innerPath.close()
            c.drawPath(innerPath, inner)
        }
        ear(150f, 130f)
        ear(362f, 382f)
        return bmp
    }

    private fun hat(): Bitmap {
        val w = 512
        val h = 300
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val brim = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(40, 90, 200) }
        val crown = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(55, 110, 230) }
        val band = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(220, 50, 70) }
        c.drawOval(RectF(30f, 190f, 482f, 270f), brim)
        c.drawRoundRect(RectF(110f, 40f, 402f, 220f), 40f, 40f, crown)
        c.drawRect(RectF(110f, 175f, 402f, 210f), band)
        return bmp
    }

    private fun clownNose(): Bitmap {
        val size = 160
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(230, 40, 50) }
        c.drawCircle(80f, 80f, 62f, paint)
        val hl = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(160, 255, 255, 255) }
        c.drawCircle(58f, 58f, 16f, hl)
        return bmp
    }

    private fun mask(): Bitmap {
        val w = 420
        val h = 480
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(210, 40, 40, 48) }
        c.drawOval(RectF(30f, 40f, 390f, 450f), fill)
        val eyes = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(40, 10, 10, 12) }
        c.drawOval(RectF(70f, 150f, 180f, 220f), eyes)
        c.drawOval(RectF(240f, 150f, 350f, 220f), eyes)
        return bmp
    }

    private fun faceSticker(): Bitmap {
        val size = 220
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val face = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(255, 210, 70) }
        c.drawCircle(110f, 110f, 95f, face)
        val eye = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(40, 30, 20) }
        c.drawCircle(75f, 95f, 12f, eye)
        c.drawCircle(145f, 95f, 12f, eye)
        val smile = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(40, 30, 20)
            style = Paint.Style.STROKE
            strokeWidth = 10f
            strokeCap = Paint.Cap.ROUND
        }
        c.drawArc(RectF(60f, 100f, 160f, 170f), 20f, 140f, false, smile)
        return bmp
    }
}

object EffectTransformResolver {
    fun resolve(
        layer: FaceStickerLayer,
        face: FaceLandmarks,
        assetAspect: Float,
        mirrorX: Boolean,
    ): EffectTransform? {
        val xy = face.normalizedXy
        val need = maxOf(layer.leftLandmark, layer.rightLandmark, layer.anchorLandmark)
        if (face.count <= need) return null

        val lx = xy[layer.leftLandmark * 2]
        val ly = xy[layer.leftLandmark * 2 + 1]
        val rx = xy[layer.rightLandmark * 2]
        val ry = xy[layer.rightLandmark * 2 + 1]
        val ax = xy[layer.anchorLandmark * 2]
        val ay = xy[layer.anchorLandmark * 2 + 1]

        val (leftX, leftY, rightX, rightY) = if (lx <= rx) {
            floatArrayOf(lx, ly, rx, ry)
        } else {
            floatArrayOf(rx, ry, lx, ly)
        }

        val refMidX = (leftX + rightX) * 0.5f
        val refMidY = (leftY + rightY) * 0.5f
        val refSpan = hypot((rightX - leftX).toDouble(), (rightY - leftY).toDouble()).toFloat()
            .coerceAtLeast(0.02f)
        val faceScale = face.scale.coerceAtLeast(0.05f)

        val roll = Math.toDegrees(
            atan2((rightY - leftY).toDouble(), (rightX - leftX).toDouble()),
        ).toFloat() + layer.rotationOffsetDeg

        val centerX = when (layer.pinX) {
            EffectPinX.REF_MIDPOINT -> refMidX
            EffectPinX.ANCHOR -> ax
        } + faceScale * layer.offsetXFaceFrac

        val centerY = when (layer.pinY) {
            EffectPinY.ANCHOR -> ay
            EffectPinY.REF_MIDLINE -> refMidY
            EffectPinY.ABOVE_REF -> min(ay, refMidY)
        } + faceScale * layer.offsetYFaceFrac

        var width = if (layer.widthFaceFrac > 0f) {
            faceScale * layer.widthFaceFrac
        } else {
            refSpan * layer.widthOverRef
        }
        width = width.coerceIn(0.04f, 1.2f)

        val height = (width * assetAspect).coerceIn(0.03f, 1.2f)
        val scaleX = yawScaleX(face.pose.yawDeg, layer.yawSqueeze)

        return EffectTransform(
            centerX = centerX.coerceIn(0f, 1f),
            centerY = centerY.coerceIn(0f, 1f),
            width = width,
            height = height,
            rotationDeg = roll,
            scaleX = scaleX,
            mirrorX = mirrorX,
            opacity = layer.opacity.coerceIn(0f, 1f),
            pivotU = layer.pivotU,
            pivotV = layer.pivotV,
        )
    }

    private fun yawScaleX(yawDeg: Float, strength: Float): Float {
        if (strength <= 0f) return 1f
        val y = kotlin.math.abs(yawDeg).coerceIn(0f, 60f) / 60f
        return (1f - y * strength).coerceIn(0.55f, 1f)
    }

    fun smooth(prev: EffectTransform?, next: EffectTransform, alpha: Float = 0.4f): EffectTransform {
        if (prev == null) return next
        val a = alpha.coerceIn(0.05f, 1f)
        fun lerp(p: Float, n: Float) = p + (n - p) * a
        return EffectTransform(
            centerX = lerp(prev.centerX, next.centerX),
            centerY = lerp(prev.centerY, next.centerY),
            width = lerp(prev.width, next.width),
            height = lerp(prev.height, next.height),
            rotationDeg = lerpAngle(prev.rotationDeg, next.rotationDeg, a),
            scaleX = lerp(prev.scaleX, next.scaleX),
            mirrorX = next.mirrorX,
            opacity = lerp(prev.opacity, next.opacity),
            pivotU = next.pivotU,
            pivotV = next.pivotV,
        )
    }

    private fun lerpAngle(from: Float, to: Float, a: Float): Float {
        var delta = (to - from) % 360f
        if (delta > 180f) delta -= 360f
        if (delta < -180f) delta += 360f
        return from + delta * a
    }
}
