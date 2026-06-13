import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/home/presentation/widgets/comments/comment_input_section.dart';
import 'package:bimobondapp/app/home/presentation/widgets/comments/comment_item.dart';
import 'package:bimobondapp/app/home/presentation/widgets/comments/comment_skeleton.dart';
import 'package:bimobondapp/app/home/presentation/widgets/comments/engagement_sheet_header.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/post_engagement_users_tab.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/comments_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/comments_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/comments_state.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart'
    as di;
import 'package:bimobondapp/app/posts/presentation/utils/comment_thread_utils.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/tag_text_editing.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_surface.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class CommentSheetWidget extends StatefulWidget {
  final String postId;
  final String postOwnerId;
  final int postLikeCount;
  final int postCommentCount;
  final int postViewCount;
  final bool isPostOwner;
  final int initialTabIndex;

  const CommentSheetWidget({
    super.key,
    required this.postId,
    required this.postOwnerId,
    this.postLikeCount = 0,
    this.postCommentCount = 0,
    this.postViewCount = 0,
    this.isPostOwner = false,
    this.initialTabIndex = 1,
  });

  int get _tabCount => isPostOwner ? 3 : 1;

  /// Tab index for comments when the post owner sees Likes / Comments / Views.
  static const int ownerCommentsTabIndex = 1;

  /// Tab index for views when the post owner sees Likes / Comments / Views.
  static const int ownerViewsTabIndex = 2;

  /// Tab index for likes when the post owner sees Likes / Comments / Views.
  static const int ownerLikesTabIndex = 0;

  /// Engagement sheet: owner sees Likes / Comments / Views; others Comments only.
  static Future<void> show(
    BuildContext context, {
    required String postId,
    required String postOwnerId,
    required int likeCount,
    required int commentCount,
    required int viewCount,
    required bool isPostOwner,
    int initialTabIndex = 1,
  }) {
    final maxIndex = isPostOwner ? 2 : 0;
    return GlassBottomSheet.showDraggable<void>(
      context,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      adaptTheme: true,
      builder: (context, scrollController) => CommentSheetWidget(
        postId: postId,
        postOwnerId: postOwnerId,
        postLikeCount: likeCount,
        postCommentCount: commentCount,
        postViewCount: viewCount,
        isPostOwner: isPostOwner,
        initialTabIndex: initialTabIndex.clamp(0, maxIndex),
      ),
    );
  }

  @override
  State<CommentSheetWidget> createState() => _CommentSheetWidgetState();
}

class _CommentSheetWidgetState extends State<CommentSheetWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  late final CommentsBloc _commentsBloc;
  bool _showPostButton = false;
  CommentsLoadSuccess? _lastLoadedState;
  int _commentsPage = 1;
  bool _isLoadingMoreComments = false;
  final ScrollController _commentsScrollController = ScrollController();
  String? _replyingToCommentId;
  String? _replyingToThreadRootId;
  String? _replyingToUsername;
  final Set<String> _expandedReplyIds = {};
  late int _headerCommentCount;
  String _commentSort = 'newest';

  void _applyCommentSort(String sort) {
    if (_commentSort == sort) return;
    setState(() {
      _commentSort = sort;
      _commentsPage = 1;
      _lastLoadedState = null;
    });
    _commentsBloc.add(
      FetchCommentsRequested(
        postId: widget.postId,
        isRefresh: true,
        sort: sort,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget._tabCount,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _headerCommentCount = widget.postCommentCount;
    _commentsBloc = di.sl<CommentsBloc>();
    _commentsBloc.add(
      FetchCommentsRequested(
        postId: widget.postId,
        isRefresh: true,
        sort: _commentSort,
      ),
    );
    _tabController.addListener(_onTabIndexChanged);
    _commentController.addListener(_onCommentChanged);
    _commentsScrollController.addListener(_onCommentsScroll);
  }

  void _onTabIndexChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {});
  }

  bool get _showCommentSort =>
      !widget.isPostOwner ||
      _tabController.index == CommentSheetWidget.ownerCommentsTabIndex;

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
      FetchCommentsRequested(
        postId: widget.postId,
        page: _commentsPage,
        sort: _commentSort,
      ),
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
    _tabController.removeListener(_onTabIndexChanged);
    _tabController.dispose();
    _commentsScrollController.removeListener(_onCommentsScroll);
    _commentController.dispose();
    _commentFocusNode.dispose();
    _commentsScrollController.dispose();
    super.dispose();
  }

  void _clearReplyingTo() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToThreadRootId = null;
      _replyingToUsername = null;
    });
  }

  void _startReply(CommentEntity comment, {String? threadRootId}) {
    if (!_checkAuth()) return;
    final rootId = threadRootId ?? comment.id;
    final isReplyToReply = comment.id != rootId;

    setState(() {
      _replyingToCommentId = comment.id;
      _replyingToThreadRootId = rootId;
      _replyingToUsername = comment.user.username ?? 'user';
      _expandedReplyIds.add(rootId);
    });

    final replies = _lastLoadedState?.repliesByParentId[rootId] ?? const [];
    if (replies.isEmpty && comment.replyCount > 0) {
      _commentsBloc.add(FetchRepliesRequested(commentId: rootId));
    } else if (isReplyToReply && replies.isEmpty) {
      _commentsBloc.add(FetchRepliesRequested(commentId: rootId));
    }

    _commentController.clear();
    if (isReplyToReply) {
      final username = comment.user.username?.trim();
      if (username != null && username.isNotEmpty) {
        TagTextEditing.insertMention(_commentController, username);
      }
    }

    _commentFocusNode.requestFocus();
  }

  void _postComment(String content) {
    if (!_checkAuth()) return;
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    _commentsBloc.add(
      AddCommentRequested(
        postId: widget.postId,
        content: trimmed,
        parentId: _replyingToCommentId,
        threadRootId: _replyingToThreadRootId,
      ),
    );
    _commentController.clear();
    _clearReplyingTo();
    FocusScope.of(context).unfocus();
  }

  void _onSendComment() => _postComment(_commentController.text);

  void _onQuickReaction(String emoji) => _postComment(emoji);

  String? get _currentUserId {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) return authState.user.id;
    return null;
  }

  Widget _buildCommentInputAvatar() {
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthSuccess) {
      return const LiquidGlassSkeletonBox.circular(
        size: 40,
        tone: LiquidGlassSkeletonTone.light,
      );
    }

    final user = authState.user;
    return StoryProfileAvatar(
      userId: user.id,
      imageUrl: user.avatarUrl,
      radius: 20,
      fallbackText: user.username ?? user.fullName ?? 'User',
      username: user.username,
      fullName: user.fullName,
    );
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
    final l10n = AppLocalizations.of(context)!;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return BlocProvider.value(
      value: _commentsBloc,
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            EngagementSheetHeader(
              tabController: _tabController,
              isPostOwner: widget.isPostOwner,
              showCommentSort: _showCommentSort,
              likeCount: widget.postLikeCount,
              commentCount: _headerCommentCount,
              viewCount: widget.postViewCount,
              commentSort: _commentSort,
              onCommentSortChanged: _applyCommentSort,
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  if (widget.isPostOwner)
                    PostEngagementUsersTab(
                      postId: widget.postId,
                      kind: PostEngagementUserListKind.likes,
                    ),
                  Column(
                    children: [
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
                                setState(() => _headerCommentCount++);
                                _commentsPage = 1;
                                _commentsBloc.add(
                                  FetchCommentsRequested(
                                    postId: widget.postId,
                                    isRefresh: true,
                                    sort: _commentSort,
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
                                state is CommentsLoading &&
                                    _lastLoadedState != null
                                ? _lastLoadedState!
                                : state;

                            if (displayState is CommentsLoading) {
                              return ListView.builder(
                                itemCount: 8,
                                padding: const EdgeInsets.fromLTRB(
                                  AppSizes.p16,
                                  AppSizes.p16,
                                  AppSizes.p16,
                                  AppSizes.p12,
                                ),
                                itemBuilder: (context, index) {
                                  return const Padding(
                                    padding: EdgeInsets.only(bottom: 20),
                                    child: CommentSkeletonRow(),
                                  );
                                },
                              );
                            }
                            if (displayState is CommentsLoadSuccess) {
                              if (displayState.comments.isEmpty) {
                                return Center(
                                  child: CustomText(l10n.noCommentsYet),
                                );
                              }
                              final showLoadMoreFooter =
                                  _isLoadingMoreComments &&
                                  !displayState.hasReachedMax;

                              return ListView.builder(
                                controller: _commentsScrollController,
                                itemCount:
                                    displayState.comments.length +
                                    (showLoadMoreFooter ? 1 : 0),
                                padding: const EdgeInsets.fromLTRB(
                                  AppSizes.p16,
                                  AppSizes.p16,
                                  AppSizes.p16,
                                  AppSizes.p12,
                                ),
                                itemBuilder: (context, index) {
                                  if (showLoadMoreFooter &&
                                      index == displayState.comments.length) {
                                    return const Padding(
                                      padding: EdgeInsets.only(bottom: 20),
                                      child: CommentSkeletonRow(),
                                    );
                                  }

                                  final comment = displayState.comments[index];
                                  final loadedReplies =
                                      displayState.repliesByParentId[comment
                                          .id] ??
                                      const [];
                                  return CommentItem(
                                    comment: comment,
                                    replies: loadedReplies,
                                    hasMoreReplies: hasMoreThreadReplies(
                                      parent: comment,
                                      loadedReplies: loadedReplies,
                                      reachedMaxByParentId: displayState
                                          .repliesHasReachedMaxByParentId,
                                    ),
                                    isExpanded: _expandedReplyIds.contains(
                                      comment.id,
                                    ),
                                    canDelete: _canDelete,
                                    onDelete: _confirmDelete,
                                    onLike: _checkAuth,
                                    onReply: _startReply,
                                    onToggleReplies: () {
                                      setState(() {
                                        if (_expandedReplyIds.contains(
                                          comment.id,
                                        )) {
                                          _expandedReplyIds.remove(comment.id);
                                        } else {
                                          _expandedReplyIds.add(comment.id);
                                        }
                                      });
                                    },
                                    onLoadMoreReplies: () {
                                      final loaded =
                                          displayState.repliesByParentId[comment
                                              .id] ??
                                          const [];
                                      final nextPage =
                                          (loaded.length / 20).ceil() + 1;
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
                      CommentInputSection(
                        bottomPadding: bottomPadding,
                        replyingToUsername: _replyingToUsername,
                        onClearReplyingTo: _clearReplyingTo,
                        onQuickReaction: _onQuickReaction,
                        commentController: _commentController,
                        commentFocusNode: _commentFocusNode,
                        onSendComment: _onSendComment,
                        showPostButton: _showPostButton,
                        inputAvatar: _buildCommentInputAvatar(),
                      ),
                    ],
                  ),
                  if (widget.isPostOwner)
                    PostEngagementUsersTab(
                      postId: widget.postId,
                      kind: PostEngagementUserListKind.views,
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
