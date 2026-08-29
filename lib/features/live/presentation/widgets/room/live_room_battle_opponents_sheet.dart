import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/models/live_battle.dart';
import '../../../domain/entities/live_battle_errors.dart';
import '../../../domain/repositories/live_session_repository.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_event.dart';
import '../../bloc/live_room/live_room_state.dart';
import 'live_room_host_sheet_chrome.dart';

/// Opponent picker for starting a PK round, the way TikTok lets a host choose
/// who to go up against.
///
/// A PK is always **live vs live** on the server: `POST /lives/:id/battle`
/// needs an `opponentLiveId` of another broadcast that is currently `LIVE`.
/// The host used to reach this only through blind auto-match
/// (`POST /battle/match`), which picks a stranger and answers `404 No
/// opponents available` whenever nobody else happens to be broadcasting —
/// surfacing as a bare "تعذر بدء المنافسة" with nothing the host could do
/// about it. Showing the real roster makes both the choice and the empty case
/// legible, and auto-match stays as the one-tap shortcut.
class LiveRoomBattleOpponentsSheet {
  const LiveRoomBattleOpponentsSheet._();

  static Future<void> show(BuildContext context) => showWith(
    context: context,
    bloc: context.read<LiveRoomBloc>(),
    repository: context.read<LiveSessionRepository>(),
  );

  /// Opens the picker from dependencies captured **before** the caller's own
  /// route was popped. The options sheet closes itself first, and by then its
  /// context can no longer resolve either provider.
  static Future<void> showWith({
    required BuildContext context,
    required LiveRoomBloc bloc,
    required LiveSessionRepository repository,
  }) {
    final state = bloc.state;
    if (state is! LiveRoomReady) return Future.value();

    return LiveRoomHostSheetChrome.show(
      context: context,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: RepositoryProvider.value(
          value: repository,
          child: _BattleOpponentsBody(liveId: state.session.id),
        ),
      ),
    );
  }
}

class _BattleOpponentsBody extends StatefulWidget {
  const _BattleOpponentsBody({required this.liveId});

  final String liveId;

  @override
  State<_BattleOpponentsBody> createState() => _BattleOpponentsBodyState();
}

class _BattleOpponentsBodyState extends State<_BattleOpponentsBody>
    with LiveRoomHostSheetMixin {
  var _loading = true;
  var _busy = false;
  String? _error;
  List<LiveBattleOpponent> _opponents = const [];

  @override
  LiveSessionRepository get repository => context.read<LiveSessionRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final opponents = await repository.loadBattleOpponents(widget.liveId);
      if (!mounted) return;
      setState(() {
        _opponents = opponents;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorMessage(e);
      });
    }
  }

  /// Runs a battle-creating call and hands the ACTIVE snapshot to the BLoC,
  /// which is what connects the opponent's media and flips the room into the
  /// split-screen stage.
  Future<void> _startBattle(
    Future<LiveBattle> Function() action, {
    required String success,
  }) async {
    if (_busy) return;
    final ready = context.read<LiveRoomBloc>().state;
    if (ready is LiveRoomReady && ready.isBattleActive) {
      snack('هناك جولة منافسة نشطة بالفعل');
      return;
    }
    setState(() => _busy = true);
    try {
      final battle = await action();
      if (!mounted) return;
      context.read<LiveRoomBloc>().add(LiveRoomBattleChanged(battle));
      Navigator.of(context).maybePop();
      snack(success);
    } catch (e) {
      if (!mounted) return;
      if (isAlreadyInBattleError(e)) {
        try {
          final existing = await repository.loadBattle(widget.liveId);
          if (mounted && existing != null && existing.isActive) {
            context.read<LiveRoomBloc>().add(LiveRoomBattleChanged(existing));
            Navigator.of(context).maybePop();
            snack('المنافسة الجارية ما زالت مفتوحة');
            return;
          }
        } catch (_) {}
      }
      setState(() => _busy = false);
      snack(noOpponentsMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LiveRoomHostSheetChrome(
      title: 'اختر منافساً',
      child: _loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (_opponents.isNotEmpty) ...[
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _startBattle(
                            () => repository.matchBattle(widget.liveId),
                            success: 'بدأت جولة المنافسة',
                          ),
                    icon: const Icon(Icons.bolt),
                    label: const Text('مطابقة سريعة'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (_opponents.isEmpty)
                  _EmptyOpponents(busy: _busy, onRefresh: _load)
                else
                  ..._opponents.map(_opponentTile),
              ],
            ),
    );
  }

  Widget _opponentTile(LiveBattleOpponent opponent) {
    final avatar = opponent.hostAvatar;
    final hasAvatar = avatar != null && avatar.isNotEmpty;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: Colors.white12,
        backgroundImage: hasAvatar ? NetworkImage(avatar) : null,
        child: hasAvatar
            ? null
            : const Icon(Icons.person, color: Colors.white70),
      ),
      title: Text(
        opponent.hostName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${opponent.viewers} مشاهد · ${opponent.title}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      trailing: FilledButton(
        onPressed: _busy
            ? null
            : () => _startBattle(
                () => repository.startBattle(
                  liveId: widget.liveId,
                  opponentLiveId: opponent.liveId,
                ),
                success: 'بدأت المنافسة مع ${opponent.hostName}',
              ),
        child: const Text('تحدّي'),
      ),
    );
  }
}

/// The common case while testing, and the one the old blind auto-match made
/// look like a failure: nobody else is broadcasting right now.
class _EmptyOpponents extends StatelessWidget {
  const _EmptyOpponents({required this.busy, required this.onRefresh});

  final bool busy;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        children: [
          const Icon(Icons.groups_outlined, size: 44, color: Colors.white38),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'لا يوجد بث مباشر آخر متاح للمنافسة الآن',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          const Text(
            'المنافسة تكون بين بثّين مباشرين. اطلب من الطرف الآخر بدء بثّه ثم حدّث القائمة.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: busy ? null : onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('تحديث القائمة'),
          ),
        ],
      ),
    );
  }
}
