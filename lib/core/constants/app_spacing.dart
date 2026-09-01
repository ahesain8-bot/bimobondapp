/// Central spacing scale used across the whole app.
///
/// Every gap, padding and margin in the UI must come from this scale
/// so the layout stays consistent and easy to tweak.
class AppSpacing {
  const AppSpacing._();

  // ── Scale ─────────────────────────────────────────────────────────────
  /// 4
  static const double xxs = 4;

  /// 6
  static const double xs = 6;

  /// 8
  static const double sm = 8;

  /// 12
  static const double smd = 12;

  /// 16
  static const double md = 16;

  /// 20
  static const double lg = 20;

  /// 24
  static const double xl = 24;

  /// 28
  static const double xxl = 28;

  /// 30
  static const double xxxl = 30;

  // ── Semantic ──────────────────────────────────────────────────────────
  /// Horizontal padding of the top status bar.
  static const double screenHorizontal = md;

  /// Gap between the sections stacked at the bottom of the screen.
  static const double sectionGap = smd;

  /// Vertical padding of the tools row container.
  static const double toolsRowVertical = smd;

  /// Gap between the tools toggle arrow and the first tools row.
  static const double toolsToggleGap = xxs;

  /// Gap between the icon and its label.
  static const double iconLabelGap = 1;

  /// Gap between the title field and the live button.
  static const double liveContentGap = sm;

  /// Gap between the share tool and the heart tool column.
  static const double toolsColumnsGap = sm;

  /// Gap between the two bottom tabs text and indicator.
  static const double tabIndicatorGap = xxs;

  /// Horizontal padding of the options row.
  static const double optionsHorizontal = lg;

  /// Gap between the two options.
  static const double optionsGap = lg;

  // ── Live room ─────────────────────────────────────────────────────────
  /// Gap between header pills.
  static const double roomHeaderGap = xs;

  /// Gap between the header and the info chips row.
  static const double roomHeaderToInfo = xs;

  /// Horizontal padding for live-room overlays.
  static const double roomHorizontal = sm;

  /// Gap between the room header and the top of the shared multi-guest stage.
  static const double roomStageTop = 112;

  /// Vertical gap between chat feed messages.
  static const double roomChatGap = xs;

  /// Horizontal padding inside the bottom action bar.
  static const double roomBottomHorizontal = md;

  /// Vertical padding inside the bottom action bar (above safe inset).
  static const double roomBottomVertical = xs;

  // ── Live effects ──────────────────────────────────────────────────────
  /// Gap between effect thumbnails.
  static const double effectsThumbGap = sm;

  /// Horizontal padding inside the effects tray.
  static const double effectsTrayHorizontal = sm;

  /// Vertical padding inside the effects tray.
  static const double effectsTrayVertical = sm;

  // ── Live room options menu ────────────────────────────────────────────
  /// Horizontal inset of the options sheet content.
  static const double optionsSheetHorizontal = smd;

  /// Vertical gap between option cards.
  static const double optionsCardGap = smd;

  /// Horizontal padding inside an option card.
  static const double optionsCardHorizontal = md;

  /// Vertical padding of a single option row.
  static const double optionsRowVertical = smd;

  /// Gap between option icon and title column.
  static const double optionsIconTextGap = smd;

  /// Bottom padding under the help footer.
  static const double optionsFooterBottom = lg;

  // ── Live share sheet ──────────────────────────────────────────────────
  /// Horizontal inset of the share sheet content.
  static const double shareSheetHorizontal = md;

  /// Vertical gap between share sheet sections.
  static const double shareSectionGap = md;

  /// Gap between horizontal share circles.
  static const double shareItemGap = smd;

  /// Gap between a share circle and its label.
  static const double shareCircleLabelGap = xs;

  /// Bottom padding under the last share row.
  static const double shareSheetBottom = lg;
}
