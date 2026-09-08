import 'package:flutter/material.dart';

import '../../../../../app/gifts/domain/entities/gift_entity.dart';
import '../../../../../core/models/live_battle.dart';
import '../../../domain/entities/live_battle_errors.dart';
import '../../../domain/repositories/live_session_repository.dart';

/// PK operations for the host's actual live, never a guest seat or user id.
class LiveBattleControls extends StatefulWidget {
  const LiveBattleControls({
    super.key,
    required this.liveId,
    required this.repository,
    required this.onChanged,
    required this.canAct,
    required this.loadGifts,
    this.battle,
  });

  final String liveId;
  final LiveSessionRepository repository;
  final LiveBattle? battle;
  final ValueChanged<LiveBattle?> onChanged;
  final bool Function() canAct;
  final Future<List<GiftEntity>> Function() loadGifts;

  @override
  State<LiveBattleControls> createState() => _LiveBattleControlsState();
}

class _LiveBattleControlsState extends State<LiveBattleControls> {
  final _form = GlobalKey<FormState>();
  final _duration = TextEditingController(text: '300');
  bool _team = false;
  int? _bestOf;
  String? _scoring;
  String? _giftId;
  bool _busy = false;
  bool _loading = true;
  int _loadGeneration = 0;
  String? _message;
  List<LiveBattleOpponent> _opponents = const [];
  List<LiveBattle> _lobbies = const [];
  List<GiftEntity> _gifts = const [];

  LiveBattle? get _battle => widget.battle;
  bool get _inBattle =>
      _battle != null &&
      !_battle!.isFinished &&
      _battle!.teamOf(widget.liveId) != null;
  bool get _captain =>
      _battle != null &&
      (_battle!.live1Id == widget.liveId || _battle!.live2Id == widget.liveId);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _duration.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final opponents = await widget.repository.loadBattleOpponents(
        widget.liveId,
      );
      final lobbies = _team && !_inBattle
          ? await widget.repository.loadOpenTeamBattles(widget.liveId)
          : const <LiveBattle>[];
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _opponents = opponents;
        _lobbies = lobbies;
      });
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _message = 'تعذر تحميل المنافسين. حاول التحديث.');
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _selectScoring(String? value) async {
    setState(() {
      _scoring = value;
      _giftId = null;
    });
    if (value != 'SPECIFIC_GIFT') return;
    try {
      final gifts = await widget.loadGifts();
      if (mounted) setState(() => _gifts = gifts);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'تعذر تحميل الهدايا. أعد اختيار طريقة النقاط للمحاولة.',
        );
      }
    }
  }

  Future<void> _run(
    Future<LiveBattle?> Function() action, {
    bool creating = false,
    bool leaving = false,
  }) async {
    if (_busy || !widget.canAct()) return;
    if (creating && (_inBattle || !(_form.currentState?.validate() ?? false))) {
      return;
    }
    final startingId = _battle?.id;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await action();
      if (!mounted || !widget.canAct()) return;
      // Do not apply a delayed operation to a different match.
      if (widget.battle?.id != startingId && widget.battle?.id != result?.id) {
        return;
      }
      if (!leaving && (result == null || result.id.isEmpty)) {
        setState(() => _message = 'وصل رد غير مكتمل. حدّث حالة المنافسة.');
        return;
      }
      widget.onChanged(leaving ? null : result);
      setState(
        () => _message = leaving
            ? 'غادرت الفريق؛ بثك مستمر.'
            : 'تم تحديث المنافسة.',
      );
    } catch (error) {
      if (mounted) setState(() => _message = noOpponentsMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _end() async {
    final battle = _battle;
    if (battle == null || !_captain) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنهاء المنافسة؟'),
        content: const Text('ستنتهي منافسة PK ويستمر البث المباشر.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            key: const ValueKey('pk-confirm-end'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إنهاء PK'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || widget.battle?.id != battle.id) return;
    await _run(
      () => widget.repository.endBattle(
        liveId: widget.liveId,
        battleId: battle.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final battle = _battle;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (battle != null) LiveBattleSummary(battle: battle),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _message!,
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
              ),
            if (_busy) const LinearProgressIndicator(),
            if (_inBattle) ...[
              if (battle!.isTeamMode &&
                  _captain &&
                  battle.teammateOf(widget.liveId) == null) ...[
                const Text('دعوة زميل إلى فريقك'),
                ..._opponents
                    .where((o) => !battle.participantLiveIds.contains(o.liveId))
                    .map(
                      (o) => ListTile(
                        title: Text(o.hostName),
                        trailing: TextButton(
                          key: ValueKey('pk-invite-${o.liveId}'),
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  () => widget.repository.inviteBattleTeammate(
                                    liveId: widget.liveId,
                                    battleId: battle.id,
                                    teammateLiveId: o.liveId,
                                  ),
                                ),
                          child: const Text('دعوة زميل'),
                        ),
                      ),
                    ),
              ],
              if (battle.isActive) ...[
                Wrap(
                  spacing: 8,
                  children: [
                    for (final type in LiveBattlePowerUpType.values)
                      OutlinedButton(
                        key: ValueKey('pk-power-$type'),
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => widget.repository.activateBattlePowerUp(
                                  liveId: widget.liveId,
                                  battleId: battle.id,
                                  type: type,
                                ),
                              ),
                        child: Text(switch (type) {
                          'STUN' => 'تجميد',
                          'TIME' => 'وقت إضافي',
                          _ => 'قفاز',
                        }),
                      ),
                    OutlinedButton(
                      key: const ValueKey('pk-multiplier'),
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => widget.repository.activateBattleMultiplier(
                                liveId: widget.liveId,
                                multiplier: 2,
                                durationSeconds: 30,
                              ),
                            ),
                      child: const Text('مضاعف ×2 · 30 ثانية'),
                    ),
                  ],
                ),
              ],
              if (_captain)
                FilledButton(
                  key: const ValueKey('pk-end'),
                  onPressed: _busy ? null : _end,
                  child: const Text('إنهاء PK'),
                )
              else if (battle.isTeamMode)
                OutlinedButton(
                  key: const ValueKey('pk-leave'),
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => widget.repository.leaveBattleTeam(
                            liveId: widget.liveId,
                            battleId: battle.id,
                          ),
                          leaving: true,
                        ),
                  child: const Text('مغادرة الفريق'),
                ),
            ] else ...[
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('1v1')),
                  ButtonSegment(value: true, label: Text('TEAM 2v2')),
                ],
                selected: {_team},
                onSelectionChanged: _busy
                    ? null
                    : (value) {
                        setState(() => _team = value.single);
                        _load();
                      },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('pk-duration'),
                controller: _duration,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'مدة الجولة بالثواني (30–1800)',
                ),
                validator: (value) {
                  final n = int.tryParse(value ?? '');
                  return n == null || n < 30 || n > 1800
                      ? 'أدخل مدة من 30 إلى 1800 ثانية'
                      : null;
                },
              ),
              DropdownButtonFormField<int>(
                key: const ValueKey('pk-best-of'),
                initialValue: _bestOf,
                decoration: const InputDecoration(labelText: 'الجولات'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('جولة واحدة')),
                  DropdownMenuItem(
                    value: 3,
                    child: Text('أفضل ثلاث جولات · BO3'),
                  ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _bestOf = value),
              ),
              DropdownButtonFormField<String>(
                key: const ValueKey('pk-scoring'),
                initialValue: _scoring,
                decoration: const InputDecoration(labelText: 'طريقة النقاط'),
                hint: const Text('إعداد الخادم الافتراضي'),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('الكل')),
                  DropdownMenuItem(value: 'GIFTS', child: Text('الهدايا')),
                  DropdownMenuItem(value: 'LIKES', child: Text('الإعجابات')),
                  DropdownMenuItem(
                    value: 'SPECIFIC_GIFT',
                    child: Text('هدية محددة'),
                  ),
                ],
                onChanged: _busy ? null : _selectScoring,
              ),
              if (_scoring == 'SPECIFIC_GIFT')
                DropdownButtonFormField<String>(
                  key: const ValueKey('pk-scoring-gift'),
                  initialValue: _giftId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'اختر الهدية'),
                  items: _gifts
                      .map(
                        (gift) => DropdownMenuItem(
                          value: gift.id,
                          child: Text(gift.name),
                        ),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _giftId = value),
                  validator: (value) =>
                      value == null ? 'اختر هدية من القائمة' : null,
                ),
              if (_team)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'يبدأ الفريقان بقبطانين، ويبقى مقعد زميل متاحًا لكل فريق.',
                  ),
                ),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else ...[
                if (_opponents.isEmpty)
                  const Text('لا يوجد بث مباشر آخر متاح للمنافسة الآن'),
                if (_opponents.isNotEmpty &&
                    _scoring == null &&
                    (_bestOf == null || _bestOf == 1))
                  OutlinedButton(
                    key: const ValueKey('pk-match'),
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => widget.repository.matchBattle(
                              widget.liveId,
                              durationSeconds: int.parse(_duration.text),
                              teamMode: _team,
                            ),
                            creating: true,
                          ),
                    child: const Text('مطابقة سريعة'),
                  ),
                ..._opponents.map(
                  (o) => ListTile(
                    title: Text(o.hostName),
                    subtitle: Text(o.title),
                    trailing: FilledButton(
                      key: ValueKey('pk-start-${o.liveId}'),
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => widget.repository.startBattle(
                                liveId: widget.liveId,
                                opponentLiveId: o.liveId,
                                durationSeconds: int.parse(_duration.text),
                                teamMode: _team,
                                scoringMode: _scoring,
                                scoringGiftId: _scoring == 'SPECIFIC_GIFT'
                                    ? _giftId
                                    : null,
                                bestOf: _bestOf,
                              ),
                              creating: true,
                            ),
                      child: const Text('تحدّي'),
                    ),
                  ),
                ),
                if (_team) ...[
                  const Text('الفرق المفتوحة'),
                  if (_lobbies.isEmpty) const Text('لا توجد فرق مفتوحة الآن'),
                  for (final lobby in _lobbies.where(
                    (b) =>
                        b.isTeamMode &&
                        !b.isFinished &&
                        b.teamOf(widget.liveId) == null,
                  ))
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LiveBattleSummary(battle: lobby),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final team in lobby.openSlots.toSet())
                              OutlinedButton(
                                key: ValueKey('pk-join-${lobby.id}-$team'),
                                onPressed: _busy
                                    ? null
                                    : () => _run(
                                        () => widget.repository.joinBattleTeam(
                                          liveId: widget.liveId,
                                          battleId: lobby.id,
                                          team: team,
                                        ),
                                      ),
                                child: Text('انضم للفريق $team'),
                              ),
                          ],
                        ),
                      ],
                    ),
                ],
              ],
            ],
            TextButton.icon(
              key: const ValueKey('pk-refresh'),
              onPressed: _busy || _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              label: const Text('تحديث القائمة'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Display only: no local point calculation or inferred winner.
class LiveBattleSummary extends StatelessWidget {
  const LiveBattleSummary({super.key, required this.battle});
  final LiveBattle battle;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        battle.isFinished
            ? (battle.status == 'CANCELLED'
                  ? 'أُلغيت المنافسة'
                  : 'انتهت المنافسة')
            : battle.isActive
            ? 'المنافسة جارية'
            : 'بانتظار بدء المنافسة',
      ),
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            for (final team in [1, 2])
              Expanded(
                child: Column(
                  children: [
                    Text('الفريق $team'),
                    Text('${battle.scoreForTeam(team)}'),
                    if (battle.isTeamMode)
                      Text(
                        (team == 1 ? battle.live3Id : battle.live4Id) == null
                            ? 'مقعد زميل فارغ'
                            : 'الزميل منضم',
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      if (battle.bestOf == 3)
        Text(
          'BO3 · الجولة ${battle.roundNumber ?? '—'} · ${battle.wins1 ?? '—'} : ${battle.wins2 ?? '—'}',
          textDirection: TextDirection.ltr,
        ),
      if (battle.isFinished &&
          battle.presentFields?.contains('winnerLiveId') == true)
        Text(
          battle.winnerLiveId == null
              ? 'تعادل'
              : 'فاز الفريق ${battle.teamOf(battle.winnerLiveId!) ?? '—'}',
        ),
      if (battle.powerUps?.stunTeam != null)
        Text('تجميد الفريق ${battle.powerUps!.stunTeam}'),
      if (battle.powerUps?.gloveCharges != null)
        Text(
          'قفاز الفريق ${battle.powerUps!.gloveTeam ?? '—'} · ${battle.powerUps!.gloveCharges}',
        ),
      if (battle.multiplier != 1) Text('المضاعف ×${battle.multiplier}'),
    ],
  );
}
