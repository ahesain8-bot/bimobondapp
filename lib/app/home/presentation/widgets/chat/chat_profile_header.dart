import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:flutter/material.dart';

class ChatProfileHeader extends StatelessWidget {
  const ChatProfileHeader({
    super.key,
    required this.username,
    required this.imageUrl,
    this.userId,
    this.followersCount,
    this.postsCount,
    this.statsText,
    this.mutualText,
    this.onTap,
  });

  final String username;
  final String imageUrl;
  final String? userId;
  final int? followersCount;
  final int? postsCount;
  final String? statsText;
  final String? mutualText;
  final VoidCallback? onTap;

  String? _buildDynamicStatsText() {
    if (statsText != null && statsText!.trim().isNotEmpty) {
      return statsText!.trim();
    }
    if (followersCount == null && postsCount == null) {
      return null;
    }
    final parts = <String>[];
    if (postsCount != null) {
      parts.add('$postsCount ${postsCount == 1 ? 'post' : 'posts'}');
    }
    if (followersCount != null) {
      parts.add('$followersCount ${followersCount == 1 ? 'follower' : 'followers'}');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final handle = '@${username.toLowerCase().replaceAll(' ', '')}';
    final computedStats = _buildDynamicStatsText();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            StoryProfileAvatar(
              userId: userId,
              imageUrl: imageUrl,
              radius: 46,
              fallbackText: username,
              username: username,
              fullName: username,
              onTap: onTap,
            ),
            const SizedBox(height: 12),
            Text(
              username,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              handle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            if (computedStats != null && computedStats.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                computedStats,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (mutualText != null && mutualText!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                mutualText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
