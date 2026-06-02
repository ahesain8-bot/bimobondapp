import 'package:bimobondapp/app/chats/presentation/utils/chat_message_mapper.dart';
import 'package:bimobondapp/app/social/domain/entities/user_mention_entity.dart';
import 'package:bimobondapp/app/social/presentation/utils/mention_post_navigation.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class UserMentionListTile extends StatelessWidget {
  const UserMentionListTile({
    required this.mention,
    super.key,
  });

  final UserMentionEntity mention;

  DateTime? get _createdAt {
    if (mention.createdAt.isEmpty) return null;
    return DateTime.tryParse(mention.createdAt);
  }

  String? _resolveThumbnailUrl() {
    final post = mention.post;
    if (post == null) return null;

    if (post.thumbnailUrl != null &&
        MediaUtils.isImage(post.thumbnailUrl!)) {
      return post.thumbnailUrl;
    }
    if (post.media.isNotEmpty) {
      final first = post.media.first;
      if (MediaUtils.isImage(first.url, mediaType: first.mediaType)) {
        return first.url;
      }
    }
    return post.thumbnailUrl;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final author = mention.user;
    final authorName =
        author?.displayName ?? l10n.messagesInboxUserFallback;
    final time = formatInboxTime(_createdAt, l10n);
    final thumbnailUrl = _resolveThumbnailUrl();
    final content = mention.content.trim();

    return InkWell(
      onTap: () => openMentionPost(context, mention),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.p16,
          vertical: AppSizes.p12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SafeNetworkAvatar(
              imageUrl: author?.avatarUrl,
              radius: 22,
              fallbackText: authorName,
            ),
            const SizedBox(width: AppSizes.p12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: RichText(
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.3,
                            ),
                            children: [
                              TextSpan(
                                text: authorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text: ' ${l10n.userMentionAction}',
                                style: TextStyle(
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withValues(alpha: 0.75),
                                ),
                              ),
                              if (mention.isCommentMention)
                                TextSpan(
                                  text: ' · ${l10n.userMentionInComment}',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (time.isNotEmpty) ...[
                        const SizedBox(width: AppSizes.p8),
                        Text(
                          time,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (content.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ],
              ),
            ),
            if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) ...[
              const SizedBox(width: AppSizes.p12),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                child: SafeNetworkImage(
                  imageUrl: thumbnailUrl,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorIcon: Icons.image_outlined,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
