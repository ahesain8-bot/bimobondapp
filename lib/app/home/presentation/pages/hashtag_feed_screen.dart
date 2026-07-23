import 'dart:async';

import 'package:bimobondapp/app/home/presentation/widgets/home_feed/home_tab_app_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_grid_tile.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_feed_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart' as posts_di;
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/navigation/post_navigation.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class HashtagFeedScreen extends StatefulWidget {
  const HashtagFeedScreen({
    required this.hashtagName,
    super.key,
  });

  final String hashtagName;

  @override
  State<HashtagFeedScreen> createState() => _HashtagFeedScreenState();
}

class _HashtagFeedScreenState extends State<HashtagFeedScreen> {
  final ScrollController _scrollController = ScrollController();

  final List<PostEntity> _posts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasReachedMax = false;
  int _page = 1;

  String get _tag => widget.hashtagName.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_loadPosts(refresh: true));
  }

  @override
  void dispose() {
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

  Future<void> _loadPosts({bool refresh = false}) async {
    if (_tag.isEmpty) return;

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
    final result = await useCase(
      GetFeedParams(
        page: refresh ? 1 : _page,
        limit: 30,
        hashtag: _tag,
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
      (page) {
        final posts = page.items.map((item) => item.post).toList();
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
          _hasReachedMax = page.hasReachedMax;
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: HomeTabAppBar(
        title: '#$_tag',
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
                    AppSizes.p8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.hash,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: AppSizes.p8),
                      Expanded(
                        child: CustomText(
                          l10n.hashtagFeedSubtitle,
                          variant: TextVariant.secondary,
                        ),
                      ),
                    ],
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
                        l10n.noHashtagPosts,
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
                      childCount: _posts.length + (_isLoadingMore ? 1 : 0),
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
