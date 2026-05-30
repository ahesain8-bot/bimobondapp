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
import 'package:bimobondapp/app/auth/presentation/pages/settings_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/change_avatar_screen.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/presentation/pages/post_detail_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/add_post_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/chat_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/live_details_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/lives_screen.dart';
import 'package:bimobondapp/app/posts/presentation/pages/edit_post_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/user_profile_screen.dart';
import 'package:bimobondapp/app/social/presentation/pages/user_connections_screen.dart';
import 'dart:io';

class AppRouter {
  static final GoRouter router = GoRouter(
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
        path: '/change-avatar',
        name: 'change_avatar',
        builder: (context, state) => const ChangeAvatarScreen(),
      ),
      GoRoute(
        path: '/post-detail',
        name: 'post_detail',
        builder: (context, state) {
          final post = state.extra as PostEntity;
          if (post.isAuctionable) {
            return LiveDetailsScreen(post: post);
          }
          return PostDetailScreen(post: post);
        },
      ),
      GoRoute(
        path: '/lives',
        name: 'lives',
        builder: (context, state) => const LivesScreen(),
      ),
      GoRoute(
        path: '/chat',
        name: 'chat',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ChatScreen(
            chatId: extra?['chatId'] as String? ?? '',
            username: extra?['username'] as String? ?? 'User',
            imageUrl: extra?['imageUrl'] as String? ??
                'https://i.pravatar.cc/150?u=default',
            peerUserId: extra?['peerUserId'] as String?,
          );
        },
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
        path: '/add-post',
        name: 'add_post',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return AddPostScreen(
            initialFiles: extra?['files'] as List<File>?,
            initialType: extra?['type'] as String?,
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
