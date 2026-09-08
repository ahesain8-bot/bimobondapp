import 'dart:async';
import 'dart:convert';

import 'package:bimobondapp/app/auctions/data/datasources/auction_socket_service.dart';
import 'package:bimobondapp/core/models/live_media_hints.dart';
import 'package:bimobondapp/core/network/live_api_client.dart';
import 'package:bimobondapp/features/live/domain/entities/live_moderator.dart';
import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import 'package:bimobondapp/features/live_viewer/data/mappers/live_mapper.dart';
import 'package:bimobondapp/features/live_viewer/data/services/fake_livekit_service.dart';
import 'package:bimobondapp/features/live_viewer/data/services/fake_socket_service.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/comment_entity.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/gift_entity.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/live_entity.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/live_session_entity.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/socket_event.dart';
import 'package:bimobondapp/features/live_viewer/domain/live_chat_rules.dart';
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
import 'package:bimobondapp/features/live_viewer/presentation/widgets/comments_section.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livekit_client/livekit_client.dart' show Room;

CommentEntity _comment({
  String id = 'c1',
  String userId = 'other-1',
  String content = 'hello',
}) {
  return CommentEntity(
    id: id,
    liveId: 'live-1',
    userId: userId,
    username: 'Other',
    content: content,
    createdAt: DateTime.utc(2026, 9, 1),
  );
}

LiveEntity _live({
  Map<String, dynamic>? metadata,
  bool isFollowing = false,
}) {
  return LiveEntity(
    id: 'live-1',
    hostId: 'host-1',
    hostName: 'Host',
    title: 'Live',
    category: 'General',
    startTime: DateTime.utc(2026, 9, 1),
    isFollowing: isFollowing,
    metadata: metadata,
  );
}

Future<void> _pumpUntil(bool Function() condition) async {
  for (var i = 0; i < 1000 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _LiveRepo implements LiveRepository {
  _LiveRepo(this.live);
  LiveEntity live;

  @override
  Future<Either<Failure, JoinLiveResult>> joinLive(
    String liveId, {
    String? campaignId,
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
  List<CommentEntity> seed = const [];
  Either<Failure, CommentEntity>? sendResult;
  Either<Failure, void> deleteResult = const Right(null);
  final sent = <String>[];
  var deleteCalls = 0;

  @override
  Future<Either<Failure, CommentBatch>> getComments({
    required String liveId,
    String? cursor,
    int limit = 20,
  }) async => Right(CommentBatch(comments: List.of(seed)));

  @override
  Future<Either<Failure, CommentEntity>> sendComment({
    required String liveId,
    required String content,
    String? replyToUserId,
  }) async {
    sent.add(content);
    final override = sendResult;
    if (override != null) return override;
    return Right(
      CommentEntity(
        id: 'c-me-${sent.length}',
        liveId: liveId,
        userId: 'viewer-1',
        username: 'Viewer',
        content: content,
        createdAt: DateTime.utc(2026, 9, 1),
      ),
    );
  }

  @override
  Future<Either<Failure, void>> deleteComment(
    String commentId, {
    String? liveId,
  }) async {
    deleteCalls += 1;
    return deleteResult;
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
  @override
  Future<Either<Failure, List<GuestSummary>>> listGuests(String liveId) async =>
      const Right([]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _QuietSocket implements SocketService {
  final _controller = StreamController<SocketEvent>.broadcast();

  @override
  Stream<SocketEvent> get events => _controller.stream;

  @override
  bool get isConnected => true;

  @override
  String? get currentLiveId => 'live-1';

  @override
  Future<void> connect({required String liveId, required String token}) async {}

  @override
  Future<void> disconnect() async {}

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
  LiveMediaHints? get mediaHints => null;

  @override
  bool get isPublishing => false;

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
  }) async {}

  @override
  Future<void> leaveStage() async {}

  @override
  Future<void> setStageMicrophoneEnabled(bool enabled) async {}

  @override
  Future<void> setStageCameraEnabled(bool enabled) async {}

  @override
  Future<void> connectBattle({
    required String url,
    required String token,
    required String roomName,
    LiveMediaHints? mediaHints,
  }) async {}

  @override
  Future<void> disconnectBattle() async {}

  void dispose() {
    _stateController.close();
  }
}

void main() {
  group('LiveChatRules', () {
    test('applies chat_rules_updated payload', () {
      const current = LiveChatRules();
      final next = current.mergeChatRules({
        'chatMode': 'FOLLOWERS',
        'slowModeSeconds': 8,
        'blockedKeywords': ['Spam', 'scam'],
      });
      expect(next.chatMode, 'FOLLOWERS');
      expect(next.slowModeSeconds, 8);
      expect(next.blockedKeywords, ['Spam', 'scam']);
      final meta = next.applyToMetadata({'layout': 'PANEL'});
      expect(meta['chatMode'], 'FOLLOWERS');
      expect(meta['slowModeSeconds'], 8);
      expect(meta['blockedKeywords'], ['Spam', 'scam']);
      expect(meta['layout'], 'PANEL');
    });

    test('blocked keywords are case-insensitive substring matches', () {
      const rules = LiveChatRules(blockedKeywords: ['BadWord']);
      expect(rules.containsBlockedKeyword('this BADWORD is here'), isTrue);
      expect(rules.containsBlockedKeyword('clean text'), isFalse);
    });

    test('FOLLOWERS disables send when not following', () {
      const rules = LiveChatRules(chatMode: 'FOLLOWERS');
      final blocked = rules.composerStatus(
        chatMuted: false,
        isHost: false,
        isFollowing: false,
        isFanClubMember: null,
      );
      expect(blocked.canSend, isFalse);
      expect(blocked.block, LiveChatComposerBlock.followers);
      final allowed = rules.composerStatus(
        chatMuted: false,
        isHost: false,
        isFollowing: true,
        isFanClubMember: null,
      );
      expect(allowed.canSend, isTrue);
    });

    test('SUBSCRIBERS does not guess when membership is unknown', () {
      const rules = LiveChatRules(chatMode: 'SUBSCRIBERS');
      final unknown = rules.composerStatus(
        chatMuted: false,
        isHost: false,
        isFollowing: true,
        isFanClubMember: null,
      );
      expect(unknown.canSend, isTrue);
      expect(unknown.block, LiveChatComposerBlock.none);
      final knownFalse = rules.composerStatus(
        chatMuted: false,
        isHost: false,
        isFollowing: true,
        isFanClubMember: false,
      );
      expect(knownFalse.canSend, isFalse);
      expect(knownFalse.block, LiveChatComposerBlock.subscribers);
    });

    test('slow mode remaining seconds disable send', () {
      const rules = LiveChatRules(slowModeSeconds: 5);
      final now = DateTime.utc(2026, 9, 1, 12);
      final status = rules.composerStatus(
        chatMuted: false,
        isHost: false,
        isFollowing: true,
        isFanClubMember: null,
        slowModeUntil: now.add(const Duration(seconds: 4)),
        now: now,
      );
      expect(status.canSend, isFalse);
      expect(status.block, LiveChatComposerBlock.slowMode);
      expect(status.slowModeRemainingSeconds, 4);
    });

    test('host is exempt from chat rules', () {
      const rules = LiveChatRules(
        chatMode: 'FOLLOWERS',
        slowModeSeconds: 10,
      );
      final status = rules.composerStatus(
        chatMuted: false,
        isHost: true,
        isFollowing: false,
        isFanClubMember: false,
        slowModeUntil: DateTime.utc(2099),
      );
      expect(status.canSend, isTrue);
    });

    test('does not invent mute when join payload omits it', () {
      expect(LiveChatRules.chatMutedFlag(const {}), isNull);
      expect(LiveChatRules.chatMutedFlag({'chatMuted': true}), isTrue);
      expect(LiveChatRules.chatMutedFlag({'isChatMuted': false}), isFalse);
    });
  });

  group('LiveCommentSendFailure', () {
    test('maps muted / slow / followers / subscribers / keyword copy', () {
      expect(
        LiveCommentSendFailure.parse(
          const ServerFailure('Chat is muted'),
        ).kind,
        LiveCommentSendFailureKind.muted,
      );
      expect(
        LiveCommentSendFailure.parse(
          const ServerFailure('Slow mode is active'),
        ).kind,
        LiveCommentSendFailureKind.slowMode,
      );
      expect(
        LiveCommentSendFailure.parse(
          const ServerFailure('Followers only chat'),
        ).kind,
        LiveCommentSendFailureKind.followers,
      );
      expect(
        LiveCommentSendFailure.parse(
          const ServerFailure('Fan club subscribers only'),
        ).kind,
        LiveCommentSendFailureKind.subscribers,
      );
      expect(
        LiveCommentSendFailure.parse(
          const ServerFailure('Blocked keyword in comment'),
        ).kind,
        LiveCommentSendFailureKind.blockedKeyword,
      );
    });

    test('unwraps Failed to send comment wrapping without inventing codes', () {
      final parsed = LiveCommentSendFailure.parse(
        const ServerFailure(
          'Failed to send comment: ApiException: Too fast (statusCode: 403)',
        ),
      );
      expect(parsed.kind, LiveCommentSendFailureKind.generic);
      expect(parsed.serverMessage, 'Too fast');
    });
  });

  group('LiveChatModerationAccess', () {
    test('normal viewers cannot open moderation controls', () {
      expect(
        LiveChatModerationAccess.canShowMenu(
          currentUserId: 'viewer-1',
          hostId: 'host-1',
          moderatorIds: const [],
          commentUserId: 'other-1',
        ),
        isFalse,
      );
    });

    test('host and mods can moderate other comments', () {
      expect(
        LiveChatModerationAccess.canShowMenu(
          currentUserId: 'host-1',
          hostId: 'host-1',
          moderatorIds: const [],
          commentUserId: 'other-1',
        ),
        isTrue,
      );
      expect(
        LiveChatModerationAccess.canShowMenu(
          currentUserId: 'mod-1',
          hostId: 'host-1',
          moderatorIds: const ['mod-1'],
          commentUserId: 'other-1',
        ),
        isTrue,
      );
    });
  });

  group('LiveMapper mute flag', () {
    test('copies chatMuted only when the live JSON exposes it', () {
      final withFlag = LiveMapper.fromJson({
        'id': 'live-1',
        'status': 'LIVE',
        'chatMuted': true,
        'user': {'id': 'h1', 'fullName': 'Host'},
        'startedAt': '2026-09-05T12:00:00.000Z',
      });
      expect(withFlag.metadata?['chatMuted'], isTrue);

      final withoutFlag = LiveMapper.fromJson({
        'id': 'live-1',
        'status': 'LIVE',
        'user': {'id': 'h1', 'fullName': 'Host'},
        'startedAt': '2026-09-05T12:00:00.000Z',
      });
      expect(withoutFlag.metadata?.containsKey('chatMuted'), isFalse);
    });
  });

  group('LiveViewerBloc chat rules', () {
    late _LiveRepo lives;
    late _Comments comments;
    late _Kit kit;
    late _QuietSocket socket;
    late AuctionSocketService gifts;
    late LiveViewerBloc bloc;
    var blocReady = false;

    LiveViewerBloc buildBloc(LiveEntity live) {
      lives = _LiveRepo(live);
      comments = _Comments();
      kit = _Kit();
      socket = _QuietSocket();
      gifts = AuctionSocketService();
      return LiveViewerBloc(
        joinLiveUseCase: JoinLiveUseCase(lives),
        leaveLiveUseCase: LeaveLiveUseCase(lives),
        likeLiveUseCase: LikeLiveUseCase(_Likes()),
        giftSocketService: gifts,
        banViewerUseCase: BanViewerUseCase(lives),
        unbanViewerUseCase: UnbanViewerUseCase(lives),
        muteViewerChatUseCase: MuteViewerChatUseCase(lives),
        unmuteViewerChatUseCase: UnmuteViewerChatUseCase(lives),
        deleteCommentUseCase: DeleteCommentUseCase(comments),
        liveRepository: lives,
        commentRepository: comments,
        giftRepository: _Gifts(),
        likeRepository: _Likes(),
        socketService: socket,
        liveKitService: kit,
        guestRepository: _Guests(),
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
    }

    Future<void> openRoom(LiveEntity live) async {
      bloc = buildBloc(live);
      blocReady = true;
      bloc.add(LiveViewerActivated(live));
      await _pumpUntil(
        () =>
            bloc.state.session?.connectionState ==
            LiveConnectionState.connected,
      );
    }

    tearDown(() async {
      if (blocReady) {
        await bloc.close();
        kit.dispose();
        socket.dispose();
        gifts.dispose();
      }
      blocReady = false;
    });

    test('chat_rules_updated persists viewer chatMode/slowMode/keywords', () async {
      await openRoom(_live());
      bloc.add(
        LiveViewerSocketEventReceived(
          LiveModerationEvent(
            liveId: 'live-1',
            moderationType: 'chat_rules_updated',
            chatRules: const {
              'chatMode': 'FOLLOWERS',
              'slowModeSeconds': 7,
              'blockedKeywords': ['x'],
            },
            timestamp: DateTime.utc(2026, 9, 1),
          ),
        ),
      );
      await _pumpUntil(
        () => bloc.state.chatRules.chatMode == 'FOLLOWERS',
      );
      expect(bloc.state.chatRules.chatMode, 'FOLLOWERS');
      expect(bloc.state.chatRules.slowModeSeconds, 7);
      expect(bloc.state.chatRules.blockedKeywords, ['x']);
      expect(bloc.state.live?.metadata?['chatMode'], 'FOLLOWERS');
      expect(bloc.state.chatNotice?.kind, LiveChatNoticeKind.rulesUpdated);
      expect(
        bloc.state.chatNotice?.ruleChanges,
        [
          const LiveChatRuleChange(
            LiveChatRuleChangeKind.slowModeEnabled,
            seconds: 7,
          ),
          const LiveChatRuleChange(LiveChatRuleChangeKind.chatFollowers),
          const LiveChatRuleChange(LiveChatRuleChangeKind.blockedKeywords),
        ],
      );
    });

    Future<void> applyRules(Map<String, dynamic> chatRules) async {
      final before = bloc.state.chatNotice;
      bloc.add(
        LiveViewerSocketEventReceived(
          LiveModerationEvent(
            liveId: 'live-1',
            moderationType: 'chat_rules_updated',
            chatRules: chatRules,
            timestamp: DateTime.utc(2026, 9, 1),
          ),
        ),
      );
      await _pumpUntil(() => !identical(bloc.state.chatNotice, before));
    }

    test('slow mode enabled notice', () async {
      await openRoom(_live());
      await applyRules({'slowModeSeconds': 10});
      expect(bloc.state.chatRules.slowModeSeconds, 10);
      expect(bloc.state.chatNotice?.ruleChanges, [
        const LiveChatRuleChange(
          LiveChatRuleChangeKind.slowModeEnabled,
          seconds: 10,
        ),
      ]);
    });

    test('slow mode changed notice', () async {
      await openRoom(_live(metadata: const {'slowModeSeconds': 5}));
      await applyRules({'slowModeSeconds': 15});
      expect(bloc.state.chatRules.slowModeSeconds, 15);
      expect(bloc.state.chatNotice?.ruleChanges, [
        const LiveChatRuleChange(
          LiveChatRuleChangeKind.slowModeChanged,
          seconds: 15,
        ),
      ]);
    });

    test('slow mode disabled notice', () async {
      await openRoom(_live(metadata: const {'slowModeSeconds': 10}));
      await applyRules({'slowModeSeconds': 0});
      expect(bloc.state.chatRules.slowModeSeconds, 0);
      expect(bloc.state.chatNotice?.ruleChanges, [
        const LiveChatRuleChange(LiveChatRuleChangeKind.slowModeDisabled),
      ]);
    });

    test('EVERYONE notice', () async {
      await openRoom(
        _live(metadata: const {'chatMode': 'FOLLOWERS'}),
      );
      await applyRules({'chatMode': 'EVERYONE'});
      expect(bloc.state.chatRules.chatMode, 'EVERYONE');
      expect(bloc.state.chatNotice?.ruleChanges, [
        const LiveChatRuleChange(LiveChatRuleChangeKind.chatEveryone),
      ]);
    });

    test('FOLLOWERS notice', () async {
      await openRoom(_live());
      await applyRules({'chatMode': 'FOLLOWERS'});
      expect(bloc.state.chatRules.chatMode, 'FOLLOWERS');
      expect(bloc.state.chatNotice?.ruleChanges, [
        const LiveChatRuleChange(LiveChatRuleChangeKind.chatFollowers),
      ]);
    });

    test('SUBSCRIBERS notice', () async {
      await openRoom(_live());
      await applyRules({'chatMode': 'SUBSCRIBERS'});
      expect(bloc.state.chatRules.chatMode, 'SUBSCRIBERS');
      expect(bloc.state.chatNotice?.ruleChanges, [
        const LiveChatRuleChange(LiveChatRuleChangeKind.chatSubscribers),
      ]);
    });

    test('blocked keywords notice does not expose the list', () async {
      await openRoom(_live());
      await applyRules({
        'blockedKeywords': ['secret-word'],
      });
      expect(bloc.state.chatRules.blockedKeywords, ['secret-word']);
      expect(bloc.state.chatNotice?.ruleChanges, [
        const LiveChatRuleChange(LiveChatRuleChangeKind.blockedKeywords),
      ]);
    });

    test('FOLLOWERS blocks send when the viewer is not following', () async {
      await openRoom(
        _live(
          isFollowing: false,
          metadata: const {'chatMode': 'FOLLOWERS', 'slowModeSeconds': 0},
        ),
      );
      bloc.add(const LiveViewerCommentSent('hello'));
      await _pumpUntil(
        () => bloc.state.chatNotice?.kind == LiveChatNoticeKind.followToComment,
      );
      expect(comments.sent, isEmpty);
      expect(bloc.state.composerStatus().canSend, isFalse);
    });

    test('SUBSCRIBERS stays backend-authoritative when membership is unknown', () async {
      await openRoom(
        _live(metadata: const {'chatMode': 'SUBSCRIBERS'}),
      );
      comments.sendResult = const Left(
        ServerFailure('Fan club subscribers only'),
      );
      expect(bloc.state.composerStatus().canSend, isTrue);
      bloc.add(const LiveViewerCommentSent('hello'));
      await _pumpUntil(
        () =>
            bloc.state.chatNotice?.kind ==
            LiveChatNoticeKind.subscribeToComment,
      );
      expect(comments.sent, ['hello']);
    });

    test('blocked keyword is rejected locally without sending', () async {
      await openRoom(
        _live(metadata: const {'blockedKeywords': ['spam']}),
      );
      bloc.add(const LiveViewerCommentSent('this SPAM link'));
      await _pumpUntil(
        () =>
            bloc.state.chatNotice?.kind == LiveChatNoticeKind.blockedKeyword,
      );
      expect(comments.sent, isEmpty);
    });

    test('successful send starts a local slow-mode cooldown', () async {
      await openRoom(
        _live(metadata: const {'slowModeSeconds': 5}),
      );
      bloc.add(const LiveViewerCommentSent('hello'));
      await _pumpUntil(() => bloc.state.slowModeUntil != null);
      expect(bloc.state.slowModeUntil!.isAfter(DateTime.now()), isTrue);
      comments.sent.clear();
      bloc.add(const LiveViewerCommentSent('again'));
      await _pumpUntil(
        () => bloc.state.chatNotice?.kind == LiveChatNoticeKind.slowMode,
      );
      expect(comments.sent, isEmpty);
      expect(bloc.state.composerStatus().canSend, isFalse);
    });

    test('chat mute and unmute drive composer state', () async {
      await openRoom(_live());
      bloc.add(
        LiveViewerSocketEventReceived(
          LiveModerationEvent(
            liveId: 'live-1',
            moderationType: 'chat_muted',
            userId: 'viewer-1',
            timestamp: DateTime.utc(2026, 9, 1),
          ),
        ),
      );
      await _pumpUntil(() => bloc.state.chatMuted);
      expect(bloc.state.composerStatus().canSend, isFalse);
      expect(bloc.state.chatNotice?.kind, LiveChatNoticeKind.muted);

      bloc.add(
        LiveViewerSocketEventReceived(
          LiveModerationEvent(
            liveId: 'live-1',
            moderationType: 'chat_unmuted',
            userId: 'viewer-1',
            timestamp: DateTime.utc(2026, 9, 1),
          ),
        ),
      );
      await _pumpUntil(() => !bloc.state.chatMuted);
      expect(bloc.state.composerStatus().canSend, isTrue);
      expect(bloc.state.chatNotice?.kind, LiveChatNoticeKind.unmuted);
    });

    test('hydrates chatMuted when join live metadata already exposes it', () async {
      await openRoom(_live(metadata: const {'chatMuted': true}));
      expect(bloc.state.chatMuted, isTrue);
      expect(bloc.state.composerStatus().canSend, isFalse);
    });

    test('delete rolls comments back when HTTP fails', () async {
      await openRoom(_live());
      bloc.add(const LiveViewerCommentSent('keep'));
      await _pumpUntil(() => bloc.state.comments.any((c) => c.content == 'keep'));
      final mine = bloc.state.comments.last;
      comments.deleteResult = const Left(ServerFailure('nope'));
      bloc.add(LiveViewerCommentDeletedRequested(mine.id));
      await _pumpUntil(
        () =>
            bloc.state.chatNotice?.kind == LiveChatNoticeKind.deleteFailed &&
            bloc.state.comments.any((c) => c.id == mine.id),
      );
      expect(bloc.state.comments.any((c) => c.id == mine.id), isTrue);
      expect(comments.deleteCalls, 1);
    });
  });

  testWidgets('normal viewer cannot access comment moderation controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: SizedBox(
            height: 240,
            child: CommentsSection(
              comments: [_comment()],
              currentUserId: 'viewer-1',
              hostId: 'host-1',
              moderatorIds: const [],
              onDeleteComment: (id, userId) {},
              onMuteUser: (id, name, reason) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('host can access comment moderation controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: SizedBox(
            height: 240,
            child: CommentsSection(
              comments: [_comment()],
              currentUserId: 'host-1',
              hostId: 'host-1',
              moderatorIds: const [],
              onDeleteComment: (id, userId) {},
              onMuteUser: (id, name, reason) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
  });
}
