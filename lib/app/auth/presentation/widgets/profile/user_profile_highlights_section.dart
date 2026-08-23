import 'package:bimobondapp/app/home/presentation/pages/stories_viewer_screen.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_header_section.dart';
import 'package:bimobondapp/app/stories/domain/entities/highlight_entity.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class UserProfileHighlightsSection extends StatelessWidget {
  const UserProfileHighlightsSection({
    required this.highlights,
    required this.isLoading,
    required this.isSelf,
    required this.onCreateHighlight,
    required this.onLongPressHighlight,
    required this.onRefreshHighlights,
    super.key,
  });

  final List<HighlightEntity> highlights;
  final bool isLoading;
  final bool isSelf;
  final VoidCallback onCreateHighlight;
  final ValueChanged<HighlightEntity> onLongPressHighlight;
  final VoidCallback onRefreshHighlights;

  Widget _buildFallbackHighlightCover(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.surfaceContainerHighest, cs.surfaceContainerHigh],
        ),
      ),
      child: Center(
        child: Icon(Icons.star_rounded, color: Colors.amber.shade600, size: 26),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (isLoading && highlights.isEmpty) {
      return const HighlightsSkeletonRow();
    }

    final visibleHighlights = isSelf
        ? highlights
        : highlights
            .where(
              (h) =>
                  h.stories.isNotEmpty ||
                  (h.coverUrl != null && h.coverUrl!.isNotEmpty),
            )
            .toList();

    if (!isSelf && visibleHighlights.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 14),
        SizedBox(
          height: 104,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: visibleHighlights.length + (isSelf ? 1 : 0),
            itemBuilder: (context, index) {
              final theme = Theme.of(context);
              final cs = theme.colorScheme;

              if (isSelf && index == 0) {
                return GestureDetector(
                  onTap: onCreateHighlight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: cs.onSurface.withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cs.surfaceContainerHighest
                                  .withValues(alpha: 0.4),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.add,
                                color: cs.onSurface.withValues(alpha: 0.8),
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 76,
                          child: Text(
                            l10n.newHighlightButton,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final h = visibleHighlights[isSelf ? index - 1 : index];
              String? displayImage = h.coverUrl;
              if ((displayImage == null || displayImage.isEmpty) &&
                  h.stories.isNotEmpty) {
                displayImage = h.stories.first.thumbnailUrl ??
                    h.stories.first.videoUrl;
              }

              return GestureDetector(
                onLongPress: isSelf ? () => onLongPressHighlight(h) : null,
                onTap: () {
                  final highlightPosts =
                      h.stories.map((s) => s.toPostEntity()).toList();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StoriesViewerScreen(
                        stories: highlightPosts,
                        initialIndex: 0,
                        highlightId: h.id,
                        highlightTitle: h.title,
                      ),
                    ),
                  ).then((_) => onRefreshHighlights());
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: cs.onSurface.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.scaffoldBackgroundColor,
                          ),
                          child: ClipOval(
                            child: (displayImage != null && displayImage.isNotEmpty)
                                ? Image.network(
                                    displayImage,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _buildFallbackHighlightCover(cs),
                                  )
                                : _buildFallbackHighlightCover(cs),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 76,
                        child: Text(
                          h.title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
