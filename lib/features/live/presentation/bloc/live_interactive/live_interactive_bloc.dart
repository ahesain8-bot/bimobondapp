import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../live_viewer/domain/entities/socket_event.dart';
import '../../../data/mappers/live_interactive_mapper.dart';
import '../../../domain/entities/live_interactive.dart';
import '../../../domain/repositories/live_interactive_repository.dart';
import '../../../domain/repositories/live_session_repository.dart';
import 'live_interactive_event.dart';
import 'live_interactive_state.dart';

/// Drives the interactive live-room features for both the host toolbar and the
/// viewer panel. Server pushes are applied on top of the REST results, so the
/// room stays in sync without polling.
class LiveInteractiveBloc
    extends Bloc<LiveInteractiveEvent, LiveInteractiveState> {
  LiveInteractiveBloc({
    required LiveInteractiveRepository repository,
    Stream<Object>? socketEvents,
    String? liveId,
  }) : _repository = repository,
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
    on<LiveInteractiveSocketEventReceived>(_onSocketEventReceived);
    on<LiveInteractiveErrorCleared>(_onErrorCleared);
    on<LiveInteractiveClaimShown>(_onClaimShown);

    if (socketEvents != null) {
      _socketSub = socketEvents.listen((event) {
        final payload = _payloadFrom(event);
        if (payload != null && !isClosed) {
          add(LiveInteractiveSocketEventReceived(payload));
        }
      });
    }
  }

  final LiveInteractiveRepository _repository;
  StreamSubscription<Object>? _socketSub;

  String get _liveId => state.liveId ?? '';

  Future<void> _onStarted(
    LiveInteractiveStarted event,
    Emitter<LiveInteractiveState> emit,
  ) async {
    if (event.liveId.isEmpty) return;
    emit(LiveInteractiveState(liveId: event.liveId, isLoading: true));
    try {
      final results = await Future.wait<Object?>([
        _repository.getActivePoll(event.liveId),
        _repository.listQuestions(event.liveId),
        _repository.listTreasureBoxes(event.liveId),
        _repository.listActiveAuctions(event.liveId),
      ]);
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          poll: results[0] as LivePoll?,
          questions: results[1] as List<LiveQA>,
          treasureBoxes: results[2] as List<LiveTreasureBox>,
          auctions: results[3] as List<LiveAuction>,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// Runs a host/viewer command, keeping `isLoading` and `error` consistent so
  /// every surface can disable its controls while a request is in flight.
  Future<void> _run(
    Emitter<LiveInteractiveState> emit,
    Future<void> Function() action,
  ) async {
    if (!state.hasLiveId) return;
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await action();
      if (!isClosed) emit(state.copyWith(isLoading: false));
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(isLoading: false, error: e.toString()));
      }
    }
  }

  Future<void> _onGiftGoalCreated(
    LiveInteractiveGiftGoalCreated event,
    Emitter<LiveInteractiveState> emit,
  ) {
    if (event.target <= 0) {
      emit(state.copyWith(error: 'Enter a target above zero.'));
      return Future.value();
    }
    return _run(emit, () async {
      await _repository.createGiftGoal(
        liveId: _liveId,
        title: event.title,
        target: event.target,
      );
    });
  }

  Future<void> _onPollCreated(
    LiveInteractivePollCreated event,
    Emitter<LiveInteractiveState> emit,
  ) {
    final question = event.question.trim();
    final options = event.options
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .toList(growable: false);
    if (question.isEmpty || options.length < 2 || options.length > 5) {
      emit(
        state.copyWith(
          error: 'A poll needs a question and between 2 and 5 options.',
        ),
      );
      return Future.value();
    }
    return _run(emit, () async {
      final poll = await _repository.createPoll(
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
  ) {
    final poll = state.activePoll;
    if (poll == null) return Future.value();
    return _run(emit, () async {
      emit(
        state.copyWith(
          poll: await _repository.votePoll(
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
  ) {
    final poll = state.poll;
    if (poll == null) return Future.value();
    return _run(emit, () async {
      await _repository.endPoll(liveId: _liveId, pollId: poll.id);
      emit(state.copyWith(clearPoll: true));
    });
  }

  Future<void> _onQuestionCreated(
    LiveInteractiveQuestionCreated event,
    Emitter<LiveInteractiveState> emit,
  ) {
    final question = event.question.trim();
    if (question.isEmpty) return Future.value();
    return _run(emit, () async {
      final created = await _repository.createQuestion(
        liveId: _liveId,
        question: question,
      );
      emit(state.copyWith(questions: [created, ...state.questions]));
    });
  }

  Future<void> _onQuestionPinned(
    LiveInteractiveQuestionPinned event,
    Emitter<LiveInteractiveState> emit,
  ) {
    return _run(emit, () async {
      final pinned = await _repository.pinQuestion(
        liveId: _liveId,
        questionId: event.questionId,
      );
      // Only one question is pinned at a time, so the freshly pinned one moves
      // to the front and any previous pin drops back into the plain list.
      emit(
        state.copyWith(
          questions: [
            pinned,
            ...state.questions.where(
              (item) => item.id != pinned.id && !item.isPinned,
            ),
          ],
        ),
      );
    });
  }

  Future<void> _onQuestionAnswered(
    LiveInteractiveQuestionAnswered event,
    Emitter<LiveInteractiveState> emit,
  ) {
    return _run(emit, () async {
      final answered = await _repository.answerQuestion(
        liveId: _liveId,
        questionId: event.questionId,
      );
      emit(state.copyWith(questions: _replaceQuestion(answered)));
    });
  }

  Future<void> _onTreasureBoxCreated(
    LiveInteractiveTreasureBoxCreated event,
    Emitter<LiveInteractiveState> emit,
  ) {
    if (event.totalCoins < 10 ||
        event.maxClaims < 1 ||
        event.maxClaims > 100 ||
        event.delaySeconds < 10 ||
        event.delaySeconds > 600) {
      emit(
        state.copyWith(
          error:
              'Use at least 10 coins, 1–100 claims and a 10–600 second delay.',
        ),
      );
      return Future.value();
    }
    return _run(emit, () async {
      final box = await _repository.createTreasureBox(
        liveId: _liveId,
        totalCoins: event.totalCoins,
        maxClaims: event.maxClaims,
        delaySeconds: event.delaySeconds,
      );
      emit(state.copyWith(treasureBoxes: [box, ...state.treasureBoxes]));
    });
  }

  Future<void> _onTreasureBoxClaimed(
    LiveInteractiveTreasureBoxClaimed event,
    Emitter<LiveInteractiveState> emit,
  ) {
    return _run(emit, () async {
      final claim = await _repository.claimTreasureBox(
        liveId: _liveId,
        boxId: event.boxId,
      );
      emit(
        state.copyWith(
          lastClaim: claim,
          treasureBoxes: _applyClaim(
            boxId: claim.boxId,
            claimedCount: claim.claimedCount,
            remainingCoins: claim.remainingCoins,
          ),
        ),
      );
    });
  }

  Future<void> _onAuctionCreated(
    LiveInteractiveAuctionCreated event,
    Emitter<LiveInteractiveState> emit,
  ) {
    final itemName = event.itemName.trim();
    if (itemName.isEmpty || event.targetPrice <= 0) {
      emit(
        state.copyWith(error: 'Enter an item name and a target above zero.'),
      );
      return Future.value();
    }
    return _run(emit, () async {
      final auction = await _repository.createAuction(
        liveId: _liveId,
        itemName: itemName,
        targetPrice: event.targetPrice,
        startingPrice: event.startingPrice,
      );
      emit(state.copyWith(auctions: [auction, ...state.auctions]));
    });
  }

  Future<void> _onAuctionPinToggled(
    LiveInteractiveAuctionPinToggled event,
    Emitter<LiveInteractiveState> emit,
  ) {
    return _run(emit, () async {
      final auction = await _repository.pinAuction(
        liveId: _liveId,
        auctionId: event.auctionId,
        pinned: event.pinned,
      );
      emit(state.copyWith(auctions: _replaceAuction(auction)));
    });
  }

  void _onSocketEventReceived(
    LiveInteractiveSocketEventReceived event,
    Emitter<LiveInteractiveState> emit,
  ) {
    final payload = event.payload;
    if (state.hasLiveId && payload.liveId != _liveId) return;
    final data = payload.payload;
    switch (payload.event) {
      case 'livePollUpdated':
        final poll = LiveInteractiveMapper.poll(data);
        emit(poll.id.isEmpty
            ? state.copyWith(clearPoll: true)
            : state.copyWith(poll: poll));
      case 'liveQAUpdated':
        final question = LiveInteractiveMapper.qa(data);
        if (question.id.isEmpty) return;
        emit(
          state.copyWith(
            questions: [
              question,
              ...state.questions.where((item) => item.id != question.id),
            ],
          ),
        );
      case 'liveTreasureBoxSpawned':
        final box = LiveInteractiveMapper.treasureBox(data);
        if (box.id.isEmpty) return;
        emit(
          state.copyWith(
            treasureBoxes: [
              box,
              ...state.treasureBoxes.where((item) => item.id != box.id),
            ],
          ),
        );
      case 'liveTreasureBoxClaimed':
        final map = LiveInteractiveMapper.asMap(data);
        final boxId = map['boxId']?.toString();
        if (boxId == null || boxId.isEmpty) return;
        final claim = LiveInteractiveMapper.treasureClaim(data);
        emit(
          state.copyWith(
            treasureBoxes: _applyClaim(
              boxId: boxId,
              claimedCount: claim.claimedCount,
              remainingCoins: claim.remainingCoins,
            ),
          ),
        );
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
    }
  }

  void _onErrorCleared(
    LiveInteractiveErrorCleared event,
    Emitter<LiveInteractiveState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }

  void _onClaimShown(
    LiveInteractiveClaimShown event,
    Emitter<LiveInteractiveState> emit,
  ) {
    emit(state.copyWith(clearLastClaim: true));
  }

  List<LiveQA> _replaceQuestion(LiveQA question) {
    return state.questions
        .map((item) => item.id == question.id ? question : item)
        .toList(growable: false);
  }

  List<LiveAuction> _replaceAuction(LiveAuction auction) {
    return state.auctions
        .map((item) => item.id == auction.id ? auction : item)
        .toList(growable: false);
  }

  /// A claim only reports counters, so the existing box is kept and just its
  /// progress fields move forward.
  List<LiveTreasureBox> _applyClaim({
    required String boxId,
    required int claimedCount,
    required int remainingCoins,
  }) {
    return state.treasureBoxes
        .map(
          (box) => box.id == boxId
              ? box.copyWith(
                  claimedCount: claimedCount > 0 ? claimedCount : null,
                  remainingCoins: remainingCoins > 0 ? remainingCoins : null,
                )
              : box,
        )
        .toList(growable: false);
  }

  /// Accepts the host HUD stream and the viewer socket stream, which carry the
  /// same normalized payload under different event types.
  LiveInteractiveSocketPayload? _payloadFrom(Object event) {
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
