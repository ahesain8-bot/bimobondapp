import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_sheets.dart';
import 'package:bimobondapp/app/home/presentation/widgets/comments/comment_layout_constants.dart';
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

  Color _fieldFill(Brightness brightness, ColorScheme scheme) {
    if (brightness == Brightness.light) {
      return CommentLayout.composerFieldFillLight;
    }
    return scheme.surfaceContainerHighest;
  }

  Color _hintColor(Brightness brightness, ColorScheme scheme) {
    if (brightness == Brightness.light) {
      return CommentLayout.composerHintLight;
    }
    return scheme.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brightness = theme.brightness;
    final fieldFill = _fieldFill(brightness, scheme);
    final hintColor = _hintColor(brightness, scheme);
    final onSurface = scheme.onSurface;
    final iconColor = brightness == Brightness.light
        ? CommentLayout.composerHintLight
        : scheme.onSurfaceVariant;
    final footerDivider = brightness == Brightness.light
        ? CommentLayout.composerFooterDividerLight
        : onSurface.withValues(alpha: 0.08);

    final textStyle = TextStyle(
      fontSize: CommentLayout.composerFontSize,
      height: 1.2,
      color: onSurface,
      fontWeight: FontWeight.w400,
    );

    return Material(
      color: scheme.surface,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: footerDivider, width: 0.5)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSizes.p16,
            AppSizes.p8,
            AppSizes.p16,
            bottomPadding + AppSizes.p8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (replyingToUsername != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.p8),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.reply,
                        size: 16,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: CustomText(
                          l10n.replyingTo(replyingToUsername!),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                      ),
                      GestureDetector(
                        onTap: onClearReplyingTo,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(LucideIcons.x, size: 18, color: iconColor),
                        ),
                      ),
                    ],
                  ),
                ),
              QuickCommentReactions(onReactionSelected: onQuickReaction),
              const SizedBox(height: AppSizes.p8),
              MentionComposerField(
                controller: commentController,
                focusNode: commentFocusNode,
                maxLines: 5,
                minLines: 1,
                style: textStyle,
                decoration: InputDecoration(
                  hintText: replyingToUsername != null
                      ? l10n.replyingTo(replyingToUsername!)
                      : l10n.addCommentHint,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintStyle: TextStyle(
                    fontSize: CommentLayout.composerFontSize,
                    height: 1.2,
                    color: hintColor,
                    fontWeight: FontWeight.w400,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
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
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (inputAvatar != null)
                            Padding(
                              padding:
                                  const EdgeInsetsDirectional.only(end: 10),
                              child: inputAvatar,
                            ),
                          Expanded(
                            child: Container(
                              constraints: const BoxConstraints(
                                minHeight: CommentLayout.composerFieldMinHeight,
                              ),
                              decoration: BoxDecoration(
                                color: fieldFill,
                                borderRadius: BorderRadius.circular(
                                  CommentLayout.composerFieldRadius,
                                ),
                              ),
                              padding: const EdgeInsetsDirectional.only(
                                start: 14,
                                end: 2,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minHeight:
                                            CommentLayout.composerFieldMinHeight,
                                      ),
                                      child: Align(
                                        alignment:
                                            AlignmentDirectional.centerStart,
                                        child: textField,
                                      ),
                                    ),
                                  ),
                                  if (!showPostButton) ...[
                                    _FieldIconButton(
                                      icon: LucideIcons.atSign,
                                      color: iconColor,
                                      onTap: _insertMentionTrigger,
                                    ),
                                    _FieldIconButton(
                                      icon: LucideIcons.smile,
                                      color: iconColor,
                                      onTap: () => _openEmojiPicker(context),
                                    ),
                                    if (onPickImage != null)
                                      _FieldIconButton(
                                        icon: LucideIcons.image,
                                        color: iconColor,
                                        onTap:
                                            isSendingImage ? null : onPickImage,
                                        isLoading: isSendingImage,
                                      ),
                                  ],
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
      constraints: const BoxConstraints(
        minWidth: 34,
        minHeight: CommentLayout.composerFieldMinHeight,
      ),
      icon: isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 1.8, color: color),
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
      borderRadius: BorderRadius.circular(CommentLayout.composerFieldRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CommentLayout.composerFieldRadius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: CommentLayout.composerFieldMinHeight,
            minWidth: 64,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
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
