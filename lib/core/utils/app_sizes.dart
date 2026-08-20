class AppSizes {
  // Spacing & Padding
  static const double p4 = 4.0;
  static const double p6 = 6.0;
  static const double p8 = 8.0;
  static const double p10 = 10.0;
  static const double p12 = 12.0;
  static const double p14 = 14.0;
  static const double p16 = 16.0;
  static const double p20 = 20.0;
  static const double p24 = 24.0;
  static const double p26 = 26.0;
  static const double p32 = 32.0;
  static const double p48 = 48.0;

  // Button heights
  static const double buttonHeightLg = 46;
  static const double buttonHeightMd = 44;
  static const double buttonHeightSm = 40;
  static const double buttonHeightXs = 36;

  /// Shared height for auth inputs, method buttons, and primary actions.
  static const double authControlHeight = buttonHeightSm;
  static const double authControlFontSize = 15;

  // Border Radius
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 18.0;
  static const double radiusXl = 24.0;
  static const double radiusCircular = 100.0;

  // ── Top status bar ────────────────────────────────────────────────────
  /// Circular button size (status icons + close button).
  static const double circularButton = 44;

  /// Icon inside a circular status button.
  static const double circularIcon = 22;

  /// Width of the live rewards status pill.
  static const double rewardsButtonWidth = 200;

  /// Height of the live rewards status pill.
  static const double rewardsButtonHeight = 48;

  /// Icon size inside the live rewards status pill.
  static const double rewardsIcon = 40;

  /// Height of the progress hint card, excluding its arrow.
  static const double progressHintHeight = 60;

  /// Width of the progress hint arrow.
  static const double progressHintArrowWidth = 16;

  /// Height of the progress hint arrow.
  static const double progressHintArrowHeight = 8;

  /// Paper-plane icon size in the progress hint.
  static const double progressHintIcon = 54;

  /// Close icon size.
  static const double closeIcon = 24;

  // ── Tool buttons ──────────────────────────────────────────────────────
  /// Width of each tool button column.
  static const double toolButtonWidth = 48;

  /// Height reserved for the tool image.
  static const double toolImageAreaHeight = 38;

  /// Tool image size.
  static const double toolImage = 40;

  /// Height reserved for the single-line label.
  static const double toolLabelHeight = 25;

  /// Tools expand/collapse toggle arrow size.
  static const double toggleArrow = 20;

  // ── Live container ────────────────────────────────────────────────────
  /// Guests avatar size.
  static const double avatarSize = 32;

  /// Guests avatar icon size.
  static const double avatarIcon = 23;

  /// Image picker button inside the live container.
  static const double imagePickerButton = 28;

  /// Image picker icon size.
  static const double imagePickerIcon = 18;

  /// LIVE start button height.
  static const double liveButtonHeight = 50;

  /// LIVE start button icon size.
  static const double liveButtonIcon = 18;

  // ── Bottom tabs ───────────────────────────────────────────────────────
  /// Active tab indicator width.
  static const double tabIndicatorWidth = 20;

  /// Active tab indicator height.
  static const double tabIndicatorHeight = 3;

  /// Active tab indicator corner radius.
  static const double tabIndicatorRadius = 2;

  // ── Radii ─────────────────────────────────────────────────────────────
  /// Card radius (live container).
  static const double radiusCard = 16;

  /// Pill button radius (LIVE start button).
  static const double radiusButton = 28;

  /// Small radius (image picker button).
  static const double radiusSmall = 6;

  // ── Font sizes ────────────────────────────────────────────────────────
  static const double fontSizeToolLabel = 12;
  static const double fontSizeTitle = 16;
  static const double fontSizeLiveTitle = 18;
  static const double fontSizeLiveStart = 16;
  static const double fontSizeOptions = 12;
  static const double fontSizeTab = 15;

  // ── Live room ─────────────────────────────────────────────────────────
  /// Host avatar diameter in the profile pill.
  static const double roomAvatar = 28;

  /// Profile / overlay pill height.
  static const double roomPillHeight = 34;

  /// Heart / like mini pill height.
  static const double roomHeartPillHeight = 22;

  /// Circular power / exit button.
  static const double roomPowerButton = 32;

  /// Info-row chip height (ranking, gallery, invite).
  static const double roomChipHeight = 26;

  /// Bottom action icon visual size.
  static const double roomBottomIcon = 26;

  /// Bottom bar icon hit target.
  static const double roomBottomAction = 36;

  /// Chat feed max width fraction of screen.
  static const double roomChatMaxWidthFactor = 0.78;

  /// Chat feed max height fraction of screen. The bloc keeps up to 80
  /// messages, which is far taller than the screen, so the feed is clamped
  /// and shows the newest run at the bottom instead of overflowing.
  static const double roomChatMaxHeightFactor = 0.34;

  /// System message leading badge size.
  static const double roomChatBadge = 16;

  /// Pill radius used across live-room chips.
  static const double radiusPill = 20;

  /// Bottom bar height excluding system inset.
  static const double roomBottomBarContentHeight = 48;

  /// Live-room host name font size.
  static const double fontSizeRoomHost = 13;

  /// Live-room chip / counter font size.
  static const double fontSizeRoomChip = 11;

  /// Live-room chat message font size.
  static const double fontSizeRoomChat = 13;

  // ── Live effects ──────────────────────────────────────────────────────
  /// Compact tray thumbnail edge length.
  static const double effectsThumb = 58;

  /// Expanded grid thumbnail edge length.
  static const double effectsGridThumb = 64;

  /// Thumbnail corner radius.
  static const double effectsThumbRadius = 14;

  /// Effects tray content height (excluding system inset).
  static const double effectsTrayHeight = 84;

  /// Expanded effects panel height factor of screen.
  static const double effectsExpandedHeightFactor = 0.42;

  // ── Live room options menu ────────────────────────────────────────────
  /// Top corner radius of the options bottom sheet.
  static const double optionsSheetRadius = 20;

  /// Corner radius of option cards inside the sheet.
  static const double optionsCardRadius = 14;

  /// Leading icon size in an option row.
  static const double optionsIcon = 24;

  /// Option row minimum height (single-line).
  static const double optionsRowHeight = 52;

  /// Toggle switch width.
  static const double optionsToggleWidth = 46;

  /// Toggle switch height.
  static const double optionsToggleHeight = 28;

  /// Red notification badge diameter.
  static const double optionsBadge = 8;

  /// Options menu title font size.
  static const double fontSizeOptionsTitle = 15;

  /// Options menu subtitle font size.
  static const double fontSizeOptionsSubtitle = 12;

  // ── Live share sheet ──────────────────────────────────────────────────
  /// Top corner radius of the share bottom sheet.
  static const double shareSheetRadius = 22;

  /// Contact / channel circle diameter.
  static const double shareCircle = 56;

  /// Inner brand icon size inside a share circle.
  static const double shareCircleIcon = 28;

  /// Contact avatar placeholder person icon.
  static const double shareAvatarIcon = 30;

  /// Share sheet title font size.
  static const double fontSizeShareTitle = 17;

  /// Share item label font size.
  static const double fontSizeShareLabel = 11;
}
