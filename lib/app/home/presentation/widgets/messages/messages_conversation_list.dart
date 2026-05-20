import 'package:bimobondapp/app/chats/presentation/bloc/inbox_bloc.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/inbox_event.dart';
import 'package:bimobondapp/app/chats/presentation/utils/inbox_chat_helper.dart';
import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class MessagesConversationList extends StatelessWidget {
  const MessagesConversationList({
    required this.items,
    super.key,
  });

  final List<InboxChatItem> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (items.isEmpty) {
      return SizedBox(
        height: MessagesLayoutConstants.emptyStateHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: theme.dividerColor.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.messagesNoResults,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.4,
                ),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final chat = items[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: chat.unread
                ? theme.colorScheme.primary.withValues(
                    alpha: MessagesLayoutConstants.conversationUnreadAlpha,
                  )
                : Colors.transparent,
            borderRadius: BorderRadius.circular(
              MessagesLayoutConstants.conversationTileRadius,
            ),
          ),
          child: ListTile(
            onTap: () async {
              await context.pushNamed(
                'chat',
                extra: {
                  'chatId': chat.chatId,
                  'username': chat.name,
                  'imageUrl': chat.imageUrl,
                },
              );
              if (context.mounted) {
                context.read<InboxBloc>().add(
                  const InboxLoadRequested(refresh: true),
                );
              }
            },
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                MessagesLayoutConstants.conversationTileRadius,
              ),
            ),
            leading: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: chat.unread
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: SafeNetworkAvatar(
                    imageUrl: chat.imageUrl,
                    radius: MessagesLayoutConstants.conversationAvatarRadius,
                    fallbackText: chat.name,
                  ),
                ),
                if (chat.active)
                  PositionedDirectional(
                    end: 4,
                    bottom: 4,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: MessagesLayoutConstants.activeDotColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            title: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      chat.name,
                      style: TextStyle(
                        fontWeight:
                            chat.unread ? FontWeight.w900 : FontWeight.w700,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    chat.time,
                    style: TextStyle(
                      color: chat.unread
                          ? theme.colorScheme.primary
                          : theme.textTheme.bodyMedium?.color?.withValues(
                              alpha: 0.4,
                            ),
                      fontSize: 12,
                      fontWeight:
                          chat.unread ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            subtitle: Row(
              children: [
                Expanded(
                  child: Text(
                    chat.preview,
                    style: TextStyle(
                      color: chat.unread
                          ? theme.textTheme.bodyLarge?.color
                          : theme.textTheme.bodyMedium?.color?.withValues(
                              alpha: 0.5,
                            ),
                      fontWeight:
                          chat.unread ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (chat.unread) ...[
                  const SizedBox(width:  8),
                  Container(
                    width: MessagesLayoutConstants.conversationUnreadDotSize,
                    height: MessagesLayoutConstants.conversationUnreadDotSize,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
