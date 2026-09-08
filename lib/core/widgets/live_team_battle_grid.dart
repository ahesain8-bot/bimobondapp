import 'package:flutter/material.dart';

import '../models/live_battle.dart';

/// Team columns stay with their scores in RTL. Every occupied seat is keyed
/// by live id; an empty slot is keyed by team, never by a list index.
class LiveTeamBattleGrid extends StatelessWidget {
  const LiveTeamBattleGrid({
    super.key,
    required this.battle,
    required this.currentLiveId,
    required this.videoFor,
  });

  final LiveBattle battle;
  final String currentLiveId;
  final Widget? Function(String liveId) videoFor;

  @override
  Widget build(BuildContext context) {
    final ownTeam = battle.teamOf(currentLiveId) ?? 1;
    final videos = {
      for (final id in battle.participantLiveIds) id: videoFor(id),
    };
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final team in [ownTeam, ownTeam == 1 ? 2 : 1])
            Expanded(
              key: ValueKey('pk-team-$team'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final liveId
                      in team == 1
                          ? [battle.live1Id, battle.live3Id]
                          : [battle.live2Id, battle.live4Id])
                    Expanded(
                      key: ValueKey(
                        liveId == null ? 'pk-empty-$team' : 'pk-live-$liveId',
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(1),
                        child: ColoredBox(
                          color: const Color(0xFF17171A),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (liveId != null && videos[liveId] != null)
                                videos[liveId]!
                              else
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      liveId == null
                                          ? 'مقعد زميل فارغ'
                                          : 'فيديو المشارك غير متاح',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                left: 4,
                                bottom: 4,
                                child: Text(
                                  'الفريق $team',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    backgroundColor: Colors.black54,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Server-reported series/effects. The label never advances rounds locally.
class LiveBattleStatusLabel extends StatelessWidget {
  const LiveBattleStatusLabel({super.key, required this.battle});
  final LiveBattle battle;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (battle.bestOf == 3)
        'BO3 · الجولة ${battle.roundNumber ?? '—'} · ${battle.wins1 ?? '—'} : ${battle.wins2 ?? '—'}',
      if (battle.powerUps?.stunTeam != null)
        'تجميد الفريق ${battle.powerUps!.stunTeam}',
      if (battle.powerUps?.gloveCharges != null)
        'قفاز ${battle.powerUps!.gloveCharges}',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Text(
            parts.join(' · '),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
      ),
    );
  }
}
