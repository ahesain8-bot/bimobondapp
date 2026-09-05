import 'package:equatable/equatable.dart';

import '../../../domain/entities/live_interactive.dart';

class LiveInteractiveState extends Equatable {
  const LiveInteractiveState({
    this.liveId,
    this.isLoading = false,
    this.error,
    this.giftGoal,
    this.hostLeague,
    this.lastUserLevelUp,
    this.lastTreasureClaim,
    this.poll,
    this.questions = const [],
    this.treasureBoxes = const [],
    this.auctions = const [],
  });

  final String? liveId;
  final bool isLoading;
  final String? error;
  final LiveGiftGoal? giftGoal;
  final LiveHostLeague? hostLeague;
  final LiveUserLevelUp? lastUserLevelUp;
  final LiveTreasureClaim? lastTreasureClaim;
  final LivePoll? poll;
  final List<LiveQA> questions;
  final List<LiveTreasureBox> treasureBoxes;
  final List<LiveAuction> auctions;

  LiveInteractiveState copyWith({
    String? liveId,
    bool? isLoading,
    String? error,
    bool clearError = false,
    LiveGiftGoal? giftGoal,
    LiveHostLeague? hostLeague,
    bool clearHostLeague = false,
    LiveUserLevelUp? lastUserLevelUp,
    LiveTreasureClaim? lastTreasureClaim,
    LivePoll? poll,
    bool clearPoll = false,
    List<LiveQA>? questions,
    List<LiveTreasureBox>? treasureBoxes,
    List<LiveAuction>? auctions,
  }) {
    return LiveInteractiveState(
      liveId: liveId ?? this.liveId,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      giftGoal: giftGoal ?? this.giftGoal,
      hostLeague: clearHostLeague ? null : (hostLeague ?? this.hostLeague),
      lastUserLevelUp: lastUserLevelUp ?? this.lastUserLevelUp,
      lastTreasureClaim: lastTreasureClaim ?? this.lastTreasureClaim,
      poll: clearPoll ? null : (poll ?? this.poll),
      questions: questions ?? this.questions,
      treasureBoxes: treasureBoxes ?? this.treasureBoxes,
      auctions: auctions ?? this.auctions,
    );
  }

  @override
  List<Object?> get props => [
    liveId,
    isLoading,
    error,
    giftGoal,
    hostLeague,
    lastUserLevelUp,
    lastTreasureClaim,
    poll,
    questions,
    treasureBoxes,
    auctions,
  ];
}
