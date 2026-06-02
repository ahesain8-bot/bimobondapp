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

    return Container(
      padding: EdgeInsets.fromLTRB(
        ChatLayoutConstants.inputBarHorizontalPadding,
        ChatLayoutConstants.inputBarTopPadding,
        ChatLayoutConstants.inputBarHorizontalPadding,
        MediaQuery.paddingOf(context).bottom +
            ChatLayoutConstants.inputBarBottomExtra,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withValues(
              alpha: ChatLayoutConstants.inputDividerAlpha,
            ),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyPreviewText != null)
            ChatReplyPreviewBar(text: replyPreviewText!, onClose: onReplyClose),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  LucideIcons.circlePlus,
                  color: theme.iconTheme.color?.withValues(
                    alpha: ChatLayoutConstants.inputLeadingIconAlpha,
                  ),
                  size: ChatLayoutConstants.inputLeadingIconSize,
                ),
                onPressed: onMoreMenu,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
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
                      const SizedBox(width: AppSizes.p16),
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
                              fontSize: ChatLayoutConstants.inputHintFontSize,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          LucideIcons.smile,
                          color: theme.iconTheme.color?.withValues(
                            alpha: ChatLayoutConstants.inputEmojiIconAlpha,
                          ),
                        ),
                        onPressed: onEmojiPicker,
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(width: AppSizes.p4),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.p8),
              GestureDetector(
                onLongPressStart: hasText ? null : (_) => onRecordingStart(),
                onLongPressEnd: hasText ? null : (_) => onRecordingEnd(),
                onLongPressCancel:
                    hasText ? null : () => onRecordingCancel?.call(),
                onTap: hasText ? onSend : null,
                child: Container(
                  width: ChatLayoutConstants.inputActionSize,
                  height: ChatLayoutConstants.inputActionSize,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasText ? LucideIcons.send : LucideIcons.mic,
                    color: theme.colorScheme.onPrimary,
                    size: hasText
                        ? ChatLayoutConstants.inputSendIconSize
                        : ChatLayoutConstants.inputMicIconSize,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
