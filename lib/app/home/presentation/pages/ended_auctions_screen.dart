import 'dart:async';

import 'package:bimobondapp/app/categories/domain/entities/category_entity.dart';
import 'package:bimobondapp/app/categories/domain/usecases/get_categories_usecase.dart';
import 'package:bimobondapp/app/categories/presentation/di/categories_injector.dart'
    as categories_di;
import 'package:bimobondapp/app/categories/presentation/utils/category_lookup.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auction_card.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auction_item.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auction_search_filters.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auctions_ended_header.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auctions_filter_sheet.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auctions_search_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/home_tab_app_bar.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_feed_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart'
    as posts_di;
import 'package:bimobondapp/core/navigation/post_navigation.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class EndedAuctionsScreen extends StatefulWidget {
  const EndedAuctionsScreen({super.key});

  @override
  State<EndedAuctionsScreen> createState() => _EndedAuctionsScreenState();
}

class _EndedAuctionsScreenState extends State<EndedAuctionsScreen> {
  static const _searchDebounceDuration = Duration(milliseconds: 400);
  static const _maxPagesPerRefresh = 10;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  String _searchQuery = '';
  AuctionSearchFilters _filters = const AuctionSearchFilters(
    liveStatus: AuctionLiveStatusFilter.ended,
  );
  final List<CategoryEntity> _categories = [];
  final List<AuctionItem> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasReachedMax = false;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    _scrollController.addListener(_onScroll);
    unawaited(_loadCategories());
    unawaited(_loadAuctions(refresh: true));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoading || _isLoadingMore || _hasReachedMax) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      unawaited(_loadAuctions());
    }
  }

  void _onSearchTextChanged() {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDuration, () {
      final next = _searchController.text.trim();
      if (next == _searchQuery) return;
      setState(() => _searchQuery = next);
      unawaited(_loadAuctions(refresh: true));
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    if (_searchQuery.isEmpty) return;
    setState(() => _searchQuery = '');
    unawaited(_loadAuctions(refresh: true));
  }

  void _submitSearch() {
    _searchDebounce?.cancel();
    final next = _searchController.text.trim();
    if (next == _searchQuery) return;
    setState(() => _searchQuery = next);
    unawaited(_loadAuctions(refresh: true));
  }

  Future<void> _loadCategories() async {
    final result = await categories_di.sl<GetCategoriesUseCase>()(
      const GetCategoriesParams.flat(),
    );
    if (!mounted) return;
    result.fold((_) {}, (categories) {
      setState(() {
        _categories
          ..clear()
          ..addAll(categories);
      });
    });
  }

  String? _categoryLabelFor(String? categoryId) {
    return CategoryLookup.labelForId(categoryId, _categories);
  }

  Future<void> _openFilters() async {
    final result = await AuctionsFilterSheet.show(
      context,
      initialFilters: _filters,
      categories: _categories,
    );
    if (!mounted || result == null) return;
    setState(() {
      _filters = result.copyWith(liveStatus: AuctionLiveStatusFilter.ended);
    });
    unawaited(_loadAuctions(refresh: true));
  }

  AuctionItem _toAuctionItem(PostEntity post) {
    return AuctionItem.fromPost(
      post,
      categoryLabel: _categoryLabelFor(post.categoryId),
      categorySlug: CategoryLookup.slugForId(post.categoryId, _categories),
    );
  }

  bool _shouldIncludeEndedPost(PostEntity post) {
    if (!post.isAuctionable || post.auction == null) return false;
    if (!_filters.matchesClientCategory(post)) return false;
    if (!AuctionSearchFilters.isPostEnded(post)) return false;
    return AuctionSearchFilters.matchesSearchQuery(post, _searchQuery);
  }

  Future<({Map<String, AuctionItem> items, int nextPage, bool reachedMax})>
      _fetchEndedPageBatch({
    required AuctionSearchFilters filters,
    required int startPage,
    required int maxPages,
    String? search,
  }) async {
    final useCase = posts_di.sl<GetFeedUseCase>();
    final byId = <String, AuctionItem>{};
    var page = startPage;
    var hasMore = true;
    var pagesLoaded = 0;
    var lastPageSize = 0;

    while (hasMore && pagesLoaded < maxPages) {
      final result = await useCase(
        filters.toFeedParams(
          page: page,
          limit: 30,
          search: search,
        ),
      );

      var shouldContinue = false;
      result.fold((_) => hasMore = false, (page) {
        lastPageSize = page.items.length;
        for (final feedItem in page.items) {
          final post = feedItem.post;
          if (!_shouldIncludeEndedPost(post)) continue;
          final item = _toAuctionItem(post);
          byId[item.id] = item;
        }
        shouldContinue = !page.hasReachedMax && page.items.length >= 30;
      });

      pagesLoaded++;
      if (!shouldContinue) {
        hasMore = false;
      } else {
        page++;
      }
    }

    return (
      items: byId,
      nextPage: page,
      reachedMax: lastPageSize < 30,
    );
  }

  Future<void> _loadAuctions({bool refresh = false}) async {
    if (refresh) {
      if (_isLoading) return;
      setState(() {
        _isLoading = true;
        _hasReachedMax = false;
        _page = 1;
        _items.clear();
      });
    } else {
      if (_isLoadingMore || _hasReachedMax) return;
      setState(() => _isLoadingMore = true);
    }

    final search = _searchQuery.trim();
    // Prefer server search when present; client filter still applies as a
    // safety net. If ENDED+search returns nothing, scan without API search.
    final searchParam = search.isEmpty ? null : search;
    final startPage = refresh ? 1 : _page;
    final maxPages = refresh ? _maxPagesPerRefresh : 1;

    var batch = await _fetchEndedPageBatch(
      filters: _filters,
      startPage: startPage,
      maxPages: maxPages,
      search: searchParam,
    );

    if (batch.items.isEmpty && refresh) {
      batch = await _fetchEndedPageBatch(
        filters: _filters.withoutLiveStatus(),
        startPage: 1,
        maxPages: _maxPagesPerRefresh,
        // Drop API search so we can match locally on ended auctions.
        search: null,
      );
    }

    if (!mounted) return;

    setState(() {
      if (refresh) {
        _items
          ..clear()
          ..addAll(batch.items.values);
        _page = batch.nextPage;
        _hasReachedMax = batch.reachedMax;
      } else {
        final existingIds = _items.map((item) => item.id).toSet();
        _items.addAll(
          batch.items.values.where((item) => !existingIds.contains(item.id)),
        );
        _page = batch.nextPage;
        _hasReachedMax = batch.reachedMax;
      }
      _isLoading = false;
      _isLoadingMore = false;
    });
  }

  int get _activeFilterCount {
    var count = _filters.activeFilterCount;
    if (_filters.liveStatus != AuctionLiveStatusFilter.any) {
      count--;
    }
    return count;
  }

  void _openAuction(AuctionItem item) {
    final post = item.post;
    if (post != null) openPost(context, post);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceElevated =
        isDark ? const Color(0xFF1E1E1E) : theme.colorScheme.surface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: HomeTabAppBar(
        title: l10n.endedAuctionsNow,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Directionality.of(context) == TextDirection.rtl
                ? LucideIcons.chevronRight
                : LucideIcons.chevronLeft,
            color: theme.iconTheme.color,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () => _loadAuctions(refresh: true),
          color: theme.primaryColor,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.p16,
                    AppSizes.p12,
                    AppSizes.p16,
                    AppSizes.p16,
                  ),
                  child: AuctionsSearchBar(
                    controller: _searchController,
                    fillColor: surfaceElevated,
                    onSubmitted: _submitSearch,
                    onClear: _clearSearch,
                    onFilterTap: _openFilters,
                    activeFilterCount: _activeFilterCount,
                  ),
                ),
              ),
              if (_isLoading && _items.isEmpty)
                const SliverToBoxAdapter(
                  child: AuctionListSkeleton(),
                )
              else if (_items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.p24),
                      child: CustomText(
                        l10n.noPostsFound,
                        variant: TextVariant.secondary,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              else ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSizes.p16,
                      0,
                      AppSizes.p16,
                      AppSizes.p12,
                    ),
                    child: AuctionsEndedHeader(),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.p16,
                    0,
                    AppSizes.p16,
                    AppSizes.p16,
                  ),
                  sliver: SliverList.separated(
                    itemCount: _items.length + (_isLoadingMore ? 1 : 0),
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSizes.p16),
                    itemBuilder: (context, index) {
                      if (index >= _items.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: AppSizes.p16),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }

                      final auction = _items[index];
                      return AuctionCard(
                        auction: auction,
                        surfaceColor: surfaceElevated,
                        showBidButton: false,
                        onOpen: () => _openAuction(auction),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
