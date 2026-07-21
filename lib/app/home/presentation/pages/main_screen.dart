import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/auth/presentation/pages/login_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/personal_info_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/profile_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/auctions_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/home_feed_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/messages_screen.dart';
import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart'
    as auth_di;
import 'package:bimobondapp/app/home/presentation/utils/active_stories_registry.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/core/services/feed_playback_gate.dart';
import 'package:bimobondapp/core/utils/system_ui_overlay_utils.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_bottom_nav.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  String? _pendingOpenStoryUserId;
  final GlobalKey<HomeFeedScreenState> _homeFeedKey =
      GlobalKey<HomeFeedScreenState>();
  final GlobalKey<AuctionsScreenState> _auctionsKey =
      GlobalKey<AuctionsScreenState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadActiveStories());
  }

  @override
  void didUpdateWidget(MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      setState(() {
        _currentIndex = widget.initialIndex;
      });
    }
  }

  void _loadActiveStories() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) {
      context.read<PostsBloc>().add(
        const FetchStoriesRequestedEvent(isRefresh: true),
      );
    }
  }

  void _openAddPostCamera() {
    FeedPlaybackGate.instance.setBlocked(true);
    context.pushNamed('add_post_camera');
  }

  void _onNavTap(int index, {required bool isLoggedIn}) {
    if (isLoggedIn &&
        index == LiquidGlassBottomNavItems.loggedInAddButtonIndex) {
      _openAddPostCamera();
      return;
    }

    // Re-tapping the active tab refreshes that section (TikTok-style).
    if (index == _currentIndex) {
      if (index == 0) {
        _homeFeedKey.currentState?.refreshFromTab();
      } else if (isLoggedIn && index == 1) {
        _auctionsKey.currentState?.refreshFromTab();
      }
      return;
    }

    setState(() => _currentIndex = index);
  }

  void _handleSystemBack() {
    // Any tab except Home → go Home first (don't exit).
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return;
    }

    // On Home → close the app.
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoggedIn = state is AuthSuccess;
        final isHome = _currentIndex == 0;

        if (_currentIndex >= (isLoggedIn ? 5 : 2)) {
          _currentIndex = 0;
        }

        final pages = isLoggedIn
            ? [
                HomeFeedScreen(key: _homeFeedKey, isTabActive: isHome),
                AuctionsScreen(
                  key: _auctionsKey,
                  isTabActive: _currentIndex == 1,
                ),
                const SizedBox.shrink(),
                MessagesScreen(isTabActive: _currentIndex == 3),
                ProfileScreen(isTabActive: _currentIndex == 4),
              ]
            : [
                HomeFeedScreen(key: _homeFeedKey, isTabActive: isHome),
                const ProfileTab(),
              ];

        return MultiBlocListener(
          listeners: [
            BlocListener<AuthBloc, AuthState>(
              listenWhen: (previous, current) {
                if (current is AuthInitial) return true;
                // Fresh login only — ignore profile refresh and
                // AuthLoading → AuthSuccess from update-profile.
                return current is AuthSuccess &&
                    (previous is AuthInitial || previous is AuthFailure);
              },
              listener: (context, authState) {
                if (authState is AuthSuccess) {
                  setState(() => _currentIndex = 0);
                } else if (authState is AuthInitial) {
                  setState(() => _currentIndex = 0);
                  context.go('/');
                }
              },
            ),
            BlocListener<PostsBloc, PostsState>(
              listener: (context, state) {
                if (state is StoriesLoadSuccess) {
                  auth_di.sl<ActiveStoriesRegistry>().updateFromStories(
                    state.stories,
                  );
                  if (_pendingOpenStoryUserId != null) {
                    final userId = _pendingOpenStoryUserId!;
                    _pendingOpenStoryUserId = null;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      openUserActiveStories(context, userId);
                    });
                  }
                } else if (state is CreatePostSuccess) {
                  if (state.post.isStory) {
                    setState(() {
                      _currentIndex = 4;
                      _pendingOpenStoryUserId = state.post.userId;
                    });
                    _loadActiveStories();
                  } else {
                    setState(() => _currentIndex = 4);
                  }
                } else if (state is DeletePostSuccess) {
                  _loadActiveStories();
                }
              },
            ),
          ],
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              _handleSystemBack();
            },
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: isHome
                  ? feedImmersiveSystemUiOverlayStyle
                  : appContentSystemUiOverlayStyle(
                      Theme.of(context).brightness,
                    ),
              child: Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                extendBody: isHome,
                body: IndexedStack(
                  key: ValueKey(isLoggedIn),
                  index: _currentIndex,
                  children: pages,
                ),
                bottomNavigationBar: LiquidGlassBottomNav(
                  currentIndex: _currentIndex,
                  glassStyle: isHome,
                  onItemTap: (index) =>
                      _onNavTap(index, isLoggedIn: isLoggedIn),
                  items: isLoggedIn
                      ? LiquidGlassBottomNavItems.loggedIn(
                          homeLabel: l10n.navHome,
                          auctionsLabel: l10n.navAuctions,
                          chatLabel: l10n.navChat,
                          profileLabel: l10n.navProfile,
                        )
                      : LiquidGlassBottomNavItems.guest(
                          homeLabel: l10n.navHome,
                          profileLabel: l10n.navProfile,
                        ),
                  center: isLoggedIn
                      ? LiquidGlassBottomNav.addButton(
                          context: context,
                          onTap: () => _onNavTap(
                            LiquidGlassBottomNavItems.loggedInAddButtonIndex,
                            isLoggedIn: true,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthSuccess) {
          return const PersonalInfoScreen();
        }
        return const LoginScreen(language: 'ar');
      },
    );
  }
}
