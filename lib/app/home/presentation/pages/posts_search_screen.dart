import 'dart:async';

import 'package:bimobondapp/app/home/presentation/widgets/auctions/auctions_search_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/home_tab_app_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_grid_tile.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_feed_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart' as posts_di;
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/navigation/hashtag_navigation.dart';
import 'package:bimobondapp/core/navigation/post_navigation.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class PostsSearchScreen extends StatefulWidget {
  const PostsSearchScreen({super.key});

  @override
  State<PostsSearchScreen> createState() => _PostsSearchScreenState();
}

class _PostsSearchScreenState extends State<PostsSearchScreen> {
  static const _searchDebounceDuration = Duration(milliseconds: 400);

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  String _searchQuery = '';
  final List<PostEntity> _posts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasReachedMax = false;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    _scrollController.addListener(_onScroll);
    unawaited(_loadPosts(refresh: true));
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
      unawaited(_loadPosts());
    }
  }

  void _onSearchTextChanged() {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDuration, () {
      final next = _searchController.text.trim();
      if (next == _searchQuery) return;
      setState(() => _searchQuery = next);
      unawaited(_loadPosts(refresh: true));
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    if (_searchQuery.isEmpty) return;
    setState(() => _searchQuery = '');
    unawaited(_loadPosts(refresh: true));
  }

  void _submitSearch() {
    _searchDebounce?.cancel();
    final next = _searchController.text.trim();
    if (next.startsWith('#') && next.length > 1) {
      openHashtagFeed(context, next);
      return;
    }
    if (next == _searchQuery) return;
    setState(() => _searchQuery = next);
    unawaited(_loadPosts(refresh: true));
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (refresh) {
      if (_isLoading) return;
      setState(() {
        _isLoading = true;
        _hasReachedMax = false;
        _page = 1;
        _posts.clear();
      });
    } else {
      if (_isLoadingMore || _hasReachedMax) return;
      setState(() => _isLoadingMore = true);
    }

    final useCase = posts_di.sl<GetFeedUseCase>();
    final search = _searchQuery.trim();
    final result = await useCase(
      GetFeedParams(
        page: refresh ? 1 : _page,
        limit: 30,
        search: search.isEmpty ? null : search,
        isStory: false,
      ),
    );

    if (!mounted) return;

    result.fold(
      (_) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
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
          _hasReachedMax = posts.length < 30;
          _isLoading = false;
          _isLoadingMore = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final surfaceElevated =
        isDark ? const Color(0xFF1E1E1E) : colorScheme.surface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: HomeTabAppBar(
        title: l10n.postsSearchTitle,
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
          onRefresh: () => _loadPosts(refresh: true),
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
                    hintText: l10n.postsSearchHint,
                    onSubmitted: _submitSearch,
                    onClear: _clearSearch,
                  ),
                ),
              ),
              if (_isLoading && _posts.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: ProfileLayoutConstants.gridCrossAxisCount,
                      crossAxisSpacing: ProfileLayoutConstants.gridSpacing,
                      mainAxisSpacing: ProfileLayoutConstants.gridSpacing,
                      childAspectRatio: ProfileLayoutConstants.gridAspectRatio,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, _) => const SkeletonWidget(
                        borderRadius: AppSizes.radiusSm,
                      ),
                      childCount: 9,
                    ),
                  ),
                )
              else if (_posts.isEmpty)
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
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.p16,
                    0,
                    AppSizes.p16,
                    AppSizes.p16,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: ProfileLayoutConstants.gridCrossAxisCount,
                      crossAxisSpacing: ProfileLayoutConstants.gridSpacing,
                      mainAxisSpacing: ProfileLayoutConstants.gridSpacing,
                      childAspectRatio: ProfileLayoutConstants.gridAspectRatio,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= _posts.length) {
                          return const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }

                        final post = _posts[index];
                        return ProfileGridTile(
                          post: post,
                          tabIndex: 0,
                          theme: theme,
                          onTap: () => openPost(context, post),
                        );
                      },
                      childCount:
                          _posts.length + (_isLoadingMore ? 1 : 0),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
