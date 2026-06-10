import 'package:bimobondapp/app/posts/domain/entities/repost_entity.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_post_reposts_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart' as posts_di;
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_surface.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _repostAccent = Color(0xFF2ECC71);

class PostRepostersSheet {
  PostRepostersSheet._();

  static Future<void> show({
    required BuildContext context,
    required String postId,
    int repostCount = 0,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;

    return GlassBottomSheet.showContent<void>(
      context,
      isScrollControlled: true,
      adaptTheme: true,
      title: l10n.postRepostersTitle(repostCount),
      child: SizedBox(
        height: maxHeight * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.p20),
              child: Text(
                l10n.repostSubtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.p8),
            Expanded(child: _PostRepostersList(postId: postId)),
          ],
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
          AppSizes.p16,
          AppSizes.p12,
          AppSizes.p16,
          AppSizes.p24,
        ),
        itemCount: 5,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: AppSizes.p10),
          child: SkeletonWidget(height: 68, borderRadius: 14),
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

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.p16,
        AppSizes.p12,
        AppSizes.p16,
        AppSizes.p24,
      ),
      itemCount: _reposts.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: AppSizes.p8),
      itemBuilder: (context, index) {
        if (index >= _reposts.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.p12),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _repostAccent,
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

class _ReposterCard extends StatelessWidget {
  const _ReposterCard({required this.repost});

  final RepostEntity repost;

  @override
  Widget build(BuildContext context) {
    final user = repost.user;
    if (user == null) return const SizedBox.shrink();

    final displayName = user.fullName?.trim().isNotEmpty == true
        ? user.fullName!
        : user.username;
    final quote = repost.quote?.trim();

    return LiquidGlassSurface(
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.p12,
          vertical: AppSizes.p10,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SafeNetworkAvatar(
              imageUrl: user.avatarUrl,
              radius: 22,
              fallbackText: user.username,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
            ),
            const SizedBox(width: AppSizes.p12),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (user.isVerified) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.verified,
                          size: 15,
                          color: Colors.blue.shade300,
                        ),
                      ],
                    ],
                  ),
                  if (user.username.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '@${user.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (quote != null && quote.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.p6),
                    Text(
                      quote,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.repeat2,
                        size: 12,
                        color: _repostAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatRepostedAt(repost.createdAt),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LiquidGlassSurface(
              borderRadius: BorderRadius.circular(28),
              padding: const EdgeInsets.all(AppSizes.p16),
              child: Icon(
                icon,
                size: 24,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: AppSizes.p16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (showRetry && onRetry != null) ...[
              const SizedBox(height: AppSizes.p16),
              IconButton.filled(
                onPressed: onRetry,
                style: IconButton.styleFrom(
                  backgroundColor: _repostAccent.withValues(alpha: 0.12),
                  foregroundColor: _repostAccent,
                ),
                icon: const Icon(LucideIcons.refreshCw, size: 20),
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
