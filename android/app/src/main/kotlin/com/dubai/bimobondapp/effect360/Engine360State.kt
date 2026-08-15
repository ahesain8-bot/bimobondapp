package com.dubai.bimobondapp.effect360

enum class Engine360Status {
    IDLE,
    LOADING,
    PLAYING,
    ERROR
}

data class Engine360State(
    val status: Engine360Status = Engine360Status.IDLE,
    val videoUrl: String? = null,
    val alphaUrl: String? = null,
    val opacity: Float = 1.0f,
    val durationMs: Long = 0L,
    val errorMessage: String? = null
)
