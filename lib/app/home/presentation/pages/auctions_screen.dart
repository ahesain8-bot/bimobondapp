import 'dart:async';

import 'package:bimobondapp/app/categories/domain/entities/category_entity.dart';
import 'package:bimobondapp/app/categories/domain/usecases/get_categories_usecase.dart';
import 'package:bimobondapp/app/categories/presentation/di/categories_injector.dart'
    as categories_di;
import 'package:bimobondapp/app/home/presentation/utils/post_owner_utils.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auction_card.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auction_item.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auctions_active_header.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auctions_category_strip.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/home_tab_app_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auctions_search_bar.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_feed_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart'
    as posts_di;
import 'package:bimobondapp/core/navigation/post_navigation.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class AuctionsScreen extends StatefulWidget {
  final bool isTabActive;

  const AuctionsScreen({super.key, this.isTabActive = false});

  @override
  State<AuctionsScreen> createState() => _AuctionsScreenState();
}

class _AuctionsScreenState extends State<AuctionsScreen> {
  static const _searchDebounceDuration = Duration(milliseconds: 400);

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  String? _selectedCategorySlug;
  final List<CategoryEntity> _categories = [];
  final List<AuctionItem> _postAuctionItems = [];
  bool _isLoadingCategories = false;
  bool _isLoadingPostAuctions = false;

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
  }

  Future<void> _onPullToRefresh() async {
    await Future.wait([_loadCategories(), _loadPostAuctions()]);
  }

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

  CategoryEntity? _selectedCategory() {
    final slug = _selectedCategorySlug;
    if (slug == null) return null;
    for (final category in _categories) {
      if (category.slug == slug) return category;
    }
    return null;
  }

  String? _categoryLabelFor(String? categoryRef) {
    if (categoryRef == null || categoryRef.trim().isEmpty) return null;
    final lower = categoryRef.trim().toLowerCase();
    for (final category in _categories) {
      if (category.slug.toLowerCase() == lower ||
          category.id.toLowerCase() == lower ||
          category.name.toLowerCase() == lower) {
        return category.name;
      }
    }
    return categoryRef;
  }

  bool _matchesSelectedCategory(PostEntity post) {
    final slug = _selectedCategorySlug;
    if (slug == null) return true;

    final postCategory = post.category?.trim().toLowerCase();
    if (postCategory == null || postCategory.isEmpty) return false;

    final selected = _selectedCategory();
    if (postCategory == slug.toLowerCase()) return true;
    if (selected != null) {
      if (postCategory == selected.id.toLowerCase()) return true;
      if (postCategory == selected.name.toLowerCase()) return true;
    }
    return false;
  }

  bool _matchesSearchQuery(PostEntity post) {
    final query = _searchQuery.trim();
    if (query.isEmpty) return true;

    final q = query.toLowerCase();

    final description = post.description?.trim().toLowerCase() ?? '';
    if (description.contains(q)) return true;

    final categoryRef = post.category?.trim().toLowerCase() ?? '';
    if (categoryRef.isNotEmpty && categoryRef.contains(q)) return true;

    final categoryLabel = _categoryLabelFor(post.category)?.toLowerCase() ?? '';
    if (categoryLabel.contains(q)) return true;

    final itemName = post.auction?.itemName.trim().toLowerCase() ?? '';
    if (itemName.contains(q)) return true;

    return false;
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
        GetFeedParams(
          page: page,
          limit: 30,
          category: _selectedCategorySlug,
          search: search.isEmpty ? null : search,
        ),
      );
      var shouldContinue = false;
      result.fold((_) => hasMore = false, (posts) {
        for (final post in posts) {
          if (post.isAuctionable &&
              post.auction != null &&
              _matchesSelectedCategory(post) &&
              _matchesSearchQuery(post)) {
            postsById[post.id] = post;
          }
        }
        shouldContinue = posts.length >= 30;
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
              categoryLabel: _categoryLabelFor(post.category),
            ),
          ),
        );
      _isLoadingPostAuctions = false;
    });
  }

  void _onCategorySelected(String? slug) {
    if (_selectedCategorySlug == slug) return;
    setState(() => _selectedCategorySlug = slug);
    _loadPostAuctions();
  }

  void _openAuction(AuctionItem item) {
    final post = item.post;
    if (post != null) {
      openPost(context, post);
    }
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
      appBar: HomeTabAppBar(title: l10n.navAuctions),
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
              const SliverToBoxAdapter(
                child: AuctionsCategoryStripSkeleton(),
              )
            else if (_categories.isNotEmpty)
              SliverToBoxAdapter(
                child: AuctionsCategoryStrip(
                  categories: _categories,
                  selectedCategorySlug: _selectedCategorySlug,
                  chipInactiveBg: chipInactiveBg,
                  inactiveBorder: chipInactiveBorder,
                  selectedColor: theme.primaryColor,
                  onCategorySelected: _onCategorySelected,
                ),
              ),
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
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.p16,
                0,
                AppSizes.p16,
                AppSizes.p16,
              ),
              sliver: _isLoadingPostAuctions
                  ? const SliverToBoxAdapter(
                      child: AuctionListSkeleton(itemCount: 3),
                    )
                  : _postAuctionItems.isEmpty
                  ? SliverToBoxAdapter(
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
                    )
                  : SliverList.separated(
                      itemCount: _postAuctionItems.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSizes.p16),
                      itemBuilder: (context, index) {
                        final auction = _postAuctionItems[index];
                        final post = auction.post;
                        final showBidButton =
                            post == null ||
                            !isCurrentUserPostOwner(context, post);

                        return AuctionCard(
                          auction: auction,
                          surfaceColor: surfaceElevated,
                          showBidButton: showBidButton,
                          onOpen: () => _openAuction(auction),
                        );
                      },
                    ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
