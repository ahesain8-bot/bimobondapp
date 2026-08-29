import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/models/live_battle.dart';
import '../../../domain/entities/live_battle_errors.dart';
import '../../../domain/entities/live_guest.dart';
import '../../../domain/repositories/live_session_repository.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_event.dart';
import '../../bloc/live_room/live_room_state.dart';
import 'live_room_host_sheet_chrome.dart';

/// Host multi-guest / collaboration sheet (lives/mobile-api.md §10).
class LiveRoomGuestsSheet {
  const LiveRoomGuestsSheet._();

  static Future<void> show(BuildContext context) {
    final bloc = context.read<LiveRoomBloc>();
    final repo = context.read<LiveSessionRepository>();
    final state = bloc.state;
    if (state is! LiveRoomReady) return Future.value();

    return LiveRoomHostSheetChrome.show(
      context: context,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: RepositoryProvider.value(
          value: repo,
          child: _LiveRoomGuestsSheetBody(liveId: state.session.id),
        ),
      ),
    );
  }
}

class _LiveRoomGuestsSheetBody extends StatefulWidget {
  const _LiveRoomGuestsSheetBody({required this.liveId});

  final String liveId;

  @override
  State<_LiveRoomGuestsSheetBody> createState() =>
      _LiveRoomGuestsSheetBodyState();
}

class _LiveRoomGuestsSheetBodyState extends State<_LiveRoomGuestsSheetBody>
    with LiveRoomHostSheetMixin {
  var _loading = true;
  var _busy = false;
  String? _error;
  List<LiveGuest> _guests = const [];
  List<LiveBattleOpponent> _opponents = const [];
  LiveBattle? _battle;
  final _inviteController = TextEditingController();

  @override
  LiveSessionRepository get repository => context.read<LiveSessionRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        repository.loadGuests(widget.liveId),
        _loadBattleSafely(),
        _loadOpponentsSafely(),
      ]);
      if (!mounted) return;
      setState(() {
        _guests = results[0] as List<LiveGuest>;
        _battle = results[1] as LiveBattle?;
        _opponents = results[2] as List<LiveBattleOpponent>;
        _loading = false;
      });
      context.read<LiveRoomBloc>().add(const LiveRoomGuestsChanged());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorMessage(e);
      });
    }
  }

  Future<LiveBattle?> _loadBattleSafely() async {
    try {
      return await repository.loadBattle(widget.liveId);
    } catch (_) {
      return null;
    }
  }

  Future<List<LiveBattleOpponent>> _loadOpponentsSafely() async {
    try {
      return await repository.loadBattleOpponents(widget.liveId);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _runBattle(
    Future<LiveBattle> Function() action, {
    required String success,
  }) async {
    if (_busy) return;
    if (_battle?.isActive == true) {
      snack('هناك جولة منافسة نشطة بالفعل');
      return;
    }
    setState(() => _busy = true);
    try {
      final battle = await action();
      if (!mounted) return;
      setState(() => _battle = battle);
      context.read<LiveRoomBloc>().add(LiveRoomBattleChanged(battle));
      snack(success);
    } catch (e) {
      if (isAlreadyInBattleError(e)) {
        final existing = await _loadBattleSafely();
        if (mounted && existing != null && existing.isActive) {
          setState(() => _battle = existing);
          context.read<LiveRoomBloc>().add(LiveRoomBattleChanged(existing));
          snack('المنافسة الجارية ما زالت مفتوحة');
          return;
        }
      }
      if (mounted) snack(noOpponentsMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      if (success != null) snack(success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      snack(errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _invite() async {
    final userId = _inviteController.text.trim();
    if (userId.isEmpty) {
      snack('أدخل معرف المستخدم للدعوة');
      return;
    }
    await _run(
      () => repository.inviteGuest(liveId: widget.liveId, userId: userId),
      success: 'تم إرسال الدعوة',
    );
    _inviteController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final pending = _guests.where((g) => g.isPending).toList();
    final active = _guests.where((g) => g.isActive).toList();

    // The bloc keeps the roster fresh off `liveGuestUpdate`; mirroring it here
    // means a viewer's request lands in the open sheet without a manual pull.
    return BlocListener<LiveRoomBloc, LiveRoomState>(
      listenWhen: (previous, current) =>
          current is LiveRoomReady &&
          (previous is! LiveRoomReady ||
              previous.guests != current.guests ||
              previous.battle != current.battle),
      listener: (context, state) {
        if (state is! LiveRoomReady || _busy) return;
        setState(() {
          _guests = state.guests;
          _battle = state.battle;
        });
      },
      child: LiveRoomHostSheetChrome(
        title: 'الضيوف والتعاون',
        actions: [
          IconButton(
            onPressed: _loading || _busy ? null : _load,
            icon: const Icon(Icons.refresh, color: Colors.white70),
          ),
        ],
        child: _loading
            ? const LiveRoomSheetStatus.loading()
            : _error != null
            ? LiveRoomSheetStatus.error(message: _error!)
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _battleSection(),
                  const SizedBox(height: 22),
                  const Text(
                    'دعوة ضيف',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inviteController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'userId',
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: Colors.white10,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _busy ? null : _invite,
                        child: const Text('دعوة'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle('طلبات معلقة (${pending.length})'),
                  if (pending.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'لا توجد طلبات حالياً',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  else
                    ...pending.map(_pendingTile),
                  const SizedBox(height: 14),
                  _sectionTitle('على المسرح (${active.length})'),
                  if (active.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'لا يوجد ضيوف نشطون',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  else
                    ...active.map(_activeTile),
                ],
              ),
      ),
    );
  }

  Widget _battleSection() {
    final battle = _battle;
    if (battle?.isActive == true) {
      final mine = battle!.scoreFor(widget.liveId);
      final theirs = battle.opponentScoreFor(widget.liveId);
      return Card(
        color: const Color(0x3325F4EE),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'المعركة جارية الآن',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$mine  —  $theirs · ${battle.phase}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _runBattle(
                            () => repository.activateBattleMultiplier(
                              liveId: widget.liveId,
                              multiplier: 2,
                              durationSeconds: 30,
                            ),
                            success: 'تم تفعيل مضاعف ×2 لمدة 30 ثانية',
                          ),
                    child: const Text('مضاعف ×2'),
                  ),
                  FilledButton.tonal(
                    onPressed: _busy
                        ? null
                        : () => _runBattle(
                            () => repository.endBattle(
                              liveId: widget.liveId,
                              battleId: battle.id,
                            ),
                            success: 'تم إنهاء المعركة',
                          ),
                    style: FilledButton.styleFrom(
                      foregroundColor: Colors.red.shade100,
                      backgroundColor: Colors.red.shade900,
                    ),
                    child: const Text('إنهاء المعركة'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'المعارك المباشرة',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'اختر مضيفاً مباشراً أو دع الخادم يجد خصماً متاحاً.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 10),
        if (_opponents.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'لا يوجد بث مباشر آخر متاح للمنافسة الآن',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          )
        else
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () => _runBattle(
                    () => repository.matchBattle(widget.liveId),
                    success: 'بدأت المعركة',
                  ),
            icon: const Icon(Icons.bolt),
            label: const Text('مطابقة تلقائية وبدء المعركة'),
          ),
        if (_opponents.isNotEmpty) ...[
          const SizedBox(height: 10),
          ..._opponents
              .take(8)
              .map(
                (opponent) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundImage: opponent.hostAvatar?.isNotEmpty == true
                        ? NetworkImage(opponent.hostAvatar!)
                        : null,
                    child: opponent.hostAvatar?.isNotEmpty == true
                        ? null
                        : const Icon(Icons.person),
                  ),
                  title: Text(
                    opponent.hostName,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '${opponent.viewers} مشاهد · ${opponent.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _runBattle(
                            () => repository.startBattle(
                              liveId: widget.liveId,
                              opponentLiveId: opponent.liveId,
                            ),
                            success: 'بدأت المعركة مع ${opponent.hostName}',
                          ),
                    child: const Text('تحدّي'),
                  ),
                ),
              ),
        ],
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
    );
  }

  Widget _pendingTile(LiveGuest guest) {
    return Card(
      color: Colors.white10,
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        title: Text(
          guest.displayName,
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          '${guest.status} · ${guest.role}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            if (guest.status == 'REQUESTED')
              IconButton(
                tooltip: 'قبول',
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => repository.acceptGuest(
                          liveId: widget.liveId,
                          userId: guest.userId,
                        ),
                        success: 'تم القبول',
                      ),
                icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
              ),
            IconButton(
              tooltip: 'رفض',
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => repository.rejectGuest(
                        liveId: widget.liveId,
                        userId: guest.userId,
                      ),
                      success: 'تم الرفض',
                    ),
              icon: const Icon(Icons.cancel, color: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeTile(LiveGuest guest) {
    return Card(
      color: Colors.white10,
      margin: const EdgeInsets.only(top: 8),
      child: ExpansionTile(
        collapsedIconColor: Colors.white70,
        iconColor: Colors.white70,
        title: Text(
          guest.displayName,
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          '${guest.role}${guest.mutedByHost ? ' · مكتوم' : ''}'
          '${guest.cameraOffByHost ? ' · كاميرا مغلقة' : ''}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _actionChip(
                guest.mutedByHost ? 'إلغاء كتم' : 'كتم المايك',
                () => _run(
                  () => guest.mutedByHost
                      ? repository.unmuteGuest(
                          liveId: widget.liveId,
                          userId: guest.userId,
                        )
                      : repository.muteGuest(
                          liveId: widget.liveId,
                          userId: guest.userId,
                        ),
                ),
              ),
              _actionChip(
                guest.cameraOffByHost ? 'تفعيل الكاميرا' : 'إغلاق الكاميرا',
                () => _run(
                  () => guest.cameraOffByHost
                      ? repository.setGuestCameraOn(
                          liveId: widget.liveId,
                          userId: guest.userId,
                        )
                      : repository.setGuestCameraOff(
                          liveId: widget.liveId,
                          userId: guest.userId,
                        ),
                ),
              ),
              if (guest.role == 'GUEST')
                _actionChip(
                  'ترقية لمضيف مشارك',
                  () => _run(
                    () => repository.promoteGuest(
                      liveId: widget.liveId,
                      userId: guest.userId,
                    ),
                    success: 'تمت الترقية',
                  ),
                ),
              if (guest.role == 'CO_HOST')
                _actionChip(
                  'إرجاع لضيف',
                  () => _run(
                    () => repository.demoteGuest(
                      liveId: widget.liveId,
                      userId: guest.userId,
                    ),
                  ),
                ),
              _actionChip(
                'طرد',
                () => _run(
                  () => repository.kickGuest(
                    liveId: widget.liveId,
                    userId: guest.userId,
                  ),
                  success: 'تم الطرد',
                ),
                danger: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _actionChip(String label, VoidCallback onTap, {bool danger = false}) {
    return ActionChip(
      onPressed: _busy ? null : onTap,
      label: Text(label),
      backgroundColor: danger ? Colors.red.shade900 : Colors.white12,
      labelStyle: TextStyle(
        color: danger ? Colors.red.shade100 : Colors.white,
        fontSize: 12,
      ),
    );
  }
}
