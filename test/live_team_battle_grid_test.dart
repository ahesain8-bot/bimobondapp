import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bimobondapp/core/models/live_battle.dart';
import 'package:bimobondapp/core/widgets/live_team_battle_grid.dart';

class VideoProbe extends StatefulWidget {
  const VideoProbe({
    super.key,
    required this.id,
    required this.mountedIds,
    required this.disposedIds,
  });
  final String id;
  final List<String> mountedIds;
  final List<String> disposedIds;
  @override
  State<VideoProbe> createState() => _ProbeState();
}

class _ProbeState extends State<VideoProbe> {
  @override
  void initState() {
    super.initState();
    widget.mountedIds.add(widget.id);
  }

  @override
  void dispose() {
    widget.disposedIds.add(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

void main() {
  LiveBattle battle({String? teammate = 'c', int score = 10}) =>
      LiveBattle.fromJson({
        'id': 'pk',
        'mode': 'TEAM',
        'status': 'ACTIVE',
        'live1Id': 'a',
        'live2Id': 'b',
        'live3Id': teammate,
        'live4Id': 'd',
        'live1Score': score,
        'live2Score': 2,
      });
  testWidgets(
    'RTL keeps teammate with captain and current team with left score',
    (tester) async {
      for (final own in ['a', 'b', 'c', 'd']) {
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: SizedBox(
                width: 320,
                height: 300,
                child: LiveTeamBattleGrid(
                  battle: battle(),
                  currentLiveId: own,
                  videoFor: (_) => null,
                ),
              ),
            ),
          ),
        );
        Rect seat(String id) =>
            tester.getRect(find.byKey(ValueKey('pk-live-$id')));
        expect(seat('a').left, seat('c').left);
        expect(seat('b').left, seat('d').left);
        expect(seat('a').top, lessThan(seat('c').top));
        expect(
          seat(own).left,
          own == 'a' || own == 'c' ? seat('a').left : seat('b').left,
        );
        expect(
          seat(own).left,
          lessThan(seat(battle().opponentLiveId(own)).left),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets('score and unrelated roster changes preserve mounted media', (
    tester,
  ) async {
    final mounted = <String>[];
    final disposed = <String>[];
    Future<void> show(LiveBattle snapshot) => tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 300,
          child: LiveTeamBattleGrid(
            battle: snapshot,
            currentLiveId: 'a',
            videoFor: (id) => VideoProbe(
              key: ValueKey(id),
              id: id,
              mountedIds: mounted,
              disposedIds: disposed,
            ),
          ),
        ),
      ),
    );
    await show(battle());
    expect(mounted.toSet(), {'a', 'b', 'c', 'd'});
    await show(battle(score: 90));
    expect(mounted, hasLength(4));
    expect(disposed, isEmpty);
    await show(battle(teammate: null));
    expect(disposed, ['c']);
    expect(find.byKey(const ValueKey('pk-empty-1')), findsOneWidget);
    expect(find.text('مقعد زميل فارغ'), findsOneWidget);
    await show(battle());
    expect(mounted.where((id) => id == 'c'), hasLength(2));
    expect(mounted.where((id) => id == 'a'), hasLength(1));
  });
}
