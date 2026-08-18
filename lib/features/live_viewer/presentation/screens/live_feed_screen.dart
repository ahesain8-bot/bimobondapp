import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../../../core/services/live_feed_refresh_bus.dart';
import '../providers/live_feed_provider.dart';
import '../providers/live_session_provider.dart';
import '../widgets/live_room_page.dart';
import '../../../live/presentation/utils/live_screen_wakelock.dart';

/// TikTok LIVE home: full-screen vertical swipe between running lives.
///
/// Wraps its own [ProviderScope] so the screen works even if the app root
/// was started without one (hot reload cannot re-run [runApp]).
class LiveFeedScreen extends StatelessWidget {
  const LiveFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: _LiveFeedView());
  }
}

class _LiveFeedView extends ConsumerStatefulWidget {
  const _LiveFeedView();

  @override
  ConsumerState<_LiveFeedView> createState() => _LiveFeedViewState();
}

class _LiveFeedViewState extends ConsumerState<_LiveFeedView>
    with WidgetsBindingObserver {
  late final PageController _pageController;
  int _currentIndex = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    LiveScreenWakelock.enable();
    Future.microtask(() async {
      await ref.read(liveFeedProvider.notifier).loadFeed();
    });

    // When the host ends a live, remove it from the feed immediately.
    LiveFeedRefreshBus.instance.addListener(_onLiveEndedSignal);

    // Background merge: new lives are appended to the feed automatically so
    // they show up when the user swipes down — no pull-to-refresh needed.
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _silentRefresh(),
    );
  }

  Future<void> _silentRefresh() async {
    if (!mounted) return;
    await ref.read(liveFeedProvider.notifier).silentRefresh();
    if (!mounted) return;
    // Clamp the current page if the list shrank below it.
    final lives = ref.read(liveFeedProvider).lives;
    if (lives.isEmpty) return;
    if (_currentIndex >= lives.length) {
      final target = lives.length - 1;
      _pageController.jumpToPage(target);
      setState(() => _currentIndex = target);
    }
  }

  void _onLiveEndedSignal() {
    if (!mounted) return;
    final endedId = LiveFeedRefreshBus.instance.lastEndedLiveId;
    if (endedId == null) return;
    // Removing the live triggers the ref.listen in build() which clamps the
    // page and re-activates the live now at the current position.
    ref.read(liveFeedProvider.notifier).removeLive(endedId);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      LiveScreenWakelock.enable();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // App sent to background: ALWAYS tear down the active live session so
      // audio/video/socket/LiveKit never keep running when the user isn't
      // viewing.
      ref.read(activeLiveProvider.notifier).deactivate();
      LiveScreenWakelock.disable();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    LiveFeedRefreshBus.instance.removeListener(_onLiveEndedSignal);
    // Deactivate current live BEFORE disposing the controller so we don't
    // leave a dangling LiveKit connection + socket on viewer exit.
    ref.read(activeLiveProvider.notifier).deactivate();
    _pageController.dispose();
    LiveScreenWakelock.disable();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final feed = ref.read(liveFeedProvider);
      final lives = feed.lives;

      // Reached the loading/refresh page at the end of the feed.
      // Swiping down here asks the server for new lives:
      //  - if a new live appeared, it shows and the user stays on it;
      //  - if nothing new, bounce back to the current live.
      if (index >= lives.length) {
        final before = lives.length;
        await ref.read(liveFeedProvider.notifier).silentRefresh();
        if (!mounted) return;
        final after = ref.read(liveFeedProvider).lives.length;
        if (after == before) {
          // No new lives: return to the last real live.
          final target = after - 1;
          if (target >= 0) {
            _pageController.jumpToPage(target);
            setState(() => _currentIndex = target);
            final currentLives = ref.read(liveFeedProvider).lives;
            ref.read(activeLiveProvider.notifier).activate(currentLives[target]);
          }
        } else {
          // New lives appeared: activate the live now at this index.
          final newLives = ref.read(liveFeedProvider).lives;
          if (index < newLives.length) {
            ref.read(activeLiveProvider.notifier).activate(newLives[index]);
          }
        }
        return;
      }

      if (index >= lives.length - 2 && feed.hasMore) {
        ref.read(liveFeedProvider.notifier).loadMore();
      }

      final notifier = ref.read(activeLiveProvider.notifier);
      final current = lives[index];
      if (notifier.activeLiveId != null &&
          notifier.activeLiveId != current.id) {
        notifier.deactivate();
      }
      notifier.activate(current);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final feed = ref.watch(liveFeedProvider);

    // When a live is removed from the feed (host ended it / socket liveEnded),
    // the live at the current index changes. Re-activate it so video/audio
    // keeps playing instead of showing only the "live" badge.
    ref.listen<LiveFeedState>(liveFeedProvider, (previous, next) {
      if (previous == null) return;
      final prevLives = previous.lives;
      final nextLives = next.lives;
      if (nextLives.isEmpty) return;

      final idx = _currentIndex.clamp(0, nextLives.length - 1);
      final prevId = idx < prevLives.length ? prevLives[idx].id : null;
      final nextId = nextLives[idx].id;

      if (prevId != nextId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final lives = ref.read(liveFeedProvider).lives;
          if (lives.isEmpty) return;
          final target = _currentIndex.clamp(0, lives.length - 1);
          if (_currentIndex != target) {
            _pageController.jumpToPage(target);
            setState(() => _currentIndex = target);
          }
          // Re-activate the live now at the current position so its
          // video/audio actually plays.
          ref.read(activeLiveProvider.notifier).activate(lives[target]);
        });
      }
    });

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: _buildBody(feed),
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
        RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: Colors.black,
          onRefresh: _refresh,
          displacement: 60,
          strokeWidth: 2.5,
          child: PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            allowImplicitScrolling: false,
            physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
            // Always keep a trailing loading/refresh page so swiping down at
            // the end of the feed triggers a check for new lives.
            itemCount: feed.lives.length + 1,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE2E8F0),
      highlightColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF1F5F9),
      child: Container(color: isDark ? Colors.black : Colors.white),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final Failure error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isAuth = error is AuthorizationFailure || error is AuthenticationFailure;
    final isNetwork = error is NetworkFailure;
    final icon = isNetwork
        ? Icons.wifi_off_outlined
        : isAuth
            ? Icons.lock_outline
            : Icons.error_outline;
    final title = isNetwork
        ? 'Can\u2019t connect'
        : isAuth
            ? 'Please sign in'
            : 'Couldn\u2019t load LIVE';
    final cta = isAuth ? 'Sign in' : 'Retry';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.error, size: 56),
            const SizedBox(height: 12),
            Text(title, style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            Text(
              error.message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onRetry, child: Text(cta)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.live_tv_outlined,
            size: 72,
            color: isDark
                ? Colors.white.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 12),
          Text(
            'No live streams right now',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: onRefresh, child: const Text('Refresh')),
        ],
      ),
    );
  }
}
