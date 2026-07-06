import 'package:bimobondapp/core/routes/app_router.dart';
import 'dart:async';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart'
    as auth_di;
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart'
    as posts_di;
import 'package:bimobondapp/app/categories/presentation/di/categories_injector.dart'
    as categories_di;
import 'package:bimobondapp/app/gifts/presentation/di/gifts_injector.dart'
    as gifts_di;
import 'package:bimobondapp/app/wallets/presentation/di/wallets_injector.dart'
    as wallets_di;
import 'package:bimobondapp/app/auctions/presentation/di/auctions_injector.dart'
    as auctions_di;
import 'package:bimobondapp/app/chats/presentation/di/chats_injector.dart'
    as chats_di;
import 'package:bimobondapp/app/social/presentation/di/social_injector.dart'
    as social_di;
import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:bimobondapp/core/theme/cubit/theme_cubit.dart';
import 'package:bimobondapp/core/theme/cubit/chat_wallpaper_cubit.dart';
import 'package:bimobondapp/core/theme/cubit/locale_cubit.dart';
import 'package:bimobondapp/app/promotions/presentation/di/promotions_injector.dart'
    as promotions_di;
import 'package:bimobondapp/app/sounds/presentation/di/sounds_injector.dart'
    as sounds_di;
import 'package:bimobondapp/app/notifications/presentation/di/notifications_injector.dart'
    as notifications_di;
import 'package:bimobondapp/app/camera_studio/presentation/di/camera_studio_injector.dart'
    as camera_studio_di;
import 'package:bimobondapp/app/camera_studio/presentation/services/camera_studio_catalog_loader.dart';
import 'package:bimobondapp/app/notifications/presentation/services/push_notification_service.dart';
import 'package:bimobondapp/app/notifications/presentation/widgets/notification_auth_listener.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:bimobondapp/firebase_options.dart';

Future<void> _preloadCameraStudioCatalog() async {
  await camera_studio_di.sl<CameraStudioCatalogLoader>().ensureLoaded();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await PushNotificationService.instance.initializeEarly();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await auth_di.initAuth();
  await social_di.initSocial();
  await posts_di.initPosts();
  await promotions_di.initPromotions();
  await sounds_di.initSounds();
  await categories_di.initCategories();
  await wallets_di.initWallets();
  await gifts_di.initGifts();
  await auctions_di.initAuctions();
  await camera_studio_di.initCameraStudio();
  unawaited(_preloadCameraStudioCatalog());
  await chats_di.initChats();
  await notifications_di.initNotifications();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => auth_di.sl<AuthBloc>()),
        BlocProvider<PostsBloc>(create: (_) => posts_di.sl<PostsBloc>()),
        BlocProvider<ThemeCubit>(create: (_) => ThemeCubit(auth_di.sl())),
        BlocProvider<LocaleCubit>(create: (_) => LocaleCubit(auth_di.sl())),
        BlocProvider<ChatWallpaperCubit>(
          create: (_) => ChatWallpaperCubit(auth_di.sl()),
        ),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return NotificationAuthListener(
            child: BlocBuilder<LocaleCubit, Locale>(
              builder: (context, locale) {
                return MaterialApp.router(
                  title: 'Bimobond App',
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: themeMode,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  locale: locale,
                  routerConfig: AppRouter.router,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
