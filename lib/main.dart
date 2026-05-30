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
import 'package:bimobondapp/app/gifts/presentation/di/gifts_injector.dart'
    as gifts_di;
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
import 'package:bimobondapp/core/theme/cubit/locale_cubit.dart';
import 'package:firebase_core/firebase_core.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await auth_di.initAuth();
  await social_di.initSocial();
  await posts_di.initPosts();
  await categories_di.initCategories();
  await gifts_di.initGifts();
  await auctions_di.initAuctions();
  await chats_di.initChats();
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
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return BlocBuilder<LocaleCubit, Locale>(
            builder: (context, locale) {
              return MaterialApp.router(
                title: 'Bimobond App',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeMode,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                locale: locale,
                routerConfig: AppRouter.router,
              );
            },
          );
        },
      ),
    );
  }
}
