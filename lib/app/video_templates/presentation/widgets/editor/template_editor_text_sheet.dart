import 'package:bimobondapp/app/video_templates/domain/repositories/video_templates_repository.dart';
import 'package:bimobondapp/app/video_templates/presentation/di/video_templates_injector.dart'
    as vt_di;
import 'package:bimobondapp/app/video_templates/presentation/models/template_editor_models.dart';
import 'package:bimobondapp/app/video_templates/presentation/utils/template_font_cache.dart';
import 'package:bimobondapp/app/video_templates/presentation/widgets/editor/template_editor_theme.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Result of the add-text placer — caption style for POST …/texts.
class TemplateEditorTextDraft {
  const TemplateEditorTextDraft({
    required this.text,
    this.font,
    this.fontSize = 48,
    this.color = '#FFFFFF',
    this.positionX = 0,
    this.positionY = 120,
  });

  final String text;
  final TemplateFontItem? font;
  /// 12–120 (canvas px on 1080×1920).
  final double fontSize;
  final String color;
  final double positionX;
  final double positionY;
}

const _kTextColors = <(String hex, Color swatch)>[
  ('#FFFFFF', Colors.white),
  ('#000000', Colors.black),
  ('#FF2D55', Color(0xFFFF2D55)),
  ('#FFD60A', Color(0xFFFFD60A)),
  ('#30D158', Color(0xFF30D158)),
  ('#64D2FF', Color(0xFF64D2FF)),
  ('#BF5AF2', Color(0xFFBF5AF2)),
  ('#FF9F0A', Color(0xFFFF9F0A)),
  ('#FF375F', Color(0xFFFF375F)),
  ('#AC8E68', Color(0xFFAC8E68)),
];

/// Full-screen text placer: type, color palette, drag on media, pinch / ± size.
class TemplateEditorTextSheet extends StatefulWidget {
  const TemplateEditorTextSheet({
    super.key,
    required this.fonts,
    this.loadingFonts = false,
    this.media,
    this.canvasWidth = 1080,
    this.canvasHeight = 1920,
    this.initial,
  });

  final List<TemplateFontItem> fonts;
  final bool loadingFonts;
  /// Media only (no outer AspectRatio) — drawn under the caption in the same box.
  final Widget? media;
  final int canvasWidth;
  final int canvasHeight;
  final TemplateEditorTextDraft? initial;

  static Future<TemplateEditorTextDraft?> show(
    BuildContext context, {
    required List<TemplateFontItem> fonts,
    bool loadingFonts = false,
    Widget? media,
    int canvasWidth = 1080,
    int canvasHeight = 1920,
    TemplateEditorTextDraft? initial,
  }) {
    return Navigator.of(context).push<TemplateEditorTextDraft>(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: const Duration(milliseconds: 120),
        pageBuilder: (_, _, _) => TemplateEditorTextSheet(
          fonts: fonts,
          loadingFonts: loadingFonts,
          media: media,
          canvasWidth: canvasWidth,
          canvasHeight: canvasHeight,
          initial: initial,
        ),
      ),
    );
  }

  @override
  State<TemplateEditorTextSheet> createState() =>
      _TemplateEditorTextSheetState();
}

class _TemplateEditorTextSheetState extends State<TemplateEditorTextSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  TemplateFontItem? _selected;
  final Set<String> _readyFamilies = {};
  late List<TemplateFontItem> _fonts;
  late bool _fontsLoading;
  late double _fontSize;
  late String _colorHex;
  late double _positionX;
  late double _positionY;

  double _baseFontSize = 48;
  /// When true, canvas consumes drag/pinch; keyboard is dismissed.
  bool _placing = false;

  int get _cw => widget.canvasWidth > 0 ? widget.canvasWidth : 1080;
  int get _ch => widget.canvasHeight > 0 ? widget.canvasHeight : 1920;
  double get _halfW => _cw / 2.0;
  double get _halfH => _ch / 2.0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _controller = TextEditingController(text: initial?.text ?? '');
    _focusNode = FocusNode();
    _selected = initial?.font;
    _fonts = List<TemplateFontItem>.from(widget.fonts);
    _fontsLoading = widget.loadingFonts || _fonts.isEmpty;
    _fontSize = (initial?.fontSize ?? 48).clamp(12, 120);
    _colorHex = initial?.color ?? '#FFFFFF';
    _positionX = initial?.positionX ?? 0;
    _positionY = initial?.positionY ?? 120;
    _controller.addListener(() => setState(() {}));
    _ensureFonts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_placing) _focusNode.requestFocus();
    });
  }

  Future<void> _ensureFonts() async {
    if (_fonts.isEmpty) {
      if (mounted) setState(() => _fontsLoading = true);
      final result = await vt_di.sl<VideoTemplatesRepository>().listFonts();
      if (!mounted) return;
      result.fold(
        (_) {
          setState(() => _fontsLoading = false);
        },
        (list) {
          setState(() {
            _fonts = list;
            _fontsLoading = false;
          });
        },
      );
    } else if (mounted) {
      setState(() => _fontsLoading = false);
    }
    await _preloadFonts(_fonts);
  }

  Future<void> _preloadFonts(List<TemplateFontItem> fonts) async {
    for (final font in fonts) {
      final ok = await TemplateFontCache.load(
        fontAssetId: font.id,
        url: font.url,
      );
      if (!mounted) return;
      if (ok) {
        setState(() => _readyFamilies.add(font.familyName));
      }
    }
  }

  Future<void> _selectFont(TemplateFontItem? font) async {
    if (font == null) {
      setState(() => _selected = null);
      return;
    }
    setState(() => _selected = font);
    final ok = await TemplateFontCache.load(
      fontAssetId: font.id,
      url: font.url,
    );
    if (!mounted) return;
    if (ok) {
      setState(() => _readyFamilies.add(font.familyName));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Color get _color {
    final hex = _colorHex.replaceFirst('#', '');
    final value = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
    return value != null ? Color(value) : Colors.white;
  }

  String? get _activeFamily {
    final selected = _selected;
    if (selected == null) return null;
    if (_readyFamilies.contains(selected.familyName)) {
      return selected.familyName;
    }
    if (TemplateFontCache.isLoaded(selected.id)) {
      return selected.familyName;
    }
    return null;
  }

  /// Custom TTFs are usually a single face — avoid weight mismatch fallback.
  TextStyle _styledText({
    required Color color,
    required double fontSize,
    FontWeight? fallbackWeight,
  }) {
    final family = _activeFamily;
    return TextStyle(
      color: color,
      fontSize: fontSize,
      fontFamily: family,
      fontWeight: family == null
          ? (fallbackWeight ?? FontWeight.w700)
          : FontWeight.normal,
      height: 1.2,
      shadows: const [
        Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 1)),
      ],
    );
  }

  void _enterPlaceMode() {
    _focusNode.unfocus();
    setState(() => _placing = true);
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      Navigator.pop(context);
      return;
    }
    // Snapshot choices at apply time (avoid any late rebuild resetting state).
    final font = _selected;
    final size = _fontSize.clamp(12.0, 120.0);
    final color = _colorHex;
    final x = _positionX.clamp(-_halfW + 40, _halfW - 40);
    final y = _positionY.clamp(-_halfH + 40, _halfH - 40);
    Navigator.pop(
      context,
      TemplateEditorTextDraft(
        text: text,
        font: font,
        fontSize: size,
        color: color,
        positionX: x,
        positionY: y,
      ),
    );
  }

  void _bumpSize(double delta) {
    setState(() => _fontSize = (_fontSize + delta).clamp(12, 120));
  }

  void _onScaleStart(ScaleStartDetails _) {
    _baseFontSize = _fontSize;
    if (!_placing || _focusNode.hasFocus) {
      _enterPlaceMode();
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size previewSize) {
    if (previewSize.width <= 0 || previewSize.height <= 0) return;
    final scaleX = _cw / previewSize.width;
    final scaleY = _ch / previewSize.height;

    setState(() {
      if (details.pointerCount >= 2 || (details.scale - 1.0).abs() > 0.015) {
        _fontSize = (_baseFontSize * details.scale).clamp(12.0, 120.0);
      }
      _positionX = (_positionX + details.focalPointDelta.dx * scaleX)
          .clamp(-_halfW + 40, _halfW - 40);
      _positionY = (_positionY + details.focalPointDelta.dy * scaleY)
          .clamp(-_halfH + 40, _halfH - 40);
    });
  }

  TextStyle _liveStyle(double previewWidth) {
    final scale = previewWidth / _cw;
    return _styledText(
      color: _color,
      fontSize: (_fontSize * scale).clamp(8.0, 120.0),
    );
  }

  Widget _buildStage() {
    final aspect = _cw / _ch;
    return LayoutBuilder(
      builder: (context, constraints) {
        var w = constraints.maxWidth;
        var h = w / aspect;
        if (h > constraints.maxHeight) {
          h = constraints.maxHeight;
          w = h * aspect;
        }
        final previewSize = Size(w, h);
        // Center-origin → top-left of text center in preview px.
        final cx = w / 2 + _positionX * (w / _cw);
        final cy = h / 2 + _positionY * (h / _ch);
        final display = _controller.text.trim().isEmpty
            ? 'Type below…'
            : _controller.text.trim();
        final style = _liveStyle(w).copyWith(
          color: _controller.text.trim().isEmpty
              ? _color.withValues(alpha: 0.45)
              : _color,
        );

        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Color(0xFF111111)),
                  if (widget.media != null)
                    Positioned.fill(child: widget.media!),
                  // Drag / pinch anywhere on the media.
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (_placing) {
                          setState(() => _placing = false);
                          _focusNode.requestFocus();
                        } else {
                          _enterPlaceMode();
                        }
                      },
                      onScaleStart: _onScaleStart,
                      onScaleUpdate: (d) => _onScaleUpdate(d, previewSize),
                    ),
                  ),
                  // Caption follows finger (ignore pointer — parent handles gestures).
                  Positioned(
                    left: cx,
                    top: cy,
                    child: IgnorePointer(
                      child: FractionalTranslation(
                        translation: const Offset(-0.5, -0.5),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: w * 0.9),
                          child: Text(
                            display,
                            textAlign: TextAlign.center,
                            style: style,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8,
                    child: IgnorePointer(
                      child: Text(
                        _placing
                            ? 'Drag to move · Pinch to resize'
                            : 'Tap media to place · Drag to move',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          shadows: const [
                            Shadow(color: Colors.black54, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sizeControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _roundIcon(icon: LucideIcons.minus, onTap: () => _bumpSize(-4)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '${_fontSize.round()}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _roundIcon(icon: LucideIcons.plus, onTap: () => _bumpSize(4)),
      ],
    );
  }

  Widget _roundIcon({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _colorPalette() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final entry in _kTextColors)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => setState(() => _colorHex = entry.$1),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: entry.$2,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _colorHex.toUpperCase() == entry.$1.toUpperCase()
                          ? TemplateEditorTheme.accent
                          : Colors.white38,
                      width: _colorHex.toUpperCase() == entry.$1.toUpperCase()
                          ? 2.5
                          : 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fontChips() {
    return SizedBox(
      height: 44,
      child: _fontsLoading && _fonts.isEmpty
          ? const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              ),
            )
          : ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _FontChip(
                  label: 'Default',
                  selected: _selected == null,
                  onTap: () => _selectFont(null),
                ),
                for (final font in _fonts)
                  _FontChip(
                    label: font.label,
                    selected: _selected?.id == font.id,
                    fontFamily: TemplateFontCache.isLoaded(font.id) ||
                            _readyFamilies.contains(font.familyName)
                        ? font.familyName
                        : null,
                    onTap: () => _selectFont(font),
                  ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.x, color: Colors.white70),
                    ),
                    const Expanded(
                      child: Text(
                        'Add text',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          _controller.text.trim().isEmpty ? null : _submit,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: TemplateEditorTheme.accent,
                        disabledForegroundColor: Colors.white38,
                        disabledBackgroundColor:
                            Colors.white.withValues(alpha: 0.12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        'Apply',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: _buildStage(),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                4,
                12,
                bottomInset > 0 ? 8 : 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: 2,
                    onTap: () => setState(() => _placing = false),
                    style: _styledText(
                      color: _color,
                      fontSize: 18,
                      fallbackWeight: FontWeight.w600,
                    ),
                    cursorColor: TemplateEditorTheme.accent,
                    decoration: InputDecoration(
                      hintText: 'Type your caption…',
                      hintStyle: TextStyle(
                        color: _color.withValues(alpha: 0.4),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) {
                      _enterPlaceMode();
                    },
                  ),
                  const SizedBox(height: 10),
                  _sizeControls(),
                  const SizedBox(height: 10),
                  _colorPalette(),
                  const SizedBox(height: 10),
                  _fontChips(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FontChip extends StatelessWidget {
  const _FontChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.fontFamily,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected
            ? TemplateEditorTheme.accent.withValues(alpha: 0.35)
            : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? TemplateEditorTheme.accent
                    : Colors.white24,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: fontFamily,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
