// Scratch entrypoint for on-device inspection of the live screens.
//
// The real entrypoint lands on the login form and the live surface is behind
// it, so this boots straight into `LiveViewerEntry` — which already runs on
// `FakeLiveRepository`, i.e. the same seed rooms the QA screenshots show.
//
// Not part of the shipped app: run with
//   flutter run -t lib/main_live_preview.dart
import 'package:bimobondapp/app/auctions/presentation/di/auctions_injector.dart'
    as auctions_di;
import 'package:bimobondapp/app/gifts/presentation/di/gifts_injector.dart'
    as gifts_di;
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/features/live_viewer/data/datasources/live_remote_datasource.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/live_entity.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/live_session_entity.dart';
import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:bimobondapp/features/live_viewer/presentation/di/live_viewer_injector.dart'
    as live_viewer_di;
import 'package:bimobondapp/features/live_viewer/presentation/live_viewer.dart';
import 'package:bimobondapp/firebase_options.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // The live surface reaches into the auction gift pipeline for combo
  // payloads, which in turn needs the gift catalog and the shared ApiClient.
  final prefs = await SharedPreferences.getInstance();
  live_viewer_di.sl.registerLazySingleton<ApiClient>(
    () => ApiClient(sharedPreferences: prefs),
  );
  await gifts_di.initGifts();
  await auctions_di.initAuctions();
  await live_viewer_di.initLiveViewer();
  // The seeded rooms cover the three layouts the live surface has to render:
  // a plain broadcast, a PK battle and a multi-guest grid. The real feed is
  // empty outside a live event, which leaves nothing on screen to inspect.
  live_viewer_di.sl.unregister<LiveRemoteDataSource>();
  live_viewer_di.sl.registerLazySingleton<LiveRemoteDataSource>(
    () => _PkFirstDataSource(FakeLiveRemoteDataSource()),
  );
  runApp(const _LivePreviewApp());
}

class _LivePreviewApp extends StatelessWidget {
  const _LivePreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LiveViewerEntry(),
    );
  }
}


/// Forces the first room of the seeded feed into an ACTIVE PK battle so the
/// battle chrome can be inspected without waiting for two real hosts to match.
class _PkFirstDataSource implements LiveRemoteDataSource {
  _PkFirstDataSource(this._inner);

  final LiveRemoteDataSource _inner;

  LiveEntity _asBattle(LiveEntity live) {
    final now = DateTime.now();
    return live.copyWith(
      metadata: {
        ...?live.metadata,
        'isPk': true,
        'isMultiGrid': false,
        'isMultiGuest': false,
        'guestName': 'Henry Zhang',
        'guestAvatar': 'https://i.pravatar.cc/150?u=henry',
        'scoreLeft': 19535,
        'scoreRight': 2400,
        'battle': {
          'id': 'preview-battle',
          'live1Id': live.id,
          'live2Id': 'opponent',
          'live1Score': 19535,
          'live2Score': 2400,
          'status': 'ACTIVE',
          'phase': 'BATTLE',
          'multiplier': 2,
          'startTime': now.toIso8601String(),
          'endTime': now.add(const Duration(minutes: 3, seconds: 55))
              .toIso8601String(),
        },
      },
    );
  }

  @override
  Future<List<LiveEntity>> getLiveFeed({
    int page = 1,
    int limit = 10,
    String? category,
  }) async {
    final lives = await _inner.getLiveFeed(
      page: page,
      limit: limit,
      category: category,
    );
    if (lives.isEmpty) return lives;
    return [_asBattle(lives.first), ...lives.skip(1)];
  }

  @override
  Future<LiveEntity> getLiveById(String liveId) async =>
      _asBattle(await _inner.getLiveById(liveId));

  @override
  Future<JoinLiveResult> joinLive(String liveId) => _inner.joinLive(liveId);

  @override
  Future<void> leaveLive(String liveId) => _inner.leaveLive(liveId);

  @override
  Future<List<String>> getTrendingCategories() =>
      _inner.getTrendingCategories();

  @override
  Future<void> followHost(String hostId) => _inner.followHost(hostId);

  @override
  Future<void> unfollowHost(String hostId) => _inner.unfollowHost(hostId);

  @override
  Future<void> banViewer({
    required String liveId,
    required String userId,
    String? reason,
  }) => _inner.banViewer(liveId: liveId, userId: userId, reason: reason);

  @override
  Future<void> unbanViewer({
    required String liveId,
    required String userId,
  }) => _inner.unbanViewer(liveId: liveId, userId: userId);

  @override
  Future<void> muteViewerChat({
    required String liveId,
    required String userId,
    String? reason,
  }) => _inner.muteViewerChat(liveId: liveId, userId: userId, reason: reason);

  @override
  Future<void> unmuteViewerChat({
    required String liveId,
    required String userId,
  }) => _inner.unmuteViewerChat(liveId: liveId, userId: userId);
}
