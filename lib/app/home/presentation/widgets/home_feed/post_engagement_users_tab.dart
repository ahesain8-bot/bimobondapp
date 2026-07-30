import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/chats/domain/usecases/create_or_get_chat_usecase.dart';
import 'package:bimobondapp/app/chats/presentation/di/chats_injector.dart'
    as chats_di;
import 'package:bimobondapp/app/home/presentation/widgets/comments/comment_layout_constants.dart';
import 'package:bimobondapp/app/home/presentation/utils/story_l10n_format.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_view_entity.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_post_likes_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_post_views_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart' as posts_di;
import 'package:bimobondapp/app/stories/domain/usecases/stories_usecases.dart';
import 'package:bimobondapp/app/stories/presentation/di/stories_injector.dart'
    as stories_di;
import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/app/social/presentation/utils/social_follow_toggle.dart';
import 'package:bimobondapp/app/social/presentation/widgets/social_user_list_tile.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_surface.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum PostEngagementUserListKind { likes, views }

/// Likes or views audience list (post owner only).
class PostEngagementUsersTab extends StatefulWidget {
  const PostEngagementUsersTab({
    super.key,
    required this.postId,
    required this.kind,
    this.scrollController,
    this.hideFollowForViewers = false,
    this.hideFollowButton = false,
    this.showMessageButton = false,
    this.showLikedHeart = false,
    this.isStory = false,
  });

  final String postId;
  final PostEngagementUserListKind kind;

  /// When set (e.g. engagement sheet), drives [DraggableScrollableSheet] resize.
  final ScrollController? scrollController;

  /// Story viewers sheet: list viewers only, no follow actions.
  final bool hideFollowForViewers;

  /// Explicit flag to hide the follow button entirely.
  final bool hideFollowButton;

  /// TikTok-style Message trailing action on each row.
  final bool showMessageButton;

  /// Instagram-style: show a heart on viewers who also liked the story.
  final bool showLikedHeart;

  /// When true, views are loaded from `GET /stories/:id/viewers`.
  final bool isStory;

  @override
  State<PostEngagementUsersTab> createState() => _PostEngagementUsersTabState();
}

class _PostEngagementUsersTabState extends State<PostEngagementUsersTab> {
  static const int _pageSize = 20;
  static const int _likedIdsPageSize = 100;

  final ScrollController _scrollController = ScrollController();

  ScrollController get _listController =>
      widget.scrollController ?? _scrollController;

  bool get _ownsListController => widget.scrollController == null;

  final List<SocialUserEntity> _likedUsers = [];
  final List<PostViewEntity> _views = [];
  final Set<String> _likedViewerIds = {};
  final Set<String> _followLoadingIds = {};
  final Set<String> _messageLoadingIds = {};

  int _page = 1;
  bool _hasReachedMax = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  bool get _isViews => widget.kind == PostEngagementUserListKind.views;

  bool get _isLikes => widget.kind == PostEngagementUserListKind.likes;

  bool get _compactLikesList => _isLikes && !widget.isStory;

  int get _itemCount => _isViews ? _views.length : _likedUsers.length;

  @override
  void initState() {
    super.initState();
    _listController.addListener(_onScroll);
    _load(refresh: true);
  }

  @override
  void dispose() {
    _listController.removeListener(_onScroll);
    if (_ownsListController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(PostEngagementUsersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      (oldWidget.scrollController ?? _scrollController)
          .removeListener(_onScroll);
      _listController.addListener(_onScroll);
    }
  }

  String? get _currentUserId {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) return authState.user.id;
    return null;
  }

  bool _isSelfUser(SocialUserEntity user) {
    final me = _currentUserId;
    return me != null && me == user.id;
  }

  String get _emptyMessage {
    final l10n = AppLocalizations.of(context)!;
    return widget.kind == PostEngagementUserListKind.likes
        ? l10n.postLikesEmpty
        : l10n.postViewsEmpty;
  }

  void _onScroll() {
    if (!_listController.hasClients || _hasReachedMax || _isLoadingMore) {
      return;
    }
    final position = _listController.position;
    if (position.pixels >= position.maxScrollExtent - 120) {
      _load(loadMore: true);
    }
  }

  Future<void> _toggleFollowForUser(int index, SocialUserEntity user) async {
    if (_isSelfUser(user) || _followLoadingIds.contains(user.id)) return;

    final previousFollowing = user.isFollowing;
    setState(() {
      _followLoadingIds.add(user.id);
      _applyFollowState(index, user.copyWith(isFollowing: !previousFollowing));
    });

    final result = await toggleSocialUserFollow(
      userId: user.id,
      wasFollowing: previousFollowing,
    );
    if (!mounted) return;

    if (result.failure != null) {
      setState(() {
        _applyFollowState(index, user.copyWith(isFollowing: previousFollowing));
        _followLoadingIds.remove(user.id);
      });
      return;
    }

    setState(() {
      _applyFollowState(
        index,
        user.copyWith(isFollowing: result.isFollowing!),
      );
      _followLoadingIds.remove(user.id);
    });
  }

  void _applyFollowState(int index, SocialUserEntity updated) {
    if (_isViews) {
      final view = _views[index];
      _views[index] = PostViewEntity(
        id: view.id,
        userId: view.userId,
        postId: view.postId,
        watchedDuration: view.watchedDuration,
        createdAt: view.createdAt,
        user: updated,
      );
    } else {
      _likedUsers[index] = updated;
    }
  }

  Future<void> _load({bool refresh = false, bool loadMore = false}) async {
    if (_isLoading || _isLoadingMore) return;
    if (loadMore && _hasReachedMax) return;

    if (refresh) {
      _page = 1;
      _hasReachedMax = false;
      _errorMessage = null;
    }

    setState(() {
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        _isLoading = _itemCount == 0;
      }
    });

    if (_isViews) {
      if (refresh && widget.showLikedHeart) {
        await _loadLikedViewerIds();
      }
      await _loadViews(refresh: refresh, loadMore: loadMore);
    } else {
      await _loadLikes(refresh: refresh, loadMore: loadMore);
    }
  }

  Future<void> _loadLikedViewerIds() async {
    _likedViewerIds.clear();
    var page = 1;
    var hasMore = true;

    while (hasMore && page <= 5) {
      final result = await posts_di.sl<GetPostLikesUseCase>()(
        GetPostLikesParams(
          postId: widget.postId,
          page: page,
          limit: _likedIdsPageSize,
        ),
      );

      final continuePaging = result.fold(
        (_) => false,
        (likesPage) {
          for (final user in likesPage.users) {
            if (user.id.isNotEmpty) _likedViewerIds.add(user.id);
          }
          return likesPage.users.length >= _likedIdsPageSize;
        },
      );

      if (!continuePaging) break;
      page++;
      hasMore = continuePaging;
    }
  }

  Future<void> _loadLikes({required bool refresh, required bool loadMore}) async {
    final result = await posts_di.sl<GetPostLikesUseCase>()(
      GetPostLikesParams(
        postId: widget.postId,
        page: _page,
        limit: _pageSize,
      ),
    );

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = failure.message;
        if (refresh) _likedUsers.clear();
      }),
      (page) => setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = null;
        _hasReachedMax = page.page >= page.lastPage;
        if (refresh) {
          _likedUsers
            ..clear()
            ..addAll(page.users);
        } else {
          final existing = _likedUsers.map((u) => u.id).toSet();
          _likedUsers.addAll(
            page.users.where((u) => !existing.contains(u.id)),
          );
        }
        if (!loadMore || page.users.isNotEmpty) {
          _page++;
        }
      }),
    );
  }

  Future<void> _loadViews({required bool refresh, required bool loadMore}) async {
    final result = widget.isStory
        ? await stories_di.sl<GetStoryViewersUseCase>()(
            GetStoryViewersParams(
              storyId: widget.postId,
              page: _page,
              limit: _pageSize,
            ),
          ).then(
            (either) => either.map((page) => page.toPostViewsPage()),
          )
        : await posts_di.sl<GetPostViewsUseCase>()(
            GetPostViewsParams(
              postId: widget.postId,
              page: _page,
              limit: _pageSize,
            ),
          );

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = failure.message;
        if (refresh) _views.clear();
      }),
      (page) => setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = null;
        _hasReachedMax = page.page >= page.lastPage;
        final incoming = page.views.where((v) => _viewDedupeKey(v).isNotEmpty);
        if (refresh) {
          _views
            ..clear()
            ..addAll(incoming);
        } else {
          final existing = _views.map(_viewDedupeKey).toSet();
          _views.addAll(
            incoming.where((v) => !existing.contains(_viewDedupeKey(v))),
          );
        }
        if (widget.showLikedHeart) {
          _sortViewsLikedFirst();
        }
        if (!loadMore || page.views.isNotEmpty) {
          _page++;
        }
      }),
    );
  }

  void _sortViewsLikedFirst() {
    if (_likedViewerIds.isEmpty) return;
    _views.sort((a, b) {
      final aLiked = _viewerLiked(a);
      final bLiked = _viewerLiked(b);
      if (aLiked == bLiked) return 0;
      return aLiked ? -1 : 1;
    });
  }

  String _viewerId(PostViewEntity view) {
    if (view.userId.isNotEmpty) return view.userId;
    return view.user?.id ?? '';
  }

  bool _viewerLiked(PostViewEntity view) {
    final id = _viewerId(view);
    return id.isNotEmpty && _likedViewerIds.contains(id);
  }

  String _viewDedupeKey(PostViewEntity view) {
    if (view.id.isNotEmpty) return view.id;
    if (view.userId.isNotEmpty) {
      return '${view.userId}_${view.createdAt?.toIso8601String() ?? ''}';
    }
    return '';
  }

  SocialUserEntity _viewerUser(PostViewEntity view, AppLocalizations l10n) {
    if (view.user != null) return view.user!;
    if (view.userId.isNotEmpty) return SocialUserEntity(id: view.userId);
    return SocialUserEntity(
      id: view.id,
      fullName: l10n.storyViewerUnknown,
    );
  }

  String? _viewTimeSubtitle(PostViewEntity view, AppLocalizations l10n) {
    final at = view.createdAt;
    if (at == null) return null;
    return formatTimeAgo(at, l10n);
  }

  Widget _buildUserTile({
    required SocialUserEntity user,
    required int index,
    String? subtitle,
    bool disableProfileTap = false,
    bool likedStory = false,
  }) {
    final hideFollow =
        widget.hideFollowButton || (_isViews && widget.hideFollowForViewers);
    final showMessage = widget.showMessageButton && !_isSelfUser(user);
    final showHeart = widget.showLikedHeart && likedStory;

    Widget? trailing;
    if (showMessage || showHeart) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showMessage)
            _MessageTrailingButton(
              isLoading: _messageLoadingIds.contains(user.id),
              onPressed: () => _openMessage(user),
            ),
          if (showHeart) ...[
            if (showMessage) const SizedBox(width: 10),
            const Icon(
              Icons.favorite,
              color: Color(0xFFE1306C),
              size: 22,
            ),
          ],
        ],
      );
    }

    return SocialUserListTile(
      user: user,
      isSelf: _isSelfUser(user),
      hideFollowButton: hideFollow || showMessage || showHeart,
      isFollowLoading: _followLoadingIds.contains(user.id),
      onTap: disableProfileTap ? () {} : null,
      onFollowTap: hideFollow ? null : () => _toggleFollowForUser(index, user),
      showUsernameSubtitle: !_compactLikesList,
      compact: _compactLikesList,
      avatarRadius: _compactLikesList
          ? CommentLayout.likesAvatarRadius
          : 24,
      onProfileFollowStateChanged: (isFollowing) {
        setState(() {
          final updated = user.copyWith(isFollowing: isFollowing);
          if (_isViews) {
            final view = _views[index];
            _views[index] = PostViewEntity(
              id: view.id,
              userId: view.userId,
              postId: view.postId,
              watchedDuration: view.watchedDuration,
              createdAt: view.createdAt,
              user: updated,
            );
          } else {
            _likedUsers[index] = updated;
          }
        });
      },
      subtitleOverride: _compactLikesList ? null : subtitle,
      trailingOverride: trailing,
    );
  }

  Future<void> _openMessage(SocialUserEntity user) async {
    if (_messageLoadingIds.contains(user.id) || user.id.isEmpty) return;
    setState(() => _messageLoadingIds.add(user.id));

    final result = await chats_di.sl<CreateOrGetChatUseCase>()(
      CreateOrGetChatParams(participantIds: [user.id]),
    );

    if (!mounted) return;
    setState(() => _messageLoadingIds.remove(user.id));

    await result.fold(
      (failure) async {
        PopupDialogs.showErrorDialog(context, failure.message);
      },
      (chat) async {
        final displayName = user.fullName?.trim().isNotEmpty == true
            ? user.fullName!.trim()
            : user.username ?? user.displayName;
        await context.pushNamed(
          'chat',
          extra: {
            'chatId': chat.id,
            'username': displayName,
            if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
              'imageUrl': user.avatarUrl,
            'peerUserId': user.id,
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final skeletonTone = theme.brightness == Brightness.dark
        ? LiquidGlassSkeletonTone.standard
        : LiquidGlassSkeletonTone.light;

    if (_isLoading) {
      return ListView.builder(
        controller: _listController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: _compactLikesList
              ? CommentLayout.likesListHorizontalPadding
              : AppSizes.p16,
          vertical: _compactLikesList ? AppSizes.p4 : AppSizes.p12,
        ),
        itemCount: 15,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(
            bottom: _compactLikesList ? CommentLayout.likesRowSpacing : AppSizes.p16,
          ),
          child: Row(
            children: [
              LiquidGlassSkeletonBox.circular(
                size: _compactLikesList
                    ? CommentLayout.likesAvatarRadius * 2
                    : 44,
                tone: skeletonTone,
              ),
              SizedBox(
                width: _compactLikesList ? AppSizes.p8 : AppSizes.p12,
              ),
              Expanded(
                child: _compactLikesList
                    ? LiquidGlassSkeletonBox(
                        height: CommentLayout.likesNameFontSize,
                        width: 120,
                        tone: skeletonTone,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LiquidGlassSkeletonBox(
                            height: 14,
                            width: 120,
                            tone: skeletonTone,
                          ),
                          const SizedBox(height: 6),
                          LiquidGlassSkeletonBox(
                            height: 12,
                            width: 80,
                            tone: skeletonTone,
                          ),
                        ],
                      ),
              ),
              if (!_compactLikesList)
                LiquidGlassSkeletonBox(
                  height: 32,
                  width: 72,
                  tone: skeletonTone,
                ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null && _itemCount == 0) {
      return ListView(
        controller: _listController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.22,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.p24),
                child: CustomText(
                  _errorMessage!,
                  color: theme.colorScheme.error,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_itemCount == 0) {
      return ListView(
        controller: _listController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.22,
            child: Center(
              child: CustomText(
                _emptyMessage,
                variant: TextVariant.secondary,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    final showFooter = _isLoadingMore && !_hasReachedMax;

    return ListView.separated(
      controller: _listController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: _compactLikesList
            ? CommentLayout.likesListHorizontalPadding
            : 0,
        vertical: _compactLikesList ? AppSizes.p4 : AppSizes.p8,
      ),
      itemCount: _itemCount + (showFooter ? 1 : 0),
      separatorBuilder: (context, index) {
        if (index >= _itemCount - 1) return const SizedBox.shrink();
        if (_compactLikesList) {
          return const SizedBox(height: CommentLayout.likesRowSpacing);
        }
        return Divider(
          height: 1,
          indent: 72,
          color: theme.dividerColor.withValues(alpha: 0.08),
        );
      },
      itemBuilder: (context, index) {
        if (showFooter && index == _itemCount) {
          return Padding(
            padding: const EdgeInsets.only(
              top: AppSizes.p8,
              bottom: AppSizes.p16,
            ),
            child: Row(
              children: [
                LiquidGlassSkeletonBox.circular(
                  size: 44,
                  tone: skeletonTone,
                ),
                const SizedBox(width: AppSizes.p12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LiquidGlassSkeletonBox(
                        height: 14,
                        width: 120,
                        tone: skeletonTone,
                      ),
                      const SizedBox(height: 6),
                      LiquidGlassSkeletonBox(
                        height: 12,
                        width: 80,
                        tone: skeletonTone,
                      ),
                    ],
                  ),
                ),
                LiquidGlassSkeletonBox(
                  height: 32,
                  width: 72,
                  tone: skeletonTone,
                ),
              ],
            ),
          );
        }

        if (_isViews) {
          final view = _views[index];
          return _buildUserTile(
            user: _viewerUser(view, l10n),
            index: index,
            subtitle: _viewTimeSubtitle(view, l10n),
            disableProfileTap: !view.hasViewerProfile,
            likedStory: _viewerLiked(view),
          );
        }

        return _buildUserTile(
          user: _likedUsers[index],
          index: index,
        );
      },
    );
  }
}

class _MessageTrailingButton extends StatelessWidget {
  const _MessageTrailingButton({
    required this.onPressed,
    this.isLoading = false,
  });

  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SizedBox(
      height: 34,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurface,
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.35)),
          backgroundColor: theme.colorScheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          minimumSize: const Size(0, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                l10n.profileMessageButton,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
