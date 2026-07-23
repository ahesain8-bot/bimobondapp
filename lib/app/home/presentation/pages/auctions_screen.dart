import 'dart:async';
import 'dart:ui';

import 'package:bimobondapp/app/auctions/domain/usecases/get_active_auctions_usecase.dart';
import 'package:bimobondapp/app/auctions/presentation/di/auctions_injector.dart'
    as auctions_di;
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
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_empty_state.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_feed_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_post_by_id_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart'
    as posts_di;
import 'package:bimobondapp/core/navigation/post_navigation.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AuctionsScreen extends StatefulWidget {
  final bool isTabActive;

  const AuctionsScreen({super.key, this.isTabActive = false});

  @override
  State<AuctionsScreen> createState() => AuctionsScreenState();
}

class AuctionsScreenState extends State<AuctionsScreen> {
  static const _searchDebounceDuration = Duration(milliseconds: 400);
  static const _endedPreviewLimit = 3;

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  Timer? _expiryTicker;
  String _searchQuery = '';
  AuctionSearchFilters _filters = AuctionSearchFilters.empty;
  final List<CategoryEntity> _categories = [];
  final List<AuctionItem> _postAuctionItems = [];
  final List<AuctionItem> _endedPreviewItems = [];
  bool _isLoadingCategories = false;
  bool _isLoadingPostAuctions = false;
  bool _isLoadingEndedPreview = false;
  bool _postAuctionsLoadFailed = false;
  String? _postAuctionsErrorMessage;

  /// Called when the user re-taps the Auctions tab while already on it.
  void refreshFromTab() {
    if (!mounted) return;
    _beginVisibleRefresh();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    _expiryTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !widget.isTabActive) return;
      _onExpiryTick();
    });
    if (widget.isTabActive) {
      _loadTabData();
    }
  }

  @override
  void didUpdateWidget(AuctionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTabActive && !oldWidget.isTabActive) {
      _beginVisibleRefresh();
    }
  }

  /// Clear content and show skeleton while auctions reload (Auctions icon tap).
  void _beginVisibleRefresh() {
    setState(() {
      _postAuctionItems.clear();
      _endedPreviewItems.clear();
      _postAuctionsLoadFailed = false;
      _postAuctionsErrorMessage = null;
      _isLoadingPostAuctions = true;
      _isLoadingEndedPreview = true;
      _isLoadingCategories = _categories.isEmpty;
    });
    _loadTabData();
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
    _expiryTicker?.cancel();
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  /// Drop time-expired auctions from Active and refresh countdowns.
  void _onExpiryTick() {
    if (_postAuctionItems.isEmpty) return;

    final now = DateTime.now().toUtc();
    final stillActive = <AuctionItem>[];
    final newlyEnded = <AuctionItem>[];
    var changed = false;

    for (final item in _postAuctionItems) {
      if (item.isEndedNow) {
        newlyEnded.add(
          item.copyWith(isLive: false, isEnded: true, countdown: null),
        );
        changed = true;
        continue;
      }
      final startedAt = item.startedAt?.toUtc();
      final endedAt = item.endedAt?.toUtc();
      final nextCountdown = startedAt != null && endedAt != null
          ? formatAuctionCountdown(now, startedAt, endedAt)
          : item.countdown;
      if (nextCountdown != item.countdown) {
        stillActive.add(item.copyWith(countdown: nextCountdown));
        changed = true;
      } else {
        stillActive.add(item);
      }
    }

    if (!changed) return;

    setState(() {
      _postAuctionItems
        ..clear()
        ..addAll(stillActive);

      if (newlyEnded.isEmpty) return;
      if (_searchQuery.isNotEmpty || _filters.hasActiveFilters) return;

      // Prepend into ended preview (cap at limit), avoiding duplicates.
      final existingIds = _endedPreviewItems.map((e) => e.id).toSet();
      for (final item in newlyEnded.reversed) {
        if (existingIds.contains(item.id)) continue;
        _endedPreviewItems.insert(0, item);
        existingIds.add(item.id);
      }
      while (_endedPreviewItems.length > _endedPreviewLimit) {
        _endedPreviewItems.removeLast();
      }
    });
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

    final result = await categories_di.sl<GetCategoriesUseCase>()(
      const GetCategoriesParams.flat(),
    );

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
      result.fold((_) => hasMore = false, (page) {
        for (final item in page.items) {
          final post = item.post;
          if (!post.isAuctionable || post.auction == null) continue;
          if (!_isEndedPost(post)) continue;
          postsById[post.id] = post;
          if (postsById.length >= _endedPreviewLimit) break;
        }
        shouldContinue = !page.hasReachedMax && page.items.length >= 30;
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
      _postAuctionsLoadFailed = false;
      _postAuctionsErrorMessage = null;
    });

    final search = _searchQuery.trim();
    final useActiveEndpoint = search.isEmpty &&
        !_filters.hasUserFilters &&
        _filters.liveStatus != AuctionLiveStatusFilter.ended;

    if (useActiveEndpoint) {
      final result = await auctions_di.sl<GetActiveAuctionsUseCase>()(
        NoParams(),
      );
      if (!mounted) return;

      final loaded = result.fold<bool>(
        (_) => false,
        (auctions) {
          final mapped = auctions
              .where((a) => !a.isEnded)
              .map((a) => AuctionItem.fromAuction(a))
              .where((item) => !item.isEndedNow)
              .where((item) {
                if (_filters.liveStatus == AuctionLiveStatusFilter.live) {
                  return item.isLive;
                }
                return true;
              })
              .toList();
          setState(() {
            _postAuctionItems
              ..clear()
              ..addAll(mapped);
            _postAuctionsLoadFailed = false;
            _postAuctionsErrorMessage = null;
            _isLoadingPostAuctions = false;
          });
          return true;
        },
      );
      if (loaded) return;
      // Fall back to feed filters if /auctions/active fails.
    }

    final useCase = posts_di.sl<GetFeedUseCase>();
    final postsById = <String, PostEntity>{};
    var page = 1;
    var hasMore = true;
    String? failureMessage;
    var loadFailed = false;

    while (hasMore && page <= 10) {
      final result = await useCase(
        _filters.toFeedParams(
          page: page,
          limit: 30,
          search: search.isEmpty ? null : search,
        ),
      );
      var shouldContinue = false;
      result.fold(
        (failure) {
          loadFailed = true;
          failureMessage = failure.message;
          hasMore = false;
        },
        (page) {
          for (final item in page.items) {
            final post = item.post;
            if (!post.isAuctionable || post.auction == null) continue;
            if (_isEndedPost(post)) continue;
            if (!_filters.matchesClientCategory(post)) continue;
            if (!_filters.matchesClientLiveStatus(post)) continue;
            postsById[post.id] = post;
          }
          shouldContinue = !page.hasReachedMax && page.items.length >= 30;
        },
      );
      if (!shouldContinue) {
        hasMore = false;
      } else {
        page++;
      }
    }

    if (!mounted) return;

    if (loadFailed && postsById.isEmpty) {
      setState(() {
        _isLoadingPostAuctions = false;
        _postAuctionsLoadFailed = true;
        _postAuctionsErrorMessage = failureMessage;
      });
      return;
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

    setState(() {
      _postAuctionItems
        ..clear()
        ..addAll(mappedItems);
      _postAuctionsLoadFailed = false;
      _postAuctionsErrorMessage = null;
      _isLoadingPostAuctions = false;
    });
  }

  Future<void> _openAuction(AuctionItem item) async {
    final post = item.post;
    final auctionId = item.auctionId?.trim();
    if (post != null) {
      openPost(context, post, auctionId: auctionId);
      return;
    }
    final postId = item.id;
    if (postId.isEmpty) return;
    final result = await posts_di.sl<GetPostByIdUseCase>()(postId);
    if (!mounted) return;
    result.fold(
      (failure) => PopupDialogs.showErrorDialog(context, failure.message),
      (loaded) => openPost(context, loaded, auctionId: auctionId),
    );
  }

  bool _isEndedPost(PostEntity post) => AuctionSearchFilters.isPostEnded(post);

  List<AuctionItem> get _activeAuctionItems =>
      _postAuctionItems.where((item) => !item.isEndedNow).toList();

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
            child: _postAuctionsLoadFailed
                ? FeedLoadErrorState(
                    lightForeground: false,
                    message: _postAuctionsErrorMessage,
                    onRetry: () => unawaited(_loadPostAuctions()),
                  )
                : Center(
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
              if (_isLoadingPostAuctions && _postAuctionItems.isEmpty)
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


