import 'dart:async';
import 'dart:ui';

import 'package:bimobondapp/app/categories/domain/entities/category_entity.dart';
import 'package:bimobondapp/app/categories/presentation/utils/category_lookup.dart';
import 'package:bimobondapp/app/categories/domain/usecases/get_categories_usecase.dart';
import 'package:bimobondapp/app/categories/presentation/di/categories_injector.dart'
    as categories_di;
import 'package:bimobondapp/app/home/presentation/utils/post_owner_utils.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auction_card.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auction_item.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auction_status_badge.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auctions_active_header.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auctions_ended_header.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auctions_category_strip.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/home_tab_app_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auction_search_filters.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auctions_filter_sheet.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auctions_search_bar.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_feed_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart'
    as posts_di;
import 'package:bimobondapp/core/navigation/post_navigation.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AuctionsScreen extends StatefulWidget {
  final bool isTabActive;

  const AuctionsScreen({super.key, this.isTabActive = false});

  @override
  State<AuctionsScreen> createState() => _AuctionsScreenState();
}

class _AuctionsScreenState extends State<AuctionsScreen> {
  static const _searchDebounceDuration = Duration(milliseconds: 400);
  static const _endedPreviewLimit = 3;

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  AuctionSearchFilters _filters = AuctionSearchFilters.empty;
  final List<CategoryEntity> _categories = [];
  final List<AuctionItem> _postAuctionItems = [];
  final List<AuctionItem> _endedPreviewItems = [];
  bool _isLoadingCategories = false;
  bool _isLoadingPostAuctions = false;
  bool _isLoadingEndedPreview = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    if (widget.isTabActive) {
      _loadTabData();
    }
  }

  @override
  void didUpdateWidget(AuctionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTabActive && !oldWidget.isTabActive) {
      _loadTabData();
    }
  }

  void _loadTabData() {
    unawaited(_loadCategories());
    unawaited(_loadPostAuctions());
    unawaited(_loadEndedPreview());
  }

  Future<void> _onPullToRefresh() async {
    await Future.wait([
      _loadCategories(),
      _loadPostAuctions(),
      _loadEndedPreview(),
    ]);
  }

  void _openEndedAuctions() => context.pushNamed('ended_auctions');

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDuration, () {
      final next = _searchController.text.trim();
      if (next == _searchQuery) return;
      setState(() => _searchQuery = next);
      _loadPostAuctions();
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    if (_searchQuery.isEmpty) return;
    setState(() => _searchQuery = '');
    _loadPostAuctions();
  }

  void _submitSearch() {
    _searchDebounce?.cancel();
    final next = _searchController.text.trim();
    if (next == _searchQuery) return;
    setState(() => _searchQuery = next);
    _loadPostAuctions();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);

    final result = await categories_di.sl<GetCategoriesUseCase>()(NoParams());

    if (!mounted) return;
    setState(() {
      _isLoadingCategories = false;
      result.fold((_) {}, (categories) {
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
    setState(() => _filters = result);
    unawaited(_loadPostAuctions());
    unawaited(_loadEndedPreview());
  }

  void _toggleCategoryFilter(String categoryId) {
    final nextIds = Set<String>.from(_filters.categoryIds);
    if (nextIds.contains(categoryId)) {
      nextIds.remove(categoryId);
    } else {
      nextIds.add(categoryId);
    }
    setState(() {
      _filters = _filters.copyWith(categoryIds: nextIds);
    });
    unawaited(_loadPostAuctions());
    unawaited(_loadEndedPreview());
  }

  void _clearCategoryFilters() {
    if (_filters.categoryIds.isEmpty) return;
    setState(() {
      _filters = _filters.copyWith(categoryIds: {});
    });
    unawaited(_loadPostAuctions());
    unawaited(_loadEndedPreview());
  }

  Future<void> _loadEndedPreview() async {
    if (_searchQuery.isNotEmpty || _filters.hasActiveFilters) {
      if (!mounted) return;
      setState(() {
        _endedPreviewItems.clear();
        _isLoadingEndedPreview = false;
      });
      return;
    }

    setState(() {
      _isLoadingEndedPreview = true;
      _endedPreviewItems.clear();
    });

    const endedFilters = AuctionSearchFilters(
      liveStatus: AuctionLiveStatusFilter.ended,
    );
    final useCase = posts_di.sl<GetFeedUseCase>();
    final postsById = <String, PostEntity>{};
    var page = 1;
    var hasMore = true;

    while (hasMore && page <= 5 && postsById.length < _endedPreviewLimit) {
      final result = await useCase(
        endedFilters.toFeedParams(page: page, limit: 30),
      );
      var shouldContinue = false;
      result.fold((_) => hasMore = false, (items) {
        for (final item in items) {
          final post = item.post;
          if (!post.isAuctionable || post.auction == null) continue;
          if (!_isEndedPost(post)) continue;
          postsById[post.id] = post;
          if (postsById.length >= _endedPreviewLimit) break;
        }
        shouldContinue = items.length >= 30;
      });
      if (!shouldContinue || postsById.length >= _endedPreviewLimit) {
        hasMore = false;
      } else {
        page++;
      }
    }

    final mappedEnded = postsById.values.map(
      (post) => AuctionItem.fromPost(
        post,
        categoryLabel: _categoryLabelFor(post.categoryId),
        categorySlug: CategoryLookup.slugForId(
          post.categoryId,
          _categories,
        ),
      ),
    ).toList();

    mappedEnded.sort((a, b) {
      final aDate = a.post?.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.post?.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    if (!mounted) return;
    setState(() {
      _endedPreviewItems
        ..clear()
        ..addAll(mappedEnded.take(_endedPreviewLimit));
      _isLoadingEndedPreview = false;
    });
  }

  Future<void> _loadPostAuctions() async {
    setState(() {
      _isLoadingPostAuctions = true;
      _postAuctionItems.clear();
    });

    final useCase = posts_di.sl<GetFeedUseCase>();
    final postsById = <String, PostEntity>{};
    var page = 1;
    var hasMore = true;

    while (hasMore && page <= 10) {
      final search = _searchQuery.trim();
      final result = await useCase(
        _filters.toFeedParams(
          page: page,
          limit: 30,
          search: search.isEmpty ? null : search,
        ),
      );
      var shouldContinue = false;
      result.fold((_) => hasMore = false, (items) {
        for (final item in items) {
          final post = item.post;
          if (!post.isAuctionable || post.auction == null) continue;
          if (_isEndedPost(post)) continue;
          if (!_filters.matchesClientCategory(post)) continue;
          if (!_filters.matchesClientLiveStatus(post)) continue;
          postsById[post.id] = post;
        }
        shouldContinue = items.length >= 30;
      });
      if (!shouldContinue) {
        hasMore = false;
      } else {
        page++;
      }
    }

    final mappedItems = postsById.values.map(
      (post) => AuctionItem.fromPost(
        post,
        categoryLabel: _categoryLabelFor(post.categoryId),
        categorySlug: CategoryLookup.slugForId(
          post.categoryId,
          _categories,
        ),
      ),
    ).toList();

    mappedItems.sort((a, b) {
      final aDate = a.post?.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.post?.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    if (!mounted) return;
    setState(() {
      _postAuctionItems
        ..clear()
        ..addAll(mappedItems);
      _isLoadingPostAuctions = false;
    });
  }

  void _openAuction(AuctionItem item) {
    final post = item.post;
    if (post != null) {
      openPost(context, post);
    }
  }

  bool _isEndedPost(PostEntity post) => AuctionSearchFilters.isPostEnded(post);

  List<AuctionItem> get _activeAuctionItems => _postAuctionItems;

  List<Widget> _buildAuctionSections({
    required BuildContext context,
    required ThemeData theme,
    required Color surfaceElevated,
    required AppLocalizations l10n,
  }) {
    return _buildActiveAuctionSection(
      context: context,
      theme: theme,
      surfaceElevated: surfaceElevated,
      l10n: l10n,
      items: _activeAuctionItems,
    );
  }

  List<Widget> _buildActiveAuctionSection({
    required BuildContext context,
    required ThemeData theme,
    required Color surfaceElevated,
    required AppLocalizations l10n,
    required List<AuctionItem> items,
  }) {
    return [
      if (items.isNotEmpty) ...[
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSizes.p16,
              AppSizes.p24,
              AppSizes.p16,
              AppSizes.p12,
            ),
            child: AuctionsActiveHeader(),
          ),
        ),
        ..._buildAuctionListSlivers(
          context: context,
          theme: theme,
          surfaceElevated: surfaceElevated,
          items: items,
        ),
      ],
      if (items.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSizes.p48,
              horizontal: AppSizes.p16,
            ),
            child: Center(
              child: CustomText(
                l10n.noPostsFound,
                variant: TextVariant.secondary,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ..._buildEndedPreviewSection(
        context: context,
        theme: theme,
        surfaceElevated: surfaceElevated,
      ),
    ];
  }

  List<Widget> _buildEndedPreviewSection({
    required BuildContext context,
    required ThemeData theme,
    required Color surfaceElevated,
  }) {
    if (_searchQuery.isNotEmpty || _filters.hasActiveFilters) {
      return const [];
    }

    if (_isLoadingEndedPreview) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: AppSizes.p24),
            child: AuctionListSkeleton(itemCount: 1),
          ),
        ),
      ];
    }

    if (_endedPreviewItems.isEmpty) return const [];

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.p16,
            AppSizes.p24,
            AppSizes.p16,
            AppSizes.p12,
          ),
          child: AuctionsEndedHeader(
            onTap: _openEndedAuctions,
            showViewAll: true,
          ),
        ),
      ),
      ..._buildAuctionListSlivers(
        context: context,
        theme: theme,
        surfaceElevated: surfaceElevated,
        items: _endedPreviewItems,
        showBidButton: false,
      ),
    ];
  }

  List<Widget> _buildAuctionListSlivers({
    required BuildContext context,
    required ThemeData theme,
    required Color surfaceElevated,
    required List<AuctionItem> items,
    bool showBidButton = true,
  }) {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.p16,
          0,
          AppSizes.p16,
          AppSizes.p16,
        ),
        sliver: SliverList.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSizes.p16),
          itemBuilder: (context, index) {
            final auction = items[index];
            final post = auction.post;
            final canBid = showBidButton &&
                (post == null || !isCurrentUserPostOwner(context, post));

            return AuctionCard(
              auction: auction,
              surfaceColor: surfaceElevated,
              showBidButton: canBid,
              onOpen: () => _openAuction(auction),
            );
          },
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final surfaceElevated = isDark
        ? const Color(0xFF1E1E1E)
        : colorScheme.surface;
    final chipInactiveBg = isDark
        ? const Color(0xFF252525)
        : const Color(0xFFF3F4F6);
    final chipInactiveBorder = isDark
        ? Colors.white24
        : theme.dividerColor.withValues(alpha: 0.35);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: HomeTabAppBar(
        title: l10n.navAuctions,
        showBottomDivider: false,
        actions: [
          HomeTabGlassIconButton(
            icon: LucideIcons.history,
            onTap: _openEndedAuctions,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _onPullToRefresh,
          color: theme.primaryColor,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
                  child: AuctionsSearchBar(
                    controller: _searchController,
                    fillColor: surfaceElevated,
                    onSubmitted: _submitSearch,
                    onClear: _clearSearch,
                    onFilterTap: _openFilters,
                    activeFilterCount: _filters.activeFilterCount,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.p16,
                    AppSizes.p20,
                    AppSizes.p16,
                    AppSizes.p12,
                  ),
                  child: CustomText(
                    l10n.popularCategories,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_isLoadingCategories && _categories.isEmpty)
                const SliverToBoxAdapter(child: AuctionsCategoryStripSkeleton())
              else if (_categories.isNotEmpty)
                SliverToBoxAdapter(
                  child: AuctionsCategoryStrip(
                    categories: _categories,
                    selectedCategoryIds: _filters.categoryIds,
                    chipInactiveBg: chipInactiveBg,
                    inactiveBorder: chipInactiveBorder,
                    selectedColor: theme.primaryColor,
                    onCategoryToggled: _toggleCategoryFilter,
                    onClearCategories: _clearCategoryFilters,
                  ),
                ),
              if (_isLoadingPostAuctions)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: AppSizes.p20),
                    child: AuctionListSkeleton(),
                  ),
                )
              else
                ..._buildAuctionSections(
                  context: context,
                  theme: theme,
                  surfaceElevated: surfaceElevated,
                  l10n: l10n,
                ),
            ],
          ),
        ),
      ),
    );
  }
}


