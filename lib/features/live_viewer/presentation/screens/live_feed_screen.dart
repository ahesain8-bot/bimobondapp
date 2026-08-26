import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/services/live_feed_refresh_bus.dart';
import '../../../../core/theme/cubit/theme_cubit.dart';
import '../../../live/presentation/utils/live_screen_wakelock.dart';
import '../bloc/live_feed/live_feed_bloc.dart';
import '../bloc/live_feed/live_feed_event.dart';
import '../bloc/live_feed/live_feed_state.dart';
import '../bloc/live_viewer/live_viewer_bloc.dart';
import '../bloc/live_viewer/live_viewer_event.dart';
import '../bloc/live_viewer/live_viewer_state.dart';
import '../di/live_viewer_injector.dart' as di;
import '../widgets/live_room_page.dart';
import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/entities/live_entity.dart';

/// TikTok LIVE home: full-screen vertical swipe between running lives.
///
/// Now uses BLoC (LiveFeedBloc + LiveViewerBloc) instead of Riverpod.
/// Both blocs are wired here so their lifecycle matches the feed screen.
class LiveFeedScreen extends StatefulWidget {
  const LiveFeedScreen({super.key});

  @override
  State<LiveFeedScreen> createState() => _LiveFeedViewState();
}

class _LiveFeedViewState extends State<LiveFeedScreen>
    with WidgetsBindingObserver {
  late final LiveFeedBloc _feedBloc;
  late final LiveViewerBloc _viewerBloc;
  late final PageController _pageController;
  int _currentIndex = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _feedBloc = di.sl<LiveFeedBloc>();
    _viewerBloc = di.sl<LiveViewerBloc>();
    _pageController = PageController();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    LiveScreenWakelock.enable();
    Future.microtask(() {
      _feedBloc.add(const LiveFeedLoadRequested(refresh: true));
    });

    LiveFeedRefreshBus.instance.addListener(_onLiveEndedSignal);

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _silentRefresh(),
    );
  }

  Future<void> _silentRefresh() async {
    if (!mounted) return;
    _feedBloc.add(const LiveFeedSilentRefreshRequested());
  }

  void _onLiveEndedSignal() {
    if (!mounted) return;
    final endedId = LiveFeedRefreshBus.instance.lastEndedLiveId;
    if (endedId == null) return;
    _feedBloc.add(LiveFeedLiveRemoved(endedId));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      LiveScreenWakelock.enable();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _viewerBloc.add(const LiveViewerDeactivated());
      LiveScreenWakelock.disable();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    LiveFeedRefreshBus.instance.removeListener(_onLiveEndedSignal);
    _viewerBloc.add(const LiveViewerDeactivated());
    _pageController.dispose();
    _feedBloc.close();
    _viewerBloc.close();
    LiveScreenWakelock.disable();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final feed = _feedBloc.state;
      final lives = feed.lives;

      if (index >= lives.length) {
        final before = lives.length;
        _feedBloc.add(const LiveFeedSilentRefreshRequested());
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        final after = _feedBloc.state.lives.length;
        if (after == before) {
          final target = (after - 1).clamp(0, double.maxFinite.toInt());
          if (target >= 0) {
            _pageController.jumpToPage(target);
            setState(() => _currentIndex = target);
            final newLives = _feedBloc.state.lives;
            if (target < newLives.length) {
              _viewerBloc.add(LiveViewerActivated(newLives[target]));
            }
          }
        } else {
          final newLives = _feedBloc.state.lives;
          if (index < newLives.length) {
            _viewerBloc.add(LiveViewerActivated(newLives[index]));
          }
        }
        return;
      }

      if (index >= lives.length - 2 && feed.hasMore) {
        _feedBloc.add(const LiveFeedLoadMoreRequested());
      }

      final current = lives[index];
      if (_viewerBloc.activeLiveId != null &&
          _viewerBloc.activeLiveId != current.id) {
        _viewerBloc.add(const LiveViewerDeactivated());
      }
      _viewerBloc.add(LiveViewerActivated(current));
    });
  }

  Future<void> _refresh() async {
    _feedBloc.add(const LiveFeedRefreshRequested());
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    final lives = _feedBloc.state.lives;
    if (lives.isNotEmpty) {
      _pageController.jumpToPage(0);
      setState(() => _currentIndex = 0);
      _viewerBloc.add(LiveViewerActivated(lives.first));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MultiBlocProvider(
      providers: [
        BlocProvider<LiveFeedBloc>.value(value: _feedBloc),
        BlocProvider<LiveViewerBloc>.value(value: _viewerBloc),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<LiveFeedBloc, LiveFeedState>(
            listenWhen: (prev, next) {
              if (prev.lives.length == next.lives.length) return false;
              return true;
            },
            listener: (context, next) {
              if (next.lives.isEmpty) return;
              final idx = _currentIndex.clamp(0, next.lives.length - 1);
              final prevLivesCount = 0;
              if (next.lives.length != prevLivesCount &&
                  (_viewerBloc.activeLiveId == null ||
                      !next.lives.any(
                        (l) => l.id == _viewerBloc.activeLiveId,
                      ))) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  final lives = _feedBloc.state.lives;
                  if (lives.isEmpty) return;
                  final target = _currentIndex.clamp(0, lives.length - 1);
                  if (_currentIndex != target) {
                    _pageController.jumpToPage(target);
                    setState(() => _currentIndex = target);
                  }
                  _viewerBloc.add(LiveViewerActivated(lives[target]));
                });
              }
            },
          ),
        ],
        child: Scaffold(
          backgroundColor: isDark ? Colors.black : Colors.white,
          // The live canvas remains full-screen while the composer handles
          // its own keyboard inset. Resizing this scaffold moves the video,
          // chrome, comments, and every bottom-anchored overlay together.
          resizeToAvoidBottomInset: false,
          body: BlocBuilder<LiveFeedBloc, LiveFeedState>(
            builder: (context, feed) {
              return _buildBody(feed);
            },
          ),
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
        RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: Colors.black,
          onRefresh: () async {
            _refresh();
          },
          displacement: 60,
          strokeWidth: 2.5,
          child: PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            allowImplicitScrolling: false,
            physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
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
      highlightColor: isDark
          ? const Color(0xFF2A2A2A)
          : const Color(0xFFF1F5F9),
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
    final isAuth =
        error is AuthorizationFailure || error is AuthenticationFailure;
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
