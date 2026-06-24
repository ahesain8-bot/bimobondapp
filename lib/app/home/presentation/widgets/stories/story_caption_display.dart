import 'package:bimobondapp/app/home/presentation/widgets/stories/story_text_overlay.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class StoryCaptionUtils {
  StoryCaptionUtils._();

  static String plainCaption(String? description) {
    final raw = description?.trim() ?? '';
    if (raw.isEmpty) return '';
    if (StoryTextOverlayCodec.hasEncodedOverlays(raw)) {
      return StoryTextOverlayCodec.decode(raw)
          .map((overlay) => overlay.text.trim())
          .where((text) => text.isNotEmpty)
          .join(' ');
    }
    return raw;
  }
}

class StoryCaptionDisplay extends StatefulWidget {
  const StoryCaptionDisplay({
    required this.caption,
    super.key,
  });

  final String caption;

  @override
  State<StoryCaptionDisplay> createState() => _StoryCaptionDisplayState();
}

class _StoryCaptionDisplayState extends State<StoryCaptionDisplay> {
  bool _expanded = false;

  static const _captionStyle = TextStyle(
    color: Colors.white,
    fontSize: 15,
    height: 1.35,
    fontWeight: FontWeight.w500,
    shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
  );

  static final _linkStyle = TextStyle(
    color: Colors.white.withValues(alpha: 0.85),
    fontSize: 13,
    fontWeight: FontWeight.w600,
    shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
  );

  bool _exceedsOneLine(double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: widget.caption, style: _captionStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.caption.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final canToggle = _exceedsOneLine(constraints.maxWidth);
        final showLoadMore = !_expanded && canToggle;
        final showLess = _expanded && canToggle;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              widget.caption,
              textAlign: TextAlign.center,
              maxLines: _expanded ? null : 1,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: _captionStyle,
            ),
            if (showLoadMore) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => setState(() => _expanded = true),
                child: Text(
                  l10n.storyLoadMore,
                  textAlign: TextAlign.center,
                  style: _linkStyle,
                ),
              ),
            ],
            if (showLess) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => setState(() => _expanded = false),
                child: Text(
                  l10n.storyShowLess,
                  textAlign: TextAlign.center,
                  style: _linkStyle,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
