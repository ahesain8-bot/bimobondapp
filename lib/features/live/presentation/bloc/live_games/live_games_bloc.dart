import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/mappers/live_game_mapper.dart';
import '../../../domain/entities/live_game.dart';
import '../../../../live_viewer/domain/entities/socket_event.dart';
import '../../../domain/repositories/live_games_repository.dart';
import '../../../domain/repositories/live_session_repository.dart';

sealed class LiveGamesEvent {
  const LiveGamesEvent();
}

/// Loads the catalog and whatever game is already running.
class LiveGamesStarted extends LiveGamesEvent {
  const LiveGamesStarted(this.liveId);

  final String liveId;
}

/// Host starts the single ACTIVE game.
class LiveGameStartRequested extends LiveGamesEvent {
  const LiveGameStartRequested({
    required this.type,
    this.question,
    this.options,
    this.correctIndex,
    this.prizes,
  });

  final LiveGameType type;
  final String? question;
  final List<String>? options;
  final int? correctIndex;
  final List<String>? prizes;
}

/// Viewer plays once. [optionIndex] applies to QUIZ only.
class LiveGamePlayRequested extends LiveGamesEvent {
  const LiveGamePlayRequested({this.optionIndex});

  final int? optionIndex;
}

/// Host closes the game; the server reveals the answer and the winner.
class LiveGameEndRequested extends LiveGamesEvent {
  const LiveGameEndRequested();
}

/// A `liveGame` socket push.
class LiveGameSocketReceived extends LiveGamesEvent {
  const LiveGameSocketReceived(this.payload);

  final Map<String, dynamic> payload;
}

class LiveGameMessageShown extends LiveGamesEvent {
  const LiveGameMessageShown();
}

/// A refusal the client itself decided, so the UI can localize it instead of
/// showing a message built in the BLoC.
enum LiveGamesNotice {
  /// One ACTIVE game per live; a second start is not sent.
  alreadyRunning,
}

class LiveGamesState {
  const LiveGamesState({
    this.loading = false,
    this.busy = false,
    this.catalog = const [],
    this.game,
    this.message,
    this.notice,
  });

  final bool loading;
  final bool busy;
  final List<LiveGameCatalogEntry> catalog;

  /// Null when no game is running.
  final LiveGame? game;

  /// A server-provided error, shown as it arrived.
  final String? message;

  /// A refusal this client made; the UI turns it into localized text.
  final LiveGamesNotice? notice;

  /// One ACTIVE game per live: the host cannot start another while this runs.
  bool get hasActiveGame => game?.isActive == true;

  LiveGamesState copyWith({
    bool? loading,
    bool? busy,
    List<LiveGameCatalogEntry>? catalog,
    LiveGame? game,
    String? message,
    LiveGamesNotice? notice,
    bool clearGame = false,
    bool clearMessage = false,
  }) {
    return LiveGamesState(
      loading: loading ?? this.loading,
      busy: busy ?? this.busy,
      catalog: catalog ?? this.catalog,
      game: clearGame ? null : (game ?? this.game),
      message: clearMessage ? null : (message ?? this.message),
      // A notice is transient: it clears with the message it accompanies.
      notice: clearMessage ? null : (notice ?? this.notice),
    );
  }
}

/// Official in-LIVE games (`lives/live-p3-parity.md` §3).
///
/// Results are always the server's. Nothing here picks a wheel prize, chooses
/// a lucky-draw winner, or reveals a quiz answer that the server withheld — a
/// spinning animation is presentation, never an outcome.
class LiveGamesBloc extends Bloc<LiveGamesEvent, LiveGamesState> {
  LiveGamesBloc({
    required LiveGamesRepository repository,
    Stream<Object>? socketEvents,
  }) : _repository = repository,
       super(const LiveGamesState()) {
    on<LiveGamesStarted>(_onStarted);
    on<LiveGameStartRequested>(_onStartRequested);
    on<LiveGamePlayRequested>(_onPlayRequested);
    on<LiveGameEndRequested>(_onEndRequested);
    on<LiveGameSocketReceived>(_onSocketReceived);
    on<LiveGameMessageShown>((event, emit) {
      emit(state.copyWith(clearMessage: true));
    });

    if (socketEvents != null) {
      _socketSubscription = socketEvents.listen((event) {
        // The host room and the viewer room wrap the same push differently.
        final payload = switch (event) {
          LiveHudInteractiveEvent(:final payload) => payload,
          LiveInteractiveSocketEvent(:final payload) => payload,
          _ => null,
        };
        if (payload == null || payload.event != 'liveGame') return;
        if (_liveId != null &&
            payload.liveId.isNotEmpty &&
            payload.liveId != _liveId) {
          // A push from a room the viewer already left never rewrites this one.
          return;
        }
        add(LiveGameSocketReceived(payload.payload));
      });
    }
  }

  final LiveGamesRepository _repository;
  StreamSubscription<Object>? _socketSubscription;
  String? _liveId;

  @override
  Future<void> close() async {
    await _socketSubscription?.cancel();
    return super.close();
  }

  Future<void> _onStarted(
    LiveGamesStarted event,
    Emitter<LiveGamesState> emit,
  ) async {
    _liveId = event.liveId;
    emit(state.copyWith(loading: true, clearGame: true, clearMessage: true));
    List<LiveGameCatalogEntry> catalog = state.catalog;
    try {
      catalog = await _repository.catalog();
    } catch (_) {
      // A missing catalog only removes the host's start menu; a game already
      // running still shows.
    }
    LiveGame? game;
    try {
      game = await _repository.activeGame(event.liveId);
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(loading: false, catalog: catalog, message: e.toString()),
      );
      return;
    }
    if (isClosed || _liveId != event.liveId) return;
    emit(LiveGamesState(catalog: catalog, game: game));
  }

  Future<void> _onStartRequested(
    LiveGameStartRequested event,
    Emitter<LiveGamesState> emit,
  ) async {
    final liveId = _liveId;
    if (liveId == null || state.busy) return;
    if (state.hasActiveGame) {
      emit(state.copyWith(notice: LiveGamesNotice.alreadyRunning));
      return;
    }
    emit(state.copyWith(busy: true, clearMessage: true));
    try {
      final game = await _repository.startGame(
        liveId,
        type: event.type,
        question: event.question,
        options: event.options,
        correctIndex: event.correctIndex,
        prizes: event.prizes,
      );
      if (isClosed || _liveId != liveId) return;
      emit(state.copyWith(busy: false, game: game));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(busy: false, message: e.toString()));
    }
  }

  Future<void> _onPlayRequested(
    LiveGamePlayRequested event,
    Emitter<LiveGamesState> emit,
  ) async {
    final liveId = _liveId;
    final game = state.game;
    if (liveId == null || game == null || state.busy) return;
    // One play per viewer, and only while the game is running.
    if (!game.canPlay) return;
    if (game.type == LiveGameType.quiz &&
        (event.optionIndex == null ||
            event.optionIndex! < 0 ||
            event.optionIndex! >= game.options.length)) {
      return;
    }
    emit(state.copyWith(busy: true, clearMessage: true));
    try {
      final updated = await _repository.play(
        liveId,
        gameId: game.id,
        optionIndex: game.type == LiveGameType.quiz ? event.optionIndex : null,
      );
      if (isClosed || _liveId != liveId) return;
      emit(
        state.copyWith(
          busy: false,
          // The server's own view wins; the local flag only covers a response
          // that carried no game body.
          game:
              updated ??
              game.copyWith(myPlayed: true, myOptionIndex: event.optionIndex),
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(busy: false, message: e.toString()));
    }
  }

  Future<void> _onEndRequested(
    LiveGameEndRequested event,
    Emitter<LiveGamesState> emit,
  ) async {
    final liveId = _liveId;
    final game = state.game;
    if (liveId == null || game == null || state.busy || !game.isActive) return;
    emit(state.copyWith(busy: true, clearMessage: true));
    try {
      final updated = await _repository.endGame(liveId, gameId: game.id);
      if (isClosed || _liveId != liveId) return;
      emit(state.copyWith(busy: false, game: updated ?? game));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(busy: false, message: e.toString()));
    }
  }

  void _onSocketReceived(
    LiveGameSocketReceived event,
    Emitter<LiveGamesState> emit,
  ) {
    final incoming = LiveGameMapper.gameFromJson(event.payload);
    if (incoming == null) return;
    final current = state.game;
    if (current != null && current.id != incoming.id && current.isActive) {
      // A push about a different game does not replace the running one unless
      // that one already ended.
      if (incoming.isActive) {
        emit(state.copyWith(game: incoming));
      }
      return;
    }
    emit(
      state.copyWith(
        // A push is broadcast to the room, so it carries no viewer-scoped
        // play. Keep what this viewer already knows about their own play.
        game: current == null
            ? incoming
            : incoming.copyWith(
                myPlayed: incoming.myPlayed || current.myPlayed,
                myOptionIndex: incoming.myOptionIndex ?? current.myOptionIndex,
              ),
      ),
    );
  }
}
