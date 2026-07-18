import 'package:bimobondapp/core/services/feed_playback_gate.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bimobondapp/app/home/presentation/pages/main_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/login_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/email_login_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/email_signup_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/interest_selection_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/phone_login_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/signup_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/otp_verification_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/email_otp_verification_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/forgot_password_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/email_verification_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/splash_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/personal_info_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/admin_user_activity_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/settings_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/chat_wallpaper_settings_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/change_avatar_screen.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/home/presentation/pages/activity_screen.dart';
import 'package:bimobondapp/app/notifications/presentation/pages/notifications_screen.dart';
import 'package:bimobondapp/app/posts/presentation/pages/post_detail_screen.dart';
import 'package:bimobondapp/app/posts/presentation/pages/profile_posts_viewer_screen.dart';
import 'package:bimobondapp/core/navigation/post_navigation.dart';
import 'package:bimobondapp/core/navigation/profile_posts_navigation.dart';
import 'package:bimobondapp/app/home/presentation/pages/add_post_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/add_post_camera_screen.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_catalog.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_gallery_picker.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_item_edit_state.dart';
import 'package:bimobondapp/app/home/presentation/pages/media_studio_editor_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/stories_viewer_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/chat_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/all_chats_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/new_chat_screen.dart';
import 'package:bimobondapp/app/social/presentation/pages/follow_suggestions_screen.dart';
import 'package:bimobondapp/app/social/presentation/pages/user_comments_screen.dart';
import 'package:bimobondapp/app/social/presentation/pages/my_followers_screen.dart';
import 'package:bimobondapp/app/social/presentation/pages/user_likes_screen.dart';
import 'package:bimobondapp/app/social/presentation/pages/user_mentions_screen.dart';
import 'package:bimobondapp/app/wallets/presentation/pages/coins_hub_screen.dart';
import 'package:bimobondapp/app/wallets/presentation/pages/balance_screen.dart';
import 'package:bimobondapp/app/wallets/presentation/pages/balance_transactions_screen.dart';
import 'package:bimobondapp/app/wallets/presentation/pages/balance_transaction_detail_screen.dart';
import 'package:bimobondapp/app/wallets/presentation/pages/add_payout_method_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/live_details_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/lives_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/hashtag_feed_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/camera_effect_test_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/posts_search_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/ended_auctions_screen.dart';
import 'package:bimobondapp/app/promotions/presentation/pages/promote_post_screen.dart';
import 'package:bimobondapp/app/promotions/presentation/pages/promoted_post_insights_screen.dart';
import 'package:bimobondapp/app/promotions/presentation/pages/promoted_posts_screen.dart';
import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/presentation/pages/sound_detail_screen.dart';
import 'package:bimobondapp/app/posts/presentation/pages/edit_post_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/user_profile_screen.dart';
import 'package:bimobondapp/app/social/presentation/pages/user_connections_screen.dart';
import 'dart:io';

class AppRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();

  static final GoRouter router = _createRouter();

  static GoRouter _createRouter() {
    final router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/splash',
      observers: [FeedPlaybackNavigatorObserver.instance],
      routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) {
          final tab = state.uri.queryParameters['tab'];
          int initialIndex = 0;
          if (tab == 'profile') {
            initialIndex = 4;
          } else if (tab != null) {
            initialIndex = int.tryParse(tab) ?? 0;
          }
          return MainScreen(initialIndex: initialIndex);
        },
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
        path: '/email-login',
        name: 'email_login',
        builder: (context, state) => const EmailLoginScreen(),
      ),
      GoRoute(
        path: '/email-signup',
        name: 'email_signup',
        builder: (context, state) => const EmailSignUpScreen(),
      ),
      GoRoute(
        path: '/interest-selection',
        name: 'interest_selection',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'];
          final mode = state.uri.queryParameters['mode'];
          return InterestSelectionScreen(
            pendingVerificationEmail: email,
            isEditMode: mode == 'edit',
          );
        },
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
        path: '/forgot-password',
        name: 'forgot_password',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'];
          return ForgotPasswordScreen(initialEmail: email);
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
        path: '/settings/wallet',
        name: 'wallet',
        builder: (context, state) {
          final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
          return CoinsHubScreen(initialTab: tab);
        },
      ),
      GoRoute(
        path: '/settings/balance',
        name: 'balance',
        builder: (context, state) => const BalanceScreen(),
      ),
      GoRoute(
        path: '/settings/balance/transactions',
        name: 'balance_transactions',
        builder: (context, state) {
          final tabName = state.uri.queryParameters['tab'] ?? 'all';
          final tabIndex = switch (tabName) {
            'revenue' => 1,
            'expense' => 2,
            'payout' => 3,
            'refund' => 4,
            _ => 0,
          };
          return BalanceTransactionsScreen(initialTab: tabIndex);
        },
      ),
      GoRoute(
        path: '/settings/balance/transactions/:id',
        name: 'balance_transaction_detail',
        builder: (context, state) => BalanceTransactionDetailScreen(
          transactionId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/settings/balance/payout/add',
        name: 'add_payout_method',
        builder: (context, state) => const AddPayoutMethodScreen(),
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
        path: '/activity',
        name: 'activity',
        builder: (context, state) => const ActivityScreen(),
      ),
      GoRoute(
        path: '/post-detail',
        name: 'post_detail',
        builder: (context, state) {
          final args = postOpenArgsFromExtra(state.extra);
          if (args == null) {
            return const Scaffold(body: Center(child: Text('Post not found')));
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
        pageBuilder: (context, state) {
          final args = profilePostsOpenArgsFromExtra(state.extra);
          final child = args == null
              ? const Scaffold(body: Center(child: Text('Post not found')))
              : ProfilePostsViewerScreen(args: args);
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: child,
            transitionDuration: const Duration(milliseconds: 380),
            reverseTransitionDuration: const Duration(milliseconds: 280),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                ),
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/lives',
        name: 'lives',
        builder: (context, state) => const LivesScreen(),
      ),
      GoRoute(
        path: '/effect-test',
        name: 'effect_test',
        builder: (context, state) => const CameraEffectTestScreen(),
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
            openCamera: extra?['openCamera'] as bool? ?? false,
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
        path: '/new-chat',
        name: 'new_chat',
        builder: (context, state) => const NewChatScreen(),
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
        path: '/add-post-camera',
        name: 'add_post_camera',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return AddPostCameraScreen(
            isStory: extra?['isStory'] as bool? ?? false,
            initialSound: extra?['initialSound'] as SoundEntity?,
            returnMediaOnDone: extra?['returnMediaOnDone'] as bool? ?? false,
            initialFilterName: extra?['initialFilterName'] as String?,
            initialFilterCategory: CameraFilterCategory.values
                .asNameMap()[extra?['initialFilterCategory'] as String?],
          );
        },
      ),
      GoRoute(
        path: '/media-studio-editor',
        name: 'media_studio_editor',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final List<GalleryMediaItem> items;
          if (extra?['items'] is List) {
            items = galleryItemsFromExtra(extra!['items'] as List<dynamic>);
          } else {
            items = [
              GalleryMediaItem(
                file: extra!['file'] as File,
                type: extra['type'] as String? ?? 'IMAGE',
              ),
            ];
          }
          return MediaStudioEditorScreen(
            items: items,
            initialIndex: extra?['initialIndex'] as int? ?? 0,
            isStory: extra?['isStory'] as bool? ?? false,
            initialSound: extra?['initialSound'] as SoundEntity?,
            popOnDone: extra?['popOnDone'] as bool? ?? false,
            initialEdit: MediaEditorSeed.fromExtra(extra?['initialEdit']),
          );
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
            initialSound: extra?['initialSound'] as SoundEntity?,
            initialFilterName: extra?['filterName'] as String?,
            initialFilterCategory: extra?['filterCategory'] as String?,
            initialEffectSlug: extra?['effectSlug'] as String?,
            initialBeautyEnabled: extra?['beautyEnabled'] as bool? ?? false,
          );
        },
      ),
      GoRoute(
        path: '/sounds/:id',
        name: 'sound_detail',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final pickMode = state.uri.queryParameters['pick'] == 'true';
          final preview = state.extra as SoundEntity?;
          return SoundDetailScreen(
            soundId: id,
            pickMode: pickMode,
            previewSound: preview,
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
        path: '/promote-post',
        name: 'promote_post',
        builder: (context, state) {
          final post = state.extra as PostEntity;
          return PromotePostScreen(post: post);
        },
      ),
      GoRoute(
        path: '/promoted-posts',
        name: 'promoted_posts',
        builder: (context, state) => const PromotedPostsScreen(),
      ),
      GoRoute(
        path: '/promoted-posts/:postId/insights',
        name: 'promoted_post_insights',
        builder: (context, state) {
          final postId = state.pathParameters['postId'] ?? '';
          final campaignId = state.uri.queryParameters['campaignId'];
          return PromotedPostInsightsScreen(
            postId: postId,
            initialCampaignId: campaignId,
          );
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
    router.routerDelegate.addListener(
      FeedPlaybackGate.instance.syncFromRouter,
    );
    return router;
  }
}
