import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/services/live_operation_guard.dart';

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
    on<LiveInteractiveGiftGoalSnapshotReceived>((event, emit) {
      if (event.liveId != _liveId || (_revisions['goal'] ?? 0) != 0) return;
      emit(
        state.copyWith(giftGoal: event.goal, clearGiftGoal: event.goal == null),
      );
    });
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

  /// Polls this room has already seen end. A late `livePollUpdated` must not
  /// put one of them back on screen.
  final Set<String> _endedPolls = {};

  // Per-view debounce. The repository owns the shared durable money guard.
  final Set<String> _claimsInFlight = {};

  int _generation = 0;
  final Map<String, int> _revisions = {};
  final Set<String> _votedPolls = {};

  String get _liveId => state.liveId ?? '';

  Future<void> _onStarted(
    LiveInteractiveStarted event,
    Emitter<LiveInteractiveState> emit,
  ) async {
    if (event.liveId.isEmpty) return;
    final sameLive = _liveId == event.liveId;
    final generation = ++_generation;
    if (!sameLive) {
      _endedPolls.clear();
      _votedPolls.clear();
      _revisions.clear();
    }
    emit(
      sameLive
          ? state.copyWith(
              isLoading: true,
              clearError: true,
              giftGoal: (_revisions['goal'] ?? 0) == 0 ? event.giftGoal : null,
            )
          : LiveInteractiveState(
              liveId: event.liveId,
              isLoading: true,
              giftGoal: event.giftGoal,
            ),
    );
    Future<void> read<T>(
      String section,
      Future<T> Function() fetch,
      LiveInteractiveState Function(T) apply,
    ) async {
      final revision = _revisions[section] ?? 0;
      try {
        final value = await fetch();
        if (isClosed || generation != _generation || emit.isDone) return;
        if (revision == (_revisions[section] ?? 0)) emit(apply(value));
      } catch (e) {
        if (!isClosed && generation == _generation && !emit.isDone) {
          emit(state.copyWith(error: e.toString()));
        }
      }
    }

    await Future.wait([
      read(
        'poll',
        () => _repository.getActivePoll(event.liveId),
        (poll) => state.copyWith(poll: poll, clearPoll: poll == null),
      ),
      read(
        'qa',
        () => _repository.listQuestions(event.liveId),
        (questions) => state.copyWith(questions: questions),
      ),
      read(
        'treasure',
        () => _repository.listTreasureBoxes(event.liveId),
        (boxes) => state.copyWith(treasureBoxes: boxes),
      ),
      read(
        'auction',
        () => _repository.listActiveAuctions(event.liveId),
        (auctions) => state.copyWith(auctions: auctions),
      ),
    ]);
    if (!isClosed && generation == _generation && !emit.isDone) {
      emit(state.copyWith(isLoading: false));
    }
  }

  /// Runs a host/viewer command, keeping `isLoading` and `error` consistent so
  /// every surface can disable its controls while a request is in flight.
  Future<void> _run(
    Emitter<LiveInteractiveState> emit,
    Future<void> Function(void Function(LiveInteractiveState) publish) action,
  ) async {
    if (!state.hasLiveId) return;
    final generation = _generation;
    final revisions = Map<String, int>.from(_revisions);
    bool unchanged(String key) =>
        (revisions[key] ?? 0) == (_revisions[key] ?? 0);
    bool current() => !isClosed && !emit.isDone && generation == _generation;
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await action((next) {
        if (!current()) return;
        emit(
          next.copyWith(
            poll: unchanged('poll') ? next.poll : state.poll,
            clearPoll: unchanged('poll')
                ? next.poll == null
                : state.poll == null,
            giftGoal: unchanged('goal') ? next.giftGoal : state.giftGoal,
            clearGiftGoal: unchanged('goal')
                ? next.giftGoal == null
                : state.giftGoal == null,
            questions: unchanged('qa') ? next.questions : state.questions,
            auctions: unchanged('auction') ? next.auctions : state.auctions,
            treasureBoxes: unchanged('treasure')
                ? next.treasureBoxes
                : state.treasureBoxes,
          ),
        );
      });
      if (current()) emit(state.copyWith(isLoading: false));
    } catch (e) {
      if (current()) {
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
    return _run(emit, (publish) async {
      // The POST response is the authoritative goal; dropping it left the bar
      // empty until the next gift arrived.
      final goal = await _repository.createGiftGoal(
        liveId: _liveId,
        title: event.title,
        target: event.target,
      );
      if (!isClosed) publish(state.copyWith(giftGoal: goal));
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
    return _run(emit, (publish) async {
      final poll = await _repository.createPoll(
        liveId: _liveId,
        question: question,
        options: options,
      );
      publish(state.copyWith(poll: poll));
    });
  }

  Future<void> _onPollVoted(
    LiveInteractivePollVoted event,
    Emitter<LiveInteractiveState> emit,
  ) {
    final poll = state.activePoll;
    if (poll == null ||
        event.optionIndex < 0 ||
        event.optionIndex >= poll.options.length)
      return Future.value();
    final liveId = _liveId;
    final pollKey = '$liveId|${poll.id}';
    if (!_votedPolls.add(pollKey)) return Future.value();
    return _run(emit, (publish) async {
      publish(
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
    return _run(emit, (publish) async {
      await _repository.endPoll(liveId: _liveId, pollId: poll.id);
      _endedPolls.add(poll.id);
      publish(state.copyWith(clearPoll: true));
    });
  }

  Future<void> _onQuestionCreated(
    LiveInteractiveQuestionCreated event,
    Emitter<LiveInteractiveState> emit,
  ) {
    final question = event.question.trim();
    if (question.isEmpty) return Future.value();
    return _run(emit, (publish) async {
      final created = await _repository.createQuestion(
        liveId: _liveId,
        question: question,
      );
      publish(state.copyWith(questions: [created, ...state.questions]));
    });
  }

  Future<void> _onQuestionPinned(
    LiveInteractiveQuestionPinned event,
    Emitter<LiveInteractiveState> emit,
  ) {
    return _run(emit, (publish) async {
      final pinned = await _repository.pinQuestion(
        liveId: _liveId,
        questionId: event.questionId,
      );
      publish(state.copyWith(questions: _replaceQuestion(pinned)));
      final questions = await _repository.listQuestions(pinned.liveId);
      publish(state.copyWith(questions: questions));
    });
  }

  Future<void> _onQuestionAnswered(
    LiveInteractiveQuestionAnswered event,
    Emitter<LiveInteractiveState> emit,
  ) {
    return _run(emit, (publish) async {
      final answered = await _repository.answerQuestion(
        liveId: _liveId,
        questionId: event.questionId,
      );
      publish(state.copyWith(questions: _replaceQuestion(answered)));
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
    return _run(emit, (publish) async {
      final box = await _repository.createTreasureBox(
        liveId: _liveId,
        totalCoins: event.totalCoins,
        maxClaims: event.maxClaims,
        delaySeconds: event.delaySeconds,
      );
      publish(state.copyWith(treasureBoxes: [box, ...state.treasureBoxes]));
    });
  }

  Future<void> _onTreasureBoxClaimed(
    LiveInteractiveTreasureBoxClaimed event,
    Emitter<LiveInteractiveState> emit,
  ) {
    final liveId = _liveId;
    final claimKey = '$liveId|${event.boxId}';
    if (!state.hasLiveId || !_claimsInFlight.add(claimKey)) {
      return Future.value();
    }
    return _run(emit, (publish) async {
      try {
        final claim = await _repository.claimTreasureBox(
          liveId: liveId,
          boxId: event.boxId,
        );
        publish(
          state.copyWith(
            lastClaim: claim,
            treasureBoxes: _applyClaim(
              boxId: claim.boxId,
              claimedCount: claim.claimedCount,
              remainingCoins: claim.remainingCoins,
            ),
          ),
        );
      } on LiveOperationNotSent {
        _claimsInFlight.remove(claimKey);
        rethrow;
      }
      // Confirmed and uncertain claims both stay reserved. General network
      // exceptions do not prove that the server failed to credit the wallet.
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
    return _run(emit, (publish) async {
      final auction = await _repository.createAuction(
        liveId: _liveId,
        itemName: itemName,
        targetPrice: event.targetPrice,
        startingPrice: event.startingPrice,
      );
      publish(state.copyWith(auctions: [auction, ...state.auctions]));
    });
  }

  Future<void> _onAuctionPinToggled(
    LiveInteractiveAuctionPinToggled event,
    Emitter<LiveInteractiveState> emit,
  ) {
    return _run(emit, (publish) async {
      final auction = await _repository.pinAuction(
        liveId: _liveId,
        auctionId: event.auctionId,
        pinned: event.pinned,
      );
      publish(state.copyWith(auctions: _replaceAuction(auction)));
    });
  }

  void _onSocketEventReceived(
    LiveInteractiveSocketEventReceived event,
    Emitter<LiveInteractiveState> emit,
  ) {
    final payload = event.payload;
    if (state.hasLiveId && payload.liveId != _liveId) return;
    if (!state.hasLiveId) return;
    final data = payload.payload;
    final section = switch (payload.event) {
      'livePollUpdated' => 'poll',
      'liveQAUpdated' => 'qa',
      'liveTreasureBoxSpawned' || 'liveTreasureBoxClaimed' => 'treasure',
      'liveAuction' => 'auction',
      'liveGiftGoalUpdate' => 'goal',
      _ => '',
    };
    _revisions[section] = (_revisions[section] ?? 0) + 1;
    switch (payload.event) {
      case 'liveGiftGoalUpdate':
        // Server-authoritative: the progress is never added up locally, so one
        // gift cannot be counted twice by the response and the event together.
        final goal = LiveInteractiveMapper.giftGoalPatch(data, state.giftGoal);
        emit(
          goal == null
              ? state.copyWith(clearGiftGoal: true)
              : state.copyWith(giftGoal: goal),
        );
      case 'livePollUpdated':
        final poll = LiveInteractiveMapper.poll(data);
        if (poll.id.isEmpty) return;
        if (poll.liveId.isNotEmpty && poll.liveId != _liveId) return;
        if (!poll.isActive) {
          _endedPolls.add(poll.id);
          // Only the poll on screen can close the poll on screen.
          if (state.poll?.id != poll.id) return;
          emit(state.copyWith(poll: poll));
          return;
        }
        // Filtered by poll id: a late event must never revive a poll this
        // room already saw end.
        if (_endedPolls.contains(poll.id)) return;
        emit(state.copyWith(poll: poll));
      case 'liveQAUpdated':
        final question = LiveInteractiveMapper.qaPatch(data, state.questions);
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
        final auction = LiveInteractiveMapper.auctionPatch(
          data,
          state.auctions,
        );
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
    required int? claimedCount,
    required int? remainingCoins,
  }) {
    return state.treasureBoxes
        .map(
          (box) => box.id == boxId
              ? box.copyWith(
                  claimedCount: claimedCount,
                  remainingCoins: remainingCoins,
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
    _generation++;
    await _socketSub?.cancel();
    return super.close();
  }
}
