import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/mappers/live_interactive_mapper.dart';
import '../../../domain/entities/live_interactive.dart';
import '../../../domain/repositories/live_session_repository.dart';
import '../../../domain/usecases/live_interactive_usecases.dart';
import '../../../../live_viewer/domain/entities/socket_event.dart';
import 'live_interactive_event.dart';
import 'live_interactive_state.dart';

class LiveInteractiveBloc
    extends Bloc<LiveInteractiveEvent, LiveInteractiveState> {
  LiveInteractiveBloc({
    required LiveInteractiveUseCases useCases,
    Stream<Object>? socketEvents,
    String? liveId,
  }) : _useCases = useCases,
       super(LiveInteractiveState(liveId: liveId)) {
    on<LiveInteractiveStarted>(_onStarted);
    on<LiveInteractiveGiftGoalCreated>(_onGiftGoalCreated);
    on<LiveInteractivePollCreated>(_onPollCreated);
    on<LiveInteractivePollVoted>(_onPollVoted);
    on<LiveInteractivePollEnded>(_onPollEnded);
    on<LiveInteractiveQuestionCreated>(_onQuestionCreated);
    on<LiveInteractiveQuestionPinned>(_onQuestionPinned);
    on<LiveInteractiveQuestionAnswered>(_onQuestionAnswered);
    on<LiveInteractiveTreasureBoxCreated>(_onTreasureBoxCreated);
    on<LiveInteractiveTreasureBoxClaimed>(_onTreasureBoxClaimed);
    on<LiveInteractiveAuctionCreated>(_onAuctionCreated);
    on<LiveInteractiveAuctionPinToggled>(_onAuctionPinToggled);
    on<LiveInteractiveAuctionsReordered>(_onAuctionsReordered);
    on<LiveInteractiveSocketEventReceived>(_onSocketEventReceived);
    on<LiveInteractiveErrorCleared>(_onErrorCleared);
    if (socketEvents != null) {
      _socketSub = socketEvents.listen((event) {
        final payload = _payloadFrom(event);
        if (payload != null && !isClosed) {
          add(LiveInteractiveSocketEventReceived(payload));
        }
      });
    }
  }

  final LiveInteractiveUseCases _useCases;
  StreamSubscription<Object>? _socketSub;

  String get _liveId => state.liveId ?? '';

  Future<void> _onStarted(
    LiveInteractiveStarted event,
    Emitter<LiveInteractiveState> emit,
  ) async {
    emit(LiveInteractiveState(liveId: event.liveId, isLoading: true));
    try {
      Future<LiveHostLeague?> hostLeague() async {
        final userId = event.userId;
        if (userId == null || userId.isEmpty) return null;
        try {
          return await _useCases.getHostLeague(userId);
        } catch (_) {
          return null;
        }
      }

      final results = await Future.wait<Object?>([
        _useCases.getActivePoll(event.liveId),
        _useCases.listQuestions(event.liveId),
        _useCases.listTreasureBoxes(event.liveId),
        _useCases.listGallery(event.liveId),
        hostLeague(),
      ]);
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          poll: results[0] as LivePoll?,
          questions: results[1] as List<LiveQA>,
          treasureBoxes: results[2] as List<LiveTreasureBox>,
          auctions: results[3] as List<LiveAuction>,
          hostLeague: results[4] as LiveHostLeague?,
        ),
      );
    } catch (error) {
      if (!isClosed) {
        emit(state.copyWith(isLoading: false, error: error.toString()));
      }
    }
  }

  Future<void> _run(
    Emitter<LiveInteractiveState> emit,
    Future<void> Function() action,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await action();
      if (!isClosed) emit(state.copyWith(isLoading: false));
    } catch (error) {
      if (!isClosed) emit(state.copyWith(isLoading: false, error: error.toString()));
    }
  }

  Future<void> _onGiftGoalCreated(
    LiveInteractiveGiftGoalCreated event,
    Emitter<LiveInteractiveState> emit,
  ) async => _run(emit, () async {
    final goal = await _useCases.createGiftGoal(
      liveId: _liveId,
      title: event.title,
      target: event.target,
    );
    emit(state.copyWith(giftGoal: goal));
  });

  Future<void> _onPollCreated(
    LiveInteractivePollCreated event,
    Emitter<LiveInteractiveState> emit,
  ) async {
    final question = event.question.trim();
    final options = event.options
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .toList(growable: false);
    if (question.isEmpty || question.length > 200 || options.length < 2 || options.length > 5) {
      emit(state.copyWith(error: 'A poll must have between 2 and 5 options.'));
      return;
    }
    await _run(emit, () async {
      final poll = await _useCases.createPoll(
        liveId: _liveId,
        question: question,
        options: options,
      );
      emit(state.copyWith(poll: poll));
    });
  }

  Future<void> _onPollVoted(
    LiveInteractivePollVoted event,
    Emitter<LiveInteractiveState> emit,
  ) async {
    final poll = state.poll;
    if (poll == null) return;
    await _run(emit, () async {
      emit(
        state.copyWith(
          poll: await _useCases.votePoll(
            liveId: _liveId,
            pollId: poll.id,
            optionIndex: event.optionIndex,
          ),
        ),
      );
    });
  }

  Future<void> _onPollEnded(
    LiveInteractivePollEnded event,
    Emitter<LiveInteractiveState> emit,
  ) async {
    final poll = state.poll;
    if (poll == null) return;
    await _run(emit, () async {
      await _useCases.endPoll(liveId: _liveId, pollId: poll.id);
      emit(state.copyWith(clearPoll: true));
    });
  }

  Future<void> _onQuestionCreated(
    LiveInteractiveQuestionCreated event,
    Emitter<LiveInteractiveState> emit,
  ) async => _run(emit, () async {
    final qa = await _useCases.createQuestion(
      liveId: _liveId,
      question: event.question,
    );
    emit(state.copyWith(questions: [qa, ...state.questions]));
  });

  Future<void> _onQuestionPinned(
    LiveInteractiveQuestionPinned event,
    Emitter<LiveInteractiveState> emit,
  ) async => _run(emit, () async {
    final qa = await _useCases.pinQuestion(
      liveId: _liveId,
      questionId: event.questionId,
    );
    emit(
      state.copyWith(
        questions: [
          qa,
          ...state.questions.where((item) => item.id != qa.id && !item.isPinned),
        ],
      ),
    );
  });

  Future<void> _onQuestionAnswered(
    LiveInteractiveQuestionAnswered event,
    Emitter<LiveInteractiveState> emit,
  ) async => _run(emit, () async {
    final qa = await _useCases.answerQuestion(
      liveId: _liveId,
      questionId: event.questionId,
    );
    emit(
      state.copyWith(
        questions: state.questions
            .map((item) => item.id == qa.id ? qa : item)
            .toList(growable: false),
      ),
    );
  });

  Future<void> _onTreasureBoxCreated(
    LiveInteractiveTreasureBoxCreated event,
    Emitter<LiveInteractiveState> emit,
  ) async => _run(emit, () async {
    final box = await _useCases.createTreasureBox(
      liveId: _liveId,
      totalCoins: event.totalCoins,
      maxClaims: event.maxClaims,
      delaySeconds: event.delaySeconds,
    );
    emit(state.copyWith(treasureBoxes: [box, ...state.treasureBoxes]));
  });

  Future<void> _onTreasureBoxClaimed(
    LiveInteractiveTreasureBoxClaimed event,
    Emitter<LiveInteractiveState> emit,
  ) async => _run(emit, () async {
    final claim = await _useCases.claimTreasureBox(
      liveId: _liveId,
      boxId: event.boxId,
    );
    final existingBox = state.treasureBoxes
        .where((box) => box.id == claim.box.id)
        .toList(growable: false);
    final previousBox = existingBox.isEmpty ? null : existingBox.first;
    final claimedBox = previousBox == null
        ? claim.box
        : LiveTreasureBox(
            id: previousBox.id,
            liveId: previousBox.liveId,
            totalCoins: previousBox.totalCoins,
            remainingCoins: claim.box.remainingCoins > 0
                ? claim.box.remainingCoins
                : previousBox.remainingCoins,
            maxClaims: claim.box.maxClaims > 0
                ? claim.box.maxClaims
                : previousBox.maxClaims,
            delaySeconds: claim.box.delaySeconds > 0
                ? claim.box.delaySeconds
                : previousBox.delaySeconds,
            claimedCount: claim.claimedCount > 0
                ? claim.claimedCount
                : previousBox.claimedCount,
            status: claim.box.status,
            createdAt: claim.box.createdAt ?? previousBox.createdAt,
            unlocksAt: claim.box.unlocksAt ?? previousBox.unlocksAt,
          );
    emit(
      state.copyWith(
        lastTreasureClaim: claim,
        treasureBoxes: state.treasureBoxes
            .map((box) => box.id == claim.box.id ? claimedBox : box)
            .toList(growable: false),
      ),
    );
  });

  Future<void> _onAuctionCreated(
    LiveInteractiveAuctionCreated event,
    Emitter<LiveInteractiveState> emit,
  ) async => _run(emit, () async {
    final auction = await _useCases.createAuction(
      liveId: _liveId,
      itemName: event.itemName,
      targetPrice: event.targetPrice,
      itemImageUrl: event.itemImageUrl,
      startingPrice: event.startingPrice,
    );
    emit(state.copyWith(auctions: [auction, ...state.auctions]));
  });

  Future<void> _onAuctionPinToggled(
    LiveInteractiveAuctionPinToggled event,
    Emitter<LiveInteractiveState> emit,
  ) async => _run(emit, () async {
    final auction = await _useCases.pinAuction(
      liveId: _liveId,
      auctionId: event.auctionId,
      pinned: event.pinned,
    );
    emit(
      state.copyWith(
        auctions: state.auctions
            .map((item) => item.id == auction.id ? auction : item)
            .toList(growable: false),
      ),
    );
  });

  Future<void> _onAuctionsReordered(
    LiveInteractiveAuctionsReordered event,
    Emitter<LiveInteractiveState> emit,
  ) async => _run(emit, () async {
    final auctions = await _useCases.reorderAuctions(
      liveId: _liveId,
      auctionIds: event.auctionIds,
    );
    emit(state.copyWith(auctions: auctions));
  });

  void _onSocketEventReceived(
    LiveInteractiveSocketEventReceived event,
    Emitter<LiveInteractiveState> emit,
  ) {
    final payload = event.payload;
    if (_liveId.isNotEmpty && payload.liveId != _liveId) return;
    final data = payload.payload;
    switch (payload.event) {
      case 'liveGiftGoalUpdate':
        emit(state.copyWith(giftGoal: LiveInteractiveMapper.giftGoal(data)));
        break;
      case 'livePollUpdated':
        final poll = LiveInteractiveMapper.poll(data);
        if (poll.id.isEmpty) {
          emit(state.copyWith(clearPoll: true));
        } else {
          emit(state.copyWith(poll: poll));
        }
        break;
      case 'liveQAUpdated':
        final qa = LiveInteractiveMapper.qa(data);
        if (qa.id.isEmpty) return;
        emit(
          state.copyWith(
            questions: [
              qa,
              ...state.questions.where((item) => item.id != qa.id),
            ],
          ),
        );
        break;
      case 'liveTreasureBoxSpawned':
        final box = LiveInteractiveMapper.treasureBox(data);
        emit(
          state.copyWith(
            treasureBoxes: [
              box,
              ...state.treasureBoxes.where((item) => item.id != box.id),
            ],
          ),
        );
        break;
      case 'liveTreasureBoxClaimed':
        final boxId = data['boxId']?.toString();
        if (boxId == null) return;
        final count = LiveInteractiveMapper.integer(data['claimedCount']);
        emit(
          state.copyWith(
            treasureBoxes: state.treasureBoxes
                .map(
                  (box) => box.id == boxId
                      ? LiveTreasureBox(
                          id: box.id,
                          liveId: box.liveId,
                          totalCoins: box.totalCoins,
                          remainingCoins: LiveInteractiveMapper.integer(
                            data['remainingCoins'],
                            box.remainingCoins,
                          ),
                          maxClaims: LiveInteractiveMapper.integer(
                            data['maxClaims'],
                            box.maxClaims,
                          ),
                          delaySeconds: box.delaySeconds,
                          claimedCount: count,
                          status: box.status,
                          createdAt: box.createdAt,
                          unlocksAt: box.unlocksAt,
                        )
                      : box,
                )
                .toList(growable: false),
          ),
        );
        break;
      case 'liveAuction':
        final auction = LiveInteractiveMapper.auction(data);
        if (auction.id.isEmpty) return;
        emit(
          state.copyWith(
            auctions: [
              auction,
              ...state.auctions.where((item) => item.id != auction.id),
            ],
          ),
        );
        break;
      case 'hostLeagueUpdated':
        final league = LiveInteractiveMapper.hostLeague(data);
        if (league.userId.isNotEmpty) {
          emit(state.copyWith(hostLeague: league));
        }
        break;
      case 'userLevelUp':
        final levelUp = LiveInteractiveMapper.userLevelUp(data);
        if (levelUp.userId.isNotEmpty) {
          emit(state.copyWith(lastUserLevelUp: levelUp));
        }
        break;
    }
  }

  void _onErrorCleared(
    LiveInteractiveErrorCleared event,
    Emitter<LiveInteractiveState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }

  LiveInteractiveSocketPayload? _payloadFrom(Object event) {
    if (event is LiveInteractiveSocketPayload) return event;
    // Host socket event.
    if (event is LiveHudInteractiveEvent) return event.payload;
    if (event is LiveInteractiveSocketEvent) return event.payload;
    return null;
  }

  @override
  Future<void> close() async {
    await _socketSub?.cancel();
    return super.close();
  }
}
