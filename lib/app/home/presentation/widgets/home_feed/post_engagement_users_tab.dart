import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/home/presentation/utils/story_l10n_format.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_view_entity.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_post_likes_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_post_views_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart' as posts_di;
import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/app/social/presentation/utils/social_follow_toggle.dart';
import 'package:bimobondapp/app/social/presentation/widgets/social_user_list_tile.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum PostEngagementUserListKind { likes, views }

/// Likes or views audience list (post owner only).
class PostEngagementUsersTab extends StatefulWidget {
  const PostEngagementUsersTab({
    super.key,
    required this.postId,
    required this.kind,
    this.hideFollowForViewers = false,
  });

  final String postId;
  final PostEngagementUserListKind kind;

  /// Story viewers sheet: list viewers only, no follow actions.
  final bool hideFollowForViewers;

  @override
  State<PostEngagementUsersTab> createState() => _PostEngagementUsersTabState();
}

class _PostEngagementUsersTabState extends State<PostEngagementUsersTab> {
  static const int _pageSize = 20;

  final ScrollController _scrollController = ScrollController();
  final List<SocialUserEntity> _likedUsers = [];
  final List<PostViewEntity> _views = [];
  final Set<String> _followLoadingIds = {};

  int _page = 1;
  bool _hasReachedMax = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  bool get _isViews => widget.kind == PostEngagementUserListKind.views;

  int get _itemCount => _isViews ? _views.length : _likedUsers.length;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
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
    if (!_scrollController.hasClients || _hasReachedMax || _isLoadingMore) {
      return;
    }
    final position = _scrollController.position;
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
      await _loadViews(refresh: refresh, loadMore: loadMore);
    } else {
      await _loadLikes(refresh: refresh, loadMore: loadMore);
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
    final result = await posts_di.sl<GetPostViewsUseCase>()(
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
        if (!loadMore || page.views.isNotEmpty) {
          _page++;
        }
      }),
    );
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

  String? _likeTimeSubtitle(SocialUserEntity user, AppLocalizations l10n) {
    final at = user.likedAt;
    if (at == null) return null;
    return formatTimeAgo(at, l10n);
  }

  Widget _buildUserTile({
    required SocialUserEntity user,
    required int index,
    String? subtitle,
    bool disableProfileTap = false,
  }) {
    final hideFollow = _isViews && widget.hideFollowForViewers;

    return SocialUserListTile(
      user: user,
      isSelf: _isSelfUser(user),
      hideFollowButton: hideFollow,
      isFollowLoading: _followLoadingIds.contains(user.id),
      onTap: disableProfileTap ? () {} : null,
      onFollowTap: hideFollow ? null : () => _toggleFollowForUser(index, user),
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
      subtitleOverride: subtitle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.p16,
          vertical: AppSizes.p12,
        ),
        itemCount: 15,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.p16),
          child: Row(
            children: [
              const SkeletonWidget.circular(size: 44),
              const SizedBox(width: AppSizes.p12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonWidget(height: 14, width: 120),
                    SizedBox(height: 6),
                    SkeletonWidget(height: 12, width: 80),
                  ],
                ),
              ),
              const SkeletonWidget(height: 32, width: 72),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null && _itemCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: CustomText(
            _errorMessage!,
            color: theme.colorScheme.error,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_itemCount == 0) {
      return Center(
        child: CustomText(
          _emptyMessage,
          variant: TextVariant.secondary,
          textAlign: TextAlign.center,
        ),
      );
    }

    final showFooter = _isLoadingMore && !_hasReachedMax;

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: AppSizes.p8),
      itemCount: _itemCount + (showFooter ? 1 : 0),
      separatorBuilder: (context, index) {
        if (index >= _itemCount - 1) return const SizedBox.shrink();
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
                const SkeletonWidget.circular(size: 44),
                const SizedBox(width: AppSizes.p12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonWidget(height: 14, width: 120),
                      SizedBox(height: 6),
                      SkeletonWidget(height: 12, width: 80),
                    ],
                  ),
                ),
                const SkeletonWidget(height: 32, width: 72),
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
          );
        }

        return _buildUserTile(
          user: _likedUsers[index],
          index: index,
          subtitle: _likeTimeSubtitle(_likedUsers[index], l10n),
        );
      },
    );
  }
}
