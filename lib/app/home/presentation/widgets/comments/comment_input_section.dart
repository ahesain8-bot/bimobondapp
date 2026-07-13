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
    this.inputAvatar,
    super.key,
  });

  final double bottomPadding;
  final String? replyingToUsername;
  final VoidCallback onClearReplyingTo;
  final ValueChanged<String> onQuickReaction;
  final TextEditingController commentController;
  final FocusNode commentFocusNode;
  final VoidCallback onSendComment;
  final bool showPostButton;
  final Widget? inputAvatar;

  void _insertMentionTrigger() {
    final text = commentController.text;
    final selection = commentController.selection;
    final cursor = selection.isValid ? selection.baseOffset : text.length;
    final needsSpace = cursor > 0 && text[cursor - 1] != ' ' && text[cursor - 1] != '\n';
    final insert = needsSpace ? ' @' : '@';
    final newText = text.replaceRange(cursor, cursor, insert);
    final newOffset = cursor + insert.length;
    commentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    commentFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.4);
    final fieldFill = theme.colorScheme.surfaceContainerHighest
        .withValues(alpha: 0.55);
    final borderColor = onSurface.withValues(alpha: 0.06);

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSizes.p12,
        AppSizes.p8,
        AppSizes.p12,
        bottomPadding + AppSizes.p10,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: borderColor)),
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
                  Expanded(
                    child: CustomText(
                      l10n.replyingTo(replyingToUsername!),
                      fontSize: 13,
                      variant: TextVariant.secondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: onClearReplyingTo,
                    child: Icon(LucideIcons.x, size: 18, color: muted),
                  ),
                ],
              ),
            ),
          QuickCommentReactions(onReactionSelected: onQuickReaction),
          const SizedBox(height: AppSizes.p10),
          MentionComposerField(
            controller: commentController,
            focusNode: commentFocusNode,
            maxLines: 5,
            minLines: 1,
            style: TextStyle(fontSize: 15, color: onSurface),
            decoration: InputDecoration(
              hintText: replyingToUsername != null
                  ? l10n.replyingTo(replyingToUsername!)
                  : l10n.addCommentHint,
              border: InputBorder.none,
              hintStyle: TextStyle(fontSize: 15, color: muted),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                            end: 8,
                            bottom: 2,
                          ),
                          child: inputAvatar,
                        ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: fieldFill,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          padding: const EdgeInsetsDirectional.only(start: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(child: textField),
                              if (showPostButton)
                                IconButton(
                                  onPressed: onSendComment,
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(
                                    LucideIcons.send,
                                    size: 20,
                                    color: theme.colorScheme.primary,
                                  ),
                                )
                              else ...[
                                IconButton(
                                  onPressed: _insertMentionTrigger,
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 40,
                                  ),
                                  icon: Icon(
                                    LucideIcons.atSign,
                                    size: 20,
                                    color: muted,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    commentFocusNode.requestFocus();
                                  },
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 40,
                                  ),
                                  icon: Icon(
                                    LucideIcons.smile,
                                    size: 20,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
