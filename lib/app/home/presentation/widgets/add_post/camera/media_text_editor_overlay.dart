import 'package:bimobondapp/app/home/presentation/utils/media_text_font_styles.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_text_overlay.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/app/social/presentation/services/mention_friends_source.dart';
import 'package:bimobondapp/core/utils/mention_compose.dart';
import 'package:bimobondapp/core/utils/tag_text_editing.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Full-screen text entry used by the media studio editor to add / edit a text
/// sticker. Returns the resulting [MediaTextOverlay] (or null on cancel).
class MediaTextEditorOverlay extends StatefulWidget {
  const MediaTextEditorOverlay({super.key, this.initial, this.background});

  /// When editing an existing overlay; null when adding a new one.
  final MediaTextOverlay? initial;

  /// The captured photo (with its filters) rendered behind the text editing
  /// UI so the background stays visible instead of turning black.
  final Widget? background;

  static Future<MediaTextOverlay?> show(
    BuildContext context, {
    MediaTextOverlay? initial,
    Widget? background,
  }) {
    return Navigator.of(context).push<MediaTextOverlay>(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: const Duration(milliseconds: 120),
        pageBuilder: (_, _, _) => MediaTextEditorOverlay(
          initial: initial,
          background: background,
        ),
      ),
    );
  }

  @override
  State<MediaTextEditorOverlay> createState() => _MediaTextEditorOverlayState();
}

class _MediaTextEditorOverlayState extends State<MediaTextEditorOverlay> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late Color _color;
  late double _fontSize;
  late TextAlign _textAlign;
  late int _fontStyleIndex;
  late MediaTextLook _look;
  final _colorsKey = GlobalKey();
  bool _allowPop = false;

  // ---- @mention autocomplete -----------------------------------------------
  List<SocialUserEntity> _friends = const [];
  List<SocialUserEntity> _mentionSuggestions = const [];
  ActiveMentionQuery? _mentionQuery;
  bool _loadingFriends = false;

  static const _palette = <Color>[
    Colors.white,
    Colors.black,
    Color(0xFFFE2C55),
    Color(0xFFFFC107),
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFF9C27B0),
    Color(0xFFFF5722),
    Color(0xFF00BCD4),
    Color(0xFFE91E63),
  ];

  MediaTextFontStyle get _activeFont =>
      MediaTextFontStyles.all[_fontStyleIndex];

  /// Live preview overlay used only to resolve contrast / look helpers.
  MediaTextOverlay get _previewOverlay => MediaTextOverlay(
        id: 'preview',
        text: _controller.text,
        color: _color,
        backgroundColor:
            _look == MediaTextLook.background ? _color : null,
        fontSize: _fontSize,
        textAlign: _textAlign,
        fontStyleId: _activeFont.id,
        fontWeight: _activeFont.fontWeight,
        fontStyle: _activeFont.fontStyle,
        fontFamily: _activeFont.fontFamily,
        letterSpacing: _activeFont.letterSpacing,
        look: _look,
      );

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial?.text ?? '');
    _focusNode = FocusNode();
    _color = widget.initial?.color ?? Colors.white;
    _fontSize = widget.initial?.fontSize ?? 28;
    _textAlign = widget.initial?.textAlign ?? TextAlign.center;
    _fontStyleIndex =
        MediaTextFontStyles.indexOfId(widget.initial?.fontStyleId);
    _look = widget.initial?.look ?? MediaTextLook.none;
    _controller.addListener(_onTextChanged);
    _preloadPeople();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _preloadPeople() async {
    setState(() => _loadingFriends = true);
    final people = await MentionFriendsSource.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _friends = people;
      _loadingFriends = false;
    });
    final active = _mentionQuery;
    if (active != null) _applyMentionFilter(active);
  }

  /// Detects a `@query` at the cursor and refreshes the people dropdown.
  void _onTextChanged() {
    final text = _controller.text;
    final selection = _controller.selection;
    var cursor = selection.isValid ? selection.baseOffset : text.length;
    if (cursor < 0) cursor = 0;

    final active = MentionCompose.activeAt(text, cursor);
    if (active == null) {
      if (_mentionQuery != null) {
        setState(() {
          _mentionQuery = null;
          _mentionSuggestions = const [];
        });
      }
      return;
    }
    setState(() => _mentionQuery = active);
    _applyMentionFilter(active);
  }

  void _applyMentionFilter(ActiveMentionQuery active) {
    if (!mounted) return;
    setState(
      () => _mentionSuggestions =
          MentionFriendsSource.filter(_friends, active.query),
    );
  }

  void _pickUser(SocialUserEntity user) {
    final active = _mentionQuery;
    final username = user.username?.trim();
    if (active == null || username == null || username.isEmpty) return;
    TagTextEditing.completeMention(
      _controller,
      mentionStart: active.start,
      mentionEnd: active.end,
      username: username,
    );
    setState(() {
      _mentionQuery = null;
      _mentionSuggestions = const [];
    });
  }

  void _done() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _allowPop = true;
      Navigator.of(context).pop();
      return;
    }
    final dy = widget.initial?.center.dy ?? 0.4;
    final alignChanged =
        widget.initial == null || widget.initial!.textAlign != _textAlign;
    final dx = alignChanged
        ? MediaTextOverlay.dxForAlign(_textAlign)
        : (widget.initial?.center.dx ??
            MediaTextOverlay.dxForAlign(_textAlign));
    final font = _activeFont;
    final base = widget.initial ??
        MediaTextOverlay(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          text: text,
        );
    _allowPop = true;
    Navigator.of(context).pop(
      base.copyWith(
        text: text,
        color: _color,
        fontSize: _fontSize,
        textAlign: _textAlign,
        center: Offset(dx, dy),
        fontWeight: font.fontWeight,
        fontStyle: font.fontStyle,
        fontFamily: font.fontFamily,
        fontStyleId: font.id,
        letterSpacing: font.letterSpacing,
        look: _look,
        backgroundColor:
            _look == MediaTextLook.background ? _color : null,
      ),
    );
  }

  void _cycleTextAlign() {
    setState(() {
      if (_textAlign == TextAlign.center) {
        _textAlign = TextAlign.right;
      } else if (_textAlign == TextAlign.right) {
        _textAlign = TextAlign.left;
      } else {
        _textAlign = TextAlign.center;
      }
    });
  }

  void _cycleFontStyle() {
    setState(() {
      _fontStyleIndex =
          (_fontStyleIndex + 1) % MediaTextFontStyles.all.length;
    });
  }

  void _cycleLook() {
    setState(() => _look = MediaTextOverlay.nextLook(_look));
  }

  void _scrollToColors() {
    final ctx = _colorsKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  IconData get _alignIcon {
    switch (_textAlign) {
      case TextAlign.left:
        return Icons.format_align_left;
      case TextAlign.right:
        return Icons.format_align_right;
      default:
        return Icons.format_align_center;
    }
  }

  List<Shadow>? get _fieldShadows {
    switch (_look) {
      case MediaTextLook.outline:
        // Approximate a white outline inside TextField (stroke isn't supported).
        const o = Colors.white;
        return const [
          Shadow(offset: Offset(-2, -2), color: o),
          Shadow(offset: Offset(2, -2), color: o),
          Shadow(offset: Offset(2, 2), color: o),
          Shadow(offset: Offset(-2, 2), color: o),
          Shadow(offset: Offset(0, -2), color: o),
          Shadow(offset: Offset(0, 2), color: o),
          Shadow(offset: Offset(-2, 0), color: o),
          Shadow(offset: Offset(2, 0), color: o),
        ];
      case MediaTextLook.background:
        return null;
      case MediaTextLook.none:
        return const [
          Shadow(
            color: Colors.black45,
            blurRadius: 8,
            offset: Offset(0, 1),
          ),
        ];
    }
  }

  TextStyle get _editorTextStyle => _activeFont.resolve(
        color: _previewOverlay.resolvedTextColor,
        fontSize: _fontSize,
        shadows: _fieldShadows,
      );

  Widget _roundIconButton({
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: child,
      ),
    );
  }

  /// TikTok-style rainbow color button.
  Widget _colorButton() {
    return _roundIconButton(
      onTap: _scrollToColors,
      child: Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [
              Color(0xFFFF0000),
              Color(0xFFFFFF00),
              Color(0xFF00FF00),
              Color(0xFF00FFFF),
              Color(0xFF0000FF),
              Color(0xFFFF00FF),
              Color(0xFFFF0000),
            ],
          ),
          border: Border.fromBorderSide(
            BorderSide(color: Colors.white, width: 1.5),
          ),
        ),
      ),
    );
  }

  /// TikTok-style "A" in a rounded box — cycles background / outline / none.
  Widget _lookButton() {
    final active = _look != MediaTextLook.none;
    return _roundIconButton(
      onTap: _cycleLook,
      child: Container(
        width: 26,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _look == MediaTextLook.background
              ? Colors.white
              : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: Colors.white,
            width: active ? 2 : 1.4,
          ),
        ),
        child: Text(
          'A',
          style: TextStyle(
            color: _look == MediaTextLook.background
                ? Colors.black
                : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            height: 1,
            shadows: _look == MediaTextLook.outline
                ? const [
                    Shadow(offset: Offset(-0.8, -0.8), color: Colors.white),
                    Shadow(offset: Offset(0.8, 0.8), color: Colors.white),
                  ]
                : null,
          ),
        ),
      ),
    );
  }

  /// Inline `@` people picker shown above the controls while typing a mention.
  Widget _mentionDropdown() {
    final l10n = AppLocalizations.of(context)!;
    final loading = _loadingFriends && _mentionSuggestions.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.black.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 190),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    )
                  : _mentionSuggestions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        l10n.messagesNoResults,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _mentionSuggestions.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        indent: 56,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      itemBuilder: (context, index) {
                        final user = _mentionSuggestions[index];
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          leading: StoryProfileAvatar(
                            userId: user.id,
                            imageUrl: user.avatarUrl,
                            radius: 18,
                            fallbackText: user.username ?? user.displayName,
                            username: user.username,
                            fullName: user.fullName,
                            onTap: () => _pickUser(user),
                          ),
                          title: Text(
                            user.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: user.username != null
                              ? Text(
                                  '@${user.username}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                )
                              : null,
                          onTap: () => _pickUser(user),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bg = _look == MediaTextLook.background ? _color : null;
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.background != null) ...[
            Positioned.fill(child: widget.background!),
            // Subtle scrim keeps the white editing controls / text readable
            // over bright photos without hiding the background.
            const Positioned.fill(
              child: ColoredBox(color: Color(0x59000000)),
            ),
          ],
          SafeArea(
            child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // TikTok order: color → look(A) → alignment → font
                      _colorButton(),
                      const SizedBox(width: 10),
                      _lookButton(),
                      const SizedBox(width: 10),
                      _roundIconButton(
                        onTap: _cycleTextAlign,
                        child: Icon(_alignIcon, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 10),
                      _roundIconButton(
                        onTap: _cycleFontStyle,
                        child: Text(
                          'Aa',
                          style: _activeFont
                              .resolve(color: Colors.white, fontSize: 15)
                              .copyWith(height: 1),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: _done,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            l10n.mediaEditorDone,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: bg != null
                        ? const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          )
                        : EdgeInsets.zero,
                    decoration: bg != null
                        ? BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(10),
                          )
                        : null,
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: false,
                      maxLines: null,
                      textAlign: _textAlign,
                      cursorColor: _previewOverlay.resolvedTextColor,
                      style: _editorTextStyle,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: l10n.mediaTextHint,
                        hintStyle: _editorTextStyle.copyWith(
                          color: _previewOverlay.resolvedTextColor
                              .withValues(alpha: 0.45),
                          shadows: null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_mentionQuery != null) _mentionDropdown(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Row(
                children: [
                  const Icon(Icons.format_size, color: Colors.white70, size: 20),
                  Expanded(
                    child: Slider(
                      value: _fontSize,
                      min: 16,
                      max: 64,
                      activeColor: Colors.white,
                      inactiveColor: Colors.white24,
                      onChanged: (v) => setState(() => _fontSize = v),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              key: _colorsKey,
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                itemCount: _palette.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final color = _palette[index];
                  final selected = color.toARGB32() == _color.toARGB32();
                  return GestureDetector(
                    onTap: () => setState(() => _color = color),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFFE2C55)
                              : Colors.white,
                          width: selected ? 3 : 1.5,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
          ),
        ],
      ),
      ),
    );
  }

  bool get _shouldPromptExit =>
      widget.initial != null || _controller.text.trim().isNotEmpty;

  Future<bool> _onWillPop() async {
    if (_allowPop) return true;
    if (!_shouldPromptExit) return true;

    final l10n = AppLocalizations.of(context)!;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.mediaEditorDiscardTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.mediaEditorContinueEditing),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.addPostDraftsComingSoon)),
              );
            },
            child: Text(l10n.mediaEditorSaveDraft),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _allowPop = true;
              Navigator.of(context).pop<MediaTextOverlay?>(null);
            },
            child: Text(l10n.mediaEditorDiscard),
          ),
        ],
      ),
    );

    return false;
  }
}
