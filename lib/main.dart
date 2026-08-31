import 'package:bimobondapp/core/routes/app_router.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart'
    as auth_di;
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart'
    as posts_di;
import 'package:bimobondapp/app/categories/presentation/di/categories_injector.dart'
    as categories_di;
import 'package:bimobondapp/app/countries/presentation/di/countries_injector.dart'
    as countries_di;
import 'package:bimobondapp/app/interests/presentation/di/interests_injector.dart'
    as interests_di;
import 'package:bimobondapp/app/gifts/presentation/di/gifts_injector.dart'
    as gifts_di;
import 'package:bimobondapp/app/wallets/presentation/di/wallets_injector.dart'
    as wallets_di;
import 'package:bimobondapp/app/auctions/presentation/di/auctions_injector.dart'
    as auctions_di;
import 'package:bimobondapp/app/shop/presentation/cubit/shop_cart_cubit.dart';
import 'package:bimobondapp/app/shop/presentation/di/shop_injector.dart'
    as shop_di;
import 'package:bimobondapp/app/seller_verification/presentation/di/seller_verification_injector.dart'
    as seller_verification_di;
import 'package:bimobondapp/app/stories/presentation/di/stories_injector.dart'
    as stories_di;
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
import 'package:bimobondapp/app/search/presentation/di/search_injector.dart'
    as search_di;
import 'package:bimobondapp/app/notifications/presentation/di/notifications_injector.dart'
    as notifications_di;
import 'package:bimobondapp/app/camera_studio/presentation/di/camera_studio_injector.dart'
    as camera_studio_di;
import 'package:bimobondapp/app/video_templates/presentation/di/video_templates_injector.dart'
    as video_templates_di;
import 'package:bimobondapp/app/calls/presentation/di/calls_injector.dart'
    as calls_di;
import 'package:bimobondapp/app/calls/presentation/bloc/call_bloc.dart';
import 'package:bimobondapp/app/calls/presentation/widgets/global_call_listener.dart';
import 'package:bimobondapp/app/camera_studio/presentation/services/camera_studio_catalog_loader.dart';
import 'package:bimobondapp/app/notifications/presentation/services/push_notification_service.dart';
import 'package:bimobondapp/app/notifications/presentation/widgets/notification_auth_listener.dart';
import 'package:bimobondapp/features/live_viewer/presentation/di/live_viewer_injector.dart'
    as live_viewer_di;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:bimobondapp/firebase_options.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Google Maps and the camera/beauty stack are deliberately lazy. Native
  // warm-up work still competes for the Android platform thread even when its
  // Dart Future is not awaited, which previously kept the native splash on
  // screen for ~30 seconds on a cold start. The map screen and camera screen
  // initialise their own dependencies immediately before first use.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await PushNotificationService.instance.initializeEarly();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  // Auth first and on its own: the rest read the SharedPreferences instance
  // and the API client it registers.
  await auth_di.initAuth();

  // Everything below only registers into GetIt and touches already-cached
  // async singletons, so there is no ordering between them — but they used to
  // be twenty-one sequential awaits in front of `runApp`, which is what the
  // platform log reported as "Skipped 160 frames! The application may be doing
  // too much work on its main thread" and the long run of `onPreDraw return
  // false` while Flutter waited for a first frame that could not be produced.
  // Awaited as one batch they cost roughly the slowest of the group instead of
  // the sum of all of them.
  await Future.wait<void>([
    social_di.initSocial(),
    posts_di.initPosts(),
    promotions_di.initPromotions(),
    sounds_di.initSounds(),
    search_di.initSearch(),
    categories_di.initCategories(),
    countries_di.initCountries(),
    interests_di.initInterests(),
    wallets_di.initWallets(),
    gifts_di.initGifts(),
    auctions_di.initAuctions(),
    shop_di.initShop(),
    seller_verification_di.initSellerVerification(),
    stories_di.initStories(),
    camera_studio_di.initCameraStudio(),
    video_templates_di.initVideoTemplates(),
    chats_di.initChats(),
    notifications_di.initNotifications(),
    calls_di.initCalls(),
    live_viewer_di.initLiveViewer(),
  ]);
  CameraStudioCatalogLoader.applyBundledCatalog();
  runApp(const ProviderScope(child: MyApp()));
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
        BlocProvider<ShopCartCubit>(create: (_) => shop_di.sl<ShopCartCubit>()),
        BlocProvider<CallBloc>(create: (_) => calls_di.sl<CallBloc>()),
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
                  builder: (context, child) {
                    return GlobalCallListener(
                      child: child ?? const SizedBox.shrink(),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
