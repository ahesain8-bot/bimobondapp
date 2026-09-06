import 'package:flutter_test/flutter_test.dart';

import 'package:bimobondapp/core/models/live_battle.dart';

/// Mirrors the host stage / viewer page battle-layout `buildWhen` rule:
/// score-only changes must not rebuild video tiles.
bool battleLayoutChanged(LiveBattle? prev, LiveBattle? curr) {
  return (prev?.isActive == true) != (curr?.isActive == true) ||
      prev?.id != curr?.id ||
      prev?.live1Id != curr?.live1Id ||
      prev?.live2Id != curr?.live2Id ||
      prev?.status != curr?.status ||
      prev?.phase != curr?.phase;
}

void main() {
  LiveBattle battle({
    int live1Score = 0,
    int live2Score = 0,
    String status = 'ACTIVE',
    String phase = 'BATTLE',
    String id = 'b1',
  }) {
    return LiveBattle(
      id: id,
      live1Id: 'live-a',
      live2Id: 'live-b',
      live1Score: live1Score,
      live2Score: live2Score,
      status: status,
      phase: phase,
    );
  }

  test('score-only battle ticks do not change layout identity', () {
    final a = battle(live1Score: 10, live2Score: 5);
    final b = battle(live1Score: 99, live2Score: 40);
    expect(battleLayoutChanged(a, b), isFalse);
    expect(a == b, isFalse);
  });

  test('status / id / phase / opponent changes do change layout identity', () {
    final a = battle();
    expect(battleLayoutChanged(a, battle(status: 'FINISHED')), isTrue);
    expect(battleLayoutChanged(a, battle(id: 'b2')), isTrue);
    expect(battleLayoutChanged(a, battle(phase: 'PENALTY')), isTrue);
    expect(battleLayoutChanged(null, a), isTrue);
    expect(battleLayoutChanged(a, null), isTrue);
  });
}
