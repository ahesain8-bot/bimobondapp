import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_reply_preview_bar.dart';
import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ChatInputBar extends StatelessWidget {
  const ChatInputBar({
    required this.controller,
    required this.hasText,
    required this.replyPreviewText,
    required this.onSend,
    required this.onMoreMenu,
    required this.onEmojiPicker,
    required this.onRecordingStart,
    required this.onRecordingEnd,
    this.onRecordingCancel,
    required this.onReplyClose,
    this.onTextChanged,
    super.key,
  });

  final TextEditingController controller;
  final bool hasText;
  final String? replyPreviewText;
  final VoidCallback onSend;
  final VoidCallback onMoreMenu;
  final VoidCallback onEmojiPicker;
  final VoidCallback onRecordingStart;
  final VoidCallback onRecordingEnd;
  final VoidCallback? onRecordingCancel;
  final VoidCallback onReplyClose;
  final ValueChanged<bool>? onTextChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(ChatLayoutConstants.inputBarTopRadius),
          topRight: Radius.circular(ChatLayoutConstants.inputBarTopRadius),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        ChatLayoutConstants.inputBarHorizontalPadding,
        ChatLayoutConstants.inputBarTopPadding,
        ChatLayoutConstants.inputBarHorizontalPadding,
        MediaQuery.paddingOf(context).bottom +
            ChatLayoutConstants.inputBarBottomExtra,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyPreviewText != null)
            ChatReplyPreviewBar(text: replyPreviewText!, onClose: onReplyClose),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                _ChatInputActionButton(
                  color: primary,
                  onTap: hasText ? onSend : null,
                  onLongPressStart: hasText ? null : (_) => onRecordingStart(),
                  onLongPressEnd: hasText ? null : (_) => onRecordingEnd(),
                  onLongPressCancel:
                      hasText ? null : () => onRecordingCancel?.call(),
                  icon: hasText ? LucideIcons.send : LucideIcons.mic,
                  iconSize: hasText
                      ? ChatLayoutConstants.inputSendIconSize
                      : ChatLayoutConstants.inputMicIconSize,
                ),
                const SizedBox(width: AppSizes.p8),
                Expanded(
                  child: Container(
                    height: ChatLayoutConstants.inputFieldHeight,
                    decoration: BoxDecoration(
                      color: chatTheme.inputFill,
                      borderRadius: BorderRadius.circular(
                        ChatLayoutConstants.inputFieldRadius,
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            LucideIcons.smile,
                            color: primary,
                            size: 22,
                          ),
                          onPressed: onEmojiPicker,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: controller,
                            onSubmitted: (_) => onSend(),
                            onChanged: (value) =>
                                onTextChanged?.call(value.isNotEmpty),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: ChatLayoutConstants.inputFieldFontSize,
                            ),
                            decoration: InputDecoration(
                              hintText: l10n.chatAddComment,
                              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.hintColor.withValues(
                                  alpha: ChatLayoutConstants.inputHintAlpha,
                                ),
                                fontSize:
                                    ChatLayoutConstants.inputHintFontSize,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSizes.p4),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.p8),
                _ChatInputActionButton(
                  color: primary,
                  onTap: onMoreMenu,
                  icon: LucideIcons.plus,
                  iconSize: 24,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatInputActionButton extends StatelessWidget {
  const _ChatInputActionButton({
    required this.color,
    required this.icon,
    required this.iconSize,
    this.onTap,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.onLongPressCancel,
  });

  final Color color;
  final IconData icon;
  final double iconSize;
  final VoidCallback? onTap;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressEndCallback? onLongPressEnd;
  final VoidCallback? onLongPressCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      onLongPressStart: onLongPressStart,
      onLongPressEnd: onLongPressEnd,
      onLongPressCancel: onLongPressCancel,
      child: Container(
        width: ChatLayoutConstants.inputActionSize,
        height: ChatLayoutConstants.inputActionSize,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: theme.colorScheme.onPrimary,
          size: iconSize,
        ),
      ),
    );
  }
}
