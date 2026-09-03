package com.dubai.bimobondapp.ar_camera

import android.app.Activity
import android.app.Dialog
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

/**
 * TikTok-style Go LIVE chrome in a translucent [Dialog] so it sits ABOVE
 * FaceWarp GLSurfaceView (Flutter overlays are covered by that surface).
 *
 * Layout matches the TikTok pre-LIVE screen:
 *  - top: close + cover/title card (Change · Add topic · LIVE goal)
 *  - bottom: Flip/Enhance/Effects/Settings/More · Go LIVE · modes · tabs
 */
object ArLiveStartPopup {
    private const val TIKTOK_RED = "#FE2C55"
    private const val CYAN_DOT = "#20D5EC"

    private var dialog: Dialog? = null
    private var titleField: EditText? = null
    private var pendingShow = false

    fun setVisible(activity: Activity?, visible: Boolean) {
        if (activity == null || activity.isFinishing) {
            android.util.Log.w("ArLiveStartPopup", "setVisible($visible) skipped")
            return
        }
        activity.runOnUiThread {
            if (!visible) {
                pendingShow = false
                dismiss()
                return@runOnUiThread
            }
            pendingShow = true
            show(activity)
        }
    }

    fun titleText(): String = titleField?.text?.toString()?.trim().orEmpty()

    fun dismiss() {
        try {
            dialog?.dismiss()
        } catch (_: Throwable) {
        }
        dialog = null
        titleField = null
    }

    private fun show(activity: Activity) {
        if (!pendingShow) return
        if (dialog?.isShowing == true) return

        val density = activity.resources.displayMetrics.density
        fun dp(v: Int): Int = (v * density).toInt()
        fun dpF(v: Float): Float = v * density

        val root = FrameLayout(activity).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            setBackgroundColor(Color.TRANSPARENT)
        }

        // ── Top: close + info card ───────────────────────────────────────
        val topCol = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(8), dp(40), dp(8), dp(8))
        }

        val close = ImageButton(activity).apply {
            setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
            setBackgroundColor(Color.TRANSPARENT)
            setColorFilter(Color.WHITE)
            contentDescription = "Close"
            setOnClickListener {
                ArCameraBridge.liveStartEventSink?.invoke("onLiveStartClose", null)
            }
        }
        topCol.addView(
            close,
            LinearLayout.LayoutParams(dp(40), dp(40)).apply {
                marginStart = dp(6)
            },
        )

        val infoCard = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(10), dp(10), dp(12), dp(12))
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#99000000"))
                cornerRadius = dpF(14f)
            }
        }

        val titleRow = LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.TOP
        }

        val coverCol = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
        }
        val cover = FrameLayout(activity).apply {
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#2A2A2E"))
                cornerRadius = dpF(8f)
            }
        }
        cover.addView(
            ImageView(activity).apply {
                setImageResource(android.R.drawable.ic_menu_gallery)
                setColorFilter(Color.parseColor("#73FFFFFF"))
                scaleType = ImageView.ScaleType.CENTER
            },
            FrameLayout.LayoutParams(dp(28), dp(28), Gravity.CENTER),
        )
        coverCol.addView(cover, LinearLayout.LayoutParams(dp(64), dp(64)))
        coverCol.addView(
            TextView(activity).apply {
                text = "Change"
                setTextColor(Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
                setTypeface(Typeface.DEFAULT_BOLD)
                gravity = Gravity.CENTER
                setPadding(0, dp(4), 0, 0)
            },
        )
        titleRow.addView(coverCol)

        val titleCol = LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(12), dp(6), 0, 0)
        }
        val title = EditText(activity).apply {
            hint = "Add a title to chat"
            setHintTextColor(Color.parseColor("#88FFFFFF"))
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setTypeface(Typeface.DEFAULT_BOLD)
            maxLines = 1
            background = null
            setPadding(0, 0, dp(6), 0)
        }
        titleField = title
        titleCol.addView(
            title,
            LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f),
        )
        titleCol.addView(
            TextView(activity).apply {
                text = "✎"
                setTextColor(Color.parseColor("#D9FFFFFF"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            },
        )
        titleRow.addView(
            titleCol,
            LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f),
        )
        infoCard.addView(titleRow)

        val chips = LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, dp(12), 0, 0)
        }
        fun chip(label: String, glyph: String): TextView {
            return TextView(activity).apply {
                text = "$glyph  $label"
                setTextColor(Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
                setTypeface(Typeface.DEFAULT_BOLD)
                setPadding(dp(10), dp(7), dp(10), dp(7))
                background = GradientDrawable().apply {
                    setColor(Color.parseColor("#1FFFFFFF"))
                    cornerRadius = dpF(18f)
                }
            }
        }
        chips.addView(chip("Add topic", "🪙"))
        chips.addView(
            chip("Add a LIVE goal", "🏆"),
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { marginStart = dp(8) },
        )
        infoCard.addView(chips)

        topCol.addView(
            infoCard,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply {
                marginStart = dp(6)
                marginEnd = dp(6)
                topMargin = dp(4)
            },
        )

        root.addView(
            topCol,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { gravity = Gravity.TOP },
        )

        // ── Bottom: tools + Go LIVE + mode + tabs ───────────────────────
        val panel = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(10), dp(10), dp(10), dp(16))
            background = GradientDrawable(
                GradientDrawable.Orientation.BOTTOM_TOP,
                intArrayOf(
                    Color.parseColor("#E6000000"),
                    Color.parseColor("#99000000"),
                    Color.TRANSPARENT,
                ),
            )
        }

        fun toolCell(
            label: String,
            glyph: String,
            method: String?,
            showDot: Boolean = false,
            badge: String? = null,
            comingSoon: Boolean = false,
            onLocalTap: (() -> Unit)? = null,
        ): View {
            val col = LinearLayout(activity).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER_HORIZONTAL
                setPadding(dp(4), dp(6), dp(4), dp(6))
                setOnClickListener {
                    when {
                        onLocalTap != null -> onLocalTap()
                        comingSoon -> {
                            ArCameraBridge.liveStartEventSink?.invoke(
                                "onLiveStartComingSoon",
                                label,
                            )
                        }
                        method != null -> {
                            ArCameraBridge.liveStartEventSink?.invoke(method, null)
                        }
                    }
                }
            }
            val iconWrap = FrameLayout(activity)
            iconWrap.addView(
                TextView(activity).apply {
                    text = glyph
                    setTextColor(Color.WHITE)
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 22f)
                    gravity = Gravity.CENTER
                },
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    Gravity.CENTER,
                ),
            )
            if (showDot) {
                iconWrap.addView(
                    View(activity).apply {
                        background = GradientDrawable().apply {
                            setColor(Color.parseColor(TIKTOK_RED))
                            shape = GradientDrawable.OVAL
                        }
                    },
                    FrameLayout.LayoutParams(dp(8), dp(8)).apply {
                        gravity = Gravity.TOP or Gravity.END
                    },
                )
            }
            if (badge != null) {
                iconWrap.addView(
                    TextView(activity).apply {
                        text = badge
                        setTextColor(Color.WHITE)
                        setTextSize(TypedValue.COMPLEX_UNIT_SP, 9f)
                        setTypeface(Typeface.DEFAULT_BOLD)
                        gravity = Gravity.CENTER
                        setPadding(dp(4), dp(1), dp(4), dp(1))
                        background = GradientDrawable().apply {
                            setColor(Color.parseColor(TIKTOK_RED))
                            cornerRadius = dpF(8f)
                        }
                    },
                    FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.WRAP_CONTENT,
                        ViewGroup.LayoutParams.WRAP_CONTENT,
                    ).apply {
                        gravity = Gravity.TOP or Gravity.END
                    },
                )
            }
            col.addView(iconWrap, LinearLayout.LayoutParams(dp(28), dp(28)))
            col.addView(
                TextView(activity).apply {
                    text = label
                    setTextColor(Color.parseColor("#EEFFFFFF"))
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
                    gravity = Gravity.CENTER
                    setPadding(0, dp(4), 0, 0)
                    maxLines = 1
                },
            )
            return col
        }

        fun toolRow(vararg cells: View): LinearLayout {
            return LinearLayout(activity).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER
                weightSum = 5f
                for (cell in cells) {
                    addView(
                        cell,
                        LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f),
                    )
                }
            }
        }

        var toolsExpanded = false
        val toolsHost = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
        }

        fun rebuildTools() {
            toolsHost.removeAllViews()
            if (!toolsExpanded) {
                toolsHost.addView(
                    toolRow(
                        toolCell("Flip", "⟲", "onLiveStartFlip"),
                        toolCell("Enhance", "✦", "onLiveStartBeautify"),
                        toolCell("Effects", "☺", "onLiveStartEffects"),
                        toolCell("Settings", "⚙", "onLiveStartSettings", showDot = true),
                        toolCell(
                            "More",
                            "▾",
                            null,
                            onLocalTap = {
                                toolsExpanded = true
                                rebuildTools()
                            },
                        ),
                    ),
                )
            } else {
                toolsHost.addView(
                    toolRow(
                        toolCell("Flip", "⟲", "onLiveStartFlip"),
                        toolCell("Enhance", "✦", "onLiveStartBeautify"),
                        toolCell("Effects", "☺", "onLiveStartEffects"),
                        toolCell("Settings", "⚙", "onLiveStartSettings", showDot = true),
                        toolCell(
                            "Less",
                            "▴",
                            null,
                            onLocalTap = {
                                toolsExpanded = false
                                rebuildTools()
                            },
                        ),
                    ),
                )
                toolsHost.addView(
                    toolRow(
                        toolCell("Boards", "▦", null, comingSoon = true),
                        toolCell("Dual", "📷", null, comingSoon = true),
                        toolCell("Share", "↗", "onLiveStartShare"),
                        toolCell("LIVE Center", "⌂", "onLiveStartLiveCenter"),
                        toolCell(
                            "Campaigns",
                            "★",
                            "onLiveStartCampaigns",
                            badge = "2",
                        ),
                    ),
                    LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.WRAP_CONTENT,
                    ).apply { topMargin = dp(8) },
                )
                toolsHost.addView(
                    toolRow(
                        toolCell("Subscription", "☆", null, comingSoon = true),
                        toolCell("Service+", "💬", "onLiveStartServicePlus"),
                        toolCell("Shop", "🛍", null, comingSoon = true),
                        toolCell("Interact", "OX", "onLiveStartInteract"),
                        toolCell("Promote", "🔥", null, comingSoon = true),
                    ),
                    LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.WRAP_CONTENT,
                    ).apply { topMargin = dp(8) },
                )
            }
        }
        rebuildTools()
        panel.addView(
            toolsHost,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { bottomMargin = dp(12) },
        )

        val goLive = Button(activity).apply {
            text = "Go LIVE"
            isAllCaps = false
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
            setTypeface(Typeface.DEFAULT_BOLD)
            background = GradientDrawable().apply {
                setColor(Color.parseColor(TIKTOK_RED))
                cornerRadius = dpF(28f)
            }
            setOnClickListener {
                ArCameraBridge.liveStartEventSink?.invoke(
                    "onLiveStartGoLive",
                    titleText(),
                )
            }
        }
        panel.addView(
            goLive,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(50),
            ).apply {
                marginStart = dp(18)
                marginEnd = dp(18)
            },
        )

        // Mode selector with cyan selected dot.
        val modes = LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(0, dp(12), 0, dp(6))
        }
        fun modeCol(text: String, glyph: String, active: Boolean): LinearLayout {
            return LinearLayout(activity).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER_HORIZONTAL
                setPadding(dp(12), 0, dp(12), 0)
                addView(
                    TextView(activity).apply {
                        this.text = "$glyph  $text"
                        setTextColor(
                            if (active) Color.WHITE else Color.parseColor("#73FFFFFF"),
                        )
                        setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                        setTypeface(if (active) Typeface.DEFAULT_BOLD else Typeface.DEFAULT)
                        gravity = Gravity.CENTER
                    },
                )
                addView(
                    View(activity).apply {
                        background = GradientDrawable().apply {
                            setColor(
                                if (active) Color.parseColor(CYAN_DOT) else Color.TRANSPARENT,
                            )
                            shape = GradientDrawable.OVAL
                        }
                    },
                    LinearLayout.LayoutParams(dp(6), dp(6)).apply {
                        topMargin = dp(5)
                        gravity = Gravity.CENTER_HORIZONTAL
                    },
                )
            }
        }
        modes.addView(modeCol("Device camera", "📹", true))
        modes.addView(modeCol("Mobile gaming", "📱", false))
        panel.addView(modes)

        // Bottom tabs: POST · TEMPLATES · LIVE
        val tabs = LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(0, dp(4), 0, dp(2))
        }
        fun tab(label: String, active: Boolean): LinearLayout {
            return LinearLayout(activity).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER_HORIZONTAL
                setPadding(dp(16), 0, dp(16), 0)
                addView(
                    TextView(activity).apply {
                        text = label
                        setTextColor(
                            if (active) Color.WHITE else Color.parseColor("#73FFFFFF"),
                        )
                        setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                        setTypeface(
                            if (active) Typeface.DEFAULT_BOLD else Typeface.DEFAULT,
                        )
                        gravity = Gravity.CENTER
                    },
                )
                addView(
                    View(activity).apply {
                        background = GradientDrawable().apply {
                            setColor(if (active) Color.WHITE else Color.TRANSPARENT)
                            shape = GradientDrawable.OVAL
                        }
                    },
                    LinearLayout.LayoutParams(dp(5), dp(5)).apply {
                        topMargin = dp(5)
                        gravity = Gravity.CENTER_HORIZONTAL
                    },
                )
            }
        }
        tabs.addView(tab("POST", false))
        tabs.addView(tab("TEMPLATES", false))
        tabs.addView(tab("LIVE", true))
        panel.addView(tabs)

        root.addView(
            panel,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { gravity = Gravity.BOTTOM },
        )

        val d = Dialog(activity, android.R.style.Theme_Translucent_NoTitleBar_Fullscreen)
        d.setContentView(root)
        d.setCancelable(false)
        d.setCanceledOnTouchOutside(false)
        d.window?.apply {
            setLayout(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            setBackgroundDrawableResource(android.R.color.transparent)
            clearFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
            setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
        }

        try {
            d.show()
            dialog = d
            android.util.Log.i("ArLiveStartPopup", "TikTok Go LIVE chrome shown")
        } catch (t: Throwable) {
            android.util.Log.e("ArLiveStartPopup", "show failed", t)
            dialog = null
        }
    }
}
