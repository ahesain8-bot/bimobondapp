import 'package:bimobondapp/app/posts/domain/entities/repost_entity.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_post_reposts_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart'
    as posts_di;
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_surface.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class PostRepostersSheet {
  PostRepostersSheet._();

  static Future<void> show({
    required BuildContext context,
    required String postId,
    int repostCount = 0,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final sheetTheme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;

    return GlassBottomSheet.showContent<void>(
      context,
      isScrollControlled: true,
      showHandle: true,
      lightSurface: true,
      child: Theme(
        data: sheetTheme,
        child: SizedBox(
          height: maxHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.p8,
                  0,
                  AppSizes.p8,
                  AppSizes.p4,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      l10n.postRepostersHeader,
                      textAlign: TextAlign.center,
                      style: sheetTheme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: sheetTheme.colorScheme.onSurface,
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          LucideIcons.x,
                          size: 22,
                          color: sheetTheme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.p16,
                  0,
                  AppSizes.p16,
                  AppSizes.p8,
                ),
                child: Text(
                  l10n.postRepostersTitle(repostCount),
                  textAlign: TextAlign.center,
                  style: sheetTheme.textTheme.bodySmall?.copyWith(
                    color: sheetTheme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(child: _PostRepostersList(postId: postId)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostRepostersList extends StatefulWidget {
  const _PostRepostersList({required this.postId});

  final String postId;

  @override
  State<_PostRepostersList> createState() => _PostRepostersListState();
}

class _PostRepostersListState extends State<_PostRepostersList> {
  static const int _pageSize = 20;

  final ScrollController _scrollController = ScrollController();
  final List<RepostEntity> _reposts = [];

  int _page = 1;
  bool _hasReachedMax = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _hasReachedMax || _isLoadingMore) {
      return;
    }
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 120) {
      _load(loadMore: true);
    }
  }

  Future<void> _load({bool refresh = false, bool loadMore = false}) async {
    if (_isLoading || _isLoadingMore) return;

    if (loadMore) {
      if (_hasReachedMax) return;
      setState(() {
        _isLoadingMore = true;
        _page++;
      });
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        if (refresh) {
          _page = 1;
          _hasReachedMax = false;
          _reposts.clear();
        }
      });
    }

    final result = await posts_di.sl<GetPostRepostsUseCase>()(
      GetPostRepostsParams(
        postId: widget.postId,
        page: _page,
        limit: _pageSize,
      ),
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _errorMessage = failure.message;
          _isLoading = false;
          _isLoadingMore = false;
          if (loadMore && _page > 1) _page--;
        });
      },
      (page) {
        setState(() {
          if (_page == 1) {
            _reposts
              ..clear()
              ..addAll(page.reposts);
          } else {
            final existing = _reposts.map((r) => r.id).toSet();
            _reposts.addAll(
              page.reposts.where((r) => !existing.contains(r.id)),
            );
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

    if (_isLoading && _reposts.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.p12,
          AppSizes.p4,
          AppSizes.p12,
          AppSizes.p16,
        ),
        itemCount: 5,
        itemBuilder: (_, _) => const Padding(
          padding: EdgeInsets.only(bottom: AppSizes.p8),
          child: _ReposterCardSkeleton(),
        ),
      );
    }

    if (_errorMessage != null && _reposts.isEmpty) {
      return _SheetMessage(
        icon: LucideIcons.circleAlert,
        message: _errorMessage!,
        showRetry: true,
        onRetry: () => _load(refresh: true),
      );
    }

    if (_reposts.isEmpty) {
      return _SheetMessage(
        icon: LucideIcons.repeat2,
        message: l10n.postRepostersEmpty,
      );
    }

    final cs = Theme.of(context).colorScheme;

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.p12,
        AppSizes.p4,
        AppSizes.p12,
        AppSizes.p16,
      ),
      itemCount: _reposts.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        if (index >= _reposts.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.p8),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              ),
            ),
          );
        }

        return _ReposterCard(repost: _reposts[index]);
      },
    );
  }
}

class _ReposterCardSkeleton extends StatelessWidget {
  const _ReposterCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final skeletonTone = Theme.of(context).brightness == Brightness.dark
        ? LiquidGlassSkeletonTone.standard
        : LiquidGlassSkeletonTone.light;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.p10,
          vertical: AppSizes.p8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LiquidGlassSkeletonBox.circular(size: 36, tone: skeletonTone),
            const SizedBox(width: AppSizes.p10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LiquidGlassSkeletonBox(
                    height: 12,
                    width: 120,
                    tone: skeletonTone,
                  ),
                  const SizedBox(height: 6),
                  LiquidGlassSkeletonBox(
                    height: 10,
                    width: MediaQuery.sizeOf(context).width * 0.28,
                    tone: skeletonTone,
                  ),
                  const SizedBox(height: AppSizes.p6),
                  LiquidGlassSkeletonBox(
                    height: 10,
                    width: MediaQuery.sizeOf(context).width * 0.45,
                    tone: skeletonTone,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReposterCard extends StatelessWidget {
  const _ReposterCard({required this.repost});

  final RepostEntity repost;

  @override
  Widget build(BuildContext context) {
    final user = repost.user;
    if (user == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final displayName = user.fullName?.trim().isNotEmpty == true
        ? user.fullName!
        : user.username;
    final quote = repost.quote?.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p4,
        vertical: AppSizes.p6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeNetworkAvatar(
            imageUrl: user.avatarUrl,
            radius: 22,
            fallbackText: user.username,
            backgroundColor: cs.surfaceContainerHighest,
          ),
          const SizedBox(width: AppSizes.p10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (user.isVerified) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.verified, size: 14, color: cs.primary),
                    ],
                  ],
                ),
                if (quote != null && quote.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    quote,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  _formatRepostedAt(repost.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage({
    required this.icon,
    required this.message,
    this.showRetry = false,
    this.onRetry,
  });

  final IconData icon;
  final String message;
  final bool showRetry;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.p12),
                child: Icon(icon, size: 22, color: cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: AppSizes.p12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (showRetry && onRetry != null) ...[
              const SizedBox(height: AppSizes.p12),
              IconButton.filled(
                onPressed: onRetry,
                style: IconButton.styleFrom(
                  backgroundColor: cs.primary.withValues(alpha: 0.12),
                  foregroundColor: cs.primary,
                ),
                icon: const Icon(LucideIcons.refreshCw, size: 18),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatRepostedAt(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${diff.inDays ~/ 7}w ago';
  return '${date.day}/${date.month}/${date.year}';
}
