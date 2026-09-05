import 'dart:async';
import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bimobondapp/app/auctions/data/datasources/auction_socket_service.dart';
import 'package:bimobondapp/core/network/live_api_client.dart';
import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import 'package:bimobondapp/features/live_viewer/data/services/fake_livekit_service.dart';
import 'package:bimobondapp/features/live_viewer/data/services/fake_socket_service.dart';
import 'package:bimobondapp/features/live_viewer/data/mappers/live_mapper.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/live_feed_activation.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/live_session_entity.dart';
import 'package:bimobondapp/features/live_viewer/domain/repositories/live_repository.dart';
import 'package:bimobondapp/features/live_viewer/domain/repositories/comment_repository.dart';
import 'package:bimobondapp/features/live_viewer/domain/repositories/gift_repository.dart';
import 'package:bimobondapp/features/live_viewer/domain/repositories/guest_repository.dart';
import 'package:bimobondapp/features/live_viewer/domain/repositories/like_repository.dart';
import 'package:bimobondapp/features/live_viewer/domain/usecases/join_live_usecase.dart';
import 'package:bimobondapp/features/live_viewer/domain/usecases/leave_live_usecase.dart';
import 'package:bimobondapp/features/live_viewer/domain/usecases/like_live_usecase.dart';
import 'package:bimobondapp/features/live_viewer/domain/usecases/ban_viewer_usecase.dart';
import 'package:bimobondapp/features/live_viewer/domain/usecases/unban_viewer_usecase.dart';
import 'package:bimobondapp/features/live_viewer/domain/usecases/mute_viewer_chat_usecase.dart';
import 'package:bimobondapp/features/live_viewer/domain/usecases/unmute_viewer_chat_usecase.dart';
import 'package:bimobondapp/features/live_viewer/domain/usecases/delete_comment_usecase.dart';
import 'package:bimobondapp/features/live_viewer/presentation/bloc/live_viewer/live_viewer_bloc.dart';
import 'package:bimobondapp/features/live_viewer/presentation/bloc/live_viewer/live_viewer_event.dart';
import 'live_promotion_attribution_test.dart' show live;

class _Repo implements LiveRepository {
  final calls = <({String liveId, String? campaignId})>[];
  Completer<void>? gate;
  @override
  Future<Either<Failure, JoinLiveResult>> joinLive(
    String liveId, {
    String? campaignId,
  }) async {
    calls.add((liveId: liveId, campaignId: campaignId));
    if (gate != null) await gate!.future;
    return const Left(ServerFailure('Mock connection failure'));
  }

  @override
  Future<Either<Failure, void>> leaveLive(String liveId) async =>
      const Right(null);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Comments implements CommentRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Gifts implements GiftRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Guests implements GuestRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Likes implements LikeRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test(
    'actual Bloc consumes attributed entry, retry/foreground/opponent stay organic, re-entry attributes again',
    () async {
      final repo = _Repo(), comments = _Comments(), likes = _Likes();
      final kit = FakeLiveKitService(),
          socket = FakeSocketService(),
          gifts = AuctionSocketService();
      var account = 'viewer-1';
      final bloc = LiveViewerBloc(
        joinLiveUseCase: JoinLiveUseCase(repo),
        leaveLiveUseCase: LeaveLiveUseCase(repo),
        likeLiveUseCase: LikeLiveUseCase(likes),
        giftSocketService: gifts,
        banViewerUseCase: BanViewerUseCase(repo),
        unbanViewerUseCase: UnbanViewerUseCase(repo),
        muteViewerChatUseCase: MuteViewerChatUseCase(repo),
        unmuteViewerChatUseCase: UnmuteViewerChatUseCase(repo),
        deleteCommentUseCase: DeleteCommentUseCase(comments),
        liveRepository: repo,
        commentRepository: comments,
        giftRepository: _Gifts(),
        likeRepository: likes,
        socketService: socket,
        liveKitService: kit,
        guestRepository: _Guests(),
        apiClient: LiveApiClient(
          httpClient: MockClient(
            (r) async => http.Response(jsonEncode({'id': account}), 200),
          ),
          idTokenProvider: () async => 'mock',
        ),
      );
      addTearDown(() async {
        await bloc.close();
        kit.dispose();
        socket.dispose();
        gifts.dispose();
      });
      final entry = LiveMapper.fromJson(live(promoted: true));
      final activation = LiveFeedActivation.fromEntry(entry);
      expect(
        repo.calls,
        isEmpty,
        reason: 'mapping and offscreen creation have no join side effect',
      );
      Future<void> dispatch(LiveViewerEvent event, int count) async {
        bloc.add(event);
        for (var i = 0; i < 1000 && repo.calls.length < count; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
        await Future<void>.delayed(const Duration(milliseconds: 450));
        expect(repo.calls.length, count);
      }

      await dispatch(LiveViewerActivated(entry, activation: activation), 1);
      await dispatch(LiveViewerActivated(entry, activation: activation), 1);
      await dispatch(const LiveViewerRetryRequested(), 2);
      await dispatch(const LiveViewerDeactivated(), 2);
      await dispatch(LiveViewerActivated(entry, activation: activation), 3);
      await dispatch(LiveViewerActivated(entry.copyWith(id: 'opponent')), 4);
      await dispatch(
        LiveViewerActivated(
          entry,
          activation: LiveFeedActivation.fromEntry(entry),
        ),
        5,
      );
      account = 'host-1';
      await dispatch(
        LiveViewerActivated(
          entry,
          activation: LiveFeedActivation.fromEntry(entry),
        ),
        6,
      );
      expect(repo.calls.map((c) => c.campaignId), [
        'campaign-1',
        null,
        null,
        null,
        'campaign-1',
        null,
      ]);
      expect(repo.calls[3].liveId, 'opponent');
    },
  );
}
