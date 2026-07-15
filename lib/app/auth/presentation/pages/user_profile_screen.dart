import 'dart:async';

import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:bimobondapp/app/auth/domain/usecases/get_profile_usecase.dart';
import 'package:bimobondapp/app/auth/domain/usecases/get_user_by_id_usecase.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart'
    as auth_di;
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:bimobondapp/app/chats/domain/usecases/create_or_get_chat_usecase.dart';
import 'package:bimobondapp/app/chats/presentation/di/chats_injector.dart'
    as chats_di;
import 'package:bimobondapp/app/social/domain/usecases/social_user_list_usecases.dart';
import 'package:bimobondapp/app/social/presentation/di/social_injector.dart'
    as social_di;
import 'package:bimobondapp/app/social/presentation/utils/social_follow_toggle.dart';
import 'package:bimobondapp/app/social/presentation/pages/user_connections_screen.dart';
import 'package:bimobondapp/app/social/presentation/widgets/profile_follow_button.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_grid_tile.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_posts_sort.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_format_utils.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_avatar_tap_handler.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_icon_tab_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_posts_load_more.dart';
import 'package:bimobondapp/core/navigation/profile_posts_navigation.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/core/widgets/profile_bio_text.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    required this.userId,
    this.initialUsername,
    this.initialFullName,
    this.initialAvatarUrl,
    this.initialIsFollowing,
    super.key,
  });

  final String userId;
  final String? initialUsername;
  final String? initialFullName;
  final String? initialAvatarUrl;
  final bool? initialIsFollowing;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfilePostsState {
  static const int pageSize = ProfileLayoutConstants.postsPageSize;

  final List<PostEntity> posts = [];
  int page = 1;
  bool hasReachedMax = false;
  bool isLoadingMore = false;
  bool isInitialLoading = true;
  bool isRefreshing = false;
  int? pendingLoadKey;
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  UserEntity? _user;
  String? _errorMessage;
  bool _isLoadingUser = true;
  bool _isFollowing = false;
  bool _isFollowedBy = false;
  bool _isFollowLoading = false;
  bool _isMessageLoading = false;
  int _profileLoadKey = 0;
  int? _fetchingLoadKey;
  Completer<void>? _pullRefreshCompleter;
  final ScrollController _scrollController = ScrollController();
  final _postsState = _UserProfilePostsState();

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.initialIsFollowing ?? false;
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshProfile());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isSelf {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) return false;
    final ids = {
      authState.user.id,
      authState.user.firebaseUid,
    }.whereType<String>().where((id) => id.isNotEmpty);
    return ids.contains(widget.userId);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_postsState.hasReachedMax ||
        _postsState.isLoadingMore ||
        _postsState.isRefreshing) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >=
        position.maxScrollExtent -
            ProfileLayoutConstants.scrollLoadMoreThreshold) {
      _fetchPosts(loadMore: true);
    }
  }

  void _refreshProfile() {
    unawaited(_loadUser(showLoadingShell: _user == null));
    _fetchPosts(refresh: true);
  }

  Future<void> _refreshProfileAfterNavigation(
    Future<Object?> navigation,
  ) async {
    await navigation;
    if (!mounted) return;
    _refreshProfile();
  }

  Future<void> _loadUser({bool showLoadingShell = true}) async {
    final isInitialLoad = _user == null;
    if (showLoadingShell && isInitialLoad) {
      setState(() {
        _isLoadingUser = true;
        _errorMessage = null;
      });
    }

    final result = _isSelf
        ? await auth_di.sl<GetProfileUseCase>()(NoParams())
        : await auth_di.sl<GetUserByIdUseCase>()(
            GetUserByIdParams(widget.userId),
          );
    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _isLoadingUser = false;
          if (isInitialLoad) {
            _errorMessage = failure.message;
          }
        });
      },
      (user) {
        setState(() {
          _user = user;
          _isLoadingUser = false;
          if (user.isFollowing != null) {
            _isFollowing = user.isFollowing!;
          }
          if (user.isFollowedBy != null) {
            _isFollowedBy = user.isFollowedBy!;
          }
        });
        if (!_isSelf && user.isFollowing == null) {
          unawaited(_resolveFollowStatus());
        }
      },
    );
  }

  void _fetchPosts({bool refresh = false, bool loadMore = false}) {
    if (loadMore) {
      if (_postsState.hasReachedMax || _postsState.isLoadingMore) return;
      setState(() {
        _postsState.isLoadingMore = true;
        _postsState.page++;
      });
    } else if (refresh) {
      setState(() {
        _postsState.page = 1;
        _postsState.hasReachedMax = false;
        _postsState.isInitialLoading = _postsState.posts.isEmpty;
      });
    } else if (_postsState.posts.isNotEmpty) {
      return;
    } else {
      setState(() {
        _postsState.page = 1;
        _postsState.hasReachedMax = false;
        _postsState.isInitialLoading = true;
      });
    }

    final loadKey = ++_profileLoadKey;
    _postsState.pendingLoadKey = loadKey;
    _fetchingLoadKey = loadKey;

    context.read<PostsBloc>().add(
      FetchFeedRequestedEvent(
        page: _postsState.page,
        limit: _UserProfilePostsState.pageSize,
        userId: widget.userId,
        sort: ProfileLayoutConstants.postsSortNewestFirst,
        isRefresh: refresh || _postsState.page == 1,
        isStory: false,
        profileLoadKey: loadKey,
      ),
    );
  }

  Future<void> _onPullToRefresh() async {
    _pullRefreshCompleter = Completer<void>();
    setState(() => _postsState.isRefreshing = true);
    await _loadUser(showLoadingShell: false);
    _fetchPosts(refresh: true);

    try {
      await _pullRefreshCompleter!.future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _postsState.isRefreshing = false;
          _postsState.isInitialLoading = false;
        });
      }
    } finally {
      _pullRefreshCompleter = null;
    }
  }

  Future<void> _resolveFollowStatus() async {
    if (_isSelf || !mounted) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) return;

    final result = await social_di.sl<CheckIsFollowingUseCase>()(
      CheckIsFollowingParams(
        currentUserId: authState.user.id,
        targetUserId: widget.userId,
      ),
    );
    if (!mounted) return;

    result.fold((_) {}, (isFollowing) {
      setState(() => _isFollowing = isFollowing);
    });
  }

  bool _ensureLoggedIn() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) return true;

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

  Future<void> _toggleFollow() async {
    if (_isSelf || _isFollowLoading) return;
    if (!_ensureLoggedIn()) return;

    final previousFollowing = _isFollowing;
    setState(() {
      _isFollowLoading = true;
      _isFollowing = !previousFollowing;
    });

    final result = await toggleSocialUserFollow(
      userId: widget.userId,
      wasFollowing: previousFollowing,
    );
    if (!mounted) return;

    if (result.failure != null) {
      setState(() {
        _isFollowing = previousFollowing;
        _isFollowLoading = false;
      });
      PopupDialogs.showErrorDialog(context, result.failure!.message);
      return;
    }

    setState(() {
      _isFollowing = result.isFollowing!;
      _isFollowLoading = false;
    });
    unawaited(_loadUser(showLoadingShell: false));
  }

  Future<void> _openMessage() async {
    if (_isSelf || _isMessageLoading) return;
    if (!_ensureLoggedIn()) return;

    setState(() => _isMessageLoading = true);

    final result = await chats_di.sl<CreateOrGetChatUseCase>()(
      CreateOrGetChatParams(participantIds: [widget.userId]),
    );

    if (!mounted) return;

    setState(() => _isMessageLoading = false);

    await result.fold(
      (failure) async {
        PopupDialogs.showErrorDialog(context, failure.message);
      },
      (chat) async {
        final user = _displayUser;
        final displayName = user?.fullName?.trim().isNotEmpty == true
            ? user!.fullName!.trim()
            : user?.username ?? widget.initialUsername ?? 'User';
        final avatarUrl = user?.avatarUrl ?? widget.initialAvatarUrl;

        await _refreshProfileAfterNavigation(
          context.pushNamed(
            'chat',
            extra: {
              'chatId': chat.id,
              'username': displayName,
              if (avatarUrl != null && avatarUrl.isNotEmpty)
                'imageUrl': avatarUrl,
              'peerUserId': widget.userId,
            },
          ),
        );
      },
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  UserEntity? get _displayUser {
    if (_user != null) return _user;
    if (widget.initialUsername == null &&
        widget.initialFullName == null &&
        widget.initialAvatarUrl == null) {
      return null;
    }
    return UserEntity(
      id: widget.userId,
      username: widget.initialUsername,
      fullName: widget.initialFullName,
      avatarUrl: widget.initialAvatarUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final user = _displayUser;
    final username = user?.username ?? widget.initialUsername ?? 'user';
    final displayPostCount = resolveProfilePostsCount(
      apiPostCount: user?.postCount,
      loadedPostsCount: _postsState.posts.length,
      hasLoadedAllPosts:
          _postsState.hasReachedMax && !_postsState.isInitialLoading,
    );

    return BlocListener<PostsBloc, PostsState>(
      listener: (context, state) {
        if (state is ProfilePostsLoadSuccess) {
          if (_postsState.pendingLoadKey != state.profileLoadKey) return;

          setState(() {
            if (_postsState.page == 1) {
              _postsState.posts
                ..clear()
                ..addAll(state.posts);
            } else {
              final existingIds = _postsState.posts.map((p) => p.id).toSet();
              _postsState.posts.addAll(
                state.posts.where((p) => !existingIds.contains(p.id)),
              );
            }
            sortProfilePostsNewestFirst(_postsState.posts);
            _postsState.hasReachedMax = state.hasReachedMax;
            _postsState.isLoadingMore = false;
            _postsState.isInitialLoading = false;
            _postsState.isRefreshing = false;
          });

          final completer = _pullRefreshCompleter;
          if (completer != null && !completer.isCompleted) {
            completer.complete();
          }
        } else if (state is PostsFailure &&
            state.profileLoadKey == _fetchingLoadKey) {
          setState(() {
            if (_postsState.isLoadingMore && _postsState.page > 1) {
              _postsState.page--;
            }
            _postsState.isLoadingMore = false;
            _postsState.isInitialLoading = false;
            _postsState.isRefreshing = false;
          });

          final completer = _pullRefreshCompleter;
          if (completer != null && !completer.isCompleted) {
            completer.complete();
          }
        }
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          context.pop(_isFollowing);
        },
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: CustomAppBar(
            title: '@$username',
            onBackPressed: () => context.pop(_isFollowing),
            hideBottomDivider: true,
          ),
          body: _errorMessage != null && user == null && !_isLoadingUser
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.p24),
                    child: CustomText(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      variant: TextVariant.secondary,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _onPullToRefresh,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal:
                                ProfileLayoutConstants.headerHorizontalPadding,
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: AppSizes.p12),
                              if (_isLoadingUser && user == null)
                                const SkeletonWidget.circular(size: 96)
                              else
                                StoryProfileAvatar(
                                  userId: widget.userId,
                                  imageUrl: user?.avatarUrl,
                                  radius: ProfileLayoutConstants.avatarRadius,
                                  fallbackText: user?.username ?? username,
                                  backgroundColor: theme.dividerColor
                                      .withValues(alpha: 0.08),
                                  username: user?.username ?? username,
                                  fullName: user?.fullName,
                                  isFollowing: _isFollowing,
                                  onTap: () => handleProfileScreenAvatarTap(
                                    context,
                                    userId: widget.userId,
                                    avatarUrl: user?.avatarUrl,
                                  ),
                                ),
                              const SizedBox(height: AppSizes.p12),
                              if (_isLoadingUser && user?.fullName == null)
                                const SkeletonWidget(height: 18, width: 160)
                              else
                                Text(
                                  user?.fullName?.trim().isNotEmpty == true
                                      ? user!.fullName!.trim()
                                      : username,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              const SizedBox(height: AppSizes.p6),
                              CustomText(
                                '@$username',
                                fontSize: 14,
                                variant: TextVariant.secondary,
                                textAlign: TextAlign.center,
                              ),
                              if (!_isSelf) ...[
                                const SizedBox(height: AppSizes.p16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ProfileFollowButton(
                                      width: 140,
                                      isFollowing: _isFollowing,
                                      isFollowedBy: _isFollowedBy,
                                      isLoading: _isFollowLoading,
                                      onPressed: _toggleFollow,
                                    ),
                                    const SizedBox(width: AppSizes.p12),
                                    SizedBox(
                                      width: 140,
                                      height: 40,
                                      child: OutlinedButton(
                                        onPressed: _isMessageLoading
                                            ? null
                                            : _openMessage,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              theme.colorScheme.primary,
                                          side: BorderSide(
                                            color: theme.colorScheme.primary,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              AppSizes.radiusMd,
                                            ),
                                          ),
                                        ),
                                        child: _isMessageLoading
                                            ? SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: theme
                                                          .colorScheme
                                                          .primary,
                                                    ),
                                              )
                                            : CustomText(
                                                l10n.profileMessageButton,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: AppSizes.p16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _UserProfileStatItem(
                                      number: _formatCount(displayPostCount),
                                      label: l10n.profilePostsTab,
                                    ),
                                  ),
                                  Expanded(
                                    child: _UserProfileStatItem(
                                      number: _formatCount(
                                        user?.followerCount ?? 0,
                                      ),
                                      label: l10n.followers,
                                      onTap: () =>
                                          _refreshProfileAfterNavigation(
                                            context.pushNamed(
                                              'user_connections',
                                              extra: {
                                                'userId': widget.userId,
                                                'type': UserConnectionType
                                                    .followers,
                                              },
                                            ),
                                          ),
                                    ),
                                  ),
                                  Expanded(
                                    child: _UserProfileStatItem(
                                      number: _formatCount(
                                        user?.followingCount ?? 0,
                                      ),
                                      label: l10n.following,
                                      onTap: () =>
                                          _refreshProfileAfterNavigation(
                                            context.pushNamed(
                                              'user_connections',
                                              extra: {
                                                'userId': widget.userId,
                                                'type': UserConnectionType
                                                    .following,
                                              },
                                            ),
                                          ),
                                    ),
                                  ),
                                  // _UserProfileStatItem(
                                  //   number: _formatCount(user?.totalLikes ?? 0),
                                  //   label: l10n.likes,
                                  // ),
                                ],
                              ),
                              const SizedBox(height: AppSizes.p12),
                              ProfileBioText(
                                bio: user?.bio,
                                placeholder: l10n.noBio,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: ProfileUserPostsTabBar(
                          backgroundColor: theme.scaffoldBackgroundColor,
                        ),
                      ),
                      _UserProfilePostsGrid(
                        state: _postsState,
                        emptyMessage: l10n.noPostsYet,
                        userId: widget.userId,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _UserProfileStatItem extends StatelessWidget {
  const _UserProfileStatItem({
    required this.number,
    required this.label,
    this.onTap,
  });

  final String number;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomText(number, fontSize: 18, fontWeight: FontWeight.bold),
        const SizedBox(height: AppSizes.p4),
        CustomText(label, fontSize: 13, variant: TextVariant.secondary),
      ],
    );

    final child = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p12,
        vertical: AppSizes.p4,
      ),
      child: Center(child: content),
    );

    if (onTap == null) return child;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: child,
    );
  }
}

class _UserProfilePostsGrid extends StatelessWidget {
  const _UserProfilePostsGrid({
    required this.state,
    required this.emptyMessage,
    required this.userId,
  });

  final _UserProfilePostsState state;
  final String emptyMessage;
  final String userId;

  @override
  Widget build(BuildContext context) {
    const gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: ProfileLayoutConstants.gridCrossAxisCount,
      crossAxisSpacing: ProfileLayoutConstants.gridSpacing,
      mainAxisSpacing: ProfileLayoutConstants.gridSpacing,
      childAspectRatio: ProfileLayoutConstants.gridAspectRatio,
    );

    if (state.isRefreshing || (state.isInitialLoading && state.posts.isEmpty)) {
      return SliverGrid(
        gridDelegate: gridDelegate,
        delegate: SliverChildBuilderDelegate(
          (_, _) => SkeletonWidget(
            borderRadius: ProfileLayoutConstants.gridItemRadius,
          ),
          childCount: 9,
        ),
      );
    }

    if (state.posts.isEmpty) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 220,
          child: Center(
            child: CustomText(emptyMessage, variant: TextVariant.secondary),
          ),
        ),
      );
    }

    final showLoadMoreFooter =
        state.isLoadingMore && !state.hasReachedMax && state.posts.isNotEmpty;

    final grid = SliverGrid(
      gridDelegate: gridDelegate,
      delegate: SliverChildBuilderDelegate((context, index) {
        final post = state.posts[index];
        return ProfileGridTile(
          post: post,
          tabIndex: ProfileLayoutConstants.postsTabIndex,
          theme: Theme.of(context),
          onTap: () => openProfilePosts(
            context,
            posts: state.posts,
            initialIndex: index,
            source: ProfilePostsViewerSource.userPosts,
            page: state.page,
            hasReachedMax: state.hasReachedMax,
            userId: userId,
          ),
        );
      }, childCount: state.posts.length),
    );

    if (!showLoadMoreFooter) return grid;

    return SliverMainAxisGroup(
      slivers: [
        grid,
        const SliverToBoxAdapter(child: ProfilePostsLoadMoreFooter()),
      ],
    );
  }
}
