import 'dart:async';

import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/home/presentation/widgets/posts_search/posts_search_header.dart';
import 'package:bimobondapp/app/home/presentation/widgets/posts_search/search_history_section.dart';
import 'package:bimobondapp/app/home/presentation/widgets/posts_search/search_post_result_tile.dart';
import 'package:bimobondapp/app/home/presentation/widgets/posts_search/search_results_tabs.dart';
import 'package:bimobondapp/app/home/presentation/widgets/posts_search/search_trends_section.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/search/domain/entities/search_history_entity.dart';
import 'package:bimobondapp/app/search/domain/entities/search_result_entity.dart';
import 'package:bimobondapp/app/search/domain/entities/search_trend_entity.dart';
import 'package:bimobondapp/app/search/domain/usecases/add_search_history_usecase.dart';
import 'package:bimobondapp/app/search/domain/usecases/clear_search_history_usecase.dart';
import 'package:bimobondapp/app/search/domain/usecases/delete_search_history_usecase.dart';
import 'package:bimobondapp/app/search/domain/usecases/get_search_history_usecase.dart';
import 'package:bimobondapp/app/search/domain/usecases/get_search_trends_usecase.dart';
import 'package:bimobondapp/app/search/domain/usecases/search_usecase.dart';
import 'package:bimobondapp/app/search/presentation/di/search_injector.dart'
    as search_di;
import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/app/social/presentation/widgets/social_user_list_tile.dart';
import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/core/navigation/hashtag_navigation.dart';
import 'package:bimobondapp/core/navigation/post_navigation.dart';
import 'package:bimobondapp/core/navigation/sound_navigation.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/system_ui_overlay_utils.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class PostsSearchScreen extends StatefulWidget {
  const PostsSearchScreen({super.key});

  @override
  State<PostsSearchScreen> createState() => _PostsSearchScreenState();
}

class _PostsSearchScreenState extends State<PostsSearchScreen> {
  static const _pageSize = 20;
  static const _historyFetchLimit = 10;
  static const _historyCollapsedCount = 3;
  static const _trendsCollapsedCount = 5;
  static const _trendsFetchLimit = 10;
  static const _resultsCrossAxisCount = 2;
  static const _resultsSpacing = 8.0;
  static const _resultsAspectRatio = 0.58;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  String _activeQuery = '';
  bool _showResults = false;
  SearchResultsTab _resultsTab = SearchResultsTab.top;

  final List<PostEntity> _posts = [];
  final List<SocialUserEntity> _users = [];
  final List<SoundEntity> _sounds = [];
  final List<SearchHashtagEntity> _hashtags = [];

  bool _isLoadingResults = false;
  bool _isLoadingMore = false;
  bool _hasReachedMax = false;
  int _page = 1;

  final List<SearchHistoryEntity> _history = [];
  bool _isLoadingHistory = false;
  bool _historyExpanded = false;

  final List<SearchTrendEntity> _trends = [];
  bool _isLoadingTrends = false;
  bool _trendsExpanded = false;

  bool get _isAuthenticated {
    final auth = context.read<AuthBloc>().state;
    return auth is AuthSuccess;
  }

  String? get _currentUserId {
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthSuccess) return auth.user.id;
    return null;
  }

  SearchApiTab? get _apiTab {
    switch (_resultsTab) {
      case SearchResultsTab.top:
        return SearchApiTab.best;
      case SearchResultsTab.videos:
        return SearchApiTab.posts;
      case SearchResultsTab.users:
        return SearchApiTab.users;
      case SearchResultsTab.sounds:
        return SearchApiTab.sounds;
      case SearchResultsTab.places:
        return SearchApiTab.hashtags;
      case SearchResultsTab.live:
        return null;
    }
  }

  bool get _showsPostGrid =>
      _resultsTab == SearchResultsTab.top ||
      _resultsTab == SearchResultsTab.videos;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadHistory());
      unawaited(_loadTrends());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_showResults || _isLoadingResults || _isLoadingMore || _hasReachedMax) {
      return;
    }
    if (_resultsTab == SearchResultsTab.live || _apiTab == SearchApiTab.best) {
      return;
    }
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      unawaited(_loadResults());
    }
  }

  Future<void> _loadHistory() async {
    if (!_isAuthenticated) {
      setState(() {
        _history.clear();
        _isLoadingHistory = false;
      });
      return;
    }

    setState(() => _isLoadingHistory = true);
    final result = await search_di.sl<GetSearchHistoryUseCase>()(
      const GetSearchHistoryParams(
        category: SearchHistoryCategory.all,
        page: 1,
        limit: _historyFetchLimit,
      ),
    );
    if (!mounted) return;
    result.fold(
      (_) => setState(() => _isLoadingHistory = false),
      (page) => setState(() {
        _history
          ..clear()
          ..addAll(page.items);
        _isLoadingHistory = false;
      }),
    );
  }

  Future<void> _loadTrends() async {
    if (!_isAuthenticated) {
      setState(() {
        _trends.clear();
        _isLoadingTrends = false;
      });
      return;
    }

    setState(() => _isLoadingTrends = true);
    final result = await search_di.sl<GetSearchTrendsUseCase>()(
      const GetSearchTrendsParams(
        category: SearchHistoryCategory.all,
        limit: _trendsFetchLimit,
      ),
    );
    if (!mounted) return;
    result.fold(
      (_) => setState(() => _isLoadingTrends = false),
      (trends) => setState(() {
        _trends
          ..clear()
          ..addAll(trends);
        _isLoadingTrends = false;
      }),
    );
  }

  Future<void> _saveHistory(String query) async {
    if (!_isAuthenticated || query.isEmpty) return;
    await search_di.sl<AddSearchHistoryUseCase>()(
      AddSearchHistoryParams(
        query: query,
        category: SearchHistoryCategory.all,
      ),
    );
    if (!mounted) return;
    unawaited(_loadHistory());
  }

  Future<void> _deleteHistoryItem(SearchHistoryEntity item) async {
    setState(() => _history.removeWhere((e) => e.id == item.id));
    await search_di.sl<DeleteSearchHistoryUseCase>()(
      DeleteSearchHistoryParams(id: item.id),
    );
  }

  Future<void> _clearHistory() async {
    setState(() => _history.clear());
    await search_di.sl<ClearSearchHistoryUseCase>()(
      const ClearSearchHistoryParams(category: SearchHistoryCategory.all),
    );
  }

  void _clearField() {
    _searchController.clear();
    setState(() {
      _activeQuery = '';
      _showResults = false;
      _resultsTab = SearchResultsTab.top;
      _posts.clear();
      _users.clear();
      _sounds.clear();
      _hashtags.clear();
      _hasReachedMax = false;
      _page = 1;
    });
    _searchFocusNode.requestFocus();
  }

  void _runSearchFromHistory(SearchHistoryEntity item) {
    _searchController.text = item.query;
    _searchController.selection = TextSelection.collapsed(
      offset: item.query.length,
    );
    unawaited(_submitSearch(saveHistory: false));
  }

  void _runSearchFromTrend(SearchTrendEntity item) {
    _searchController.text = item.query;
    _searchController.selection = TextSelection.collapsed(
      offset: item.query.length,
    );
    unawaited(_submitSearch(saveHistory: true));
  }

  Future<void> _submitSearch({bool saveHistory = true}) async {
    final next = _searchController.text.trim();
    if (next.isEmpty) {
      _clearField();
      return;
    }

    if (next.startsWith('#') && next.length > 1) {
      openHashtagFeed(context, next);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _activeQuery = next;
      _showResults = true;
    });
    await _loadResults(refresh: true);
    if (saveHistory) {
      unawaited(_saveHistory(next));
    }
  }

  Future<void> _onTabChanged(SearchResultsTab tab) async {
    if (_resultsTab == tab) return;
    setState(() => _resultsTab = tab);
    if (!_showResults || _activeQuery.isEmpty) return;
    await _loadResults(refresh: true);
  }

  Future<void> _loadResults({bool refresh = false}) async {
    if (!_showResults || _activeQuery.isEmpty) return;
    final apiTab = _apiTab;
    if (apiTab == null) {
      setState(() {
        _isLoadingResults = false;
        _isLoadingMore = false;
        _posts.clear();
        _users.clear();
        _sounds.clear();
        _hashtags.clear();
      });
      return;
    }

    if (refresh) {
      if (_isLoadingResults) return;
      setState(() {
        _isLoadingResults = true;
        _hasReachedMax = false;
        _page = 1;
        _posts.clear();
        _users.clear();
        _sounds.clear();
        _hashtags.clear();
      });
    } else {
      if (_isLoadingMore || _hasReachedMax) return;
      setState(() => _isLoadingMore = true);
    }

    final page = refresh ? 1 : _page;
    final limit = apiTab == SearchApiTab.best ? 5 : _pageSize;
    final result = await search_di.sl<SearchUseCase>()(
      SearchParams(
        q: _activeQuery,
        tab: apiTab,
        page: page,
        limit: limit,
      ),
    );

    if (!mounted) return;

    result.fold(
      (_) {
        setState(() {
          _isLoadingResults = false;
          _isLoadingMore = false;
        });
      },
      (payload) {
        setState(() {
          if (refresh) {
            _posts
              ..clear()
              ..addAll(payload.posts);
            _users
              ..clear()
              ..addAll(payload.users);
            _sounds
              ..clear()
              ..addAll(payload.sounds);
            _hashtags
              ..clear()
              ..addAll(payload.hashtags);
            _page = 2;
          } else {
            final postIds = _posts.map((p) => p.id).toSet();
            _posts.addAll(payload.posts.where((p) => !postIds.contains(p.id)));
            final userIds = _users.map((u) => u.id).toSet();
            _users.addAll(payload.users.where((u) => !userIds.contains(u.id)));
            final soundIds = _sounds.map((s) => s.id).toSet();
            _sounds
                .addAll(payload.sounds.where((s) => !soundIds.contains(s.id)));
            final tagNames = _hashtags.map((h) => h.name).toSet();
            _hashtags.addAll(
              payload.hashtags.where((h) => !tagNames.contains(h.name)),
            );
            _page++;
          }

          final meta = switch (apiTab) {
            SearchApiTab.best => null,
            SearchApiTab.posts => payload.postsMeta,
            SearchApiTab.users => payload.usersMeta,
            SearchApiTab.sounds => payload.soundsMeta,
            SearchApiTab.hashtags => payload.hashtagsMeta,
          };
          if (apiTab == SearchApiTab.best) {
            _hasReachedMax = true;
          } else if (meta != null) {
            _hasReachedMax = !meta.hasMore;
          } else {
            final added = switch (apiTab) {
              SearchApiTab.posts => payload.posts.length,
              SearchApiTab.users => payload.users.length,
              SearchApiTab.sounds => payload.sounds.length,
              SearchApiTab.hashtags => payload.hashtags.length,
              SearchApiTab.best => 0,
            };
            _hasReachedMax = added < _pageSize;
          }

          _isLoadingResults = false;
          _isLoadingMore = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: appContentSystemUiOverlayStyle(theme.brightness),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              PostsSearchHeader(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onBack: () => context.pop(),
                onSearch: () => unawaited(_submitSearch()),
                onSubmitted: () => unawaited(_submitSearch()),
                onClear: _clearField,
                onChanged: (_) => setState(() {}),
                showMoreMenu: _showResults,
                onMore: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.searchComingSoon)),
                  );
                },
              ),
              if (_showResults)
                SearchResultsTabs(
                  selected: _resultsTab,
                  onChanged: (tab) => unawaited(_onTabChanged(tab)),
                ),
              Expanded(
                child: _showResults
                    ? _buildResults(l10n, theme)
                    : _buildIdle(l10n),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdle(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.45);
    final idleEmpty = !_isLoadingHistory &&
        !_isLoadingTrends &&
        _history.isEmpty &&
        _trends.isEmpty;

    if (idleEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.p16,
          40,
          AppSizes.p16,
          AppSizes.p16,
        ),
        child: Center(
          child: Text(
            l10n.searchHistoryEmpty,
            style: TextStyle(fontSize: 15, color: muted),
          ),
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        SearchHistorySection(
          items: _history,
          expanded: _historyExpanded,
          isLoading: _isLoadingHistory,
          collapsedCount: _historyCollapsedCount,
          onTapItem: _runSearchFromHistory,
          onDeleteItem: (item) => unawaited(_deleteHistoryItem(item)),
          onClearAll: () => unawaited(_clearHistory()),
          onToggleExpanded: () {
            setState(() => _historyExpanded = !_historyExpanded);
          },
        ),
        SearchTrendsSection(
          items: _trends,
          expanded: _trendsExpanded,
          isLoading: _isLoadingTrends,
          collapsedCount: _trendsCollapsedCount,
          onTapItem: _runSearchFromTrend,
          onToggleExpanded: () {
            setState(() => _trendsExpanded = !_trendsExpanded);
          },
        ),
        const SizedBox(height: AppSizes.p24),
      ],
    );
  }

  Widget _buildResults(AppLocalizations l10n, ThemeData theme) {
    if (_resultsTab == SearchResultsTab.live) {
      return _comingSoon(l10n, theme);
    }
    if (_showsPostGrid) return _buildPostGrid(l10n, theme);
    if (_resultsTab == SearchResultsTab.users) {
      return _buildUserList(l10n, theme);
    }
    if (_resultsTab == SearchResultsTab.sounds) {
      return _buildSoundList(l10n, theme);
    }
    if (_resultsTab == SearchResultsTab.places) {
      return _buildHashtagList(l10n, theme);
    }
    return _comingSoon(l10n, theme);
  }

  Widget _comingSoon(AppLocalizations l10n, ThemeData theme) {
    return Center(
      child: Text(
        l10n.searchComingSoon,
        style: TextStyle(
          fontSize: 15,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
        ),
      ),
    );
  }

  Widget _empty(AppLocalizations l10n, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p24),
        child: Text(
          l10n.searchNoResults,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }

  Widget _buildPostGrid(AppLocalizations l10n, ThemeData theme) {
    if (_isLoadingResults && _posts.isEmpty) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.p12,
          AppSizes.p8,
          AppSizes.p12,
          AppSizes.p16,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _resultsCrossAxisCount,
          crossAxisSpacing: _resultsSpacing,
          mainAxisSpacing: _resultsSpacing,
          childAspectRatio: _resultsAspectRatio,
        ),
        itemCount: 8,
        itemBuilder: (_, _) => const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: SkeletonWidget(borderRadius: 4)),
            SizedBox(height: 8),
            SkeletonWidget(height: 14, borderRadius: 4),
            SizedBox(height: 6),
            SkeletonWidget(height: 12, width: 90, borderRadius: 4),
          ],
        ),
      );
    }

    if (_posts.isEmpty) return _empty(l10n, theme);

    return RefreshIndicator(
      onRefresh: () => _loadResults(refresh: true),
      color: theme.primaryColor,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.p12,
              AppSizes.p8,
              AppSizes.p12,
              AppSizes.p16,
            ),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _resultsCrossAxisCount,
                crossAxisSpacing: _resultsSpacing,
                mainAxisSpacing: _resultsSpacing,
                childAspectRatio: _resultsAspectRatio,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final post = _posts[index];
                  return SearchPostResultTile(
                    post: post,
                    onTap: () => openPost(context, post),
                  );
                },
                childCount: _posts.length,
              ),
            ),
          ),
          if (_isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserList(AppLocalizations l10n, ThemeData theme) {
    if (_isLoadingResults && _users.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_users.isEmpty) return _empty(l10n, theme);

    return RefreshIndicator(
      onRefresh: () => _loadResults(refresh: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: _users.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _users.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final user = _users[index];
          return SocialUserListTile(
            user: user,
            isSelf: user.id == _currentUserId,
            hideFollowButton: true,
            onTap: () => openUserActiveStoriesOrProfile(
              context,
              userId: user.id,
              username: user.username,
              fullName: user.fullName,
              avatarUrl: user.avatarUrl,
              isFollowing: user.isFollowing,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSoundList(AppLocalizations l10n, ThemeData theme) {
    if (_isLoadingResults && _sounds.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_sounds.isEmpty) return _empty(l10n, theme);

    return RefreshIndicator(
      onRefresh: () => _loadResults(refresh: true),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: _sounds.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index >= _sounds.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final sound = _sounds[index];
          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: sound.resolvedCoverUrl != null
                    ? SafeNetworkImage(
                        imageUrl: sound.resolvedCoverUrl!,
                        fit: BoxFit.cover,
                      )
                    : ColoredBox(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(LucideIcons.music),
                      ),
              ),
            ),
            title: Text(
              sound.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              sound.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => unawaited(
              openSoundDetail(
                context,
                soundId: sound.id,
                preview: sound,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHashtagList(AppLocalizations l10n, ThemeData theme) {
    if (_isLoadingResults && _hashtags.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_hashtags.isEmpty) return _empty(l10n, theme);

    return RefreshIndicator(
      onRefresh: () => _loadResults(refresh: true),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: _hashtags.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index >= _hashtags.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final tag = _hashtags[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: const Icon(LucideIcons.hash, size: 20),
            ),
            title: Text(tag.displayName),
            subtitle: tag.postCount > 0
                ? Text(l10n.hashtagPostCount(tag.postCount))
                : null,
            onTap: () => openHashtagFeed(context, tag.name),
          );
        },
      ),
    );
  }
}
