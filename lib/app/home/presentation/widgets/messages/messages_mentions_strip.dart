import 'package:bimobondapp/app/social/domain/entities/user_mention_entity.dart';
import 'package:bimobondapp/app/social/presentation/utils/mention_post_navigation.dart';
import 'package:bimobondapp/app/social/presentation/widgets/mention_list_card.dart';
import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/activity_feed_card.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class MessagesMentionsStrip extends StatelessWidget {
  const MessagesMentionsStrip({
    required this.mentions,
    this.onSeeAll,
    super.key,
  });

  final List<UserMentionEntity> mentions;
  final VoidCallback? onSeeAll;

  String? _resolveThumbnailUrl(UserMentionEntity mention) {
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
    if (mentions.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            MessagesLayoutConstants.sectionHorizontalPadding,
            8,
            MessagesLayoutConstants.sectionHorizontalPadding,
            12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.messagesRecentMentions,
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color,
                  fontSize: MessagesLayoutConstants.sectionHeaderFontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              if (onSeeAll != null)
                InkWell(
                  onTap: onSeeAll,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Text(
                      l10n.messagesSeeAll,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: MessagesLayoutConstants.sectionLinkFontSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: MessagesLayoutConstants.mentionsStripHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: mentions.length,
            itemBuilder: (context, index) {
              final mention = mentions[index];
              final author = mention.user;
              final authorName =
                  author?.displayName ?? l10n.messagesInboxUserFallback;
              final content = mention.content.trim();
              final preview = _resolveThumbnailUrl(mention);

              void openProfile() {
                if (author == null || author.id.isEmpty) return;
                openUserStoryOrProfile(
                  context,
                  userId: author.id,
                  username: author.username,
                  fullName: author.fullName,
                  avatarUrl: author.avatarUrl,
                  isFollowing: author.isFollowing,
                );
              }

              return MentionListCard(
                mention: mention,
                child: Container(
                  width: MessagesLayoutConstants.mentionCardWidth,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: activityFeedCardSurface(theme),
                    borderRadius: BorderRadius.circular(
                      MessagesLayoutConstants.mentionCardRadius,
                    ),
                    border: Border.all(
                      color: activityFeedCardBorderColor(theme),
                    ),
                  ),
                  child: Row(
                    children: [
                      Stack(
                          clipBehavior: Clip.none,
                          children: [
                            StoryProfileAvatar(
                              userId: author?.id,
                              imageUrl: author?.avatarUrl,
                              radius: MessagesLayoutConstants
                                  .mentionAvatarRadius,
                              fallbackText: authorName,
                              username: author?.username,
                              fullName: author?.fullName,
                              isFollowing: author?.isFollowing,
                              onTap: openProfile,
                            ),
                            PositionedDirectional(
                              end: -1,
                              bottom: -1,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: activityFeedCardSurface(theme),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.alternate_email_rounded,
                                  size: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: openProfile,
                              child: Text(
                                authorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 1),
                            content.isNotEmpty
                                ? Text(
                                    content,
                                    style: TextStyle(
                                      color: theme
                                          .textTheme.bodyMedium?.color
                                          ?.withValues(alpha: 0.6),
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : Text(
                                    l10n.userMentionAction,
                                    style: TextStyle(
                                      color: theme.textTheme.bodyMedium?.color
                                          ?.withValues(alpha: 0.6),
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                          ],
                        ),
                      ),
                      if (preview != null && preview.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => openMentionPost(context, mention),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SafeNetworkImage(
                              imageUrl: preview,
                              width:
                                  MessagesLayoutConstants.mentionPreviewSize,
                              height:
                                  MessagesLayoutConstants.mentionPreviewSize,
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.circular(8),
                              errorIcon: Icons.image_outlined,
                            ),
                          ),
                        ),
                      ],
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
