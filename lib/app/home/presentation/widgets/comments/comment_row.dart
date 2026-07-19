import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/chats/presentation/utils/chat_message_mapper.dart';
import 'package:bimobondapp/app/home/presentation/widgets/comments/comment_layout_constants.dart';
import 'package:bimobondapp/app/home/presentation/widgets/comments/comment_likers_sheet.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/comments_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/comments_event.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/core/utils/comment_media.dart';
import 'package:bimobondapp/core/utils/comment_translator.dart';
import 'package:bimobondapp/core/utils/format_count.dart';
import 'package:bimobondapp/core/utils/gift_comment_l10n.dart';
import 'package:bimobondapp/core/utils/tag_parser.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/core/widgets/tagged_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CommentRow extends StatefulWidget {
  const CommentRow({
    required this.comment,
    required this.onLike,
    this.onReply,
    this.canDelete = false,
    this.onDelete,
    required this.l10n,
    this.isReply = false,
    super.key,
  });

  final CommentEntity comment;
  final bool Function() onLike;
  final VoidCallback? onReply;
  final bool canDelete;
  final VoidCallback? onDelete;
  final AppLocalizations l10n;
  final bool isReply;

  @override
  State<CommentRow> createState() => _CommentRowState();
}

class _CommentRowState extends State<CommentRow> {
  static const _likedRed = Color(0xFFFF2D55);

  bool _showTranslation = false;
  bool _isTranslating = false;
  String? _translatedText;
  String? _translationError;

  CommentEntity get comment => widget.comment;
  AppLocalizations get l10n => widget.l10n;

  @override
  void didUpdateWidget(covariant CommentRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comment.id != widget.comment.id) {
      _showTranslation = false;
      _translatedText = null;
      _translationError = null;
      _isTranslating = false;
    }
  }

  bool get _isCommentAuthor {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) return false;
    final me = authState.user;
    final myIds = {
      me.id,
      if (me.firebaseUid != null && me.firebaseUid!.isNotEmpty) me.firebaseUid!,
    };
    return myIds.contains(comment.user.id);
  }

  bool get _canTranslate {
    if (comment.isGift) return false;
    if (CommentMedia.isImageComment(comment.content)) return false;
    final text = comment.content.trim();
    if (text.isEmpty) return false;
    // Skip emoji-only quick reactions.
    final withoutEmoji = text.replaceAll(
      RegExp(
        r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}\s]',
        unicode: true,
      ),
      '',
    );
    return withoutEmoji.isNotEmpty;
  }

  Future<void> _toggleTranslation() async {
    if (_showTranslation) {
      setState(() {
        _showTranslation = false;
        _translationError = null;
      });
      return;
    }

    if (_translatedText != null) {
      setState(() {
        _showTranslation = true;
        _translationError = null;
      });
      return;
    }

    setState(() {
      _isTranslating = true;
      _translationError = null;
    });

    final targetLang = Localizations.localeOf(context).languageCode;
    final translated = await CommentTranslator.translate(
      text: comment.content,
      targetLang: targetLang,
    );

    if (!mounted) return;
    setState(() {
      _isTranslating = false;
      if (translated == null || translated.trim().isEmpty) {
        _translationError = l10n.translationFailed;
        _showTranslation = false;
      } else {
        _translatedText = translated;
        _showTranslation = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = comment.user.id;
    final onSurface = theme.colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.45);
    final actionColor = onSurface.withValues(alpha: 0.55);
    final avatarRadius = widget.isReply
        ? CommentLayout.replyAvatarRadius
        : CommentLayout.avatarRadius;
    final timeLabel = formatInboxTime(
      DateTime.tryParse(comment.createdAt),
      l10n,
    );
    final displayName = comment.user.fullName?.trim().isNotEmpty == true
        ? comment.user.fullName!.trim()
        : (comment.user.username?.trim().isNotEmpty == true
              ? comment.user.username!.trim()
              : 'user');

    void openProfile() {
      if (userId.isEmpty) return;
      openUserStoryOrProfile(
        context,
        userId: userId,
        username: comment.user.username,
        fullName: comment.user.fullName,
        avatarUrl: comment.user.avatarUrl,
      );
    }

    void toggleLike() {
      if (!widget.onLike()) return;
      context.read<CommentsBloc>().add(
        ToggleLikeCommentRequested(comment.id, liked: !comment.isLiked),
      );
    }

    void openLikers() {
      if (!_isCommentAuthor || comment.likeCount <= 0) return;
      CommentLikersSheet.show(context, commentId: comment.id);
    }

    void handleReply() {
      if (!widget.onLike()) return;
      widget.onReply?.call();
    }

    final bodyText = _showTranslation && _translatedText != null
        ? _translatedText!
        : comment.content;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StoryProfileAvatar(
          userId: userId,
          imageUrl: comment.user.avatarUrl,
          radius: avatarRadius,
          fallbackText: comment.user.fullName ?? comment.user.username ?? 'User',
          username: comment.user.username,
          fullName: comment.user.fullName,
          onTap: openProfile,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: openProfile,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              if (comment.isGift) ...[
                Builder(
                  builder: (context) {
                    final giftImage = giftCommentImageUrl(comment);
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            localizedGiftCommentText(l10n, comment),
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.35,
                              color: onSurface,
                            ),
                          ),
                        ),
                        if (giftImage != null) ...[
                          const SizedBox(width: 8),
                          SafeNetworkImage(
                            imageUrl: giftImage,
                            width: 32,
                            height: 32,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ] else if (CommentMedia.isImageComment(comment.content))
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SafeNetworkImage(
                    imageUrl: CommentMedia.parseImageUrl(comment.content)!,
                    width: 160,
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                )
              else
                TaggedText(
                  text: bodyText,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    color: onSurface,
                  ),
                  mentionUserIds: MentionRefUtils.usernameToUserIdMap(
                    comment.content,
                    comment.mentions,
                  ),
                ),
              if (_canTranslate) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _isTranslating ? null : _toggleTranslation,
                  behavior: HitTestBehavior.opaque,
                  child: _isTranslating
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.6,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : Text(
                          _showTranslation
                              ? l10n.seeOriginal
                              : (_translationError ?? l10n.seeTranslation),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _translationError != null
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                          ),
                        ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  if (timeLabel.isNotEmpty) ...[
                    Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: muted,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  GestureDetector(
                    onTap: widget.onReply != null ? handleReply : null,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      l10n.replyAction,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: actionColor,
                      ),
                    ),
                  ),
                  if (widget.canDelete && widget.onDelete != null) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: widget.onDelete,
                      behavior: HitTestBehavior.opaque,
                      child: Icon(
                        LucideIcons.trash2,
                        size: 14,
                        color: actionColor,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Column(
          children: [
            GestureDetector(
              onTap: toggleLike,
              onLongPress: openLikers,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Column(
                  children: [
                    Icon(
                      comment.isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 18,
                      color: comment.isLiked ? _likedRed : muted,
                    ),
                    if (comment.likeCount > 0) ...[
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: _isCommentAuthor ? openLikers : toggleLike,
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          formatCompactCount(comment.likeCount),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: comment.isLiked ? _likedRed : muted,
                          ),
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
  }
}
