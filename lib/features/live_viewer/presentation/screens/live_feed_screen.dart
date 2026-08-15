import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import 'package:go_router/go_router.dart';

import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../providers/live_feed_provider.dart';
import '../providers/live_session_provider.dart';
import '../widgets/live_room_page.dart';

/// TikTok LIVE home: full-screen vertical swipe between running lives.
class LiveFeedScreen extends ConsumerStatefulWidget {
  const LiveFeedScreen({super.key});

  @override
  ConsumerState<LiveFeedScreen> createState() => _LiveFeedScreenState();
}

class _LiveFeedScreenState extends ConsumerState<LiveFeedScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    Future.microtask(() async {
      await ref.read(liveFeedProvider.notifier).loadFeed();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);

    // Defer provider writes until after this frame finishes building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final lives = ref.read(liveFeedProvider).lives;
      if (index >= lives.length - 2) {
        ref.read(liveFeedProvider.notifier).loadMore();
      }
      if (index < lives.length) {
        ref.read(activeLiveProvider.notifier).activate(lives[index]);
      }
    });
  }

  Future<void> _refresh() async {
    await ref.read(liveFeedProvider.notifier).refresh();
    if (!mounted) return;
    final lives = ref.read(liveFeedProvider).lives;
    if (lives.isNotEmpty) {
      _pageController.jumpToPage(0);
      setState(() => _currentIndex = 0);
      await ref.read(activeLiveProvider.notifier).activate(lives.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(liveFeedProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildBody(feed),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create-live'),
        backgroundColor: const Color(0xFFEF4B5B),
        icon: const Icon(Icons.videocam, color: Colors.white),
        label: const Text(
          'إنشاء بث',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildBody(LiveFeedState feed) {
    if (feed.isLoading && feed.lives.isEmpty) {
      return _LoadingSkeleton();
    }

    if (feed.error != null && feed.lives.isEmpty) {
      return _ErrorView(error: feed.error!, onRetry: _refresh);
    }

    if (feed.lives.isEmpty) {
      return _EmptyView(onRefresh: _refresh);
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          allowImplicitScrolling: false,
          physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
          itemCount: feed.lives.length + (feed.hasMore ? 1 : 0),
          onPageChanged: _onPageChanged,
          itemBuilder: (context, index) {
            if (index >= feed.lives.length) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            final live = feed.lives[index];
            return LiveRoomPage(
              key: ValueKey(live.id),
              live: live,
              isActive: index == _currentIndex,
              onClose: () {
                if (_currentIndex + 1 < feed.lives.length) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                  );
                }
              },
            );
          },
        ),
        if (_currentIndex == 0)
          Positioned(
            right: 12,
            bottom: MediaQuery.paddingOf(context).bottom + 70,
            child: IgnorePointer(
              child: Column(
                children: [
                  Icon(
                    Icons.keyboard_arrow_up,
                    color: Colors.white.withValues(alpha: 0.35),
                    size: 22,
                  ),
                  Text(
                    'Swipe',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1A1A),
      highlightColor: const Color(0xFF2A2A2A),
      child: Container(color: Colors.white),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final Failure error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 56),
            const SizedBox(height: 12),
            Text('Couldn\'t load LIVE', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            Text(
              error.message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyView({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.live_tv_outlined,
            size: 72,
            color: Colors.white.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 12),
          const Text(
            'No live streams right now',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: onRefresh, child: const Text('Refresh')),
        ],
      ),
    );
  }
}
