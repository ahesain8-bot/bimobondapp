import 'package:bimobondapp/app/home/presentation/widgets/comments/quick_comment_reactions.dart';
import 'package:bimobondapp/app/social/presentation/widgets/mention_composer_field.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_surface.dart';
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
    required this.inputAvatar,
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
  final Widget inputAvatar;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const hintColor = Color(0x73FFFFFF);
    const textColor = Colors.white;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSizes.p16,
        AppSizes.p16,
        AppSizes.p16,
        bottomPadding + AppSizes.p20,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
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
                    child: Icon(
                      LucideIcons.x,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.6),
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
            style: const TextStyle(fontSize: 15, color: textColor),
            decoration: InputDecoration(
              hintText: replyingToUsername != null
                  ? l10n.replyingTo(replyingToUsername!)
                  : l10n.addCommentHint,
              border: InputBorder.none,
              hintStyle: const TextStyle(fontSize: 15, color: hintColor),
              contentPadding: const EdgeInsets.symmetric(
                vertical: AppSizes.p10,
              ),
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
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: 10,
                          bottom: 4,
                        ),
                        child: inputAvatar,
                      ),
                      Expanded(
                        child: LiquidGlassSurface(
                          borderRadius: BorderRadius.circular(AppSizes.p24),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const SizedBox(width: AppSizes.p12),
                              Expanded(child: textField),
                              if (showPostButton)
                                IconButton(
                                  icon: const Icon(
                                    LucideIcons.send,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                  onPressed: onSendComment,
                                )
                              else
                                const SizedBox(width: AppSizes.p12),
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
