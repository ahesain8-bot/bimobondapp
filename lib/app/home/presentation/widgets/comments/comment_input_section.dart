import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_sheets.dart';
import 'package:bimobondapp/app/home/presentation/widgets/comments/quick_comment_reactions.dart';
import 'package:bimobondapp/app/social/presentation/widgets/mention_composer_field.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CommentInputSection extends StatelessWidget {
  const CommentInputSection({
    required this.bottomPadding,
    required this.replyingToUsername,
    required this.onClearReplyingTo,
    required this.onQuickReaction,
    required this.commentController,
    required this.commentFocusNode,
    required this.onSendComment,
    required this.showPostButton,
    this.onPickImage,
    this.isSendingImage = false,
    this.inputAvatar,
    super.key,
  });

  final double bottomPadding;
  final String? replyingToUsername;
  final VoidCallback onClearReplyingTo;
  final ValueChanged<String> onQuickReaction;
  final VoidCallback? onPickImage;
  final bool isSendingImage;
  final TextEditingController commentController;
  final FocusNode commentFocusNode;
  final VoidCallback onSendComment;
  final bool showPostButton;
  final Widget? inputAvatar;

  static const double _fieldMinHeight = 48;
  static const double _fieldRadius = 24;
  static const double _inputFontSize = 16;

  void _insertMentionTrigger() {
    final text = commentController.text;
    final selection = commentController.selection;
    final cursor = selection.isValid ? selection.baseOffset : text.length;
    final needsSpace =
        cursor > 0 && text[cursor - 1] != ' ' && text[cursor - 1] != '\n';
    final insert = needsSpace ? ' @' : '@';
    final newText = text.replaceRange(cursor, cursor, insert);
    final newOffset = cursor + insert.length;
    commentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    commentFocusNode.requestFocus();
  }

  void _openEmojiPicker(BuildContext context) {
    commentFocusNode.unfocus();
    ChatSheets.showEmojiPicker(
      context: context,
      messageController: commentController,
      onEmojiInserted: () {
        commentFocusNode.requestFocus();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.42);
    final fieldFill = theme.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.08)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.72);
    final borderColor = onSurface.withValues(alpha: 0.12);
    final barBorder = onSurface.withValues(alpha: 0.08);

    return Material(
      color: theme.colorScheme.surface,
      elevation: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          AppSizes.p16,
          AppSizes.p10,
          AppSizes.p16,
          bottomPadding + AppSizes.p12,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: barBorder, width: 1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (replyingToUsername != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.p10),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.reply,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: CustomText(
                        l10n.replyingTo(replyingToUsername!),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    GestureDetector(
                      onTap: onClearReplyingTo,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(LucideIcons.x, size: 18, color: muted),
                      ),
                    ),
                  ],
                ),
              ),
            QuickCommentReactions(onReactionSelected: onQuickReaction),
            const SizedBox(height: AppSizes.p12),
            MentionComposerField(
              controller: commentController,
              focusNode: commentFocusNode,
              maxLines: 5,
              minLines: 1,
              style: TextStyle(
                fontSize: _inputFontSize,
                height: 1.35,
                color: onSurface,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: replyingToUsername != null
                    ? l10n.replyingTo(replyingToUsername!)
                    : l10n.addCommentHint,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintStyle: TextStyle(
                  fontSize: _inputFontSize,
                  height: 1.35,
                  color: muted,
                  fontWeight: FontWeight.w400,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              layoutBuilder: (context, suggestions, textField) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (suggestions != null) ...[
                      suggestions,
                      const SizedBox(height: AppSizes.p8),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (inputAvatar != null)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              end: 10,
                              bottom: 4,
                            ),
                            child: inputAvatar,
                          ),
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            constraints: const BoxConstraints(
                              minHeight: _fieldMinHeight,
                            ),
                            decoration: BoxDecoration(
                              color: fieldFill,
                              borderRadius: BorderRadius.circular(_fieldRadius),
                              border: Border.all(color: borderColor),
                            ),
                            padding: const EdgeInsetsDirectional.only(
                              start: 16,
                              end: 4,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: _fieldMinHeight - 2,
                                    ),
                                    child: Align(
                                      alignment: AlignmentDirectional.centerStart,
                                      child: textField,
                                    ),
                                  ),
                                ),
                                if (!showPostButton)
                                  _FieldIconButton(
                                    icon: LucideIcons.atSign,
                                    color: muted,
                                    onTap: _insertMentionTrigger,
                                  ),
                                _FieldIconButton(
                                  icon: LucideIcons.smile,
                                  color: muted,
                                  onTap: () => _openEmojiPicker(context),
                                ),
                                if (onPickImage != null)
                                  _FieldIconButton(
                                    icon: LucideIcons.image,
                                    color: muted,
                                    onTap: isSendingImage ? null : onPickImage,
                                    isLoading: isSendingImage,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (showPostButton) ...[
                          const SizedBox(width: 8),
                          _PostActionButton(
                            label: l10n.postButton,
                            onTap: onSendComment,
                          ),
                        ],
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldIconButton extends StatelessWidget {
  const _FieldIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 42, minHeight: 46),
      icon: isLoading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: color,
              ),
            )
          : Icon(icon, size: 22, color: color),
      tooltip: null,
    );
  }
}

class _PostActionButton extends StatelessWidget {
  const _PostActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: primary,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
