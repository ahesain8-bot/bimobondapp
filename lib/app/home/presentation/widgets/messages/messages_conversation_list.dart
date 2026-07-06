import 'package:bimobondapp/app/chats/presentation/bloc/inbox_bloc.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/inbox_event.dart';
import 'package:bimobondapp/app/chats/presentation/utils/inbox_chat_helper.dart';
import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class MessagesConversationList extends StatelessWidget {
  const MessagesConversationList({
    required this.items,
    this.scrollable = false,
    this.inboxEmpty = false,
    super.key,
  });

  final List<InboxChatItem> items;
  final bool scrollable;
  final bool inboxEmpty;

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
              inboxEmpty
                  ? Icons.chat_bubble_outline_rounded
                  : Icons.search_off_rounded,
              size: 48,
              color: theme.dividerColor.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Text(
              inboxEmpty
                  ? l10n.messagesInboxNoMessagesYet
                  : l10n.messagesNoResults,
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

    return ListView.separated(
      shrinkWrap: !scrollable,
      physics: scrollable
          ? const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics())
          : const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: items.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 1,
        color: theme.brightness == Brightness.light
            ? const Color(0xFFE4E7EC)
            : theme.dividerColor.withValues(alpha: 0.12),
      ),
      itemBuilder: (context, index) {
        final chat = items[index];
        bool deleteForEveryone = false;
        return Dismissible(
          key: Key('dismiss_${chat.chatId}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: AlignmentDirectional.centerEnd,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30),
              borderRadius: BorderRadius.circular(
                MessagesLayoutConstants.conversationTileRadius,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.deleteAction,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.delete_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
          ),
          confirmDismiss: (direction) async {
            final result = await showDialog<Map<String, bool>?>(
              context: context,
              builder: (dialogContext) => const _DeleteConfirmDialog(),
            );
            if (result != null && result['confirmed'] == true) {
              deleteForEveryone = result['deleteForEveryone'] ?? false;
              return true;
            }
            return false;
          },
          onDismissed: (direction) {
            context.read<InboxBloc>().add(InboxChatDismissed(
              chatId: chat.chatId,
              deleteForEveryone: deleteForEveryone,
            ));
          },
          child: _ConversationTile(chat: chat),
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.chat});

  final InboxChatItem chat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      // margin: const EdgeInsets.only(bottom: 4),
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
              if (chat.imageUrl != null && chat.imageUrl!.isNotEmpty)
                'imageUrl': chat.imageUrl,
              if (chat.peerUserId != null) 'peerUserId': chat.peerUserId,
            },
          );
          if (context.mounted) {
            context.read<InboxBloc>().add(
              const InboxLoadRequested(refresh: true),
            );
          }
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            MessagesLayoutConstants.conversationTileRadius,
          ),
        ),
        leading: Stack(
          children: [
            Container(
              padding: chat.unread ? const EdgeInsets.all(2) : EdgeInsets.zero,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: chat.unread
                    ? Border.all(color: theme.colorScheme.primary, width: 2)
                    : null,
              ),
              child: ClipOval(
                child: StoryProfileAvatar(
                  userId: chat.peerUserId,
                  imageUrl: chat.imageUrl,
                  //   radius: MessagesLayoutConstants.conversationAvatarRadius,
                  fallbackText: chat.name,
                  username: chat.name,
                  fullName: chat.name,
                ),
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
                    fontWeight: chat.unread ? FontWeight.w900 : FontWeight.w700,
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
                  fontWeight: chat.unread ? FontWeight.w800 : FontWeight.w500,
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
                  fontWeight: chat.unread ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (chat.unread) ...[
              const SizedBox(width: 8),
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
  }
}

class _DeleteConfirmDialog extends StatefulWidget {
  const _DeleteConfirmDialog();

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  bool _deleteForEveryone = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      title: Text(
        l10n.deleteChatTitle,
        style: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.deleteChatMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Theme(
            data: theme.copyWith(
              checkboxTheme: CheckboxThemeData(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.deleteForEveryone,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              value: _deleteForEveryone,
              onChanged: (val) {
                setState(() {
                  _deleteForEveryone = val ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: theme.colorScheme.error,
              dense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(
            l10n.cancel,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, {
            'confirmed': true,
            'deleteForEveryone': _deleteForEveryone,
          }),
          child: Text(
            l10n.deleteChatConfirm,
            style: TextStyle(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
