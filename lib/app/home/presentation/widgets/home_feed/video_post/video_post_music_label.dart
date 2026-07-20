import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// TikTok-style sound attribution: music note + scrolling label.
class VideoPostMusicLabel extends StatefulWidget {
  const VideoPostMusicLabel({
    required this.soundName,
    this.soundAuthor,
    this.postUsername,
    this.onTap,
    super.key,
  });

  final String? soundName;
  final String? soundAuthor;
  final String? postUsername;
  final VoidCallback? onTap;

  @override
  State<VideoPostMusicLabel> createState() => _VideoPostMusicLabelState();
}

class _VideoPostMusicLabelState extends State<VideoPostMusicLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _marqueeController;
  final GlobalKey _textKey = GlobalKey();
  double _textWidth = 0;
  double _viewportWidth = 0;

  @override
  void initState() {
    super.initState();
    _marqueeController = AnimationController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureAndStart());
  }

  @override
  void didUpdateWidget(covariant VideoPostMusicLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.soundName != widget.soundName ||
        oldWidget.soundAuthor != widget.soundAuthor ||
        oldWidget.postUsername != widget.postUsername) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureAndStart());
    }
  }

  @override
  void dispose() {
    _marqueeController.dispose();
    super.dispose();
  }

  String _label(AppLocalizations l10n) {
    final sound = widget.soundName?.trim();
    final author = (widget.soundAuthor ?? widget.postUsername)?.trim();
    final base = (sound != null && sound.isNotEmpty)
        ? sound
        : l10n.cameraOriginalSound;
    if (author != null && author.isNotEmpty) {
      return '$base - $author';
    }
    return base;
  }

  void _measureAndStart() {
    if (!mounted) return;
    final textContext = _textKey.currentContext;
    if (textContext == null) return;
    final textWidth = textContext.size?.width ?? 0;
    if (textWidth <= 0 || _viewportWidth <= 0) return;

    setState(() => _textWidth = textWidth);

    if (textWidth <= _viewportWidth) {
      _marqueeController.stop();
      _marqueeController.value = 0;
      return;
    }

    // Scroll far enough for one full cycle of duplicated text + gap.
    final distance = textWidth + 32;
    final seconds = (distance / 30).clamp(6.0, 18.0);
    _marqueeController.duration = Duration(milliseconds: (seconds * 1000).round());
    _marqueeController.repeat();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = _label(l10n);
    final needsMarquee = _textWidth > _viewportWidth && _viewportWidth > 0;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(
            LucideIcons.music,
            size: 13,
            color: Colors.white.withValues(alpha: 0.95),
            shadows: const [
              Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
          const SizedBox(width: 6),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (_viewportWidth != constraints.maxWidth) {
                  _viewportWidth = constraints.maxWidth;
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _measureAndStart());
                }

                final textStyle = TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  shadows: const [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                );

                if (!needsMarquee) {
                  return Text(
                    key: _textKey,
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle,
                  );
                }

                return ClipRect(
                  child: SizedBox(
                    height: 18,
                    child: AnimatedBuilder(
                      animation: _marqueeController,
                      builder: (context, child) {
                        final offset =
                            -_marqueeController.value * (_textWidth + 32);
                        return Transform.translate(
                          offset: Offset(offset, 0),
                          child: child,
                        );
                      },
                      child: Row(
                        children: [
                          Text(key: _textKey, label, style: textStyle),
                          const SizedBox(width: 32),
                          Text(label, style: textStyle),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
