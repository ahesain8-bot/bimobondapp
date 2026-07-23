/**
 * Kotlin LUT diagnose (no Flutter).
 *
 * Compares:
 *   A) .cube sampled directly (dashboard-style truth)
 *   B) PNG sampled with app LutStore / GPUImage layout (what mobile uses)
 *
 * If A≈B → conversion OK, dark look is apply/intensity/camera — not PNG math.
 * If A≠B → PNG layout/conversion still wrong.
 *
 * Run (needs JDK + kotlinx not required):
 *   kotlinc tool/LutDiagnose.kt -include-runtime -d /tmp/LutDiagnose.jar && \
 *   java -jar /tmp/LutDiagnose.jar \
 *     "/path/to/file.cube" /tmp/backend.png
 *
 * Or with only PNG (skips cube truth):
 *   java -jar /tmp/LutDiagnose.jar --png-only /tmp/backend.png
 */
import java.awt.image.BufferedImage
import java.io.File
import javax.imageio.ImageIO
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.floor

private const val TILES = 8
private const val SIZE = 64
private const val DIM = TILES * SIZE // 512

private class Cube(val n: Int, val data: FloatArray) {
    fun sample(r: Float, g: Float, b: Float): FloatArray {
        fun clamp01(v: Float) = v.coerceIn(0f, 1f)
        val fr = clamp01(r) * (n - 1)
        val fg = clamp01(g) * (n - 1)
        val fb = clamp01(b) * (n - 1)
        val r0 = floor(fr.toDouble()).toInt()
        val g0 = floor(fg.toDouble()).toInt()
        val b0 = floor(fb.toDouble()).toInt()
        val r1 = (r0 + 1).coerceAtMost(n - 1)
        val g1 = (g0 + 1).coerceAtMost(n - 1)
        val b1 = (b0 + 1).coerceAtMost(n - 1)
        val dr = fr - r0
        val dg = fg - g0
        val db = fb - b0
        fun at(ri: Int, gi: Int, bi: Int): FloatArray {
            val idx = (ri + gi * n + bi * n * n) * 3
            return floatArrayOf(data[idx], data[idx + 1], data[idx + 2])
        }
        fun lerp(a: FloatArray, c: FloatArray, t: Float) =
            floatArrayOf(
                a[0] + (c[0] - a[0]) * t,
                a[1] + (c[1] - a[1]) * t,
                a[2] + (c[2] - a[2]) * t,
            )
        val c000 = at(r0, g0, b0)
        val c100 = at(r1, g0, b0)
        val c010 = at(r0, g1, b0)
        val c110 = at(r1, g1, b0)
        val c001 = at(r0, g0, b1)
        val c101 = at(r1, g0, b1)
        val c011 = at(r0, g1, b1)
        val c111 = at(r1, g1, b1)
        val c00 = lerp(c000, c100, dr)
        val c10 = lerp(c010, c110, dr)
        val c01 = lerp(c001, c101, dr)
        val c11 = lerp(c011, c111, dr)
        val c0 = lerp(c00, c10, dg)
        val c1 = lerp(c01, c11, dg)
        return lerp(c0, c1, db)
    }
}

private fun parseCube(file: File): Cube {
    var n = 0
    val values = ArrayList<Float>(32 * 32 * 32 * 3)
    file.forEachLine { raw ->
        val line = raw.trim()
        if (line.isEmpty() || line.startsWith("#")) return@forEachLine
        when {
            line.startsWith("LUT_3D_SIZE") -> n = line.split(Regex("\\s+")).last().toInt()
            line.startsWith("TITLE") ||
                line.startsWith("DOMAIN_MIN") ||
                line.startsWith("DOMAIN_MAX") ||
                line.startsWith("LUT_1D_SIZE") -> return@forEachLine
            else -> {
                val parts = line.split(Regex("\\s+"))
                if (parts.size >= 3) {
                    val r = parts[0].toFloatOrNull() ?: return@forEachLine
                    val g = parts[1].toFloatOrNull() ?: return@forEachLine
                    val b = parts[2].toFloatOrNull() ?: return@forEachLine
                    values.add(r); values.add(g); values.add(b)
                }
            }
        }
    }
    require(n > 0 && values.size == n * n * n * 3) {
        "Bad .cube size=$n values=${values.size}"
    }
    return Cube(n, values.toFloatArray())
}

/** App / GPUImage sample of 512 PNG (matches LutStore + FaceWarpRenderer). */
private fun samplePng(img: BufferedImage, r: Float, g: Float, b: Float): IntArray {
    val rr = r.coerceIn(0f, 1f)
    val gg = g.coerceIn(0f, 1f)
    val bb = b.coerceIn(0f, 1f)
    val blue = bb * 63f
    val b0 = floor(blue.toDouble()).toInt().coerceIn(0, 63)
    val b1 = ceil(blue.toDouble()).toInt().coerceIn(0, 63)
    val bf = blue - b0
    fun quad(slice: Int): Pair<Int, Int> {
        val ty = slice / TILES
        val tx = slice % TILES
        return tx to ty
    }
    fun at(slice: Int): IntArray {
        val (tx, ty) = quad(slice)
        val x = ((tx * 0.125) + 0.5 / 512.0 + ((0.125 - 1.0 / 512.0) * rr)) * 511.0
        val y = ((ty * 0.125) + 0.5 / 512.0 + ((0.125 - 1.0 / 512.0) * gg)) * 511.0
        val xi = x.toInt().coerceIn(0, 511)
        val yi = y.toInt().coerceIn(0, 511)
        val rgb = img.getRGB(xi, yi)
        return intArrayOf((rgb shr 16) and 0xFF, (rgb shr 8) and 0xFF, rgb and 0xFF)
    }
    val c0 = at(b0)
    if (bf <= 0.0001f) return c0
    val c1 = at(b1)
    return intArrayOf(
        (c0[0] + (c1[0] - c0[0]) * bf).toInt().coerceIn(0, 255),
        (c0[1] + (c1[1] - c0[1]) * bf).toInt().coerceIn(0, 255),
        (c0[2] + (c1[2] - c0[2]) * bf).toInt().coerceIn(0, 255),
    )
}

private fun luma(r: Int, g: Int, b: Int) = (0.2126 * r + 0.7152 * g + 0.0722 * b)

fun main(args: Array<String>) {
    if (args.isEmpty()) {
        System.err.println(
            "Usage:\n" +
                "  java -jar LutDiagnose.jar <input.cube> <backend.png>\n" +
                "  java -jar LutDiagnose.jar --png-only <backend.png>",
        )
        kotlin.system.exitProcess(2)
    }
    val pngOnly = args[0] == "--png-only"
    val cubePath = if (pngOnly) null else args[0]
    val pngPath = if (pngOnly) args.getOrNull(1) else args.getOrNull(1)
    if (pngPath == null) {
        System.err.println("Missing PNG path")
        kotlin.system.exitProcess(2)
    }
    val png = ImageIO.read(File(pngPath))
        ?: run {
            System.err.println("Cannot read PNG: $pngPath")
            kotlin.system.exitProcess(2)
        }
    println("PNG size=${png.width}x${png.height}")
    if (png.width != DIM || png.height != DIM) {
        println("FAIL: expected ${DIM}x${DIM}")
        kotlin.system.exitProcess(1)
    }

    val probes = listOf(
        "black" to floatArrayOf(0f, 0f, 0f),
        "mid" to floatArrayOf(0.5f, 0.5f, 0.5f),
        "skin" to floatArrayOf(0.70f, 0.52f, 0.40f),
        "brightSkin" to floatArrayOf(0.85f, 0.70f, 0.60f),
        "white" to floatArrayOf(1f, 1f, 1f),
    )

    println("--- App PNG apply (what mobile does) ---")
    var darkened = 0
    for ((name, rgb) in probes) {
        val out = samplePng(png, rgb[0], rgb[1], rgb[2])
        val inL = luma((rgb[0] * 255).toInt(), (rgb[1] * 255).toInt(), (rgb[2] * 255).toInt())
        val outL = luma(out[0], out[1], out[2])
        val delta = outL - inL
        if (delta < -8) darkened++
        println(
            "$name in=(${(rgb[0]*255).toInt()},${(rgb[1]*255).toInt()},${(rgb[2]*255).toInt()}) " +
                "out=(${out[0]},${out[1]},${out[2]}) lumaDelta=${"%.1f".format(delta)}",
        )
    }

    if (cubePath != null) {
        val cube = parseCube(File(cubePath))
        println("--- Cube direct vs PNG (conversion check) ---")
        var abs = 0.0
        var n = 0
        for (bi in 0 until 64 step 4) {
            for (gi in 0 until 64 step 4) {
                for (ri in 0 until 64 step 4) {
                    val r = ri / 63f
                    val g = gi / 63f
                    val b = bi / 63f
                    val fromCube = cube.sample(r, g, b)
                    val fromPng = samplePng(png, r, g, b)
                    abs += abs(fromCube[0] * 255 - fromPng[0])
                    abs += abs(fromCube[1] * 255 - fromPng[1])
                    abs += abs(fromCube[2] * 255 - fromPng[2])
                    n += 3
                }
            }
        }
        val mean = abs / n
        println("mean abs cube-vs-png = ${"%.2f".format(mean)}")
        println(if (mean < 2.0) "CONVERSION: PASS" else "CONVERSION: FAIL")
    }

    println("--- Verdict ---")
    when {
        darkened >= 3 ->
            println(
                "LUT itself DARKENS most probes → not an app Y-flip; " +
                    "cube/grade is dark on these tones (or wrong cube).",
            )
        darkened == 0 ->
            println(
                "LUT does NOT darken probes → if live cam goes black, app/camera path issue " +
                    "(OES/retouch/double-apply), not this PNG math.",
            )
        else ->
            println("Mixed: some tones darken. Check skin/mid probes above.")
    }
}
