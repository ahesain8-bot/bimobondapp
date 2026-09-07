import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/live_replay.dart';
import '../../../domain/repositories/live_session_repository.dart';

/// Events for the replay + clips screen.
sealed class LiveReplayEvent {
  const LiveReplayEvent();
}

/// Opens the screen. This is the only place that reads `GET /lives/:id/replay`
/// implicitly, because that endpoint counts a view.
class LiveReplayOpened extends LiveReplayEvent {
  const LiveReplayOpened();
}

/// An explicit, user-initiated reload. Counts another view, so it is only ever
/// sent from a Refresh action — never from a rebuild, a timer or a preload.
class LiveReplayReloaded extends LiveReplayEvent {
  const LiveReplayReloaded();
}

/// Loads the clip list only (`GET /lives/:id/clips`); costs no replay view.
class LiveReplayClipsRequested extends LiveReplayEvent {
  const LiveReplayClipsRequested();
}

/// Host publishes a replay URL when Egress produced none.
class LiveReplayPublished extends LiveReplayEvent {
  const LiveReplayPublished(this.replayUrl);

  final String replayUrl;
}

/// Host removes the replay.
class LiveReplayRemoved extends LiveReplayEvent {
  const LiveReplayRemoved();
}

/// Host creates a clip from the selected bounds.
class LiveReplayClipCreated extends LiveReplayEvent {
  const LiveReplayClipCreated({
    required this.startSeconds,
    required this.endSeconds,
    this.title,
  });

  final num startSeconds;
  final num endSeconds;
  final String? title;
}

/// Host publishes an existing clip as a post.
class LiveReplayClipPosted extends LiveReplayEvent {
  const LiveReplayClipPosted(this.clipId, {this.description});

  final String clipId;
  final String? description;
}

/// Clears the transient action message.
class LiveReplayMessageShown extends LiveReplayEvent {
  const LiveReplayMessageShown();
}

class LiveReplayState {
  const LiveReplayState({
    this.loading = false,
    this.busy = false,
    this.replay,
    this.clips = const [],
    this.error,
    this.message,
    this.lastPostedClipId,
    this.lastPostId,
  });

  final bool loading;

  /// True while a mutation (publish / create / post / remove) is in flight.
  final bool busy;
  final LiveReplay? replay;
  final List<LiveClip> clips;
  final String? error;
  final String? message;
  final String? lastPostedClipId;

  /// Post created by the last publish, so the screen can offer to open it.
  final String? lastPostId;

  LiveReplayState copyWith({
    bool? loading,
    bool? busy,
    LiveReplay? replay,
    List<LiveClip>? clips,
    String? error,
    String? message,
    String? lastPostedClipId,
    String? lastPostId,
    bool clearError = false,
    bool clearMessage = false,
    bool clearPosted = false,
  }) {
    return LiveReplayState(
      loading: loading ?? this.loading,
      busy: busy ?? this.busy,
      replay: replay ?? this.replay,
      clips: clips ?? this.clips,
      error: clearError ? null : (error ?? this.error),
      message: clearMessage ? null : (message ?? this.message),
      lastPostedClipId: clearPosted
          ? null
          : (lastPostedClipId ?? this.lastPostedClipId),
      lastPostId: clearPosted ? null : (lastPostId ?? this.lastPostId),
    );
  }
}

/// Drives replay playback access and the clip workflow
/// (`lives/live-p0-parity.md` §1, `lives/live-p1-parity.md` §5).
///
/// The clip is stored as start/end on the replay; there is no client-side cut
/// and no upload here. Nothing in this bloc publishes on its own.
class LiveReplayBloc extends Bloc<LiveReplayEvent, LiveReplayState> {
  LiveReplayBloc({
    required LiveSessionRepository repository,
    required this.liveId,
  }) : _repository = repository,
       super(const LiveReplayState()) {
    on<LiveReplayOpened>((event, emit) => _load(emit, countsView: true));
    on<LiveReplayReloaded>((event, emit) => _load(emit, countsView: true));
    on<LiveReplayClipsRequested>((event, emit) => _loadClips(emit));
    on<LiveReplayPublished>(_onPublished);
    on<LiveReplayRemoved>(_onRemoved);
    on<LiveReplayClipCreated>(_onClipCreated);
    on<LiveReplayClipPosted>(_onClipPosted);
    on<LiveReplayMessageShown>((event, emit) {
      emit(state.copyWith(clearMessage: true));
    });
  }

  final LiveSessionRepository _repository;
  final String liveId;

  /// [countsView] documents the cost: `GET /lives/:id/replay` increments the
  /// replay's `viewCount`, so it is never called speculatively.
  Future<void> _load(
    Emitter<LiveReplayState> emit, {
    required bool countsView,
  }) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final replay = await _repository.loadReplay(liveId);
      final clips = await _safeClips();
      if (isClosed) return;
      emit(state.copyWith(loading: false, replay: replay, clips: clips));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> _loadClips(Emitter<LiveReplayState> emit) async {
    try {
      final clips = await _repository.loadClips(liveId);
      if (isClosed) return;
      emit(state.copyWith(clips: clips));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(message: e.toString()));
    }
  }

  Future<List<LiveClip>> _safeClips() async {
    try {
      return await _repository.loadClips(liveId);
    } catch (_) {
      // Clips are secondary; a replay still opens without them.
      return state.clips;
    }
  }

  Future<void> _onPublished(
    LiveReplayPublished event,
    Emitter<LiveReplayState> emit,
  ) async {
    if (state.busy) return;
    emit(state.copyWith(busy: true, clearMessage: true));
    try {
      final replay = await _repository.publishReplay(
        liveId: liveId,
        replayUrl: event.replayUrl,
      );
      if (isClosed) return;
      emit(state.copyWith(busy: false, replay: replay));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(busy: false, message: e.toString()));
    }
  }

  Future<void> _onRemoved(
    LiveReplayRemoved event,
    Emitter<LiveReplayState> emit,
  ) async {
    if (state.busy) return;
    emit(state.copyWith(busy: true, clearMessage: true));
    try {
      await _repository.removeReplay(liveId);
      if (isClosed) return;
      // The removed state is read back rather than assumed, because the server
      // owns the lifecycle (REMOVED vs EXPIRED vs still READY).
      final replay = await _repository.loadReplay(liveId);
      if (isClosed) return;
      emit(state.copyWith(busy: false, replay: replay));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(busy: false, message: e.toString()));
    }
  }

  Future<void> _onClipCreated(
    LiveReplayClipCreated event,
    Emitter<LiveReplayState> emit,
  ) async {
    if (state.busy) return;
    emit(state.copyWith(busy: true, clearMessage: true, clearPosted: true));
    try {
      final clip = await _repository.createClip(
        liveId: liveId,
        startSeconds: event.startSeconds,
        endSeconds: event.endSeconds,
        title: event.title,
      );
      if (isClosed) return;
      final clips = await _safeClips();
      if (isClosed) return;
      emit(
        state.copyWith(
          busy: false,
          clips: clips.any((c) => c.id == clip.id) ? clips : [clip, ...clips],
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(busy: false, message: e.toString()));
    }
  }

  Future<void> _onClipPosted(
    LiveReplayClipPosted event,
    Emitter<LiveReplayState> emit,
  ) async {
    if (state.busy) return;
    emit(state.copyWith(busy: true, clearMessage: true, clearPosted: true));
    try {
      final clip = await _repository.postClip(
        liveId: liveId,
        clipId: event.clipId,
        description: event.description,
      );
      if (isClosed) return;
      final clips = await _safeClips();
      if (isClosed) return;
      emit(
        state.copyWith(
          busy: false,
          clips: clips,
          lastPostedClipId: clip.id,
          // Only a post id the server returned lets the screen offer to open
          // the post; a repeated publish is idempotent (alreadyPosted).
          lastPostId: clip.postId,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(busy: false, message: e.toString()));
    }
  }
}
