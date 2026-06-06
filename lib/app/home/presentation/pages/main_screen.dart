import 'dart:io';
import 'dart:ui';

import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/auth/presentation/pages/login_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/personal_info_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/profile_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/auctions_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/home_feed_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/messages_screen.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/add_post_media_picker_sheet.dart';
import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart' as auth_di;
import 'package:bimobondapp/app/home/presentation/utils/active_stories_registry.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/theme/feed_overlay_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadActiveStories());
  }

  void _loadActiveStories() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) {
      context.read<PostsBloc>().add(
        const FetchStoriesRequestedEvent(isRefresh: true),
      );
    }
  }

  Future<void> _showAddPostOptions() {
    return AddPostMediaPickerSheet.show(
      context,
      onPick: _pickMedia,
    );
  }

  Future<void> _pickMedia(ImageSource source, {required bool isVideo}) async {
    try {
      if (isVideo) {
        final XFile? video = await _picker.pickVideo(source: source);
        if (video != null && mounted) {
          context.pushNamed(
            'add_post',
            extra: {
              'files': [File(video.path)],
              'type': 'VIDEO',
            },
          );
        }
      } else if (source == ImageSource.camera) {
        final XFile? photo = await _picker.pickImage(
          source: ImageSource.camera,
        );
        if (photo != null && mounted) {
          context.pushNamed(
            'add_post',
            extra: {
              'files': [File(photo.path)],
              'type': 'IMAGE',
            },
          );
        }
      } else {
        final List<XFile> images = await _picker.pickMultiImage();
        if (images.isNotEmpty && mounted) {
          final files = images.map((e) => File(e.path)).toList();
          context.pushNamed(
            'add_post',
            extra: {
              'files': files,
              'type': files.length > 1 ? 'CAROUSEL' : 'IMAGE',
            },
          );
        }
      }
    } catch (e) {
      if (mounted) {
        PopupDialogs.showErrorDialog(context, 'Error picking media: $e');
      }
    }
  }

  void _onNavTap(int index, {required bool isLoggedIn, AuthState? authState}) {
    if (isLoggedIn && index == 2) {
      _showAddPostOptions();
      return;
    }

    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoggedIn = state is AuthSuccess;
        final isHome = _currentIndex == 0;

        final pages = isLoggedIn
            ? [
                HomeFeedScreen(isTabActive: _currentIndex == 0),
                AuctionsScreen(isTabActive: _currentIndex == 1),
                const SizedBox.shrink(),
                MessagesScreen(isTabActive: _currentIndex == 3),
                ProfileScreen(isTabActive: _currentIndex == 4),
              ]
            : [
                HomeFeedScreen(isTabActive: _currentIndex == 0),
                const ProfileTab(),
              ];

        if (_currentIndex >= pages.length) {
          _currentIndex = 0;
        }

        return MultiBlocListener(
          listeners: [
            BlocListener<AuthBloc, AuthState>(
              listenWhen: (previous, current) {
                if (current is AuthInitial) return true;
                // Only reset tab on fresh login, not profile refresh (AuthSuccess → AuthSuccess).
                return current is AuthSuccess && previous is! AuthSuccess;
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
                } else if (state is CreatePostSuccess) {
                  setState(() => _currentIndex = 0);
                  if (state.post.isStory) {
                    _loadActiveStories();
                  }
                } else if (state is DeletePostSuccess) {
                  _loadActiveStories();
                }
              },
            ),
          ],
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            extendBody: isHome,
            body: IndexedStack(
              key: ValueKey(isLoggedIn),
              index: _currentIndex,
              children: pages,
            ),
            bottomNavigationBar: isLoggedIn
                ? _buildTikTokBottomNav(context, l10n, state)
                : _buildGuestBottomNav(context, l10n),
          ),
        );
      },
    );
  }

  Widget _buildTikTokBottomNav(
    BuildContext context,
    AppLocalizations l10n,
    AuthState authState,
  ) {
    final isHome = _currentIndex == 0;
    final theme = Theme.of(context);
    final feedOverlay = FeedOverlayTheme.of(context);
    final primary = theme.colorScheme.primary;

    final selectedColor = primary;
    final unselectedColor = isHome
        ? feedOverlay.overlayForegroundMuted
        : theme.colorScheme.onSurface.withValues(alpha: 0.45);

    Widget navBar = Container(
      decoration: BoxDecoration(
        color: isHome ? feedOverlay.navBarScrim : theme.scaffoldBackgroundColor,
        border: isHome
            ? null
            : Border(
                top: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
              ),
      ),
      padding: EdgeInsets.only(
        bottom:
            MediaQuery.paddingOf(context).bottom +
            HomeLayoutConstants.bottomNavSafeExtra,
        top: HomeLayoutConstants.bottomNavTopPadding,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildNavItem(
            icon: LucideIcons.house,
            label: l10n.navHome,
            index: 0,
            selectedColor: selectedColor,
            unselectedColor: unselectedColor,
            isLoggedIn: true,
            authState: authState,
          ),
          _buildNavItem(
            icon: LucideIcons.gavel,
            label: l10n.navAuctions,
            index: 1,
            selectedColor: selectedColor,
            unselectedColor: unselectedColor,
            isLoggedIn: true,
            authState: authState,
          ),
          _buildAddButton(context),
          _buildNavItem(
            icon: LucideIcons.messageSquare,
            label: l10n.navChat,
            index: 3,
            selectedColor: selectedColor,
            unselectedColor: unselectedColor,
            isLoggedIn: true,
            authState: authState,
          ),
          _buildNavItem(
            icon: LucideIcons.user,
            label: l10n.navProfile,
            index: 4,
            selectedColor: selectedColor,
            unselectedColor: unselectedColor,
            isLoggedIn: true,
            authState: authState,
          ),
        ],
      ),
    );

    if (isHome) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: HomeLayoutConstants.navBlurSigma,
            sigmaY: HomeLayoutConstants.navBlurSigma,
          ),
          child: navBar,
        ),
      );
    }
    return navBar;
  }

  Widget _buildGuestBottomNav(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final feedOverlay = FeedOverlayTheme.of(context);
    final isHome = _currentIndex == 0;
    final primary = theme.colorScheme.primary;

    final selectedColor = primary;
    final unselectedColor = isHome
        ? feedOverlay.overlayForegroundMuted
        : theme.colorScheme.onSurface.withValues(alpha: 0.45);

    Widget navBar = Container(
      decoration: BoxDecoration(
        color: isHome ? feedOverlay.navBarScrim : theme.scaffoldBackgroundColor,
        border: isHome
            ? null
            : Border(
                top: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
              ),
      ),
      padding: EdgeInsets.only(
        bottom:
            MediaQuery.paddingOf(context).bottom +
            HomeLayoutConstants.bottomNavSafeExtra,
        top: HomeLayoutConstants.bottomNavTopPadding,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(
            icon: LucideIcons.house,
            label: l10n.navHome,
            index: 0,
            selectedColor: selectedColor,
            unselectedColor: unselectedColor,
            isLoggedIn: false,
          ),
          _buildNavItem(
            icon: LucideIcons.user,
            label: l10n.navProfile,
            index: 1,
            selectedColor: selectedColor,
            unselectedColor: unselectedColor,
            isLoggedIn: false,
          ),
        ],
      ),
    );

    if (isHome) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: HomeLayoutConstants.navBlurSigma,
            sigmaY: HomeLayoutConstants.navBlurSigma,
          ),
          child: navBar,
        ),
      );
    }
    return navBar;
  }

  Widget _buildAddButton(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => _onNavTap(2, isLoggedIn: true),
      child: Padding(
        padding: const EdgeInsets.only(
          bottom: HomeLayoutConstants.navItemBottomPadding,
        ),
        child: Container(
          width: HomeLayoutConstants.addButtonWidth,
          height: HomeLayoutConstants.addButtonHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(
              HomeLayoutConstants.addButtonRadius,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: HomeLayoutConstants.addButtonShadowBlur,
                offset: const Offset(
                  0,
                  HomeLayoutConstants.addButtonShadowOffsetY,
                ),
              ),
            ],
          ),
          child: Icon(
            LucideIcons.plus,
            color: theme.colorScheme.onPrimary,
            size: HomeLayoutConstants.addButtonIconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required Color selectedColor,
    required Color unselectedColor,
    required bool isLoggedIn,
    AuthState? authState,
  }) {
    final theme = Theme.of(context);
    final isSelected = _currentIndex == index;
    final color = isSelected ? selectedColor : unselectedColor;

    return GestureDetector(
      onTap: () =>
          _onNavTap(index, isLoggedIn: isLoggedIn, authState: authState),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: HomeLayoutConstants.navIconSize),
          const SizedBox(height: AppSizes.p4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontSize: HomeLayoutConstants.navLabelFontSize,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
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
