import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/navigation/feed_navigation.dart';
import 'package:bimobondapp/core/widgets/directional_chevron_icon.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Search pill text: post description, else author display name.
String feedPostSearchRecommendation(PostEntity post) {
  final desc = post.description?.trim();
  if (desc != null && desc.isNotEmpty) {
    final collapsed = desc.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.length > 72) return collapsed.substring(0, 72);
    return collapsed;
  }

  final user = post.user;
  final fullName = user?.fullName?.trim();
  if (fullName != null && fullName.isNotEmpty) return fullName;

  final username = user?.username.trim();
  if (username != null && username.isNotEmpty) return username;

  return '';
}

/// TikTok-style full-width `Search · recommendation` row under the progress line.
class FeedPostSearchHintBar extends StatelessWidget {
  const FeedPostSearchHintBar({
    required this.recommendation,
    this.embeddedInFeedChrome = false,
    this.alwaysShowSearchLabel = false,
    super.key,
  });

  final String recommendation;

  /// When true, parent [FeedVideoSearchProgressColumn] supplies the scrim.
  final bool embeddedInFeedChrome;

  /// Show the Search row even when [recommendation] is empty (TikTok-style).
  final bool alwaysShowSearchLabel;

  Future<void> _openSearch(BuildContext context) async {
    final query = recommendation.trim();
    await context.pushFromFeed(
      'posts_search',
      extra: query.isEmpty ? null : {'initialQuery': query},
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hint = recommendation.trim();
    if (hint.isEmpty && !alwaysShowSearchLabel) {
      return const SizedBox.shrink();
    }

    final row = InkWell(
      onTap: () => _openSearch(context),
      child: Ink(
        height: HomeLayoutConstants.feedSearchHintBarHeight,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        color: Colors.transparent,
        child: Row(
          children: [
            Icon(
              LucideIcons.search,
              size: 16,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.searchAction,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (hint.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '·',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ] else
              const Spacer(),
            DirectionalChevronIcon(
              size: 18,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ],
        ),
      ),
    );

    if (embeddedInFeedChrome) return row;

    return Material(color: Colors.black.withValues(alpha: 0.45), child: row);
  }
}
