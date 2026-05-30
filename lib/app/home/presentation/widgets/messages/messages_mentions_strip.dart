import 'package:bimobondapp/app/home/presentation/widgets/messages/messages_text.dart';
import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/core/navigation/user_profile_navigation.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class MessagesMentionsStrip extends StatelessWidget {
  const MessagesMentionsStrip({required this.mentions, super.key});

  final List<Map<String, dynamic>> mentions;

  @override
  Widget build(BuildContext context) {
    if (mentions.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MessagesLayoutConstants.horizontalPadding,
            vertical: 4,
          ),
          child: Text(
            l10n.messagesRecentMentions,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        SizedBox(
          height: MessagesLayoutConstants.mentionsStripHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: mentions.length,
            itemBuilder: (context, index) {
              final mention = mentions[index];
              final userId = mention['userId'] as String? ?? '';
              final user = mention['user'] as String;
              final image = mention['image'] as String;
              final content = messagesMentionText(
                mention['contentKey'] as String?,
                l10n,
              );
              final preview = mention['postPreview'] as String;

              void openProfile() {
                if (userId.isEmpty) return;
                openUserProfile(
                  context,
                  userId: userId,
                  username: user,
                  avatarUrl: image,
                );
              }

              return Container(
                width: MessagesLayoutConstants.mentionCardWidth,
                margin: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(
                    MessagesLayoutConstants.mentionCardRadius,
                  ),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: openProfile,
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(1.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            child: SafeNetworkAvatar(
                              imageUrl: image,
                              radius:
                                  MessagesLayoutConstants.mentionAvatarRadius,
                              fallbackText: user,
                            ),
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
                                  color: theme.cardColor,
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
                              user,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            content,
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
                    const SizedBox(width: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SafeNetworkImage(
                        imageUrl: preview,
                        width: MessagesLayoutConstants.mentionPreviewSize,
                        height: MessagesLayoutConstants.mentionPreviewSize,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
