import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bimobondapp/app/home/presentation/pages/main_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/login_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/phone_login_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/signup_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/otp_verification_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/email_otp_verification_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/email_verification_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/splash_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/personal_info_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/admin_user_activity_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/settings_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/chat_wallpaper_settings_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/change_avatar_screen.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/notifications/presentation/pages/notifications_screen.dart';
import 'package:bimobondapp/app/posts/presentation/pages/post_detail_screen.dart';
import 'package:bimobondapp/app/posts/presentation/pages/profile_posts_viewer_screen.dart';
import 'package:bimobondapp/core/navigation/post_navigation.dart';
import 'package:bimobondapp/core/navigation/profile_posts_navigation.dart';
import 'package:bimobondapp/app/home/presentation/pages/add_post_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/stories_viewer_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/chat_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/all_chats_screen.dart';
import 'package:bimobondapp/app/social/presentation/pages/follow_suggestions_screen.dart';
import 'package:bimobondapp/app/social/presentation/pages/user_comments_screen.dart';
import 'package:bimobondapp/app/social/presentation/pages/my_followers_screen.dart';
import 'package:bimobondapp/app/social/presentation/pages/user_likes_screen.dart';
import 'package:bimobondapp/app/social/presentation/pages/user_mentions_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/live_details_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/lives_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/hashtag_feed_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/posts_search_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/ended_auctions_screen.dart';
import 'package:bimobondapp/app/posts/presentation/pages/edit_post_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/user_profile_screen.dart';
import 'package:bimobondapp/app/social/presentation/pages/user_connections_screen.dart';
import 'dart:io';

class AppRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const MainScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(language: 'ar'),
      ),
      GoRoute(
        path: '/phone-login',
        name: 'phone_login',
        builder: (context, state) => const PhoneLoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const SignUpScreen(language: 'ar'),
      ),
      GoRoute(
        path: '/otp-verify',
        name: 'otp_verify',
        builder: (context, state) {
          final verificationId = state.uri.queryParameters['verificationId']!;
          final phoneNumber = state.uri.queryParameters['phoneNumber']!;
          return OtpVerificationScreen(
            verificationId: verificationId,
            phoneNumber: phoneNumber,
          );
        },
      ),
      GoRoute(
        path: '/email-otp-verify',
        name: 'email_otp_verify',
        builder: (context, state) {
          final email = state.uri.queryParameters['email']!;
          return EmailOtpVerificationScreen(email: email);
        },
      ),
      GoRoute(
        path: '/email-verification',
        name: 'email_verification',
        builder: (context, state) {
          final email = state.uri.queryParameters['email']!;
          return EmailVerificationScreen(email: email);
        },
      ),
      GoRoute(
        path: '/personal-info',
        name: 'personal_info',
        builder: (context, state) => const PersonalInfoScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/chat-wallpaper',
        name: 'chat_wallpaper_settings',
        builder: (context, state) => const ChatWallpaperSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/admin-activity',
        name: 'admin_user_activity',
        builder: (context, state) {
          final userId = state.uri.queryParameters['userId'];
          return AdminUserActivityScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/change-avatar',
        name: 'change_avatar',
        builder: (context, state) => const ChangeAvatarScreen(),
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/post-detail',
        name: 'post_detail',
        builder: (context, state) {
          final args = postOpenArgsFromExtra(state.extra);
          if (args == null) {
            return const Scaffold(
              body: Center(child: Text('Post not found')),
            );
          }
          if (args.post.isAuctionable) {
            return LiveDetailsScreen(post: args.post);
          }
          return PostDetailScreen(
            post: args.post,
            openCommentsOnLoad: args.openComments,
            highlightCommentId: args.highlightCommentId,
          );
        },
      ),
      GoRoute(
        path: '/profile-posts',
        name: 'profile_posts_viewer',
        builder: (context, state) {
          final args = profilePostsOpenArgsFromExtra(state.extra);
          if (args == null) {
            return const Scaffold(
              body: Center(child: Text('Post not found')),
            );
          }
          return ProfilePostsViewerScreen(args: args);
        },
      ),
      GoRoute(
        path: '/lives',
        name: 'lives',
        builder: (context, state) => const LivesScreen(),
      ),
      GoRoute(
        path: '/posts-search',
        name: 'posts_search',
        builder: (context, state) => const PostsSearchScreen(),
      ),
      GoRoute(
        path: '/hashtag',
        name: 'hashtag_feed',
        builder: (context, state) {
          final name = state.uri.queryParameters['name'] ?? '';
          return HashtagFeedScreen(hashtagName: name);
        },
      ),
      GoRoute(
        path: '/ended-auctions',
        name: 'ended_auctions',
        builder: (context, state) => const EndedAuctionsScreen(),
      ),
      GoRoute(
        path: '/chat',
        name: 'chat',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ChatScreen(
            chatId: extra?['chatId'] as String? ?? '',
            username: extra?['username'] as String? ?? 'User',
            imageUrl: extra?['imageUrl'] as String? ?? '',
            peerUserId: extra?['peerUserId'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/all-chats',
        name: 'all_chats',
        builder: (context, state) => const AllChatsScreen(),
      ),
      GoRoute(
        path: '/chat-search',
        name: 'chat_search',
        builder: (context, state) =>
            const AllChatsScreen(autofocusSearch: true),
      ),
      GoRoute(
        path: '/follow-suggestions',
        name: 'follow_suggestions',
        builder: (context, state) => const FollowSuggestionsScreen(),
      ),
      GoRoute(
        path: '/user-comments',
        name: 'user_comments',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return UserCommentsScreen(
            userId: extra['userId'] as String?,
            title: extra['title'] as String?,
            authorName: extra['authorName'] as String?,
            authorUsername: extra['authorUsername'] as String?,
            authorAvatarUrl: extra['authorAvatarUrl'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/my-followers',
        name: 'my_followers',
        builder: (context, state) => const MyFollowersScreen(),
      ),
      GoRoute(
        path: '/user-likes',
        name: 'user_likes',
        builder: (context, state) => const UserLikesScreen(),
      ),
      GoRoute(
        path: '/user-mentions',
        name: 'user_mentions',
        builder: (context, state) => const UserMentionsScreen(),
      ),
      GoRoute(
        path: '/live-details',
        name: 'live_details',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final index = extra?['index'] as int? ?? 0;
          final post = extra?['post'] as PostEntity?;
          return LiveDetailsScreen(index: index, post: post);
        },
      ),
      GoRoute(
        path: '/stories-viewer',
        name: 'stories_viewer',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            final stories = extra['stories'];
            final initialIndex = extra['initialIndex'] as int? ?? 0;
            if (stories is List<PostEntity>) {
              return StoriesViewerScreen(
                stories: stories,
                initialIndex: initialIndex,
              );
            }
          }
          return const StoriesViewerScreen(stories: []);
        },
      ),
      GoRoute(
        path: '/add-post',
        name: 'add_post',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return AddPostScreen(
            initialFiles: extra?['files'] as List<File>?,
            initialType: extra?['type'] as String?,
            isStory: extra?['isStory'] as bool? ?? false,
          );
        },
      ),
      GoRoute(
        path: '/edit-post',
        name: 'edit_post',
        builder: (context, state) {
          final post = state.extra as PostEntity;
          return EditPostScreen(post: post);
        },
      ),
      GoRoute(
        path: '/user-profile',
        name: 'user_profile',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return UserProfileScreen(
            userId: extra['userId'] as String? ?? '',
            initialUsername: extra['username'] as String?,
            initialFullName: extra['fullName'] as String?,
            initialAvatarUrl: extra['avatarUrl'] as String?,
            initialIsFollowing: extra['isFollowing'] as bool?,
          );
        },
      ),
      GoRoute(
        path: '/user-connections',
        name: 'user_connections',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return UserConnectionsScreen(
            userId: extra['userId'] as String,
            type: extra['type'] as UserConnectionType,
          );
        },
      ),
    ],
  );
}
