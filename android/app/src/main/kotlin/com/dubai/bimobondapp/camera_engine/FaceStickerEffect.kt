package com.dubai.bimobondapp.camera_engine

import android.opengl.GLES20
import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import kotlin.math.cos
import kotlin.math.sin

/**
 * Phase 4: draws face-anchored 2D sticker quads on the GL thread.
 *
 * Input is already-filtered camera preview in the framebuffer; this only blends
 * RGBA textures on top — no Bitmap per frame.
 */
class FaceStickerEffect(
    override val id: String = "face_sticker",
) : FaceOverlayEffect, EffectRenderer {

    @Volatile
    override var enabled: Boolean = false

    @Volatile
    override var intensity: Float = 1f
        set(value) {
            field = value.coerceIn(0f, 1f)
        }

    @Volatile
    private var commands: List<FaceStickerDrawCommand> = emptyList()

    private var program = 0
    private var aPosition = -1
    private var aTexCoord = -1
    private var uTexture = -1
    private var uOpacity = -1

    private val posBuffer: FloatBuffer = ByteBuffer.allocateDirect(8 * 4)
        .order(ByteOrder.nativeOrder())
        .asFloatBuffer()
    private val texBuffer: FloatBuffer = floatBufferOf(
        0f, 0f, 1f, 0f, 0f, 1f, 1f, 1f,
    )

    fun setCommands(next: List<FaceStickerDrawCommand>) {
        commands = next
    }

    fun clearCommands() {
        commands = emptyList()
    }

    fun ensureProgram() {
        if (program != 0) return
        program = buildProgram(VERTEX, FRAGMENT)
        aPosition = GLES20.glGetAttribLocation(program, "aPosition")
        aTexCoord = GLES20.glGetAttribLocation(program, "aTexCoord")
        uTexture = GLES20.glGetUniformLocation(program, "uTexture")
        uOpacity = GLES20.glGetUniformLocation(program, "uOpacity")
    }

    override fun draw(
        oesTextureId: Int,
        width: Int,
        height: Int,
        transformMatrix: FloatArray,
    ) {
        if (!enabled || intensity <= 0.001f) return
        val list = commands
        if (list.isEmpty()) return

        ensureProgram()
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
        GLES20.glUseProgram(program)

        for (cmd in list) {
            val tex = cmd.asset.glTextureId
            if (tex == 0) continue
            fillQuad(cmd.transform, width, height)
            GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, tex)
            GLES20.glUniform1i(uTexture, 0)
            GLES20.glUniform1f(uOpacity, cmd.transform.opacity * intensity)

            GLES20.glEnableVertexAttribArray(aPosition)
            GLES20.glVertexAttribPointer(aPosition, 2, GLES20.GL_FLOAT, false, 0, posBuffer)
            GLES20.glEnableVertexAttribArray(aTexCoord)
            GLES20.glVertexAttribPointer(aTexCoord, 2, GLES20.GL_FLOAT, false, 0, texBuffer)
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        }

        GLES20.glDisableVertexAttribArray(aPosition)
        GLES20.glDisableVertexAttribArray(aTexCoord)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0)
        GLES20.glDisable(GLES20.GL_BLEND)
    }

    private fun fillQuad(t: EffectTransform, frameW: Int, frameH: Int) {
        // UV → NDC (MediaPipe y down → GL y up).
        val cx = t.centerX * 2f - 1f
        val cy = 1f - t.centerY * 2f

        // Normalize sizes into NDC; compensate non-square frames so stickers stay round.
        val aspect = if (frameH > 0) frameW.toFloat() / frameH.toFloat() else 1f
        var halfW = t.width
        var halfH = t.height
        // width/height are full normalized spans; convert to half-extents in NDC.
        halfW *= t.scaleX
        if (t.mirrorX) halfW = -halfW

        val ndcHalfW = halfW
        val ndcHalfH = halfH * aspect

        val pivotOffX = (0.5f - t.pivotU) * 2f * ndcHalfW
        val pivotOffY = (t.pivotV - 0.5f) * 2f * ndcHalfH

        val rad = Math.toRadians(t.rotationDeg.toDouble())
        val cosR = cos(rad).toFloat()
        val sinR = sin(rad).toFloat()

        // Local corners relative to pivot, then rotate + translate.
        // TRIANGLE_STRIP order: BL, BR, TL, TR in local UV space.
        val locals = floatArrayOf(
            -ndcHalfW + pivotOffX, -ndcHalfH + pivotOffY,
            ndcHalfW + pivotOffX, -ndcHalfH + pivotOffY,
            -ndcHalfW + pivotOffX, ndcHalfH + pivotOffY,
            ndcHalfW + pivotOffX, ndcHalfH + pivotOffY,
        )
        val out = FloatArray(8)
        for (i in 0 until 4) {
            val lx = locals[i * 2]
            val ly = locals[i * 2 + 1]
            out[i * 2] = cx + lx * cosR - ly * sinR
            out[i * 2 + 1] = cy + lx * sinR + ly * cosR
        }
        posBuffer.position(0)
        posBuffer.put(out)
        posBuffer.position(0)
    }

    override fun release() {
        if (program != 0) {
            GLES20.glDeleteProgram(program)
            program = 0
        }
        commands = emptyList()
    }

    companion object {
        private const val TAG = "FaceStickerEffect"

        private const val VERTEX = """
            attribute vec2 aPosition;
            attribute vec2 aTexCoord;
            varying vec2 vTexCoord;
            void main() {
              gl_Position = vec4(aPosition, 0.0, 1.0);
              vTexCoord = aTexCoord;
            }
        """

        private const val FRAGMENT = """
            precision mediump float;
            uniform sampler2D uTexture;
            uniform float uOpacity;
            varying vec2 vTexCoord;
            void main() {
              vec4 c = texture2D(uTexture, vTexCoord);
              gl_FragColor = vec4(c.rgb, c.a * uOpacity);
            }
        """

        private fun floatBufferOf(vararg values: Float): FloatBuffer {
            return ByteBuffer.allocateDirect(values.size * 4)
                .order(ByteOrder.nativeOrder())
                .asFloatBuffer()
                .apply {
                    put(values)
                    position(0)
                }
        }

        private fun buildProgram(vertexSrc: String, fragmentSrc: String): Int {
            val vs = compile(GLES20.GL_VERTEX_SHADER, vertexSrc)
            val fs = compile(GLES20.GL_FRAGMENT_SHADER, fragmentSrc)
            val program = GLES20.glCreateProgram()
            GLES20.glAttachShader(program, vs)
            GLES20.glAttachShader(program, fs)
            GLES20.glLinkProgram(program)
            val link = IntArray(1)
            GLES20.glGetProgramiv(program, GLES20.GL_LINK_STATUS, link, 0)
            GLES20.glDeleteShader(vs)
            GLES20.glDeleteShader(fs)
            if (link[0] == 0) {
                val log = GLES20.glGetProgramInfoLog(program)
                GLES20.glDeleteProgram(program)
                Log.e(TAG, "link failed: $log")
                throw IllegalStateException("face sticker shader link failed")
            }
            return program
        }

        private fun compile(type: Int, source: String): Int {
            val shader = GLES20.glCreateShader(type)
            GLES20.glShaderSource(shader, source)
            GLES20.glCompileShader(shader)
            val compiled = IntArray(1)
            GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, compiled, 0)
            if (compiled[0] == 0) {
                val log = GLES20.glGetShaderInfoLog(shader)
                GLES20.glDeleteShader(shader)
                throw IllegalStateException("face sticker shader compile failed: $log")
            }
            return shader
        }
    }
}
