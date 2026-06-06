import 'package:bimobondapp/app/home/presentation/widgets/comments/comment_layout_constants.dart';
import 'package:bimobondapp/app/home/presentation/widgets/comments/comment_row.dart';
import 'package:bimobondapp/app/home/presentation/widgets/comments/comment_skeleton.dart';
import 'package:bimobondapp/app/home/presentation/widgets/comments/comment_thread_branch.dart';
import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/comments_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/comments_event.dart';
import 'package:bimobondapp/app/posts/presentation/utils/comment_thread_utils.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CommentItem extends StatefulWidget {
  const CommentItem({
    required this.comment,
    required this.replies,
    required this.hasMoreReplies,
    required this.isExpanded,
    required this.canDelete,
    required this.onDelete,
    required this.onLike,
    required this.onReply,
    required this.onToggleReplies,
    required this.onLoadMoreReplies,
    required this.l10n,
    super.key,
  });

  final CommentEntity comment;
  final List<CommentEntity> replies;
  final bool hasMoreReplies;
  final bool isExpanded;
  final bool Function(CommentEntity comment) canDelete;
  final void Function(CommentEntity comment, {String? parentId}) onDelete;
  final bool Function() onLike;
  final void Function(CommentEntity comment, {String? threadRootId}) onReply;
  final VoidCallback onToggleReplies;
  final VoidCallback onLoadMoreReplies;
  final AppLocalizations l10n;

  @override
  State<CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<CommentItem> {
  bool _isLoadingReplies = false;
  bool _isLoadingMoreReplies = false;

  List<CommentEntity> get _sortedReplies =>
      sortCommentsOldestFirst(widget.replies);

  @override
  void didUpdateWidget(covariant CommentItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isLoadingReplies &&
        (widget.replies != oldWidget.replies || !widget.isExpanded)) {
      _isLoadingReplies = false;
    }
    if (_isLoadingMoreReplies &&
        (!widget.hasMoreReplies ||
            widget.replies.length != oldWidget.replies.length)) {
      _isLoadingMoreReplies = false;
    }
  }

  void _handleLoadMoreReplies() {
    setState(() => _isLoadingMoreReplies = true);
    widget.onLoadMoreReplies();
  }

  void _toggleReplies() {
    if (!widget.isExpanded &&
        widget.replies.isEmpty &&
        widget.comment.replyCount > 0) {
      setState(() => _isLoadingReplies = true);
      context.read<CommentsBloc>().add(
        FetchRepliesRequested(commentId: widget.comment.id),
      );
    }
    widget.onToggleReplies();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comment = widget.comment;
    final l10n = widget.l10n;

    final replyToggleColor = theme.colorScheme.onSurface.withValues(
      alpha: 0.45,
    );
    final hasReplies = comment.replyCount > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.p20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommentRow(
            comment: comment,
            onLike: widget.onLike,
            onReply: () => widget.onReply(comment),
            canDelete: widget.canDelete(comment),
            onDelete: () => widget.onDelete(comment),
            l10n: l10n,
          ),
          if (hasReplies && !widget.isExpanded)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: CommentLayout.avatarSize + 10,
                top: AppSizes.p4,
              ),
              child: GestureDetector(
                onTap: _toggleReplies,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  l10n.viewReplies(comment.replyCount),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: replyToggleColor,
                  ),
                ),
              ),
            ),
          if (widget.isExpanded) ...[
            if (_isLoadingReplies && widget.replies.isEmpty)
              const CommentRepliesSkeleton(itemCount: 2)
            else if (widget.replies.isNotEmpty)
              ...List.generate(_sortedReplies.length, (index) {
                final reply = _sortedReplies[index];
                final isLast =
                    index == _sortedReplies.length - 1 &&
                    !widget.hasMoreReplies;
                return CommentThreadBranch(
                  isLast: isLast,
                  lineColor: theme.dividerColor.withValues(alpha: 0.45),
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSizes.p12),
                    child: CommentRow(
                      comment: reply,
                      onLike: widget.onLike,
                      onReply: () => widget.onReply(
                        reply,
                        threadRootId: widget.comment.id,
                      ),
                      canDelete: widget.canDelete(reply),
                      onDelete: () =>
                          widget.onDelete(reply, parentId: widget.comment.id),
                      l10n: l10n,
                      isReply: true,
                    ),
                  ),
                );
              }),
            if (widget.isExpanded && hasReplies)
              Padding(
                padding: EdgeInsetsDirectional.only(
                  start: CommentLayout.avatarSize + 10,
                  top: AppSizes.p4,
                ),
                child: GestureDetector(
                  onTap: _toggleReplies,
                  child: Text(
                    l10n.hideReplies,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: replyToggleColor,
                    ),
                  ),
                ),
              ),
            if (_isLoadingMoreReplies)
              const CommentRepliesSkeleton(itemCount: 1),
            if (widget.hasMoreReplies &&
                !_isLoadingMoreReplies &&
                !_isLoadingReplies &&
                widget.replies.isNotEmpty)
              Padding(
                padding: EdgeInsetsDirectional.only(
                  start: CommentLayout.threadIndent + 24,
                  top: AppSizes.p4,
                ),
                child: GestureDetector(
                  onTap: _handleLoadMoreReplies,
                  child: Text(
                    l10n.loadMoreReplies,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: replyToggleColor,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
