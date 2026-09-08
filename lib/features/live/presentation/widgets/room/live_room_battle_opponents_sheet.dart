import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../app/gifts/presentation/di/gifts_injector.dart'
    as gifts_di;
import '../../../../../app/gifts/domain/usecases/get_gifts_usecase.dart';
import '../../../../../app/gifts/domain/repositories/gifts_repository.dart';
import 'live_battle_controls.dart';
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
    if (state.isLivePaused) return Future.value();

    return LiveRoomHostSheetChrome.show(
      context: context,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: RepositoryProvider.value(
          value: repository,
          child: LiveRoomHostSheetChrome(
            title: 'منافسة PK',
            child: BlocBuilder<LiveRoomBloc, LiveRoomState>(
              builder: (context, current) => LiveBattleControls(
                liveId: state.session.id,
                repository: repository,
                battle: current is LiveRoomReady ? current.battle : null,
                canAct: () {
                  final latest = bloc.state;
                  return !bloc.isClosed &&
                      latest is LiveRoomReady &&
                      latest.session.id == state.session.id &&
                      !latest.isLivePaused;
                },
                onChanged: (battle) => bloc.add(LiveRoomBattleChanged(battle)),
                loadGifts: () async {
                  final result = await gifts_di.sl<GetGiftsUseCase>()(
                    const GetGiftsParams(),
                  );
                  return result.fold(
                    (failure) => throw StateError(failure.message),
                    (gifts) => gifts,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
