import 'package:bimobondapp/app/home/presentation/widgets/profile/post_cover_card.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/utils/format_count.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// TikTok-style search result card: cover + caption + avatar/username + likes.
class SearchPostResultTile extends StatelessWidget {
  const SearchPostResultTile({
    required this.post,
    required this.onTap,
    super.key,
  });

  final PostEntity post;
  final VoidCallback onTap;

  String get _caption {
    final text = post.description?.trim() ?? '';
    if (text.isNotEmpty) return text;
    if (post.hashtags.isNotEmpty) {
      return post.hashtags.map((h) => h.startsWith('#') ? h : '#$h').join(' ');
    }
    return '';
  }

  String get _username {
    final user = post.user;
    if (user == null) return '';
    final name = user.username.trim();
    if (name.isNotEmpty) return name.startsWith('@') ? name.substring(1) : name;
    return user.fullName?.trim() ?? '';
  }

  String get _avatarFallback {
    final name = _username;
    if (name.isEmpty) return '?';
    return name.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.55);
    final caption = _caption;
    final username = _username;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: PostCoverCard(
                  post: post,
                  tabIndex: 0,
                  theme: theme,
                  showCenterPlayIcon: false,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (caption.isNotEmpty)
              Text(
                caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                ),
              ),
            if (caption.isNotEmpty) const SizedBox(height: 6),
            Row(
              children: [
                _Avatar(
                  imageUrl: post.user?.avatarUrl,
                  fallback: _avatarFallback,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    username.isEmpty ? ' ' : username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: muted,
                    ),
                  ),
                ),
                Icon(
                  LucideIcons.heart,
                  size: 14,
                  color: muted,
                ),
                const SizedBox(width: 3),
                Text(
                  formatCompactCount(post.likeCount),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.fallback, this.imageUrl});

  final String? imageUrl;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = imageUrl?.trim();
    return ClipOval(
      child: SizedBox(
        width: 18,
        height: 18,
        child: url != null && url.isNotEmpty
            ? SafeNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                blankOnError: true,
                showLoadingIndicator: false,
              )
            : ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Center(
                  child: Text(
                    fallback,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
