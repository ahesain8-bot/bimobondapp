import 'dart:async';

import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/navigation/post_navigation.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/core/widgets/video_post_preview_placeholder.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_event.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class _ProfileTabPostsState {
  static const int pageSize = ProfileLayoutConstants.postsPageSize;

  final List<PostEntity> posts = [];
  int page = 1;
  bool hasReachedMax = false;
  bool isLoadingMore = false;
  bool isInitialLoading = true;
  bool isRefreshing = false;
  int? pendingLoadKey;
}

class ProfileScreen extends StatefulWidget {
  final bool isTabActive;

  const ProfileScreen({super.key, this.isTabActive = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  int _selectedTabIndex = 0;
  int? _fetchingForTabIndex;
  int _profileLoadKey = 0;
  Completer<void>? _pullRefreshCompleter;
  final ScrollController _scrollController = ScrollController();
  final List<_ProfileTabPostsState> _tabPosts = List.generate(
    ProfileLayoutConstants.tabCount,
    (_) => _ProfileTabPostsState(),
  );

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onProfileScroll);
    if (widget.isTabActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadTabData());
    }
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTabActive && !oldWidget.isTabActive) {
      _loadTabData();
    }
  }

  void _loadTabData() {
    _loadProfile();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onProfileScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onProfileScroll() {
    if (!_scrollController.hasClients) return;
    final tab = _tabPosts[_selectedTabIndex];
    if (tab.hasReachedMax || tab.isLoadingMore || tab.isRefreshing) return;

    final position = _scrollController.position;
    if (position.pixels >=
        position.maxScrollExtent -
            ProfileLayoutConstants.scrollLoadMoreThreshold) {
      _fetchUserPosts(loadMore: true);
    }
  }

  void _loadProfile() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) return;

    context.read<AuthBloc>().add(const FetchProfileEvent());
    _fetchUserPosts(refresh: true);
  }

  void _onTabSelected(int index) {
    if (_selectedTabIndex == index) return;
    setState(() => _selectedTabIndex = index);
    final tab = _tabPosts[index];
    if (tab.posts.isEmpty) {
      _fetchUserPosts(refresh: true);
    }
  }

  void _fetchUserPosts({bool refresh = false, bool loadMore = false}) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) return;

    final tab = _tabPosts[_selectedTabIndex];

    if (loadMore) {
      if (tab.hasReachedMax || tab.isLoadingMore) return;
      tab.isLoadingMore = true;
      tab.page++;
    } else {
      if (refresh) {
        tab.page = 1;
        tab.hasReachedMax = false;
        tab.isInitialLoading = tab.posts.isEmpty;
      } else if (tab.posts.isNotEmpty) {
        return;
      } else {
        tab.page = 1;
        tab.hasReachedMax = false;
        tab.isInitialLoading = true;
      }
    }

    final loadKey = ++_profileLoadKey;
    tab.pendingLoadKey = loadKey;
    _fetchingForTabIndex = _selectedTabIndex;

    final bool? isLiked = _selectedTabIndex == 1 ? true : null;
    final bool? isSaved = _selectedTabIndex == 2 ? true : null;

    context.read<PostsBloc>().add(
      FetchFeedRequestedEvent(
        page: tab.page,
        limit: _ProfileTabPostsState.pageSize,
        userId: authState.user.id,
        isRefresh: refresh || tab.page == 1,
        isLiked: isLiked,
        isSaved: isSaved,
        profileLoadKey: loadKey,
      ),
    );
  }

  void _completePullRefreshIfNeeded() {
    final completer = _pullRefreshCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    _pullRefreshCompleter = null;
  }

  bool _isStaleProfileLoad(int tabIndex, int? loadKey) {
    if (loadKey == null) return true;
    return _tabPosts[tabIndex].pendingLoadKey != loadKey;
  }

  String _emptyMessageForTab(AppLocalizations l10n) {
    switch (_selectedTabIndex) {
      case 1:
        return l10n.noLikedPosts;
      case 2:
        return l10n.noSavedPosts;
      default:
        return l10n.noPostsYet;
    }
  }

  void _mergeTabPosts(_ProfileTabPostsState tab, List<PostEntity> incoming) {
    if (tab.page == 1) {
      tab.posts
        ..clear()
        ..addAll(incoming);
    } else {
      final existingIds = tab.posts.map((p) => p.id).toSet();
      tab.posts.addAll(incoming.where((p) => !existingIds.contains(p.id)));
    }
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

  Future<void> _onPullToRefresh() async {
    final tab = _tabPosts[_selectedTabIndex];
    _pullRefreshCompleter = Completer<void>();
    setState(() => tab.isRefreshing = true);
    _fetchUserPosts(refresh: true);

    try {
      await _pullRefreshCompleter!.future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      if (mounted) {
        setState(() {
          tab.isRefreshing = false;
          tab.isInitialLoading = false;
        });
      }
    } finally {
      _pullRefreshCompleter = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthSuccess &&
            _tabPosts[_selectedTabIndex].posts.isEmpty &&
            !_tabPosts[_selectedTabIndex].isInitialLoading) {
          _fetchUserPosts(refresh: true);
        }
      },
      child: BlocListener<PostsBloc, PostsState>(
        listener: (context, state) {
          if (state is ProfilePostsLoadSuccess &&
              _fetchingForTabIndex != null) {
            final tabIndex = _fetchingForTabIndex!;
            if (_isStaleProfileLoad(tabIndex, state.profileLoadKey)) return;

            final tab = _tabPosts[tabIndex];
            setState(() {
              _mergeTabPosts(tab, state.posts);
              tab.hasReachedMax = state.hasReachedMax;
              tab.isLoadingMore = false;
              tab.isInitialLoading = false;
              tab.isRefreshing = false;
            });
            _completePullRefreshIfNeeded();
          } else if (state is PostsFailure) {
            final tabIndex = _fetchingForTabIndex ?? _selectedTabIndex;
            if (state.profileLoadKey != null &&
                _isStaleProfileLoad(tabIndex, state.profileLoadKey)) {
              return;
            }

            setState(() {
              final tab = _tabPosts[tabIndex];
              if (tab.isLoadingMore && tab.page > 1) {
                tab.page--;
              }
              tab.isLoadingMore = false;
              tab.isInitialLoading = false;
              tab.isRefreshing = false;
            });
            _completePullRefreshIfNeeded();
          } else if (state is UpdatePostSuccess || state is DeletePostSuccess) {
            final tab = _tabPosts[_selectedTabIndex];
            tab.page = 1;
            tab.hasReachedMax = false;
            tab.isInitialLoading = tab.posts.isEmpty;
            _fetchUserPosts(refresh: true);
          }
        },
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            if (authState is! AuthSuccess) {
              return const ProfileSkeleton();
            }

            final user = authState.user;
            final theme = Theme.of(context);
            final username = user.username ?? 'username';

            return Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              body: SafeArea(
                bottom: false,
                child: RefreshIndicator(
                  onRefresh: _onPullToRefresh,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _ProfileHeaderBar(
                          username: '@$username',
                          onSettings: () => context.pushNamed('settings'),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal:
                                ProfileLayoutConstants.headerHorizontalPadding,
                          ),
                          child: Column(
                            children: [
                              _ProfileAvatar(user: user, theme: theme),
                              const SizedBox(height: AppSizes.p12),
                              Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  textDirection: TextDirection.ltr,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        user.fullName ?? username,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 18,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    const SizedBox(
                                      width: ProfileLayoutConstants
                                          .editPillGapFromName,
                                    ),
                                    _ProfileEditPillButton(
                                      onPressed: () =>
                                          context.pushNamed('personal_info'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSizes.p6),
                              CustomText(
                                '@$username',
                                fontSize: 14,
                                variant: TextVariant.secondary,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSizes.p16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _ProfileStatItem(
                                    number: _formatCount(
                                      user.followingCount ?? 0,
                                    ),
                                    label: l10n.following,
                                  ),
                                  _ProfileStatItem(
                                    number: _formatCount(
                                      user.followerCount ?? 0,
                                    ),
                                    label: l10n.followers,
                                  ),
                                  _ProfileStatItem(
                                    number: _formatCount(user.totalLikes ?? 0),
                                    label: l10n.likes,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSizes.p12),
                              CustomText(
                                user.bio ?? l10n.noBio,
                                fontSize: 14,
                                variant: TextVariant.secondary,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _ProfileIconTabBar(
                          selectedIndex: _selectedTabIndex,
                          onSelected: _onTabSelected,
                          backgroundColor: theme.scaffoldBackgroundColor,
                        ),
                      ),
                      _ProfilePostsGridSliver(
                        tab: _tabPosts[_selectedTabIndex],
                        tabIndex: _selectedTabIndex,
                        emptyMessage: _emptyMessageForTab(l10n),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileHeaderBar extends StatelessWidget {
  final String username;
  final VoidCallback onSettings;

  const _ProfileHeaderBar({required this.username, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ProfileLayoutConstants.headerHorizontalPadding,
        vertical: ProfileLayoutConstants.headerVerticalPadding,
      ),
      child: Row(
        children: [
          const SizedBox(width: 48),
          Expanded(
            child: CustomText(
              username,
              textAlign: TextAlign.center,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            onPressed: onSettings,
            icon: Icon(
              LucideIcons.menu,
              size: ProfileLayoutConstants.headerMenuIconSize,
              color: theme.iconTheme.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final UserEntity user;
  final ThemeData theme;

  const _ProfileAvatar({required this.user, required this.theme});

  @override
  Widget build(BuildContext context) {
    return SafeNetworkAvatar(
      imageUrl: user.avatarUrl,
      radius: ProfileLayoutConstants.avatarRadius,
      fallbackText: user.username,
      backgroundColor: theme.dividerColor.withValues(alpha: 0.08),
    );
  }
}

class _ProfileEditPillButton extends StatelessWidget {
  const _ProfileEditPillButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.85)
        : ProfileLayoutConstants.editPillBackgroundLight;

    return Semantics(
      button: true,
      label: l10n.edit,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(
          ProfileLayoutConstants.editPillHeight / 2,
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(
            ProfileLayoutConstants.editPillHeight / 2,
          ),
          child: SizedBox(
            width: ProfileLayoutConstants.editPillHeight,
            height: ProfileLayoutConstants.editPillHeight,
            child: Icon(
              LucideIcons.userPen,
              size: ProfileLayoutConstants.editPillIconSize,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileStatItem extends StatelessWidget {
  final String number;
  final String label;

  const _ProfileStatItem({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomText(number, fontSize: 18, fontWeight: FontWeight.bold),
        const SizedBox(height: AppSizes.p4),
        CustomText(label, fontSize: 13, variant: TextVariant.secondary),
      ],
    );
  }
}

class _ProfileIconTabBar extends StatelessWidget {
  const _ProfileIconTabBar({
    required this.selectedIndex,
    required this.onSelected,
    required this.backgroundColor,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ColoredBox(
      color: backgroundColor,
      child: Column(
        children: [
          SizedBox(
            height: ProfileLayoutConstants.iconTabBarHeight,
            child: Row(
              children: [
                _ProfileIconTab(
                  isSelected: selectedIndex == 0,
                  icon: LucideIcons.layoutGrid,
                  colorScheme: colorScheme,
                  theme: theme,
                  onTap: () => onSelected(0),
                ),
                _ProfileIconTab(
                  isSelected: selectedIndex == 1,
                  icon: LucideIcons.heart,
                  colorScheme: colorScheme,
                  theme: theme,
                  onTap: () => onSelected(1),
                ),
                _ProfileIconTab(
                  isSelected: selectedIndex == 2,
                  icon: LucideIcons.bookmark,
                  colorScheme: colorScheme,
                  theme: theme,
                  onTap: () => onSelected(2),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: theme.dividerColor.withValues(alpha: 0.15),
          ),
        ],
      ),
    );
  }
}

class _ProfileIconTab extends StatelessWidget {
  const _ProfileIconTab({
    required this.isSelected,
    required this.icon,
    required this.colorScheme,
    required this.theme,
    required this.onTap,
  });

  final bool isSelected;
  final IconData icon;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: ProfileLayoutConstants.iconTabSize,
              color: isSelected
                  ? colorScheme.primary
                  : theme.iconTheme.color?.withValues(alpha: 0.45),
            ),
            const SizedBox(height: AppSizes.p6),
            AnimatedContainer(
              duration: ProfileLayoutConstants.tabAnimationDuration,
              height: ProfileLayoutConstants.iconTabIndicatorHeight,
              width: isSelected
                  ? ProfileLayoutConstants.iconTabIndicatorWidth
                  : 0,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePostsGridSliver extends StatelessWidget {
  final _ProfileTabPostsState tab;
  final int tabIndex;
  final String emptyMessage;

  const _ProfilePostsGridSliver({
    required this.tab,
    required this.tabIndex,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    const gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: ProfileLayoutConstants.gridCrossAxisCount,
      crossAxisSpacing: ProfileLayoutConstants.gridSpacing,
      mainAxisSpacing: ProfileLayoutConstants.gridSpacing,
      childAspectRatio: ProfileLayoutConstants.gridAspectRatio,
    );

    if (tab.isRefreshing || (tab.isInitialLoading && tab.posts.isEmpty)) {
      return SliverGrid(
        gridDelegate: gridDelegate,
        delegate: SliverChildBuilderDelegate(
          (context, index) =>
              const SkeletonWidget(borderRadius: AppSizes.radiusSm),
          childCount: 9,
        ),
      );
    }

    if (tab.posts.isEmpty) {
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
        tab.posts.length + (tab.isLoadingMore && !tab.hasReachedMax ? 1 : 0);

    return SliverGrid(
      gridDelegate: gridDelegate,
      delegate: SliverChildBuilderDelegate((context, index) {
        if (tab.isLoadingMore &&
            !tab.hasReachedMax &&
            index == tab.posts.length) {
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final post = tab.posts[index];
        return _ProfileGridTile(
          post: post,
          tabIndex: tabIndex,
          theme: theme,
          onTap: () => openPost(context, post),
        );
      }, childCount: itemCount),
    );
  }
}

class _ProfileGridTile extends StatelessWidget {
  final PostEntity post;
  final int tabIndex;
  final ThemeData theme;
  final VoidCallback onTap;

  const _ProfileGridTile({
    required this.post,
    required this.tabIndex,
    required this.theme,
    required this.onTap,
  });

  String? _resolveImageUrl() {
    if (post.thumbnailUrl != null && MediaUtils.isImage(post.thumbnailUrl!)) {
      return post.thumbnailUrl;
    }
    if (post.media.isNotEmpty) {
      final first = post.media.first;
      if (MediaUtils.isImage(first.url, mediaType: first.mediaType)) {
        return first.url;
      }
    }
    return null;
  }

  bool _isVideoPost() {
    if (post.type.toUpperCase() == 'VIDEO') return true;
    return post.media.any(
      (m) => MediaUtils.isVideo(m.url, mediaType: m.mediaType),
    );
  }

  bool get _isAuctionPost => post.isAuctionable;

  _ProfileAuctionStatus _auctionStatus(AppLocalizations l10n) {
    if (!_isAuctionPost) return _ProfileAuctionStatus.none;

    final auction = post.auction;
    if (auction == null) {
      return _ProfileAuctionStatus(
        label: l10n.profilePostAuction,
        borderColor: LiveDetailsLayoutConstants.giftCommentGold,
        badgeBackground: LiveDetailsLayoutConstants.auctionActiveBadgeDark,
        badgeForeground: Colors.white,
      );
    }

    final now = DateTime.now().toUtc();
    final start = auction.startedAt.toUtc();
    final end = auction.endedAt.toUtc();

    if (now.isAfter(end)) {
      return _ProfileAuctionStatus(
        label: l10n.auctionFinishedBadge,
        borderColor: LiveDetailsLayoutConstants.auctionFinishedBadgeColor,
        badgeBackground: LiveDetailsLayoutConstants.auctionFinishedBadgeDark,
        badgeForeground: Colors.white,
      );
    }

    if (now.isBefore(start)) {
      return _ProfileAuctionStatus(
        label: l10n.auctionStartsIn,
        borderColor: LiveDetailsLayoutConstants.giftCommentGold,
        badgeBackground: LiveDetailsLayoutConstants.auctionActiveBadgeDark,
        badgeForeground: Colors.white,
      );
    }

    return _ProfileAuctionStatus(
      label: l10n.auctionActiveBadge,
      borderColor: LiveDetailsLayoutConstants.auctionActiveBadgeColor,
      badgeBackground: LiveDetailsLayoutConstants.auctionActiveBadgeDark,
      badgeForeground: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final imageUrl = _resolveImageUrl();
    final isPostsTab = tabIndex == 0;
    final isVideo = isPostsTab && _isVideoPost() && !_isAuctionPost;
    final auctionStatus = _auctionStatus(l10n);
    final isAuction = _isAuctionPost;
    final placeholderColor = theme.dividerColor.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.12 : 0.06,
    );
    final itemName = post.auction?.itemName;

    return Material(
      color: isVideo ? Colors.black : placeholderColor,
      borderRadius: BorderRadius.circular(
        ProfileLayoutConstants.gridItemRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isVideo)
              const VideoPostPreviewPlaceholder(
                iconSize: ProfileLayoutConstants.gridPlaceholderIconSize,
              )
            else if (imageUrl != null &&
                imageUrl.isNotEmpty &&
                isValidNetworkImageUrl(imageUrl))
              SafeNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorIcon: isAuction
                    ? Icons.gavel_outlined
                    : Icons.image_outlined,
              )
            else
              _placeholderIcon(false, isAuction),
            if (isAuction)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),
              ),
            if (isAuction)
              Positioned(
                top: AppSizes.p6,
                left: AppSizes.p6,
                child: _AuctionBadge(status: auctionStatus),
              ),
            if (isAuction && itemName != null && itemName.isNotEmpty)
              Positioned(
                left: AppSizes.p6,
                right: AppSizes.p6,
                bottom: AppSizes.p6,
                child: Text(
                  itemName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            if (isAuction)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        ProfileLayoutConstants.gridItemRadius,
                      ),
                      border: Border.all(
                        color: auctionStatus.borderColor.withValues(alpha: 0.9),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderIcon(bool isVideo, bool isAuction) {
    final IconData icon;
    final Color color;

    if (tabIndex == 1) {
      icon = LucideIcons.heart;
      color = theme.colorScheme.primary.withValues(alpha: 0.35);
    } else if (tabIndex == 2) {
      icon = LucideIcons.bookmark;
      color = theme.colorScheme.secondary.withValues(alpha: 0.35);
    } else if (isAuction) {
      icon = LucideIcons.gavel;
      color = LiveDetailsLayoutConstants.giftCommentGold.withValues(
        alpha: 0.65,
      );
    } else {
      icon = isVideo ? Icons.play_arrow_rounded : Icons.image_outlined;
      color = theme.colorScheme.onSurface.withValues(alpha: 0.3);
    }

    return Center(
      child: Icon(
        icon,
        size: ProfileLayoutConstants.gridPlaceholderIconSize,
        color: color,
      ),
    );
  }
}

class _ProfileAuctionStatus {
  const _ProfileAuctionStatus({
    required this.label,
    required this.borderColor,
    required this.badgeBackground,
    required this.badgeForeground,
  });

  static const none = _ProfileAuctionStatus(
    label: '',
    borderColor: Colors.transparent,
    badgeBackground: Colors.transparent,
    badgeForeground: Colors.transparent,
  );

  final String label;
  final Color borderColor;
  final Color badgeBackground;
  final Color badgeForeground;
}

class _AuctionBadge extends StatelessWidget {
  const _AuctionBadge({required this.status});

  final _ProfileAuctionStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p6,
        vertical: AppSizes.p4,
      ),
      decoration: BoxDecoration(
        color: status.badgeBackground.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppSizes.p8),
        border: Border.all(color: status.borderColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.gavel, size: 12, color: status.badgeForeground),
          const SizedBox(width: AppSizes.p4),
          Text(
            status.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: status.badgeForeground,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
