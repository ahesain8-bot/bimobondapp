package com.dubai.bimobondapp.ar_camera

/**
 * Active beauty preset params from Flutter catalog (Soft Glow, etc.).
 * Cleared when switching to LUT / none / effects.
 */
object BeautyPresetState {
    @Volatile
    var active: Boolean = false

    @Volatile
    var smooth: Float = 0.65f

    @Volatile
    var whiten: Float = 0.55f

    @Volatile
    var brighten: Float = 0.40f

    @Volatile
    var blush: Float = 0.25f

    @Volatile
    var lipTintR: Float = 0xE8 / 255f

    @Volatile
    var lipTintG: Float = 0x52 / 255f

    @Volatile
    var lipTintB: Float = 0x7A / 255f

    @Volatile
    var lipStrength: Float = 0.45f

    fun clear() {
        active = false
    }

    fun apply(
        smooth: Float,
        whiten: Float,
        brighten: Float,
        blush: Float,
        lipTintHex: String?,
        lipStrength: Float,
    ) {
        this.smooth = smooth.coerceIn(0f, 1f)
        this.whiten = whiten.coerceIn(0f, 1f)
        this.brighten = brighten.coerceIn(0f, 1f)
        this.blush = blush.coerceIn(0f, 1f)
        this.lipStrength = lipStrength.coerceIn(0f, 1f)
        parseLipTint(lipTintHex)
        active = true
    }

    fun applyFromMap(map: Map<*, *>?) {
        if (map == null || map.isEmpty()) {
            clear()
            return
        }
        fun num(key: String, fallback: Float): Float {
            val v = map[key] ?: return fallback
            return when (v) {
                is Number -> v.toFloat()
                is String -> v.toFloatOrNull() ?: fallback
                else -> fallback
            }.coerceIn(0f, 1f)
        }
        apply(
            smooth = num("smooth", 0.65f),
            whiten = num("whiten", 0.55f),
            brighten = num("brighten", 0.40f),
            blush = num("blush", 0.25f),
            lipTintHex = map["lipTint"]?.toString(),
            lipStrength = num("lipStrength", 0.45f),
        )
    }

    private fun parseLipTint(hex: String?) {
        val raw = hex?.trim().orEmpty()
        if (raw.isEmpty()) {
            lipTintR = 0xE8 / 255f
            lipTintG = 0x52 / 255f
            lipTintB = 0x7A / 255f
            return
        }
        val h = if (raw.startsWith("#")) raw.substring(1) else raw
        if (h.length != 6) return
        try {
            lipTintR = h.substring(0, 2).toInt(16) / 255f
            lipTintG = h.substring(2, 4).toInt(16) / 255f
            lipTintB = h.substring(4, 6).toInt(16) / 255f
        } catch (_: Throwable) {
        }
    }
}
