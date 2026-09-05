import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' show Room;

import 'package:bimobondapp/app/auctions/data/datasources/auction_socket_service.dart';
import 'package:bimobondapp/core/models/live_media_hints.dart';
import 'package:bimobondapp/core/network/live_api_client.dart';
import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import 'package:bimobondapp/features/live_viewer/data/services/fake_livekit_service.dart';
import 'package:bimobondapp/features/live_viewer/data/services/live_session_diagnostics.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/live_entity.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/live_session_entity.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/comment_entity.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/gift_entity.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/socket_event.dart';
import 'package:bimobondapp/features/live_viewer/domain/repositories/comment_repository.dart';
import 'package:bimobondapp/features/live_viewer/domain/repositories/gift_repository.dart';
import 'package:bimobondapp/features/live_viewer/domain/repositories/guest_repository.dart';
import 'package:bimobondapp/features/live_viewer/domain/repositories/like_repository.dart';
import 'package:bimobondapp/features/live_viewer/domain/repositories/live_repository.dart';
import 'package:bimobondapp/features/live_viewer/domain/usecases/ban_viewer_usecase.dart';
import 'package:bimobondapp/features/live_viewer/domain/usecases/delete_comment_usecase.dart';
import 'package:bimobondapp/features/live_viewer/domain/usecases/join_live_usecase.dart';
import 'package:bimobondapp/features/live_viewer/domain/usecases/leave_live_usecase.dart';
import 'package:bimobondapp/features/live_viewer/domain/usecases/like_live_usecase.dart';
import 'package:bimobondapp/features/live_viewer/domain/usecases/mute_viewer_chat_usecase.dart';
import 'package:bimobondapp/features/live_viewer/domain/usecases/pin_comment_usecase.dart';
import 'package:bimobondapp/features/live_viewer/domain/usecases/unban_viewer_usecase.dart';
import 'package:bimobondapp/features/live_viewer/domain/usecases/unmute_viewer_chat_usecase.dart';
import 'package:bimobondapp/features/live_viewer/data/services/fake_socket_service.dart'
    show SocketService;
import 'package:bimobondapp/features/live_viewer/presentation/bloc/live_viewer/live_viewer_bloc.dart';
import 'package:bimobondapp/features/live_viewer/presentation/bloc/live_viewer/live_viewer_event.dart';

/// Lifecycle and race-condition coverage for the viewer session.
///
/// Everything here is about *ordering*: which room ends up connected, which
/// late callback is allowed to change state, and which disconnect is worth
/// reacting to. The media stack itself is replaced by [_RecordingLiveKit] so
/// the tests assert on the sequence of operations rather than on WebRTC.
void main() {
  late _RecordingLiveKit liveKit;
  late _StubLiveRepository liveRepository;
  late LiveViewerBloc bloc;

  LiveEntity live(String id, {LiveStatus status = LiveStatus.live}) {
    return LiveEntity(
      id: id,
      hostId: 'host-$id',
      hostName: 'Host $id',
      title: 'Live $id',
      category: 'General',
      startTime: DateTime(2026, 1, 1),
      status: status,
      isLive: status == LiveStatus.live,
    );
  }

  setUp(() {
    liveKit = _RecordingLiveKit();
    liveRepository = _StubLiveRepository();
    bloc = LiveViewerBloc(
      joinLiveUseCase: JoinLiveUseCase(liveRepository),
      leaveLiveUseCase: LeaveLiveUseCase(liveRepository),
      likeLiveUseCase: LikeLiveUseCase(_StubLikeRepository()),
      giftSocketService: AuctionSocketService(),
      banViewerUseCase: BanViewerUseCase(liveRepository),
      unbanViewerUseCase: UnbanViewerUseCase(liveRepository),
      muteViewerChatUseCase: MuteViewerChatUseCase(liveRepository),
      unmuteViewerChatUseCase: UnmuteViewerChatUseCase(liveRepository),
      deleteCommentUseCase: DeleteCommentUseCase(_StubCommentRepository()),
      pinCommentUseCase: PinCommentUseCase(_StubCommentRepository()),
      liveRepository: liveRepository,
      commentRepository: _StubCommentRepository(),
      giftRepository: _StubGiftRepository(),
      likeRepository: _StubLikeRepository(),
      socketService: _StubSocketService(),
      liveKitService: liveKit,
      apiClient: LiveApiClient(),
      guestRepository: _StubGuestRepository(),
    );
  });

  tearDown(() async => bloc.close());

  /// Lets every queued microtask, timer and the fake's connect delay run.
  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  group('activation', () {
    test('connects the requested room once', () async {
      bloc.add(LiveViewerActivated(live('a')));
      await settle();

      expect(liveKit.connectedRooms, ['a']);
      expect(bloc.requestedLiveId, 'a');
      expect(bloc.activeLiveId, 'a');
    });

    test('re-activating the live already on screen is a no-op', () async {
      bloc.add(LiveViewerActivated(live('a')));
      await settle();
      bloc.add(LiveViewerActivated(live('a')));
      await settle();

      expect(liveKit.connectedRooms, ['a']);
    });

    test('a rapid swipe leaves only the newest room connected', () async {
      bloc
        ..add(LiveViewerActivated(live('a')))
        ..add(LiveViewerActivated(live('b')))
        ..add(LiveViewerActivated(live('c')));
      await settle();

      expect(bloc.requestedLiveId, 'c');
      expect(bloc.activeLiveId, 'c');
      // Superseded activations must abandon their work instead of racing the
      // one the viewer is actually waiting for.
      expect(liveKit.connectedRooms.last, 'c');
      expect(liveKit.overlappingConnects, 0);
    });

    test('an ended live never opens a room and releases the old one', () async {
      bloc.add(LiveViewerActivated(live('a')));
      await settle();
      bloc.add(LiveViewerActivated(live('b', status: LiveStatus.ended)));
      await settle();

      expect(liveKit.connectedRooms, ['a']);
      expect(liveKit.disconnectCount, 1);
      expect(
        bloc.state.connectionState,
        LiveConnectionState.liveEnded,
      );
    });

    test('a failed join releases the previous room', () async {
      bloc.add(LiveViewerActivated(live('a')));
      await settle();
      liveRepository.failNextJoin = true;
      bloc.add(LiveViewerActivated(live('b')));
      await settle();

      expect(liveKit.connectedRooms, ['a']);
      expect(liveKit.disconnectCount, 1);
      expect(bloc.state.connectionState, LiveConnectionState.error);
    });
  });

  group('deactivation', () {
    test('a page disposed after the swipe cannot close the new room', () async {
      bloc.add(LiveViewerActivated(live('a')));
      await settle();
      bloc.add(LiveViewerActivated(live('b')));
      await settle();

      // LiveRoomPage('a') leaves the PageView cache window here.
      bloc.add(const LiveViewerDeactivated(liveId: 'a'));
      await settle();

      expect(bloc.requestedLiveId, 'b');
      expect(bloc.activeLiveId, 'b');
      expect(liveKit.disconnectCount, 0);
    });

    test('screen-level teardown always applies', () async {
      bloc.add(LiveViewerActivated(live('a')));
      await settle();
      bloc.add(const LiveViewerDeactivated());
      await settle();

      expect(bloc.requestedLiveId, isNull);
      expect(bloc.activeLiveId, isNull);
      expect(liveKit.disconnectCount, 1);
      expect(bloc.state.session, isNull);
    });

    test('leaving while a connect is pending still tears down', () async {
      liveKit.holdConnect = true;
      bloc.add(LiveViewerActivated(live('a')));
      await settle();
      bloc.add(const LiveViewerDeactivated());
      liveKit.releaseConnect();
      await settle();

      expect(bloc.activeLiveId, isNull);
      expect(liveKit.disconnectCount, greaterThanOrEqualTo(1));
    });
  });

  group('disconnect policy', () {
    Future<void> activate(String id) async {
      bloc.add(LiveViewerActivated(live(id)));
      await settle();
    }

    test('a client-initiated disconnect is not a failure', () async {
      await activate('a');
      liveKit.emit(
        LiveKitConnectionState.disconnected,
        cause: LiveKitDisconnectCause.clientInitiated,
      );
      await settle();

      expect(bloc.state.connectionState, LiveConnectionState.connected);
      expect(liveRepository.joinCount, 1);
    });

    test('a closed room ends the live instead of retrying', () async {
      await activate('a');
      liveKit.emit(
        LiveKitConnectionState.disconnected,
        cause: LiveKitDisconnectCause.roomClosed,
      );
      await settle();

      expect(bloc.state.connectionState, LiveConnectionState.liveEnded);
      expect(liveRepository.joinCount, 1);
    });

    test('a duplicate identity is terminal and explained', () async {
      await activate('a');
      liveKit.emit(
        LiveKitConnectionState.disconnected,
        cause: LiveKitDisconnectCause.duplicateIdentity,
      );
      await settle();

      expect(bloc.state.connectionState, LiveConnectionState.error);
      expect(bloc.state.session?.errorMessage, isNotNull);
      expect(liveRepository.joinCount, 1);
    });

    test('a network drop re-joins with fresh credentials', () async {
      await activate('a');
      liveKit.emit(
        LiveKitConnectionState.disconnected,
        cause: LiveKitDisconnectCause.network,
      );
      await settle();

      expect(liveRepository.joinCount, 2);
      expect(liveKit.connectedRooms, ['a', 'a']);
      expect(bloc.state.connectionState, LiveConnectionState.connected);
    });

    test('a native reconnect is surfaced without rebuilding the room',
        () async {
      await activate('a');
      liveKit.emit(LiveKitConnectionState.reconnecting);
      await settle();

      expect(bloc.state.connectionState, LiveConnectionState.reconnecting);
      expect(liveRepository.joinCount, 1);
      expect(liveKit.connectedRooms, ['a']);
    });

    test('a recovery in flight cannot resurrect the live left behind',
        () async {
      await activate('a');

      // Park the recovery's re-join, swipe to another live, then let the
      // stale re-join finish. It must recognise that it belongs to a session
      // the viewer has already replaced and connect nothing.
      liveRepository.holdJoinFor = 'a';
      liveKit.emit(
        LiveKitConnectionState.disconnected,
        cause: LiveKitDisconnectCause.network,
      );
      await settle();

      bloc.add(LiveViewerActivated(live('b')));
      await settle();
      expect(bloc.activeLiveId, 'b');

      liveRepository.releaseJoin();
      await settle();

      expect(bloc.activeLiveId, 'b');
      expect(liveKit.connectedRooms.last, 'b');
      expect(bloc.state.live?.id, 'b');
    });
  });

  group('disconnect cause classification', () {
    test('only transport-level causes are worth retrying', () {
      expect(LiveKitDisconnectCause.network.isRecoverable, isTrue);
      expect(LiveKitDisconnectCause.mediaStalled.isRecoverable, isTrue);
      expect(LiveKitDisconnectCause.unknown.isRecoverable, isTrue);
      expect(LiveKitDisconnectCause.clientInitiated.isRecoverable, isFalse);
      expect(LiveKitDisconnectCause.roomClosed.isRecoverable, isFalse);
      expect(LiveKitDisconnectCause.duplicateIdentity.isRecoverable, isFalse);
      expect(LiveKitDisconnectCause.unauthorized.isRecoverable, isFalse);
    });

    test('the live itself is over only when the room is gone', () {
      expect(LiveKitDisconnectCause.roomClosed.isTerminalForLive, isTrue);
      expect(
        LiveKitDisconnectCause.duplicateIdentity.isTerminalForLive,
        isTrue,
      );
      expect(LiveKitDisconnectCause.network.isTerminalForLive, isFalse);
    });
  });
}

/// A [LiveKitService] that records the order of operations and lets a test
/// hold a connect open to reproduce "the viewer left while connecting".
class _RecordingLiveKit implements LiveKitService {
  final _controller = StreamController<LiveKitSessionUpdate>.broadcast();
  final connectedRooms = <String>[];

  var disconnectCount = 0;
  var overlappingConnects = 0;
  var holdConnect = false;

  int _generation = 0;
  int _inFlight = 0;
  LiveKitConnectionState _state = LiveKitConnectionState.disconnected;
  String? _roomName;
  Completer<void>? _gate;

  void releaseConnect() {
    holdConnect = false;
    _gate?.complete();
    _gate = null;
  }

  void emit(
    LiveKitConnectionState state, {
    LiveKitDisconnectCause? cause,
  }) {
    _state = state;
    _controller.add(
      LiveKitSessionUpdate(
        state: state,
        generation: _generation,
        roomName: _roomName,
        cause: cause,
      ),
    );
  }

  @override
  Future<void> connect({
    required String url,
    required String token,
    required String roomName,
    String? mockStreamUrl,
    LiveMediaHints? mediaHints,
  }) async {
    _generation++;
    _roomName = roomName;
    emit(LiveKitConnectionState.connecting);
    if (_inFlight > 0) overlappingConnects++;
    _inFlight++;
    try {
      if (holdConnect) {
        final gate = _gate ??= Completer<void>();
        await gate.future;
      } else {
        await Future<void>.delayed(Duration.zero);
      }
      connectedRooms.add(roomName);
      emit(LiveKitConnectionState.connected);
    } finally {
      _inFlight--;
    }
  }

  @override
  Future<void> disconnect() async {
    disconnectCount++;
    _generation++;
    _roomName = null;
    emit(
      LiveKitConnectionState.disconnected,
      cause: LiveKitDisconnectCause.clientInitiated,
    );
  }

  @override
  LiveKitConnectionState get state => _state;

  @override
  Stream<LiveKitConnectionState> get stateStream =>
      _controller.stream.map((update) => update.state);

  @override
  Stream<LiveKitSessionUpdate> get sessionStream => _controller.stream;

  @override
  Stream<LiveKitConnectionState> get battleStateStream =>
      const Stream<LiveKitConnectionState>.empty();

  @override
  String? get roomName => _roomName;

  @override
  String? get streamUrl => null;

  @override
  LiveMediaHints? get mediaHints => null;

  @override
  Room? get room => null;

  @override
  Room? get battleRoom => null;

  @override
  bool get isPublishing => false;

  @override
  Future<void> reconnect() async {}

  @override
  Future<void> connectBattle({
    required String url,
    required String token,
    required String roomName,
    LiveMediaHints? mediaHints,
  }) async {}

  @override
  Future<void> disconnectBattle() async {}

  @override
  Future<void> prepareStage() async {}

  @override
  Future<void> joinStage({
    required String url,
    required String token,
    required String roomName,
    LiveMediaHints? mediaHints,
  }) async {}

  @override
  Future<void> leaveStage() async {}

  @override
  Future<void> setStageMicrophoneEnabled(bool enabled) async {}

  @override
  Future<void> setStageCameraEnabled(bool enabled) async {}
}

class _StubLiveRepository implements LiveRepository {
  var joinCount = 0;
  var failNextJoin = false;

  /// Parks `joinLive` for this live id until [releaseJoin] is called.
  String? holdJoinFor;
  Completer<void>? _gate;

  void releaseJoin() {
    holdJoinFor = null;
    _gate?.complete();
    _gate = null;
  }

  @override
  Future<Either<Failure, JoinLiveResult>> joinLive(String liveId) async {
    joinCount++;
    if (holdJoinFor == liveId) {
      await (_gate ??= Completer<void>()).future;
    }
    if (failNextJoin) {
      failNextJoin = false;
      return const Left(ServerFailure('join rejected'));
    }
    return Right(
      JoinLiveResult(
        liveId: liveId,
        socketToken: 'socket',
        liveKitToken: 'token',
        liveKitUrl: 'wss://livekit.test',
        live: LiveEntity(
          id: liveId,
          hostId: 'host-$liveId',
          hostName: 'Host $liveId',
          title: 'Live $liveId',
          category: 'General',
          startTime: DateTime(2026, 1, 1),
        ),
      ),
    );
  }

  @override
  Future<Either<Failure, void>> leaveLive(String liveId) async =>
      const Right(null);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubCommentRepository implements CommentRepository {
  @override
  Future<Either<Failure, CommentBatch>> getComments({
    required String liveId,
    String? cursor,
    int limit = 20,
  }) async => const Right(CommentBatch(comments: <CommentEntity>[]));

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A socket that answers immediately.
///
/// [FakeSocketService] simulates a live room with timers and multi-hundred
/// millisecond delays, which would make these ordering tests depend on wall
/// clock time rather than on the sequence being asserted.
class _StubSocketService implements SocketService {
  final _controller = StreamController<SocketEvent>.broadcast();
  var _connected = false;
  String? _liveId;

  @override
  Stream<SocketEvent> get events => _controller.stream;

  @override
  bool get isConnected => _connected;

  @override
  String? get currentLiveId => _liveId;

  @override
  Future<void> connect({
    required String liveId,
    required String token,
    String? userId,
    bool includeUserIdInLiveJoin = false,
  }) async {
    _liveId = liveId;
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _liveId = null;
  }

  @override
  Future<void> emitComment(CommentEntity comment) async {}

  @override
  Future<void> emitLike({required int likeCount, int delta = 1}) async {}

  @override
  Future<void> emitGift(GiftSentEntity gift) async {}

  @override
  void simulateNetworkLoss() {}
}

class _StubGiftRepository implements GiftRepository {
  @override
  Future<Either<Failure, int>> getCoinBalance() async => const Right(0);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubLikeRepository implements LikeRepository {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubGuestRepository implements GuestRepository {
  @override
  Future<Either<Failure, List<GuestSummary>>> listGuests(String liveId) async =>
      const Right(<GuestSummary>[]);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
