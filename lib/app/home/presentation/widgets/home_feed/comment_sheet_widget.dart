import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/comments_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/comments_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/comments_state.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/core/navigation/user_profile_navigation.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/gift_comment_l10n.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart'
    as di;

class CommentSheetWidget extends StatefulWidget {
  final String postId;
  final String postOwnerId;

  const CommentSheetWidget({
    super.key,
    required this.postId,
    required this.postOwnerId,
  });

  @override
  State<CommentSheetWidget> createState() => _CommentSheetWidgetState();
}

class _CommentSheetWidgetState extends State<CommentSheetWidget> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  late final CommentsBloc _commentsBloc;
  bool _showPostButton = false;
  CommentsLoadSuccess? _lastLoadedState;
  int _commentsPage = 1;
  bool _isLoadingMoreComments = false;
  final ScrollController _commentsScrollController = ScrollController();
  String? _replyingToCommentId;
  String? _replyingToUsername;
  final Set<String> _expandedReplyIds = {};

  @override
  void initState() {
    super.initState();
    _commentsBloc = di.sl<CommentsBloc>();
    _commentsBloc.add(
      FetchCommentsRequested(postId: widget.postId, isRefresh: true),
    );
    _commentController.addListener(_onCommentChanged);
    _commentsScrollController.addListener(_onCommentsScroll);
  }

  void _onCommentsScroll() {
    if (!_commentsScrollController.hasClients) return;
    final loaded = _lastLoadedState;
    if (loaded == null || loaded.hasReachedMax || _isLoadingMoreComments) {
      return;
    }
    final position = _commentsScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 120) {
      _loadMoreComments();
    }
  }

  void _loadMoreComments() {
    if (_isLoadingMoreComments || (_lastLoadedState?.hasReachedMax ?? true)) {
      return;
    }
    setState(() => _isLoadingMoreComments = true);
    _commentsPage++;
    _commentsBloc.add(
      FetchCommentsRequested(postId: widget.postId, page: _commentsPage),
    );
  }

  void _onCommentChanged() {
    final isNotEmpty = _commentController.text.trim().isNotEmpty;
    if (isNotEmpty != _showPostButton) {
      setState(() {
        _showPostButton = isNotEmpty;
      });
    }
  }

  @override
  void dispose() {
    _commentController.removeListener(_onCommentChanged);
    _commentsScrollController.removeListener(_onCommentsScroll);
    _commentController.dispose();
    _commentFocusNode.dispose();
    _commentsScrollController.dispose();
    super.dispose();
  }

  void _clearReplyingTo() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToUsername = null;
    });
  }

  void _startReply(CommentEntity comment) {
    if (!_checkAuth()) return;
    setState(() {
      _replyingToCommentId = comment.id;
      _replyingToUsername = comment.user.username ?? 'user';
      _expandedReplyIds.add(comment.id);
    });
    final replies = _lastLoadedState?.repliesByParentId[comment.id] ?? const [];
    if (replies.isEmpty && comment.replyCount > 0) {
      _commentsBloc.add(FetchRepliesRequested(commentId: comment.id));
    }
    _commentFocusNode.requestFocus();
  }

  void _onSendComment() {
    if (!_checkAuth()) return;
    final content = _commentController.text.trim();
    if (content.isNotEmpty) {
      _commentsBloc.add(
        AddCommentRequested(
          postId: widget.postId,
          content: content,
          parentId: _replyingToCommentId,
        ),
      );
      _commentController.clear();
      _clearReplyingTo();
      FocusScope.of(context).unfocus();
    }
  }

  String? get _currentUserId {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) return authState.user.id;
    return null;
  }

  bool _canDelete(CommentEntity comment) {
    final userId = _currentUserId;
    if (userId == null) return false;
    return comment.user.id == userId || widget.postOwnerId == userId;
  }

  void _confirmDelete(CommentEntity comment, {String? parentId}) {
    final l10n = AppLocalizations.of(context)!;
    PopupDialogs.showConfirmDialog(
      context,
      title: l10n.deleteCommentTitle,
      message: l10n.deleteCommentMessage,
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.deleteAction,
      destructive: true,
      onConfirm: () {
        if (parentId == null) {
          _expandedReplyIds.remove(comment.id);
        }
        _commentsBloc.add(
          DeleteCommentRequested(comment.id, parentId: parentId),
        );
      },
    );
  }

  bool _checkAuth() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) {
      return true;
    }

    final l10n = AppLocalizations.of(context)!;
    PopupDialogs.showConfirmDialog(
      context,
      title: l10n.loginRequired,
      message: l10n.loginRequiredMessage,
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.login,
      onConfirm: () => context.pushNamed('login'),
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return BlocProvider.value(
      value: _commentsBloc,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSizes.p16),
          ),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.p16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomText(
                    l10n.commentsTitle,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  // PositionedDirectional(
                  //   end: 22,
                  //   child: IconButton(
                  //     icon: const Icon(LucideIcons.x, size: 20),
                  //     onPressed: () => Navigator.pop(context),
                  //   ),
                  // ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Comments List
            Expanded(
              child: BlocConsumer<CommentsBloc, CommentsState>(
                listenWhen: (previous, current) =>
                    current is AddCommentSuccess ||
                    current is CommentsFailure ||
                    current is CommentsLoadSuccess,
                listener: (context, state) {
                  if (state is CommentsLoadSuccess) {
                    setState(() {
                      _lastLoadedState = state;
                      _isLoadingMoreComments = false;
                    });
                  } else if (state is AddCommentSuccess) {
                    if (state.comment.parentId == null) {
                      _commentsPage = 1;
                      _commentsBloc.add(
                        FetchCommentsRequested(
                          postId: widget.postId,
                          isRefresh: true,
                        ),
                      );
                    }
                  }
                },
                buildWhen: (previous, current) =>
                    current is CommentsLoading ||
                    current is CommentsLoadSuccess ||
                    current is CommentsFailure,
                builder: (context, state) {
                  final displayState =
                      state is CommentsLoading && _lastLoadedState != null
                      ? _lastLoadedState!
                      : state;

                  if (displayState is CommentsLoading) {
                    return ListView.builder(
                      itemCount: 8,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.p16,
                        vertical: AppSizes.p12,
                      ),
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SkeletonWidget.circular(size: 32),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SkeletonWidget(
                                      height: 12,
                                      width: 100,
                                    ),
                                    const SizedBox(height: 8),
                                    const SkeletonWidget(
                                      height: 14,
                                      width: double.infinity,
                                    ),
                                    const SizedBox(height: 4),
                                    const SkeletonWidget(
                                      height: 14,
                                      width: 200,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: const [
                                        SkeletonWidget(height: 12, width: 60),
                                        SizedBox(width: 24),
                                        SkeletonWidget(height: 12, width: 40),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              const SkeletonWidget(height: 30, width: 24),
                            ],
                          ),
                        );
                      },
                    );
                  }
                  if (displayState is CommentsLoadSuccess) {
                    if (displayState.comments.isEmpty) {
                      return Center(child: CustomText(l10n.noCommentsYet));
                    }
                    final showLoadMoreFooter =
                        _isLoadingMoreComments && !displayState.hasReachedMax;

                    return ListView.builder(
                      controller: _commentsScrollController,
                      itemCount:
                          displayState.comments.length +
                          (showLoadMoreFooter ? 1 : 0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.p16,
                        vertical: AppSizes.p12,
                      ),
                      itemBuilder: (context, index) {
                        if (showLoadMoreFooter &&
                            index == displayState.comments.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }

                        final comment = displayState.comments[index];
                        return _CommentItem(
                          comment: comment,
                          replies:
                              displayState.repliesByParentId[comment.id] ??
                              const [],
                          hasMoreReplies:
                              !(displayState
                                      .repliesHasReachedMaxByParentId[comment
                                      .id] ??
                                  false),
                          isExpanded: _expandedReplyIds.contains(comment.id),
                          canDelete: _canDelete,
                          onDelete: _confirmDelete,
                          onLike: _checkAuth,
                          onReply: _startReply,
                          onToggleReplies: () {
                            setState(() {
                              if (_expandedReplyIds.contains(comment.id)) {
                                _expandedReplyIds.remove(comment.id);
                              } else {
                                _expandedReplyIds.add(comment.id);
                              }
                            });
                          },
                          onLoadMoreReplies: () {
                            final loaded =
                                displayState.repliesByParentId[comment.id] ??
                                const [];
                            final nextPage = (loaded.length / 20).ceil() + 1;
                            _commentsBloc.add(
                              FetchRepliesRequested(
                                commentId: comment.id,
                                page: nextPage,
                              ),
                            );
                          },
                          l10n: l10n,
                        );
                      },
                    );
                  }
                  if (displayState is CommentsFailure) {
                    return Center(
                      child: CustomText(
                        displayState.message,
                        color: Colors.red,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),

            // Input Area
            Container(
              padding: EdgeInsets.fromLTRB(
                AppSizes.p16,
                AppSizes.p16,
                AppSizes.p16,
                bottomPadding + AppSizes.p20,
              ),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(color: theme.dividerColor, width: 0.5),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_replyingToUsername != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.p8),
                      child: Row(
                        children: [
                          Expanded(
                            child: CustomText(
                              l10n.replyingTo(_replyingToUsername!),
                              fontSize: 13,
                              variant: TextVariant.secondary,
                            ),
                          ),
                          GestureDetector(
                            onTap: _clearReplyingTo,
                            child: Icon(
                              LucideIcons.x,
                              size: 18,
                              color: theme.iconTheme.color?.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant.withOpacity(
                              0.5,
                            ),
                            borderRadius: BorderRadius.circular(AppSizes.p20),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const SizedBox(width: AppSizes.p12),
                              Expanded(
                                child: TextField(
                                  controller: _commentController,
                                  focusNode: _commentFocusNode,
                                  maxLines: 5,
                                  minLines: 1,
                                  style: const TextStyle(fontSize: 15),
                                  decoration: InputDecoration(
                                    hintText: _replyingToUsername != null
                                        ? l10n.replyingTo(_replyingToUsername!)
                                        : l10n.addCommentHint,
                                    border: InputBorder.none,
                                    hintStyle: const TextStyle(fontSize: 15),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: AppSizes.p10,
                                    ),
                                  ),
                                ),
                              ),
                              if (_showPostButton)
                                IconButton(
                                  icon: Icon(
                                    LucideIcons.send,
                                    size: 20,
                                    color: theme.primaryColor,
                                  ),
                                  onPressed: _onSendComment,
                                )
                              else ...[
                                IconButton(
                                  icon: Icon(
                                    LucideIcons.atSign,
                                    size: 20,
                                    color: theme.iconTheme.color?.withOpacity(
                                      0.6,
                                    ),
                                  ),
                                  onPressed: () {},
                                ),
                                IconButton(
                                  icon: Icon(
                                    LucideIcons.smile,
                                    size: 20,
                                    color: theme.iconTheme.color?.withOpacity(
                                      0.6,
                                    ),
                                  ),
                                  onPressed: () {},
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
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

class _CommentItem extends StatefulWidget {
  final CommentEntity comment;
  final List<CommentEntity> replies;
  final bool hasMoreReplies;
  final bool isExpanded;
  final bool Function(CommentEntity comment) canDelete;
  final void Function(CommentEntity comment, {String? parentId}) onDelete;
  final bool Function() onLike;
  final void Function(CommentEntity comment) onReply;
  final VoidCallback onToggleReplies;
  final VoidCallback onLoadMoreReplies;
  final AppLocalizations l10n;

  const _CommentItem({
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
  });

  @override
  State<_CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<_CommentItem> {
  static const double _contentInset = 44;
  static const EdgeInsets _repliesSectionPadding = EdgeInsets.only(
    left: _contentInset,
    top: 4,
    right: AppSizes.p24,
  );
  static const EdgeInsets _repliesListPadding = EdgeInsets.only(
    left: AppSizes.p12,
    top: AppSizes.p8,
    bottom: AppSizes.p4,
    right: AppSizes.p4,
  );

  bool _isLoadingReplies = false;

  @override
  void didUpdateWidget(covariant _CommentItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isLoadingReplies &&
        (widget.replies != oldWidget.replies || !widget.isExpanded)) {
      _isLoadingReplies = false;
    }
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

    final replyToggleColor = theme.textTheme.bodyMedium?.color?.withOpacity(
      0.6,
    );
    final hasReplies = comment.replyCount > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.p16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentRow(
            comment: comment,
            onLike: widget.onLike,
            onReply: () => widget.onReply(comment),
            canDelete: widget.canDelete(comment),
            onDelete: () => widget.onDelete(comment),
            l10n: l10n,
          ),
          if (hasReplies || widget.isExpanded)
            Padding(
              padding: _repliesSectionPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasReplies)
                    GestureDetector(
                      onTap: _toggleReplies,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: AppSizes.p12,
                          top: AppSizes.p4,
                          bottom: AppSizes.p4,
                        ),
                        child: CustomText(
                          widget.isExpanded
                              ? l10n.hideReplies
                              : l10n.viewReplies(comment.replyCount),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: replyToggleColor,
                        ),
                      ),
                    ),
                  if (widget.isExpanded) ...[
                    if (_isLoadingReplies && widget.replies.isEmpty)
                      Padding(
                        padding: _repliesListPadding,
                        child: const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (widget.replies.isNotEmpty)
                      Padding(
                        padding: _repliesListPadding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ...widget.replies.map(
                              (reply) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSizes.p12,
                                ),
                                child: _CommentRow(
                                  comment: reply,
                                  onLike: widget.onLike,
                                  canDelete: widget.canDelete(reply),
                                  onDelete: () => widget.onDelete(
                                    reply,
                                    parentId: widget.comment.id,
                                  ),
                                  l10n: l10n,
                                  isReply: true,
                                ),
                              ),
                            ),
                            if (widget.hasMoreReplies)
                              GestureDetector(
                                onTap: widget.onLoadMoreReplies,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppSizes.p4,
                                    bottom: AppSizes.p8,
                                  ),
                                  child: CustomText(
                                    l10n.loadMoreReplies,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: replyToggleColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  final CommentEntity comment;
  final bool Function() onLike;
  final VoidCallback? onReply;
  final bool canDelete;
  final VoidCallback? onDelete;
  final AppLocalizations l10n;
  final bool isReply;

  const _CommentRow({
    required this.comment,
    required this.onLike,
    this.onReply,
    this.canDelete = false,
    this.onDelete,
    required this.l10n,
    this.isReply = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = comment.user.id;

    void openProfile() {
      if (userId.isEmpty) return;
      openUserProfile(
        context,
        userId: userId,
        username: comment.user.username,
        fullName: comment.user.fullName,
        avatarUrl: comment.user.avatarUrl,
      );
    }

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: openProfile,
          child: SafeNetworkAvatar(
            imageUrl: comment.user.avatarUrl,
            radius: isReply ? 14 : 16,
            fallbackText: comment.user.username,
          ),
        ),
        const SizedBox(width: AppSizes.p8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: openProfile,
                child: CustomText(
                  comment.user.username ?? 'user',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 4),
              CustomText(
                comment.isGift
                    ? localizedGiftCommentText(l10n, comment)
                    : comment.content,
                fontSize: 15,
              ),
              if (!isReply) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    CustomText(
                      l10n.justNow,
                      fontSize: 13,
                      variant: TextVariant.secondary,
                    ),
                    const SizedBox(width: 24),
                    GestureDetector(
                      onTap: () {
                        if (onLike()) {
                          onReply?.call();
                        }
                      },
                      child: CustomText(
                        l10n.replyAction,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(
                          0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                if (onLike()) {
                  context.read<CommentsBloc>().add(
                    ToggleLikeCommentRequested(
                      comment.id,
                      liked: !comment.isLiked,
                    ),
                  );
                }
              },
              child: Column(
                children: [
                  Icon(
                    comment.isLiked ? Icons.favorite : LucideIcons.heart,
                    size: 16,
                    color: comment.isLiked
                        ? Colors.red
                        : theme.iconTheme.color?.withOpacity(0.5),
                  ),
                  const SizedBox(height: 2),
                  CustomText(
                    comment.likeCount.toString(),
                    fontSize: 11,
                    variant: TextVariant.secondary,
                  ),
                ],
              ),
            ),
            if (canDelete && onDelete != null) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onDelete,
                child: Icon(
                  LucideIcons.trash2,
                  size: 16,
                  color: theme.iconTheme.color?.withOpacity(0.45),
                ),
              ),
            ],
          ],
        ),
      ],
    );

    if (!isReply) return row;

    return Padding(
      padding: const EdgeInsets.only(left: AppSizes.p4),
      child: row,
    );
  }
}
