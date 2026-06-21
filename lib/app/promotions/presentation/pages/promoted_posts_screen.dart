import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart';
import 'package:bimobondapp/app/promotions/data/datasources/promotions_remote_data_source.dart';
import 'package:bimobondapp/app/promotions/domain/entities/promotion_entities.dart';
import 'package:bimobondapp/app/promotions/presentation/widgets/promoted_posts_widgets.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class PromotedPostsScreen extends StatefulWidget {
  const PromotedPostsScreen({super.key});

  @override
  State<PromotedPostsScreen> createState() => _PromotedPostsScreenState();
}

class _PromotedPostsScreenState extends State<PromotedPostsScreen> {
  final _remote = sl<PromotionsRemoteDataSource>();
  final _scrollController = ScrollController();

  final List<PromotedPostRowEntity> _rows = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasReachedMax = false;
  int _page = 1;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_hasReachedMax || _loadingMore || _loading) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _load();
    }
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _loading = true;
        _errorMessage = null;
        _page = 1;
        _hasReachedMax = false;
      });
    } else {
      if (_hasReachedMax) return;
      setState(() => _loadingMore = true);
    }

    try {
      final result = await _remote.getPromotedPosts(page: _page, limit: 20);
      if (!mounted) return;

      setState(() {
        if (refresh) {
          _rows
            ..clear()
            ..addAll(result.data);
        } else {
          _rows.addAll(result.data);
        }
        _page++;
        _hasReachedMax = _page > result.meta.totalPages;
        _loading = false;
        _loadingMore = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _errorMessage = _message(error);
      });
    }
  }

  String _message(Object error) {
    if (error is AppException) return error.message ?? error.toString();
    return error.toString();
  }

  void _openInsights(PromotedPostRowEntity row) {
    context.pushNamed(
      'promoted_post_insights',
      pathParameters: {'postId': row.post.id},
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: l10n.promoteInsightsDashboardTitle,
        showBackButton: true,
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: _loading && _rows.isEmpty
            ? const PromotedPostsListSkeleton()
            : _errorMessage != null && _rows.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      Icon(
                        LucideIcons.circleAlert,
                        size: 48,
                        color: scheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: FilledButton(
                          onPressed: () => _load(refresh: true),
                          child: Text(l10n.notificationsRetry),
                        ),
                      ),
                    ],
                  )
                : _rows.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(32),
                        children: [
                          Icon(
                            LucideIcons.megaphone,
                            size: 56,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.promoteInsightsEmptyTitle,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.promoteInsightsEmptyHint,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _rows.length + (_loadingMore ? 1 : 0),
                        separatorBuilder: (_, index) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          if (index >= _rows.length) {
                            return const PromotedPostCardSkeleton();
                          }
                          return PromotedPostCard(
                            row: _rows[index],
                            onTap: () => _openInsights(_rows[index]),
                          );
                        },
                      ),
      ),
    );
  }
}
