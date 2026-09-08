package com.dubai.bimobondapp.ar_camera.beauty_v3

/**
 * Per-frame camera → canonical geometry contract.
 *
 * Reused across frames (no heap allocation in steady state). Treat field values as
 * immutable for the duration of a single [V3Pipeline.drawFrame] call.
 *
 * ## Canonical coordinate space (Beauty V3)
 *
 * - **Origin:** top-left of the upright, display-oriented camera image.
 * - **Axes:** +X right, +Y down (Android / image convention — NOT OpenGL bottom-left).
 * - **Normalized UV:** `u ∈ [0,1]` left→right, `v ∈ [0,1]` top→bottom.
 * - **Content:** full oriented camera frame (no letterbox). Rotation and front-camera
 *   mirroring are applied exactly once via [stMatrix] during InputPass; effects must
 *   not re-apply mirror/rotation.
 * - **GL storage note:** the RGBA FBO uses OpenGL's bottom-left texel origin.
 *   [V3PresentPass] maps canonical UV → FBO sample UV (Y flip). Effects reason in
 *   canonical UV only.
 *
 * Framing (FILL/FIT / wide-zoom) is **not** baked into the canonical texture; it
 * is applied only in PresentPass to match legacy RAW FOV.
 */
class V3FrameContract {
    /** CameraX / SurfaceTexture buffer width (pre display-orientation swap). */
    var sourceWidth: Int = 0
        private set
    /** CameraX / SurfaceTexture buffer height (pre display-orientation swap). */
    var sourceHeight: Int = 0
        private set
    /** Display-oriented width after 90/270 swap (same as legacy OES tex size). */
    var orientedWidth: Int = 0
        private set
    /** Display-oriented height after 90/270 swap. */
    var orientedHeight: Int = 0
        private set
    /** Sensor→display rotation degrees from CameraX TransformationInfo. */
    var rotationDegrees: Int = 0
        private set
    /**
     * True when the front camera should appear mirrored to the user.
     * Already encoded in [stMatrix] for sampling; kept for FaceCoordinateContract later.
     */
    var mirrorX: Boolean = false
        private set
    /** Frame timestamp (nanoseconds). Prefer SurfaceTexture timestamp when available. */
    var timestampNs: Long = 0L
        private set
    /** Monotonic generation for this preview pipeline. */
    var frameGeneration: Long = 0L
        private set
    /**
     * 4×4 column-major SurfaceTexture transform matrix.
     * Valid for the current GL frame only; contents are overwritten each update.
     */
    val stMatrix: FloatArray = FloatArray(16)
    /** Present-time wide zoom: 1.0 = FILL_CENTER, 2.0 = FIT_CENTER (production). */
    var wideZoom: Float = 2.0f
        private set
    /** Current GL viewport width in pixels (present framing). */
    var viewWidth: Int = 0
        private set
    /** Current GL viewport height in pixels (present framing). */
    var viewHeight: Int = 0
        private set
    /** Canonical RGBA texture width (equals [orientedWidth] in V3-0). */
    var canonicalWidth: Int = 0
        private set
    /** Canonical RGBA texture height (equals [orientedHeight] in V3-0). */
    var canonicalHeight: Int = 0
        private set

    fun update(
        sourceWidth: Int,
        sourceHeight: Int,
        rotationDegrees: Int,
        mirrorX: Boolean,
        stMatrixIn: FloatArray,
        viewWidth: Int,
        viewHeight: Int,
        wideZoom: Float,
        timestampNs: Long,
        frameGeneration: Long,
    ): V3FrameContract {
        val rot = ((rotationDegrees % 360) + 360) % 360
        val srcW = sourceWidth.coerceAtLeast(1)
        val srcH = sourceHeight.coerceAtLeast(1)
        this.sourceWidth = srcW
        this.sourceHeight = srcH
        if (rot == 90 || rot == 270) {
            this.orientedWidth = srcH
            this.orientedHeight = srcW
        } else {
            this.orientedWidth = srcW
            this.orientedHeight = srcH
        }
        this.rotationDegrees = rot
        this.mirrorX = mirrorX
        this.timestampNs = timestampNs
        this.frameGeneration = frameGeneration
        System.arraycopy(stMatrixIn, 0, this.stMatrix, 0, 16)
        this.wideZoom = wideZoom
        this.viewWidth = viewWidth.coerceAtLeast(1)
        this.viewHeight = viewHeight.coerceAtLeast(1)
        this.canonicalWidth = this.orientedWidth
        this.canonicalHeight = this.orientedHeight
        return this
    }

    /** Updates present viewport only (e.g. capture FBO vs window) without reallocating. */
    fun setPresentViewport(width: Int, height: Int) {
        viewWidth = width.coerceAtLeast(1)
        viewHeight = height.coerceAtLeast(1)
    }
}
