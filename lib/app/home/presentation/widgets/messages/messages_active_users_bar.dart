import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class MessagesActiveUsersBar extends StatelessWidget {
  const MessagesActiveUsersBar({
    required this.chats,
    super.key,
  });

  final List<Map<String, dynamic>> chats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SizedBox(
      height: MessagesLayoutConstants.activeUsersBarHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: MessagesLayoutConstants.horizontalPadding,
        ),
        itemCount: chats.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _StoryAddItem(label: l10n.messagesYourStory);
          }

          final chat = chats[index - 1];
          final name = chat['name'] as String;
          final image = chat['image'] as String;
          final active = chat['active'] as bool? ?? false;

          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(
                        MessagesLayoutConstants.activeRingWidth,
                      ),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: theme.scaffoldBackgroundColor,
                          shape: BoxShape.circle,
                        ),
                        child: SafeNetworkAvatar(
                          imageUrl: image,
                          radius: MessagesLayoutConstants.activeAvatarRadius,
                          fallbackText: name,
                        ),
                      ),
                    ),
                    if (active)
                      PositionedDirectional(
                        end: 2,
                        bottom: 2,
                        child: Container(
                          width: MessagesLayoutConstants.activeDotSize,
                          height: MessagesLayoutConstants.activeDotSize,
                          decoration: BoxDecoration(
                            color: MessagesLayoutConstants.activeDotColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.scaffoldBackgroundColor,
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  name.split(' ').first,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StoryAddItem extends StatelessWidget {
  const _StoryAddItem({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 16),
      child: Column(
        children: [
          Container(
            width: MessagesLayoutConstants.activeStorySize,
            height: MessagesLayoutConstants.activeStorySize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.1),
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.add,
                color: theme.colorScheme.primary,
                size: 30,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
