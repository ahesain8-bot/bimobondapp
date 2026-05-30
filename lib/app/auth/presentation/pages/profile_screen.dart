import 'dart:async';

import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_event.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_header_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_header_section.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_icon_tab_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_posts_grid_sliver.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_tab_posts_state.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:bimobondapp/app/social/presentation/pages/user_connections_screen.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
  final List<ProfileTabPostsState> _tabPosts = List.generate(
    ProfileLayoutConstants.tabCount,
    (_) => ProfileTabPostsState(),
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

  Future<void> _refreshProfileAfterNavigation(
    Future<Object?> navigation,
  ) async {
    await navigation;
    if (!mounted) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) return;

    context.read<AuthBloc>().add(const FetchProfileEvent());
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
        limit: ProfileTabPostsState.pageSize,
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

  void _mergeTabPosts(ProfileTabPostsState tab, List<PostEntity> incoming) {
    if (tab.page == 1) {
      tab.posts
        ..clear()
        ..addAll(incoming);
    } else {
      final existingIds = tab.posts.map((p) => p.id).toSet();
      tab.posts.addAll(incoming.where((p) => !existingIds.contains(p.id)));
    }
  }

  Future<void> _onPullToRefresh() async {
    final tab = _tabPosts[_selectedTabIndex];
    _pullRefreshCompleter = Completer<void>();
    setState(() => tab.isRefreshing = true);
    context.read<AuthBloc>().add(const FetchProfileEvent());
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
                        child: ProfileHeaderBar(
                          username: '@$username',
                          onSettings: () => _refreshProfileAfterNavigation(
                            context.pushNamed('settings'),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: ProfileHeaderSection(
                          user: user,
                          l10n: l10n,
                          onEditProfile: () => _refreshProfileAfterNavigation(
                            context.pushNamed('personal_info'),
                          ),
                          onFollowersTap: () => _refreshProfileAfterNavigation(
                            context.pushNamed(
                              'user_connections',
                              extra: {
                                'userId': user.id,
                                'type': UserConnectionType.followers,
                              },
                            ),
                          ),
                          onFollowingTap: () => _refreshProfileAfterNavigation(
                            context.pushNamed(
                              'user_connections',
                              extra: {
                                'userId': user.id,
                                'type': UserConnectionType.following,
                              },
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: ProfileIconTabBar(
                          selectedIndex: _selectedTabIndex,
                          onSelected: _onTabSelected,
                          backgroundColor: theme.scaffoldBackgroundColor,
                        ),
                      ),
                      ProfilePostsGridSliver(
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
