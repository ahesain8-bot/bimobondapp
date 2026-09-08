import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bimobondapp/features/live/domain/entities/live_host.dart';
import 'package:bimobondapp/features/live/domain/entities/live_session.dart';
import 'package:bimobondapp/features/live/presentation/bloc/live_room/live_room_bloc.dart';
import 'package:bimobondapp/features/live/presentation/bloc/live_room/live_room_event.dart';
import 'package:bimobondapp/features/live/presentation/bloc/live_room/live_room_state.dart';
import 'package:bimobondapp/features/live/presentation/widgets/room/live_room_battle_opponents_sheet.dart';
import 'live_battle_controls_test.dart' show Repository;

class RoomBloc extends Fake implements LiveRoomBloc {
  final events = <LiveRoomEvent>[];
  @override
  LiveRoomState get state => const LiveRoomReady(
    session: LiveSession(
      id: 'captain-a',
      host: LiveHost(id: 'user-a', displayName: 'A'),
      viewerCount: 0,
      likeCount: 0,
      galleryCurrent: 0,
      galleryTotal: 0,
      guestInviteCount: 0,
      hourlyRankingLabel: '',
      messages: [],
    ),
  );
  @override
  Stream<LiveRoomState> get stream => const Stream.empty();
  @override
  bool get isClosed => false;
  @override
  void add(LiveRoomEvent event) => events.add(event);
}

void main() {
  testWidgets(
    'actual modal entry sends TEAM and forwards server snapshot to room event',
    (tester) async {
      final repository = Repository();
      final bloc = RoomBloc();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => LiveRoomBattleOpponentsSheet.showWith(
                  context: context,
                  bloc: bloc,
                  repository: repository,
                ),
                child: const Text('PK'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('PK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEAM 2v2'));
      await tester.pumpAndSettle();
      final challenge = find.byKey(const ValueKey('pk-start-captain-b'));
      await tester.ensureVisible(challenge);
      await tester.tap(challenge);
      await tester.pumpAndSettle();
      expect(repository.calls.single['team'], true);
      expect(repository.calls.single['opponent'], 'captain-b');
      expect(bloc.events.single, isA<LiveRoomBattleChanged>());
      expect((bloc.events.single as LiveRoomBattleChanged).battle!.id, 'pk');
      expect(tester.takeException(), isNull);
    },
  );
}
