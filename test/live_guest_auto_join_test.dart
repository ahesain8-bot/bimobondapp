import 'dart:async';
import 'dart:convert';

import 'package:bimobondapp/app/auctions/data/datasources/auction_socket_service.dart';
import 'package:bimobondapp/core/models/live_media_hints.dart';
import 'package:bimobondapp/core/network/live_api_client.dart';
import 'package:bimobondapp/features/live/domain/entities/live_moderator.dart';
import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import 'package:bimobondapp/features/live_viewer/data/services/fake_livekit_service.dart';
import 'package:bimobondapp/features/live_viewer/data/services/fake_socket_service.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/comment_entity.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/gift_entity.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/live_entity.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/live_session_entity.dart';
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
import 'package:bimobondapp/features/live_viewer/domain/usecases/unban_viewer_usecase.dart';
import 'package:bimobondapp/features/live_viewer/domain/usecases/unmute_viewer_chat_usecase.dart';
import 'package:bimobondapp/features/live_viewer/presentation/bloc/live_viewer/live_viewer_bloc.dart';
import 'package:bimobondapp/features/live_viewer/presentation/bloc/live_viewer/live_viewer_event.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livekit_client/livekit_client.dart' show Room;

LiveEntity _audioLive() => LiveEntity(
  id: 'live-1',
  hostId: 'host-1',
  hostName: 'Host',
  title: 'Audio room',
  category: 'chat',
  startTime: DateTime.utc(2026, 9, 1),
  mediaMode: 'AUDIO',
  audioOnly: true,
);

GuestSummary _guest(String status) => GuestSummary(
  userId: 'viewer-1',
  displayName: 'Viewer',
  role: 'GUEST',
  status: status,
);

const _usableToken = GuestStageCredentials(
  token: 'guest-jwt',
  url: 'wss://example.invalid',
  role: 'GUEST',
);

class _LiveRepo implements LiveRepository {
  _LiveRepo(this.live);
  final LiveEntity live;

  // Activation now checks fresh room permissions before joining. Supply the
  // same unrestricted fixture; keep all stage/publish assertions unchanged.
  @override
  Future<Either<Failure, LiveEntity>> getLiveById(String liveId) async =>
      Right(live);

  @override
  Future<Either<Failure, JoinLiveResult>> joinLive(
    String liveId, {
    String? campaignId,
    String? trafficSource,
  }) async {
    return Right(
      JoinLiveResult(
        liveId: live.id,
        socketToken: 'socket',
        liveKitToken: 'viewer-jwt',
        liveKitUrl: 'wss://example.invalid',
        live: live,
      ),
    );
  }

  @override
  Future<Either<Failure, void>> leaveLive(String liveId) async =>
      const Right(null);

  @override
  Future<Either<Failure, List<LiveModerator>>> listModerators(
    String liveId,
  ) async => const Right([]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Comments implements CommentRepository {
  @override
  Future<Either<Failure, CommentBatch>> getComments({
    required String liveId,
    String? cursor,
    int limit = 20,
  }) async => const Right(CommentBatch(comments: []));

  @override
  Future<Either<Failure, CommentEntity>> sendComment({
    required String liveId,
    required String content,
    String? replyToUserId,
  }) async {
    return Right(
      CommentEntity(
        id: 'c-me',
        liveId: liveId,
        userId: 'viewer-1',
        username: 'Viewer',
        content: content,
        createdAt: DateTime.utc(2026, 9, 1),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Gifts implements GiftRepository {
  @override
  Future<Either<Failure, int>> getCoinBalance() async => const Right(0);

  @override
  Future<Either<Failure, List<GiftEntity>>> getAllGifts() async =>
      const Right([]);

  @override
  Future<Either<Failure, List<GiftLeaderboardEntry>>> getTopGifters(
    String liveId, {
    int limit = 10,
  }) async => const Right([]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Likes implements LikeRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Guests implements GuestRepository {
  List<GuestSummary> roster = const [];
  Either<Failure, GuestStageCredentials> tokenResult = const Right(
    _usableToken,
  );
  Completer<void>? tokenGate;
  var tokenCalls = 0;
  var leaveCalls = 0;

  @override
  Future<Either<Failure, List<GuestSummary>>> listGuests(String liveId) async {
    return Right(List<GuestSummary>.from(roster));
  }

  @override
  Future<Either<Failure, GuestStageCredentials>> refreshStageCredentials(
    String liveId,
  ) async {
    tokenCalls += 1;
    final gate = tokenGate;
    if (gate != null) await gate.future;
    return tokenResult;
  }

  @override
  Future<Either<Failure, void>> leaveStage(String liveId) async {
    leaveCalls += 1;
    roster = [_guest('LEFT')];
    return const Right(null);
  }

  @override
  Future<Either<Failure, GuestStageCredentials?>> requestSeat(
    String liveId,
  ) async => const Right(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _QuietSocket implements SocketService {
  final _controller = StreamController<SocketEvent>.broadcast();
  String? _liveId;

  @override
  Stream<SocketEvent> get events => _controller.stream;

  @override
  bool get isConnected => _liveId != null;

  @override
  String? get currentLiveId => _liveId;

  @override
  Future<void> connect({required String liveId, required String token}) async {
    _liveId = liveId;
  }

  @override
  Future<void> disconnect() async {
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

  void dispose() {
    _controller.close();
  }
}

class _Kit implements LiveKitService {
  final _stateController = StreamController<LiveKitConnectionState>.broadcast();
  var _publishing = false;
  var joinCalls = 0;
  var leaveCalls = 0;
  Completer<void>? joinGate;
  LiveMediaHints? lastJoinHints;

  @override
  LiveKitConnectionState get state => LiveKitConnectionState.connected;

  @override
  Stream<LiveKitConnectionState> get stateStream => _stateController.stream;

  @override
  Stream<LiveKitConnectionState> get battleStateStream =>
      const Stream<LiveKitConnectionState>.empty();

  @override
  String? get roomName => 'live-1';

  @override
  String? get streamUrl => null;

  @override
  Room? get room => null;

  @override
  Room? get battleRoom => null;

  @override
  LiveMediaHints? get mediaHints => lastJoinHints;

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
  bool get isPublishing => _publishing;

  @override
  Future<void> connect({
    required String url,
    required String token,
    required String roomName,
    String? mockStreamUrl,
    LiveMediaHints? mediaHints,
    bool keepBattleRoom = false,
  }) async {
    _stateController.add(LiveKitConnectionState.connected);
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> reconnect() async {}

  @override
  Future<void> prepareStage({bool audioOnly = false}) async {}

  @override
  Future<void> joinStage({
    required String url,
    required String token,
    required String roomName,
    LiveMediaHints? mediaHints,
  }) async {
    joinCalls += 1;
    lastJoinHints = mediaHints;
    final gate = joinGate;
    if (gate != null) await gate.future;
    _publishing = true;
  }

  @override
  Future<void> leaveStage() async {
    leaveCalls += 1;
    _publishing = false;
  }

  @override
  Future<void> setStageMicrophoneEnabled(bool enabled) async {}

  @override
  Future<void> setStageCameraEnabled(bool enabled) async {}

  void dispose() {
    _stateController.close();
  }
}

Future<void> _pumpUntil(
  bool Function() test, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!test()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('timed out waiting for condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _LiveRepo lives;
  late _Guests guests;
  late _Kit kit;
  late _QuietSocket socket;
  late AuctionSocketService gifts;
  late LiveViewerBloc bloc;

  setUp(() {
    lives = _LiveRepo(_audioLive());
    guests = _Guests();
    kit = _Kit();
    socket = _QuietSocket();
    gifts = AuctionSocketService();
    bloc = LiveViewerBloc(
      joinLiveUseCase: JoinLiveUseCase(lives),
      leaveLiveUseCase: LeaveLiveUseCase(lives),
      likeLiveUseCase: LikeLiveUseCase(_Likes()),
      giftSocketService: gifts,
      banViewerUseCase: BanViewerUseCase(lives),
      unbanViewerUseCase: UnbanViewerUseCase(lives),
      muteViewerChatUseCase: MuteViewerChatUseCase(lives),
      unmuteViewerChatUseCase: UnmuteViewerChatUseCase(lives),
      deleteCommentUseCase: DeleteCommentUseCase(_Comments()),
      liveRepository: lives,
      commentRepository: _Comments(),
      giftRepository: _Gifts(),
      likeRepository: _Likes(),
      socketService: socket,
      liveKitService: kit,
      guestRepository: guests,
      apiClient: LiveApiClient(
        httpClient: MockClient((request) async {
          final path = request.url.path;
          if (path.contains('battle') ||
              path.contains('leaderboard') ||
              path.contains('gifters')) {
            return http.Response('{}', 200);
          }
          return http.Response(jsonEncode({'id': 'viewer-1'}), 200);
        }),
        idTokenProvider: () async => 'mock',
      ),
    );
  });

  tearDown(() async {
    await bloc.close();
    kit.dispose();
    socket.dispose();
    gifts.dispose();
  });

  Future<void> openRoom() async {
    bloc.add(LiveViewerActivated(_audioLive()));
    await _pumpUntil(
      () =>
          bloc.state.session?.connectionState == LiveConnectionState.connected,
    );
    if (bloc.state.currentUserId != 'viewer-1') {
      bloc.add(const LiveViewerCommentSent('hi'));
      await _pumpUntil(() => bloc.state.currentUserId == 'viewer-1');
    }
  }

  test('ACTIVE roster does not set local isOnStage without publish', () async {
    guests.tokenResult = const Left(ServerFailure('not active yet'));
    await openRoom();
    expect(bloc.state.isOnStage, isFalse);

    guests.roster = [_guest('ACTIVE')];
    bloc.add(const LiveViewerGuestsRefreshed());
    await _pumpUntil(() => guests.tokenCalls >= 1);

    expect(bloc.state.guests.single.status, 'ACTIVE');
    expect(bloc.state.isOnStage, isFalse);
    expect(kit.joinCalls, 0);
    expect(kit.isPublishing, isFalse);
  });

  test('ACTIVE and not publishing fetches token and joinStage', () async {
    await openRoom();
    guests.roster = [_guest('ACTIVE')];
    bloc.add(const LiveViewerGuestsRefreshed());
    await _pumpUntil(() => bloc.state.isOnStage && kit.isPublishing);

    expect(guests.tokenCalls, 1);
    expect(kit.joinCalls, 1);
    expect(kit.lastJoinHints?.audioOnly, isTrue);
    expect(bloc.state.isOnStage, isTrue);
    expect(bloc.state.moderationBanner, 'أصبحت متحدثاً');
  });

  test('isOnStage becomes true only after joinStage succeeds', () async {
    kit.joinGate = Completer<void>();
    await openRoom();
    guests.roster = [_guest('ACTIVE')];
    bloc.add(const LiveViewerGuestsRefreshed());
    await _pumpUntil(() => kit.joinCalls == 1);

    expect(bloc.state.isOnStage, isFalse);
    expect(kit.isPublishing, isFalse);

    kit.joinGate!.complete();
    await _pumpUntil(() => bloc.state.isOnStage);

    expect(bloc.state.isOnStage, isTrue);
    expect(kit.isPublishing, isTrue);
    expect(kit.joinCalls, 1);
  });

  test('duplicate ACTIVE refreshes start only one join', () async {
    guests.tokenGate = Completer<void>();
    await openRoom();
    guests.roster = [_guest('ACTIVE')];
    bloc.add(const LiveViewerGuestsRefreshed());
    await _pumpUntil(() => guests.tokenCalls == 1);
    bloc.add(const LiveViewerGuestsRefreshed());
    await Future<void>.delayed(const Duration(milliseconds: 40));
    guests.tokenGate!.complete();
    await _pumpUntil(() => bloc.state.isOnStage);

    expect(guests.tokenCalls, 1);
    expect(kit.joinCalls, 1);
  });

  test('kick on the roster clears local stage and unpublishes', () async {
    await openRoom();
    guests.roster = [_guest('ACTIVE')];
    bloc.add(const LiveViewerGuestsRefreshed());
    await _pumpUntil(() => bloc.state.isOnStage);

    guests.roster = [_guest('KICKED')];
    bloc.add(const LiveViewerGuestsRefreshed());
    await _pumpUntil(() => !bloc.state.isOnStage);

    expect(bloc.state.isOnStage, isFalse);
    expect(kit.leaveCalls, 1);
    expect(kit.isPublishing, isFalse);
  });

  test('reject socket event clears stage without publishing', () async {
    await openRoom();
    expect(bloc.state.isOnStage, isFalse);
    bloc.add(
      LiveViewerSocketEventReceived(
        LiveGuestUpdateEvent(
          liveId: 'live-1',
          updateType: 'rejected',
          guestUserId: 'viewer-1',
          timestamp: DateTime.now(),
        ),
      ),
    );
    await _pumpUntil(
      () => bloc.state.moderationBanner == 'رفض المضيف طلب رفع اليد',
    );
    expect(bloc.state.isOnStage, isFalse);
    expect(kit.joinCalls, 0);
  });

  test('leave stage clears local isOnStage', () async {
    await openRoom();
    guests.roster = [_guest('ACTIVE')];
    bloc.add(const LiveViewerGuestsRefreshed());
    await _pumpUntil(() => bloc.state.isOnStage);

    bloc.add(const LiveViewerLeftStage());
    await _pumpUntil(() => !bloc.state.isOnStage && guests.leaveCalls == 1);

    expect(bloc.state.isOnStage, isFalse);
    expect(kit.isPublishing, isFalse);
  });
}
