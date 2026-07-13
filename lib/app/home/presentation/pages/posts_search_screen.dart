import 'dart:async';

import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/home/presentation/widgets/posts_search/posts_search_header.dart';
import 'package:bimobondapp/app/home/presentation/widgets/posts_search/search_history_section.dart';
import 'package:bimobondapp/app/home/presentation/widgets/posts_search/search_post_result_tile.dart';
import 'package:bimobondapp/app/home/presentation/widgets/posts_search/search_results_tabs.dart';
import 'package:bimobondapp/app/home/presentation/widgets/posts_search/search_trends_section.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_feed_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart'
    as posts_di;
import 'package:bimobondapp/app/search/domain/entities/search_history_entity.dart';
import 'package:bimobondapp/app/search/domain/entities/search_trend_entity.dart';
import 'package:bimobondapp/app/search/domain/usecases/add_search_history_usecase.dart';
import 'package:bimobondapp/app/search/domain/usecases/clear_search_history_usecase.dart';
import 'package:bimobondapp/app/search/domain/usecases/delete_search_history_usecase.dart';
import 'package:bimobondapp/app/search/domain/usecases/get_search_history_usecase.dart';
import 'package:bimobondapp/app/search/domain/usecases/get_search_trends_usecase.dart';
import 'package:bimobondapp/app/search/presentation/di/search_injector.dart'
    as search_di;
import 'package:bimobondapp/core/navigation/hashtag_navigation.dart';
import 'package:bimobondapp/core/navigation/post_navigation.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class PostsSearchScreen extends StatefulWidget {
  const PostsSearchScreen({super.key});

  @override
  State<PostsSearchScreen> createState() => _PostsSearchScreenState();
}

class _PostsSearchScreenState extends State<PostsSearchScreen> {
  static const _pageSize = 30;
  static const _historyFetchLimit = 10;
  static const _historyCollapsedCount = 3;
  static const _trendsCollapsedCount = 5;
  static const _trendsFetchLimit = 10;
  static const _resultsCrossAxisCount = 2;
  static const _resultsSpacing = 8.0;
  /// Cover + caption + meta row (TikTok search card).
  static const _resultsAspectRatio = 0.58;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  String _activeQuery = '';
  bool _showResults = false;
  SearchResultsTab _resultsTab = SearchResultsTab.videos;

  final List<PostEntity> _posts = [];
  bool _isLoadingPosts = false;
  bool _isLoadingMorePosts = false;
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
    if (!_showResults || _isLoadingPosts || _isLoadingMorePosts || _hasReachedMax) {
      return;
    }
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      unawaited(_loadPosts());
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
        category: SearchHistoryCategory.posts,
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
        category: SearchHistoryCategory.posts,
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
        category: SearchHistoryCategory.posts,
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
      const ClearSearchHistoryParams(category: SearchHistoryCategory.posts),
    );
  }

  void _clearField() {
    _searchController.clear();
    setState(() {
      _activeQuery = '';
      _showResults = false;
      _resultsTab = SearchResultsTab.videos;
      _posts.clear();
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
    await _loadPosts(refresh: true);
    if (saveHistory) {
      unawaited(_saveHistory(next));
    }
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (!_showResults || _activeQuery.isEmpty) return;

    if (refresh) {
      if (_isLoadingPosts) return;
      setState(() {
        _isLoadingPosts = true;
        _hasReachedMax = false;
        _page = 1;
        _posts.clear();
      });
    } else {
      if (_isLoadingMorePosts || _hasReachedMax) return;
      setState(() => _isLoadingMorePosts = true);
    }

    final result = await posts_di.sl<GetFeedUseCase>()(
      GetFeedParams(
        page: refresh ? 1 : _page,
        limit: _pageSize,
        search: _activeQuery,
        isStory: false,
      ),
    );

    if (!mounted) return;

    result.fold(
      (_) {
        setState(() {
          _isLoadingPosts = false;
          _isLoadingMorePosts = false;
        });
      },
      (items) {
        final posts = items.map((item) => item.post).toList();
        setState(() {
          if (refresh) {
            _posts
              ..clear()
              ..addAll(posts);
            _page = 2;
          } else {
            final existingIds = _posts.map((p) => p.id).toSet();
            _posts.addAll(posts.where((p) => !existingIds.contains(p.id)));
            _page++;
          }
          _hasReachedMax = posts.length < _pageSize;
          _isLoadingPosts = false;
          _isLoadingMorePosts = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
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
                onChanged: (tab) {
                  setState(() => _resultsTab = tab);
                },
              ),
            Expanded(
              child: _showResults
                  ? _buildResults(l10n, theme)
                  : _buildIdle(l10n),
            ),
          ],
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
    if (!_showsPostGrid) {
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

    if (_isLoadingPosts && _posts.isEmpty) {
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

    if (_posts.isEmpty) {
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

    return RefreshIndicator(
      onRefresh: () => _loadPosts(refresh: true),
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
          if (_isLoadingMorePosts)
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
}
