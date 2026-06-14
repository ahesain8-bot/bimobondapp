import 'dart:io';

import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/auth/presentation/pages/login_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/personal_info_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/profile_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/auctions_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/home_feed_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/messages_screen.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/add_post_media_picker_sheet.dart';
import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart'
    as auth_di;
import 'package:bimobondapp/app/home/presentation/utils/active_stories_registry.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_bottom_nav.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final ImagePicker _picker = ImagePicker();
  String? _pendingOpenStoryUserId;

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
    return AddPostMediaPickerSheet.show(context, onPick: _pickMedia);
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

  void _onNavTap(int index, {required bool isLoggedIn}) {
    if (isLoggedIn &&
        index == LiquidGlassBottomNavItems.loggedInAddButtonIndex) {
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
                    setState(() => _currentIndex = 0);
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
            bottomNavigationBar: LiquidGlassBottomNav(
              currentIndex: _currentIndex,
              glassStyle: isHome,
              onItemTap: (index) => _onNavTap(index, isLoggedIn: isLoggedIn),
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
