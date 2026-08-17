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
import 'package:bimobondapp/app/auth/presentation/pages/reset_password_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/email_verification_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/splash_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/personal_info_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/privacy_settings_screen.dart';
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
import 'package:bimobondapp/core/constants/traffic_source.dart';
import 'package:bimobondapp/app/home/presentation/pages/add_post_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/add_post_camera_screen.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_catalog.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_gallery_picker.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_item_edit_state.dart';
import 'package:bimobondapp/app/video_templates/presentation/pages/video_templates_browser_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/media_studio_editor_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/stories_viewer_screen.dart';
import 'package:bimobondapp/app/calls/presentation/pages/active_call_screen.dart';
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
import 'package:bimobondapp/features/live_viewer/presentation/live_viewer.dart';
import 'package:bimobondapp/features/live/presentation/pages/live_room_page.dart' as host_live;
import 'package:bimobondapp/app/shop/domain/entities/checkout_entity.dart';
import 'package:bimobondapp/app/shop/presentation/pages/cart_screen.dart';
import 'package:bimobondapp/app/shop/presentation/pages/checkout_screen.dart';
import 'package:bimobondapp/app/shop/presentation/pages/ecommerce_home_screen.dart';
import 'package:bimobondapp/app/shop/presentation/pages/order_details_screen.dart';
import 'package:bimobondapp/app/shop/presentation/pages/orders_screen.dart';
import 'package:bimobondapp/app/shop/presentation/pages/product_details_screen.dart';
import 'package:bimobondapp/app/shop/presentation/pages/shop_search_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/hashtag_feed_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/camera_effect_test_screen.dart';
import 'package:bimobondapp/app/camera_engine/native_camera_phase1_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/posts_search_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/ended_auctions_screen.dart';
import 'package:bimobondapp/app/seller_verification/presentation/pages/seller_verification_screen.dart';
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
        path: '/reset-password',
        name: 'reset_password',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return ResetPasswordScreen(email: email);
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
        builder: (context, state) {
          final isOnboarding =
              state.uri.queryParameters['onboarding'] == '1';
          return PersonalInfoScreen(isOnboarding: isOnboarding);
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/privacy',
        name: 'privacy_settings',
        builder: (context, state) => const PrivacySettingsScreen(),
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
            final auctionId = args.post.auction?.id?.trim();
            return LiveDetailsScreen(
              post: args.post,
              auctionId: auctionId != null && auctionId.isNotEmpty
                  ? auctionId
                  : null,
              trafficSource: args.trafficSource,
            );
          }
          return PostDetailScreen(
            post: args.post,
            openCommentsOnLoad: args.openComments,
            highlightCommentId: args.highlightCommentId,
            trafficSource: args.trafficSource,
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
        builder: (context, state) => const LiveViewerEntry(),
      ),
      GoRoute(
        path: '/create-live',
        name: 'create_live',
        builder: (context, state) => const host_live.LiveRoomPage(),
      ),
      GoRoute(
        path: '/shop',
        name: EcommerceHomeScreen.routeName,
        builder: (context, state) => const EcommerceHomeScreen(),
      ),
      GoRoute(
        path: '/shop/search',
        name: ShopSearchScreen.routeName,
        builder: (context, state) => const ShopSearchScreen(),
      ),
      GoRoute(
        path: '/shop/cart',
        name: CartScreen.routeName,
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: '/shop/checkout',
        name: CheckoutScreen.routeName,
        builder: (context, state) {
          final liveId = state.uri.queryParameters['liveId'];
          final postId = state.uri.queryParameters['postId'];
          final extra = state.extra;
          List<CheckoutItemInput>? items;
          if (extra is Map) {
            final raw = extra['items'];
            if (raw is List) {
              items = raw.whereType<CheckoutItemInput>().toList();
            }
          } else if (extra is List) {
            items = extra.whereType<CheckoutItemInput>().toList();
          }
          if (items != null && items.isEmpty) items = null;
          return CheckoutScreen(
            liveId: liveId,
            postId: postId,
            items: items,
          );
        },
      ),
      GoRoute(
        path: '/shop/orders',
        name: OrdersScreen.routeName,
        builder: (context, state) {
          final tab = state.uri.queryParameters['tab'];
          final purchasesOnly =
              state.uri.queryParameters['only'] == 'purchases' ||
                  tab == 'purchases_only';
          final initialTabIndex = switch (tab) {
            'sales' || '1' => 1,
            _ => 0,
          };
          return OrdersScreen(
            initialTabIndex: initialTabIndex,
            purchasesOnly: purchasesOnly,
          );
        },
      ),
      GoRoute(
        path: '/shop/orders/:orderId',
        name: OrderDetailsScreen.routeName,
        builder: (context, state) {
          final orderId = state.pathParameters['orderId'] ?? '';
          final fromCheckout =
              state.uri.queryParameters['fromCheckout'] == '1';
          return OrderDetailsScreen(
            orderId: orderId,
            showGoToMyProducts: fromCheckout,
          );
        },
      ),
      GoRoute(
        path: '/shop/products/:productId',
        name: ProductDetailsScreen.routeName,
        builder: (context, state) {
          final productId = state.pathParameters['productId'] ?? '';
          final liveId = state.uri.queryParameters['liveId'];
          final postId = state.uri.queryParameters['postId'];
          return ProductDetailsScreen(
            productId: productId,
            liveId: liveId,
            postId: postId,
          );
        },
      ),
      GoRoute(
        path: '/effect-test',
        name: 'effect_test',
        builder: (context, state) => const CameraEffectTestScreen(),
      ),
      GoRoute(
        path: '/native-camera-phase1',
        name: 'native_camera_phase1',
        builder: (context, state) => const NativeCameraPhase1Screen(),
      ),
      GoRoute(
        path: '/posts-search',
        name: 'posts_search',
        builder: (context, state) {
          final extra = state.extra;
          String? initialQuery;
          if (extra is Map) {
            initialQuery = extra['initialQuery']?.toString();
          } else if (extra is String) {
            initialQuery = extra;
          }
          return PostsSearchScreen(initialQuery: initialQuery);
        },
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
        path: '/active-call',
        name: 'active_call',
        builder: (context, state) => const ActiveCallScreen(),
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
          final auctionId = extra?['auctionId']?.toString();
          final trafficSource = extra?['trafficSource']?.toString();
          return LiveDetailsScreen(
            index: index,
            post: post,
            auctionId: auctionId,
            trafficSource: (trafficSource != null && trafficSource.isNotEmpty)
                ? trafficSource
                : TrafficSource.live,
          );
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
            initialSoundSegmentId: extra?['initialSoundSegmentId'] as String?,
            returnMediaOnDone: extra?['returnMediaOnDone'] as bool? ?? false,
            initialFilterName: extra?['initialFilterName'] as String?,
            initialFilterCategory: CameraFilterCategory.values
                .asNameMap()[extra?['initialFilterCategory'] as String?],
            initialArFilterId: extra?['initialArFilterId'] as String?,
            initialArColorCategoryId:
                extra?['initialArColorCategoryId'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/video-templates',
        name: 'video_templates_browser',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return VideoTemplatesBrowserScreen(
            initialKind: extra?['templateKind'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/media-studio-editor',
        name: 'media_studio_editor',
        pageBuilder: (context, state) {
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
          final child = MediaStudioEditorScreen(
            items: items,
            initialIndex: extra['initialIndex'] as int? ?? 0,
            isStory: extra['isStory'] as bool? ?? false,
            initialSound: extra['initialSound'] as SoundEntity?,
            initialSoundOffset: Duration(
              milliseconds: extra['initialSoundOffsetMs'] as int? ?? 0,
            ),
            initialMuteOriginal:
                extra['initialMuteOriginal'] as bool? ?? false,
            popOnDone: extra['popOnDone'] as bool? ?? false,
            initialEdit: MediaEditorSeed.fromExtra(extra['initialEdit']),
            initialVideoTemplateId: extra['videoTemplateId'] as String?,
            initialVideoTemplateName: extra['videoTemplateName'] as String?,
            initialVideoTemplateSlotCount:
                extra['videoTemplateSlotCount'] as int?,
            initialTemplateProjectId: extra['templateProjectId'] as String?,
          );
          // Instant push after capture — avoids a blank/flashy default transition.
          return CustomTransitionPage<MediaStudioExportResult>(
            key: state.pageKey,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: const Duration(milliseconds: 150),
            child: child,
            transitionsBuilder: (_, animation, _, child) {
              return FadeTransition(opacity: animation, child: child);
            },
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
            initialSoundOffset: extra?['initialSoundOffset'] is Duration
                ? extra!['initialSoundOffset'] as Duration
                : Duration(
                    milliseconds: extra?['initialSoundOffsetMs'] as int? ?? 0,
                  ),
            initialSoundWindow: extra?['initialSoundWindow'] is Duration
                ? extra!['initialSoundWindow'] as Duration
                : Duration(
                    milliseconds:
                        extra?['initialSoundWindowMs'] as int? ?? 15000,
                  ),
            initialSoundDidTrim: extra?['initialSoundDidTrim'] as bool? ?? false,
            initialSoundSegmentId: extra?['initialSoundSegmentId'] as String?,
            initialFilterName: extra?['filterName'] as String?,
            initialFilterCategory: extra?['filterCategory'] as String?,
            initialEffectSlug: extra?['effectSlug'] as String?,
            initialBeautyEnabled: extra?['beautyEnabled'] as bool? ?? false,
            initialVideoTemplateId: extra?['videoTemplateId'] as String?,
            initialVideoTemplateName: extra?['videoTemplateName'] as String?,
            initialVideoTemplateSlotCount:
                extra?['videoTemplateSlotCount'] as int?,
            initialTemplateProjectId: extra?['templateProjectId'] as String?,
            initialTemplateRenderedVideo:
                extra?['templateRenderedVideo'] as File?,
            initialTemplateSlotFiles:
                (extra?['templateSlotFiles'] as List?)?.whereType<File>().toList(),
            initialTemplateServerExportUrl:
                extra?['templateServerExportUrl'] as String?,
            initialTemplateClientExportQuality:
                extra?['templateClientExportQuality'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/seller-verification',
        name: 'seller_verification',
        builder: (context, state) => const SellerVerificationScreen(),
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
