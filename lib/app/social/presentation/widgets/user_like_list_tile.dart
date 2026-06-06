import 'package:bimobondapp/app/chats/presentation/utils/chat_message_mapper.dart';
import 'package:bimobondapp/app/social/domain/entities/user_like_entity.dart';
import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/core/navigation/post_navigation.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class UserLikeListTile extends StatelessWidget {
  const UserLikeListTile({
    required this.like,
    super.key,
  });

  final UserLikeEntity like;

  DateTime? get _likedAt {
    if (like.createdAt.isEmpty) return null;
    return DateTime.tryParse(like.createdAt);
  }

  void _openLikedPost(BuildContext context) {
    openPostById(context, like.postId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final liker = like.user;
    final likerName = liker?.displayName ?? l10n.messagesInboxUserFallback;
    final time = formatInboxTime(_likedAt, l10n);

    Future<void> openLikerProfile() async {
      if (liker == null || liker.id.isEmpty) return;
      await openUserStoryOrProfile(
        context,
        userId: liker.id,
        username: liker.username,
        fullName: liker.fullName,
        avatarUrl: liker.avatarUrl,
        isFollowing: liker.isFollowing,
      );
    }

    return InkWell(
      onTap: () => _openLikedPost(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.p16,
          vertical: AppSizes.p12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                StoryProfileAvatar(
                  userId: liker?.id,
                  imageUrl: liker?.avatarUrl,
                  radius: 22,
                  fallbackText: likerName,
                  username: liker?.username,
                  fullName: liker?.fullName,
                  isFollowing: liker?.isFollowing,
                  onTap: openLikerProfile,
                ),
                  PositionedDirectional(
                    end: -1,
                    bottom: -1,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: MessagesLayoutConstants.activityLikesColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.scaffoldBackgroundColor,
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
            ),
            const SizedBox(width: AppSizes.p12),
            Expanded(
              child: Row(
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
                            text: likerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text: ' ${l10n.userLikeReceivedAction}',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withValues(alpha: 0.75),
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
            ),
          ],
        ),
      ),
    );
  }
}
