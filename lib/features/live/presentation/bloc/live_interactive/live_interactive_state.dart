import 'package:equatable/equatable.dart';

import '../../../domain/entities/live_interactive.dart';

class LiveInteractiveState extends Equatable {
  const LiveInteractiveState({
    this.liveId,
    this.isLoading = false,
    this.error,
    this.poll,
    this.questions = const [],
    this.treasureBoxes = const [],
    this.auctions = const [],
    this.lastClaim,
  });

  final String? liveId;
  final bool isLoading;
  final String? error;
  final LivePoll? poll;
  final List<LiveQA> questions;
  final List<LiveTreasureBox> treasureBoxes;
  final List<LiveAuction> auctions;

  /// Set once after a successful claim so the viewer panel can announce the
  /// reward, then cleared by [LiveInteractiveClaimShown].
  final LiveTreasureClaim? lastClaim;

  bool get hasLiveId => liveId != null && liveId!.isNotEmpty;

  /// The active poll, or null when there is none to show.
  LivePoll? get activePoll => poll != null && poll!.isActive ? poll : null;

  List<LiveTreasureBox> get openTreasureBoxes =>
      treasureBoxes.where((box) => box.isOpen).toList(growable: false);

  List<LiveAuction> get activeAuctions =>
      auctions.where((auction) => auction.isActive).toList(growable: false);

  LiveQA? get pinnedQuestion {
    for (final question in questions) {
      if (question.isPinned) return question;
    }
    return null;
  }

  LiveInteractiveState copyWith({
    String? liveId,
    bool? isLoading,
    String? error,
    bool clearError = false,
    LivePoll? poll,
    bool clearPoll = false,
    List<LiveQA>? questions,
    List<LiveTreasureBox>? treasureBoxes,
    List<LiveAuction>? auctions,
    LiveTreasureClaim? lastClaim,
    bool clearLastClaim = false,
  }) {
    return LiveInteractiveState(
      liveId: liveId ?? this.liveId,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      poll: clearPoll ? null : (poll ?? this.poll),
      questions: questions ?? this.questions,
      treasureBoxes: treasureBoxes ?? this.treasureBoxes,
      auctions: auctions ?? this.auctions,
      lastClaim: clearLastClaim ? null : (lastClaim ?? this.lastClaim),
    );
  }

  @override
  List<Object?> get props => [
    liveId,
    isLoading,
    error,
    poll,
    questions,
    treasureBoxes,
    auctions,
    lastClaim,
  ];
}
