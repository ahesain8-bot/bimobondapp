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
import 'package:bimobondapp/app/social/domain/usecases/toggle_follow_usecase.dart';
import 'package:bimobondapp/app/social/presentation/di/social_injector.dart'
    as social_di;
import 'package:bimobondapp/app/social/presentation/pages/user_connections_screen.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/navigation/post_navigation.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/core/widgets/video_post_preview_placeholder.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
      _postsState.isLoadingMore = true;
      _postsState.page++;
    } else if (refresh) {
      _postsState.page = 1;
      _postsState.hasReachedMax = false;
      _postsState.isInitialLoading = _postsState.posts.isEmpty;
    } else if (_postsState.posts.isNotEmpty) {
      return;
    } else {
      _postsState.page = 1;
      _postsState.hasReachedMax = false;
      _postsState.isInitialLoading = true;
    }

    final loadKey = ++_profileLoadKey;
    _postsState.pendingLoadKey = loadKey;
    _fetchingLoadKey = loadKey;

    context.read<PostsBloc>().add(
      FetchFeedRequestedEvent(
        page: _postsState.page,
        limit: _UserProfilePostsState.pageSize,
        userId: widget.userId,
        isRefresh: refresh || _postsState.page == 1,
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

    final result = await social_di.sl<ToggleFollowUseCase>()(
      ToggleFollowParams(widget.userId),
    );
    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _isFollowing = previousFollowing;
          _isFollowLoading = false;
        });
        PopupDialogs.showErrorDialog(context, failure.message);
      },
      (_) {
        setState(() {
          _isFollowing = !previousFollowing;
          _isFollowLoading = false;
        });
        unawaited(_loadUser(showLoadingShell: false));
      },
    );
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
                              SafeNetworkAvatar(
                                imageUrl: user?.avatarUrl,
                                radius: ProfileLayoutConstants.avatarRadius,
                                fallbackText: user?.username ?? username,
                                backgroundColor: theme.dividerColor.withValues(
                                  alpha: 0.08,
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
                                  SizedBox(
                                    width: 140,
                                    height: 40,
                                    child: ElevatedButton(
                                      onPressed: _isFollowLoading
                                          ? null
                                          : _toggleFollow,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _isFollowing
                                            ? theme.dividerColor.withValues(
                                                alpha: 0.2,
                                              )
                                            : theme.colorScheme.primary,
                                        foregroundColor: _isFollowing
                                            ? theme.colorScheme.onSurface
                                            : Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppSizes.radiusMd,
                                          ),
                                        ),
                                      ),
                                      child: _isFollowLoading
                                          ? SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: _isFollowing
                                                    ? theme.colorScheme
                                                        .onSurface
                                                    : Colors.white,
                                              ),
                                            )
                                          : CustomText(
                                              _isFollowing
                                                  ? l10n.messagesFollowing
                                                  : l10n.messagesFollow,
                                              fontWeight: FontWeight.bold,
                                              color: _isFollowing
                                                  ? theme.colorScheme.onSurface
                                                  : Colors.white,
                                            ),
                                    ),
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
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                            )
                                          : CustomText(
                                              l10n.profileMessageButton,
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.primary,
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: AppSizes.p16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _UserProfileStatItem(
                                  number: _formatCount(user?.postCount ?? 0),
                                  label: l10n.profilePostsTab,
                                ),
                                _UserProfileStatItem(
                                  number: _formatCount(
                                    user?.followerCount ?? 0,
                                  ),
                                  label: l10n.followers,
                                  onTap: () => _refreshProfileAfterNavigation(
                                    context.pushNamed(
                                      'user_connections',
                                      extra: {
                                        'userId': widget.userId,
                                        'type': UserConnectionType.followers,
                                      },
                                    ),
                                  ),
                                ),
                                _UserProfileStatItem(
                                  number: _formatCount(
                                    user?.followingCount ?? 0,
                                  ),
                                  label: l10n.following,
                                  onTap: () => _refreshProfileAfterNavigation(
                                    context.pushNamed(
                                      'user_connections',
                                      extra: {
                                        'userId': widget.userId,
                                        'type': UserConnectionType.following,
                                      },
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
                            CustomText(
                              user?.bio?.trim().isNotEmpty == true
                                  ? user!.bio!.trim()
                                  : l10n.noBio,
                              fontSize: 14,
                              variant: TextVariant.secondary,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSizes.p16),
                            Divider(
                              color: theme.dividerColor.withValues(alpha: 0.15),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _UserProfilePostsGrid(
                      state: _postsState,
                      emptyMessage: l10n.noPostsYet,
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
      children: [
        CustomText(number, fontSize: 18, fontWeight: FontWeight.bold),
        const SizedBox(height: AppSizes.p4),
        CustomText(label, fontSize: 13, variant: TextVariant.secondary),
      ],
    );

    if (onTap == null) return content;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.p12,
          vertical: AppSizes.p4,
        ),
        child: content,
      ),
    );
  }
}

class _UserProfilePostsGrid extends StatelessWidget {
  const _UserProfilePostsGrid({
    required this.state,
    required this.emptyMessage,
  });

  final _UserProfilePostsState state;
  final String emptyMessage;

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
          (_, _) => const SkeletonWidget(borderRadius: AppSizes.radiusSm),
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

    final itemCount =
        state.posts.length +
        (state.isLoadingMore && !state.hasReachedMax ? 1 : 0);

    return SliverGrid(
      gridDelegate: gridDelegate,
      delegate: SliverChildBuilderDelegate((context, index) {
        if (state.isLoadingMore &&
            !state.hasReachedMax &&
            index == state.posts.length) {
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final post = state.posts[index];
        return _UserProfileGridTile(
          post: post,
          onTap: () => openPost(context, post),
        );
      }, childCount: itemCount),
    );
  }
}

class _UserProfileGridTile extends StatelessWidget {
  const _UserProfileGridTile({required this.post, required this.onTap});

  final PostEntity post;
  final VoidCallback onTap;

  bool _isVideoPost() {
    if (post.type.toUpperCase() == 'VIDEO') return true;
    return post.media.any(
      (m) => MediaUtils.isVideo(m.url, mediaType: m.mediaType),
    );
  }

  String? _resolveImageUrl() {
    if (post.thumbnailUrl != null && MediaUtils.isImage(post.thumbnailUrl!)) {
      return post.thumbnailUrl;
    }
    for (final media in post.media) {
      if (MediaUtils.isImage(media.url, mediaType: media.mediaType)) {
        return media.url;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolveImageUrl();

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: _isVideoPost()
            ? const VideoPostPreviewPlaceholder(
                iconSize: 28,
                icon: LucideIcons.play,
              )
            : imageUrl != null
            ? SafeNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              )
            : ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  LucideIcons.image,
                  color: Theme.of(context).disabledColor,
                ),
              ),
      ),
    );
  }
}
