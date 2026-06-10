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

    if (!mounted) return;
    setState(() {
      _endedPreviewItems
        ..clear()
        ..addAll(
          postsById.values.take(_endedPreviewLimit).map(
            (post) => AuctionItem.fromPost(
              post,
              categoryLabel: _categoryLabelFor(post.categoryId),
              categorySlug: CategoryLookup.slugForId(
                post.categoryId,
                _categories,
              ),
            ),
          ),
        );
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

    if (!mounted) return;
    setState(() {
      _postAuctionItems
        ..clear()
        ..addAll(
          postsById.values.map(
            (post) => AuctionItem.fromPost(
              post,
              categoryLabel: _categoryLabelFor(post.categoryId),
              categorySlug: CategoryLookup.slugForId(
                post.categoryId,
                _categories,
              ),
            ),
          ),
        );
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

  AuctionItem? _getSpotlightItem(List<AuctionItem> source) {
    if (source.isEmpty) return null;
    final liveAuctions = source.where((item) => item.isLive).toList();
    if (liveAuctions.isNotEmpty) {
      liveAuctions.sort((a, b) => b.giftTotalUsd.compareTo(a.giftTotalUsd));
      return liveAuctions.first;
    }
    return source.first;
  }

  List<Widget> _buildAuctionSections({
    required BuildContext context,
    required ThemeData theme,
    required Color surfaceElevated,
    required AppLocalizations l10n,
  }) {
    final showSpotlightBase =
        !_isLoadingPostAuctions &&
        _searchQuery.isEmpty &&
        !_filters.hasActiveFilters;

    final activeItems = _activeAuctionItems;
    final spotlightItem =
        showSpotlightBase ? _getSpotlightItem(activeItems) : null;
    final listItems = spotlightItem != null
        ? activeItems.where((item) => item.id != spotlightItem.id).toList()
        : activeItems;

    return _buildActiveAuctionSection(
      context: context,
      theme: theme,
      surfaceElevated: surfaceElevated,
      l10n: l10n,
      items: listItems,
      showSpotlight: showSpotlightBase,
      spotlightItem: spotlightItem,
    );
  }

  List<Widget> _buildActiveAuctionSection({
    required BuildContext context,
    required ThemeData theme,
    required Color surfaceElevated,
    required AppLocalizations l10n,
    required List<AuctionItem> items,
    required bool showSpotlight,
    AuctionItem? spotlightItem,
  }) {
    return [
      if (showSpotlight && spotlightItem != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSizes.p20),
            child: _FeaturedSpotlight(
              item: spotlightItem,
              onTap: () => _openAuction(spotlightItem),
            ),
          ),
        ),
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
      if (items.isEmpty && (spotlightItem == null || !showSpotlight))
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
                  child: AuctionListSkeleton(itemCount: 3),
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

class _FeaturedSpotlight extends StatelessWidget {
  const _FeaturedSpotlight({required this.item, required this.onTap});

  final AuctionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);

    final total = item.giftTotalUsd;
    final text = total == total.roundToDouble()
        ? total.round().toString()
        : total.toStringAsFixed(2);
    final localizedAmount = LocaleFormatUtils.localizeDigits(text, locale);
    final bidText = l10n.liveHighestBidAmount(
      localizedAmount,
      l10n.currencyUsd,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        child: AspectRatio(
          aspectRatio: 1.85,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                item.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    LucideIcons.image,
                    color: theme.disabledColor,
                    size: 48,
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.75),
                      ],
                      stops: const [0.35, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: AppSizes.p12,
                right: AppSizes.p12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.p8,
                    vertical: AppSizes.p4,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [theme.primaryColor, const Color(0xFFFF5E97)],
                    ),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.sparkles,
                        size: 11,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.viewAll.toUpperCase() == "VIEW ALL"
                            ? "SPOTLIGHT"
                            : "مميز",
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: AppSizes.p12,
                left: AppSizes.p12,
                child: AuctionStatusBadge(auction: item),
              ),
              Positioned(
                bottom: AppSizes.p16,
                left: AppSizes.p16,
                right: AppSizes.p16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 4,
                            offset: Offset(0, 1.5),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                    const SizedBox(height: AppSizes.p8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.p12,
                            vertical: AppSizes.p8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusMd,
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.liveTopBid,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white.withValues(
                                        alpha: 0.75,
                                      ),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    bidText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              ElevatedButton(
                                onPressed: onTap,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSizes.p16,
                                    vertical: 0,
                                  ),
                                  minimumSize: const Size(0, 32),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSizes.radiusSm,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      LucideIcons.gavel,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      l10n.bidNow,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
