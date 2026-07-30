import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_post_search_hint.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/navigation/feed_navigation.dart';
import 'package:bimobondapp/core/widgets/directional_back_icon.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Back + related-content search (TikTok-style) for profile fullscreen posts.
class ProfilePostsViewerTopBar extends StatelessWidget {
  const ProfilePostsViewerTopBar({
    required this.onBack,
    required this.post,
    this.showSearch = true,
    super.key,
  });

  final VoidCallback onBack;
  final PostEntity post;
  final bool showSearch;

  static const double barHeight = 44;

  static double stackHeight(BuildContext context) {
    return MediaQuery.paddingOf(context).top + barHeight + 12;
  }

  Future<void> _openSearch(BuildContext context) async {
    final query = feedPostSearchRecommendation(post).trim();
    await context.pushFromFeed(
      'posts_search',
      extra: query.isEmpty ? null : {'initialQuery': query},
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final top = MediaQuery.paddingOf(context).top;
    final recommendation = feedPostSearchRecommendation(post).trim();
    final pillHint = recommendation.isNotEmpty
        ? recommendation
        : l10n.soundFindRelatedHint;

    return Padding(
      padding: EdgeInsets.fromLTRB(4, top + 4, 8, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const DirectionalBackIcon(color: Colors.white, size: 22),
          ),
          if (showSearch) ...[
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openSearch(context),
                  borderRadius: BorderRadius.circular(22),
                  child: Ink(
                    height: barHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.search,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            pillHint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => _openSearch(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                l10n.searchAction,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tap-to-comment strip above the video progress bar (TikTok-style).
class ProfilePostsViewerCommentBar extends StatelessWidget {
  const ProfilePostsViewerCommentBar({
    required this.onTap,
    super.key,
  });

  final VoidCallback onTap;

  static const double barHeight = 44;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;

    return Material(
      color: Colors.black,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 6, 12, bottom + 6),
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: barHeight,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.storyAddCommentHint,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  LucideIcons.image,
                  size: 22,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
                const SizedBox(width: 14),
                Icon(
                  LucideIcons.smile,
                  size: 22,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
                const SizedBox(width: 14),
                Icon(
                  LucideIcons.atSign,
                  size: 22,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
