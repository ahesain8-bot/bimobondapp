import 'package:bimobondapp/app/chats/domain/entities/chat_participant_entity.dart';
import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Friend row on the New Chat screen (avatar, name, mutual-message action).
class NewChatFriendTile extends StatelessWidget {
  const NewChatFriendTile({
    required this.friend,
    required this.onTap,
    super.key,
  });

  final ChatParticipantEntity friend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    final name = friend.displayName;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MessagesLayoutConstants.horizontalPadding,
          vertical: 10,
        ),
        child: Row(
          children: [
            StoryProfileAvatar(
              userId: friend.id,
              imageUrl: friend.avatarUrl,
              radius: MessagesLayoutConstants.conversationAvatarRadius,
              fallbackText: name,
              username: friend.username,
              fullName: friend.fullName,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              LucideIcons.usersRound,
              size: 22,
              color: chatTheme.inboxSecondaryText,
            ),
          ],
        ),
      ),
    );
  }
}
