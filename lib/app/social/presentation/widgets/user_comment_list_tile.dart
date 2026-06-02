import 'package:bimobondapp/app/chats/presentation/utils/chat_message_mapper.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_post_by_id_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart' as posts_di;
import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/user_comment_entity.dart';
import 'package:bimobondapp/core/navigation/post_navigation.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class UserCommentListTile extends StatelessWidget {
  const UserCommentListTile({
    required this.comment,
    this.authorFallback,
    super.key,
  });

  final UserCommentEntity comment;
  final SocialUserEntity? authorFallback;

  DateTime? get _createdAt {
    if (comment.createdAt.isEmpty) return null;
    return DateTime.tryParse(comment.createdAt);
  }

  SocialUserEntity? get _author {
    if (comment.user != null) return comment.user;
    if (authorFallback == null) return null;
    if (comment.userId.isNotEmpty && authorFallback!.id != comment.userId) {
      return SocialUserEntity(id: comment.userId);
    }
    return authorFallback;
  }

  Future<void> _openCommentedPost(BuildContext context) async {
    final postId = comment.postId.trim();
    if (postId.isEmpty) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await posts_di.sl<GetPostByIdUseCase>()(postId);

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    result.fold(
      (failure) => PopupDialogs.showErrorDialog(context, failure.message),
      (post) => openPost(context, post),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final author = _author;
    final authorName =
        author?.displayName ?? l10n.messagesInboxUserFallback;
    final time = formatInboxTime(_createdAt, l10n);

    return InkWell(
      onTap: () => _openCommentedPost(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.p16,
          vertical: AppSizes.p12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SafeNetworkAvatar(
              imageUrl: author?.avatarUrl,
              radius: 22,
              fallbackText: authorName,
            ),
            const SizedBox(width: AppSizes.p12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.3,
                            ),
                            children: [
                              TextSpan(
                                text: authorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text: ' ${l10n.userCommentAction}',
                                style: TextStyle(
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withValues(alpha: 0.75),
                                ),
                              ),
                              if (comment.isReply)
                                TextSpan(
                                  text: ' · ${l10n.userCommentReplyLabel}',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (time.isNotEmpty) ...[
                        const SizedBox(width: AppSizes.p8),
                        Text(
                          time,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment.content,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
