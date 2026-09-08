package com.dubai.bimobondapp.ar_camera.beauty_v3

import android.opengl.GLES20
import java.nio.FloatBuffer

/**
 * Presents the canonical RGBA texture to the current framebuffer with the same
 * FILL→FIT wide-zoom framing as legacy RAW_OES (production FOV).
 */
internal class V3PresentPass {
    private var program = 0
    private var aPosition = 0
    private var aTexCoord = 0
    private var uTexture = 0
    private var uViewSize = 0
    private var uTexSize = 0
    private var uWideZoom = 0

    fun ensureProgram(): Boolean {
        if (program != 0) return true
        program = V3GlProgram.build(VERTEX, FRAGMENT)
        if (program == 0) return false
        aPosition = GLES20.glGetAttribLocation(program, "aPosition")
        aTexCoord = GLES20.glGetAttribLocation(program, "aTexCoord")
        uTexture = GLES20.glGetUniformLocation(program, "uTexture")
        uViewSize = GLES20.glGetUniformLocation(program, "uViewSize")
        uTexSize = GLES20.glGetUniformLocation(program, "uTexSize")
        uWideZoom = GLES20.glGetUniformLocation(program, "uWideZoom")
        return true
    }

    /**
     * Draws [canonicalTexId] into the currently bound framebuffer / viewport.
     * [contract.framing] supplies view size and wideZoom; tex aspect uses canonical size.
     */
    fun draw(
        canonicalTexId: Int,
        contract: V3FrameContract,
        vertexBuffer: FloatBuffer,
    ): Boolean {
        if (canonicalTexId == 0 || !ensureProgram()) return false
        if (contract.viewWidth < 1 || contract.viewHeight < 1) return false

        GLES20.glUseProgram(program)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, canonicalTexId)
        GLES20.glUniform1i(uTexture, 0)
        GLES20.glUniform2f(
            uViewSize,
            contract.viewWidth.toFloat(),
            contract.viewHeight.toFloat(),
        )
        GLES20.glUniform2f(
            uTexSize,
            contract.canonicalWidth.toFloat().coerceAtLeast(1f),
            contract.canonicalHeight.toFloat().coerceAtLeast(1f),
        )
        GLES20.glUniform1f(uWideZoom, contract.wideZoom)

        vertexBuffer.position(0)
        GLES20.glEnableVertexAttribArray(aPosition)
        GLES20.glVertexAttribPointer(aPosition, 2, GLES20.GL_FLOAT, false, 16, vertexBuffer)
        GLES20.glEnableVertexAttribArray(aTexCoord)
        vertexBuffer.position(2)
        GLES20.glVertexAttribPointer(aTexCoord, 2, GLES20.GL_FLOAT, false, 16, vertexBuffer)
        vertexBuffer.position(0)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(aPosition)
        GLES20.glDisableVertexAttribArray(aTexCoord)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
        return true
    }

    fun release() {
        if (program != 0) {
            GLES20.glDeleteProgram(program)
            program = 0
        }
    }

    fun forgetHandles() {
        program = 0
    }

    companion object {
        private const val VERTEX = """
            attribute vec4 aPosition;
            attribute vec2 aTexCoord;
            varying vec2 vTexCoord;
            void main() {
                gl_Position = aPosition;
                vTexCoord = aTexCoord;
            }
        """

        /**
         * Framing math for OES→canonical present (letterbox / wide zoom).
         * Samples canonical texture with Y flip because FBO texel (0,0) is bottom-left
         * while canonical UV is top-left.
         */
        private const val FRAGMENT = """
            precision highp float;
            varying vec2 vTexCoord;
            uniform sampler2D uTexture;
            uniform vec2 uViewSize;
            uniform vec2 uTexSize;
            uniform float uWideZoom;

            vec2 fillCenter(vec2 uv) {
                float viewAspect = uViewSize.x / max(uViewSize.y, 1.0);
                float texAspect = uTexSize.x / max(uTexSize.y, 1.0);
                if (texAspect > viewAspect) {
                    float s = viewAspect / texAspect;
                    return vec2(uv.x * s + (1.0 - s) * 0.5, uv.y);
                }
                float s = texAspect / viewAspect;
                return vec2(uv.x, uv.y * s + (1.0 - s) * 0.5);
            }

            vec2 fitCenter(vec2 uv) {
                float viewAspect = uViewSize.x / max(uViewSize.y, 1.0);
                float texAspect = uTexSize.x / max(uTexSize.y, 1.0);
                if (texAspect > viewAspect) {
                    float s = texAspect / viewAspect;
                    return vec2(uv.x, uv.y * s + (1.0 - s) * 0.5);
                }
                float s = viewAspect / texAspect;
                return vec2(uv.x * s + (1.0 - s) * 0.5, uv.y);
            }

            void main() {
                float t = clamp(uWideZoom - 1.0, 0.0, 1.0);
                vec2 framed = mix(fillCenter(vTexCoord), fitCenter(vTexCoord), t);
                if (framed.x < 0.0 || framed.x > 1.0 ||
                    framed.y < 0.0 || framed.y > 1.0) {
                    gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
                    return;
                }
                // Canonical UV is top-left; FBO texture origin is bottom-left.
                vec2 sampleUv = vec2(framed.x, 1.0 - framed.y);
                gl_FragColor = texture2D(uTexture, sampleUv);
            }
        """
    }
}
