import 'package:bimobondapp/app/auth/data/models/user_model.dart';
import 'package:bimobondapp/app/auth/domain/entities/user_current_live.dart';
import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_live_now_badge.dart';
import 'package:bimobondapp/features/live_viewer/data/mappers/live_mapper.dart';
import 'package:bimobondapp/features/live_viewer/presentation/utils/open_profile_live.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _currentLive({
  String id = 'live-9',
  String title = 'Late night',
  String? coverUrl = 'https://example.com/c.jpg',
  int viewers = 42,
  String mediaMode = 'VIDEO',
  bool audioOnly = false,
  String? status,
}) {
  return {
    'id': id,
    'title': title,
    'coverUrl': coverUrl,
    'viewers': viewers,
    'mediaMode': mediaMode,
    'audioOnly': audioOnly,
    'status': ?status,
  };
}

UserEntity _user({
  String id = 'user-1',
  bool isLive = false,
  Map<String, dynamic>? currentLive,
  bool isPrivate = false,
  bool isProfileLocked = false,
}) {
  return UserEntity(
    id: id,
    username: 'maya',
    fullName: 'Maya',
    isLive: isLive,
    currentLive: currentLive,
    isPrivate: isPrivate,
    isProfileLocked: isProfileLocked,
  );
}

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  setUp(() {
    debugSkipProfileLiveNavigation = true;
    debugLastProfileLiveOpen = null;
    debugLastProfileLiveInconsistency = null;
  });

  tearDown(() {
    debugSkipProfileLiveNavigation = false;
    debugLastProfileLiveOpen = null;
    debugLastProfileLiveInconsistency = null;
  });

  group('profile model mapping', () {
    test('parses isLive == true and currentLive fields', () {
      final user = UserModel.fromJson({
        'id': 'user-1',
        'isLive': true,
        'currentLive': _currentLive(mediaMode: 'AUDIO', audioOnly: true),
      });

      expect(user.isLive, isTrue);
      expect(user.showsProfileLiveBadge, isTrue);
      final live = user.profileCurrentLive;
      expect(live, isNotNull);
      expect(live!.id, 'live-9');
      expect(live.title, 'Late night');
      expect(live.coverUrl, 'https://example.com/c.jpg');
      expect(live.viewers, 42);
      expect(live.mediaMode, 'AUDIO');
      expect(live.audioOnly, isTrue);
    });

    test('non-live user does not show badge', () {
      final user = _user(isLive: false);
      expect(user.showsProfileLiveBadge, isFalse);
    });

    test('live user shows badge', () {
      final user = _user(isLive: true, currentLive: _currentLive());
      expect(user.showsProfileLiveBadge, isTrue);
    });

    test('scheduled/PLANNED data does not produce a profile LIVE badge', () {
      final plannedWhileFlaggedLive = _user(
        isLive: true,
        currentLive: _currentLive(status: 'PLANNED'),
      );
      final plannedNotLive = _user(
        isLive: false,
        currentLive: _currentLive(status: 'PLANNED'),
      );
      expect(plannedWhileFlaggedLive.showsProfileLiveBadge, isFalse);
      expect(plannedNotLive.showsProfileLiveBadge, isFalse);
      expect(
        LiveMapper.fromProfileCurrentLive(
          isLive: true,
          currentLive: _currentLive(status: 'PLANNED'),
          hostId: 'user-1',
        ),
        isNull,
      );
      expect(
        LiveMapper.fromProfileCurrentLive(
          isLive: true,
          currentLive: _currentLive(status: 'SCHEDULED'),
          hostId: 'user-1',
        ),
        isNull,
      );
    });

    test('locked/private profile can still show the LIVE indicator', () {
      final user = UserModel.fromJson({
        'id': 'user-1',
        'isPrivate': true,
        'isProfileLocked': true,
        'isLive': true,
        'currentLive': _currentLive(),
      });
      expect(user.isPrivate, isTrue);
      expect(user.isProfileLocked, isTrue);
      expect(user.showsProfileLiveBadge, isTrue);
    });

    test('isLive false wins over stale currentLive', () {
      final user = _user(isLive: false, currentLive: _currentLive());
      expect(user.showsProfileLiveBadge, isFalse);
      expect(
        LiveMapper.fromProfileCurrentLive(
          isLive: user.isLive,
          currentLive: user.currentLive,
          hostId: user.id,
        ),
        isNull,
      );
      final decision = resolveProfileLiveOpen(
        profile: user,
        isOwnProfile: false,
      );
      expect(decision.kind, ProfileLiveOpenKind.none);
    });

    test('isLive true without currentLive hides entry and reports', () {
      final user = _user(isLive: true, currentLive: null);
      expect(user.showsProfileLiveBadge, isFalse);
      expect(user.hasInconsistentProfileLive, isTrue);
      final decision = resolveProfileLiveOpen(
        profile: user,
        isOwnProfile: false,
      );
      expect(decision.kind, ProfileLiveOpenKind.none);
      expect(decision.liveId, isNull);
      expect(debugLastProfileLiveInconsistency, contains('isLive=true'));
    });

    test('isLive true with empty currentLive id does not fabricate an id', () {
      final user = _user(
        isLive: true,
        currentLive: {'title': 'Late night', 'viewers': 3},
      );
      expect(user.showsProfileLiveBadge, isFalse);
      final decision = resolveProfileLiveOpen(
        profile: user,
        isOwnProfile: false,
      );
      expect(decision.kind, ProfileLiveOpenKind.none);
      expect(decision.liveId, isNull);
    });
  });

  group('profile LIVE navigation', () {
    test('another user tap uses currentLive.id on the viewer join path', () {
      final user = _user(isLive: true, currentLive: _currentLive());
      final decision = resolveProfileLiveOpen(
        profile: user,
        isOwnProfile: false,
      );
      expect(decision.kind, ProfileLiveOpenKind.viewer);
      expect(decision.liveId, 'live-9');
      expect(decision.usesExistingViewerJoin, isTrue);
      expect(decision.usesHostReconnect, isFalse);
      expect(decision.viewerLive, isNotNull);
      expect(decision.viewerLive!.id, 'live-9');
      expect(
        LiveMapper.fromProfileCurrentLive(
          isLive: user.isLive,
          currentLive: user.currentLive,
          hostId: user.id,
          hostName: user.fullName,
        )?.id,
        'live-9',
      );
    });

    test('own-profile LIVE reconnects as host and does not viewer-join', () {
      final user = _user(isLive: true, currentLive: _currentLive());
      final decision = resolveProfileLiveOpen(
        profile: user,
        isOwnProfile: true,
      );
      expect(decision.kind, ProfileLiveOpenKind.host);
      expect(decision.liveId, 'live-9');
      expect(decision.usesHostReconnect, isTrue);
      expect(decision.usesExistingViewerJoin, isFalse);
      expect(decision.viewerLive, isNull);
    });
  });

  group('ProfileLiveNowBadge', () {
    testWidgets('hides the LIVE label for a non-live user', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProfileLiveNowBadge(
            user: _user(),
            child: const SizedBox(width: 48, height: 48),
          ),
        ),
      );
      expect(find.byKey(kProfileLiveNowBadgeKey), findsNothing);
      expect(find.text('LIVE'), findsNothing);
    });

    testWidgets('shows the LIVE label for a live user', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProfileLiveNowBadge(
            user: _user(isLive: true, currentLive: _currentLive()),
            child: const SizedBox(width: 48, height: 48),
          ),
        ),
      );
      expect(find.byKey(kProfileLiveNowBadgeKey), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
    });

    testWidgets('does not show a badge for PLANNED currentLive', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProfileLiveNowBadge(
            user: _user(
              isLive: true,
              currentLive: _currentLive(status: 'PLANNED'),
            ),
            child: const SizedBox(width: 48, height: 48),
          ),
        ),
      );
      expect(find.byKey(kProfileLiveNowBadgeKey), findsNothing);
    });

    testWidgets('locked/private live profile still shows the badge', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ProfileLiveNowBadge(
            user: _user(
              isLive: true,
              currentLive: _currentLive(),
              isPrivate: true,
              isProfileLocked: true,
            ),
            child: const SizedBox(width: 48, height: 48),
          ),
        ),
      );
      expect(find.byKey(kProfileLiveNowBadgeKey), findsOneWidget);
    });

    testWidgets('Arabic uses the localized LIVE label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProfileLiveNowBadge(
            user: _user(isLive: true, currentLive: _currentLive()),
            child: const SizedBox(width: 48, height: 48),
          ),
          locale: const Locale('ar'),
        ),
      );
      expect(find.text('مباشر'), findsOneWidget);
    });

    testWidgets('tapping another user badge uses currentLive.id as viewer', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ProfileLiveNowBadge(
            user: _user(isLive: true, currentLive: _currentLive()),
            child: const SizedBox(width: 48, height: 48),
          ),
        ),
      );
      await tester.tap(find.byKey(kProfileLiveNowBadgeKey));
      await tester.pump();
      expect(debugLastProfileLiveOpen, isNotNull);
      expect(debugLastProfileLiveOpen!.liveId, 'live-9');
      expect(debugLastProfileLiveOpen!.usesExistingViewerJoin, isTrue);
    });

    testWidgets('tapping own-profile badge reconnects as host', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProfileLiveNowBadge(
            user: _user(isLive: true, currentLive: _currentLive()),
            isOwnProfile: true,
            child: const SizedBox(width: 48, height: 48),
          ),
        ),
      );
      await tester.tap(find.byKey(kProfileLiveNowBadgeKey));
      await tester.pump();
      expect(debugLastProfileLiveOpen, isNotNull);
      expect(debugLastProfileLiveOpen!.liveId, 'live-9');
      expect(debugLastProfileLiveOpen!.usesHostReconnect, isTrue);
      expect(debugLastProfileLiveOpen!.usesExistingViewerJoin, isFalse);
    });
  });
}
