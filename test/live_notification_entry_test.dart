import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:bimobondapp/app/auth/domain/repositories/auth_repository.dart';
import 'package:bimobondapp/app/auth/domain/usecases/get_user_by_id_usecase.dart';
import 'package:bimobondapp/app/notifications/domain/entities/notification_entity.dart';
import 'package:bimobondapp/app/notifications/presentation/utils/notification_navigation.dart';
import 'package:bimobondapp/core/constants/live_traffic_source.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

/// Feature 26 — the NOTIFICATION traffic bucket.
///
/// `LIVE_STARTED` is the documented follower notification when a host goes
/// live (`lives/mobile-api.md` §6). Before this it fell through the routing
/// switch and opened nothing, so the bucket could never be sent.

class _Repo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeGetUserById extends GetUserByIdUseCase {
  FakeGetUserById(this.result) : super(_Repo());

  final Either<Failure, UserEntity> result;
  final calls = <String>[];

  @override
  Future<Either<Failure, UserEntity>> call(GetUserByIdParams params) async {
    calls.add(params.userId);
    return result;
  }
}

NotificationEntity liveStarted({String? actorId}) => NotificationEntity(
  id: 'n1',
  userId: 'me',
  type: 'LIVE_STARTED',
  isRead: false,
  createdAt: DateTime.utc(2026, 9, 8),
  actorId: actorId,
);

/// Pumps a real route so `navigateFromNotification` runs against a live
/// Navigator, and reports whether it pushed anything.
Future<int> routeAndCountPushes(
  WidgetTester tester,
  NotificationEntity notification,
) async {
  final observer = _CountingObserver();
  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers: [observer],
      home: Builder(
        builder: (context) {
          ctx = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await navigateFromNotification(ctx, notification);
  await tester.pumpAndSettle();
  return observer.pushes;
}

class _CountingObserver extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // The initial home route is pushed before any notification is handled.
    if (previousRoute != null) pushes++;
  }
}

void main() {
  final getIt = GetIt.instance;

  tearDown(() async {
    if (getIt.isRegistered<GetUserByIdUseCase>()) {
      await getIt.unregister<GetUserByIdUseCase>();
    }
  });

  testWidgets('a LIVE_STARTED without an actor resolves nothing', (
    tester,
  ) async {
    final fake = FakeGetUserById(right(const UserEntity(id: 'host-1')));
    getIt.registerSingleton<GetUserByIdUseCase>(fake);
    expect(await routeAndCountPushes(tester, liveStarted()), 0);
    // No id means no lookup at all; the notification is not a live id source.
    expect(fake.calls, isEmpty);
  });

  testWidgets('a host who is no longer live opens nothing', (tester) async {
    final fake = FakeGetUserById(
      right(const UserEntity(id: 'host-1', isLive: false)),
    );
    getIt.registerSingleton<GetUserByIdUseCase>(fake);
    expect(
      await routeAndCountPushes(tester, liveStarted(actorId: 'host-1')),
      0,
    );
    // The host profile is the authority for whether the stream still runs.
    expect(fake.calls, ['host-1']);
  });

  testWidgets('an unreadable profile opens nothing and does not throw', (
    tester,
  ) async {
    final fake = FakeGetUserById(left(ServerFailure('nope')));
    getIt.registerSingleton<GetUserByIdUseCase>(fake);
    expect(
      await routeAndCountPushes(tester, liveStarted(actorId: 'host-1')),
      0,
    );
    expect(fake.calls, ['host-1']);
  });

  testWidgets('an unrelated notification type never looks up a host', (
    tester,
  ) async {
    final fake = FakeGetUserById(right(const UserEntity(id: 'host-1')));
    getIt.registerSingleton<GetUserByIdUseCase>(fake);
    final other = NotificationEntity(
      id: 'n2',
      userId: 'me',
      type: 'SYSTEM',
      isRead: false,
      createdAt: DateTime.utc(2026, 9, 8),
      actorId: 'host-1',
    );
    expect(await routeAndCountPushes(tester, other), 0);
    expect(fake.calls, isEmpty);
  });

  test('NOTIFICATION is a documented bucket the join body accepts', () {
    expect(LiveTrafficSource.notification, 'NOTIFICATION');
    expect(
      LiveTrafficSource.normalise(LiveTrafficSource.notification),
      'NOTIFICATION',
    );
  });
}
