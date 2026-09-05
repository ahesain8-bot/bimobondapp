import 'package:equatable/equatable.dart';

import '../../../domain/entities/live_interactive.dart';

sealed class LiveInteractiveEvent extends Equatable {
  const LiveInteractiveEvent();

  @override
  List<Object?> get props => const [];
}

class LiveInteractiveStarted extends LiveInteractiveEvent {
  const LiveInteractiveStarted(this.liveId, {this.userId});

  final String liveId;
  final String? userId;

  @override
  List<Object?> get props => [liveId, userId];
}

class LiveInteractiveGiftGoalCreated extends LiveInteractiveEvent {
  const LiveInteractiveGiftGoalCreated({this.title, required this.target});

  final String? title;
  final int target;

  @override
  List<Object?> get props => [title, target];
}

class LiveInteractivePollCreated extends LiveInteractiveEvent {
  const LiveInteractivePollCreated({
    required this.question,
    required this.options,
  });

  final String question;
  final List<String> options;

  @override
  List<Object?> get props => [question, options];
}

class LiveInteractivePollVoted extends LiveInteractiveEvent {
  const LiveInteractivePollVoted(this.optionIndex);

  final int optionIndex;

  @override
  List<Object?> get props => [optionIndex];
}

class LiveInteractivePollEnded extends LiveInteractiveEvent {
  const LiveInteractivePollEnded();
}

class LiveInteractiveQuestionCreated extends LiveInteractiveEvent {
  const LiveInteractiveQuestionCreated(this.question);

  final String question;

  @override
  List<Object?> get props => [question];
}

class LiveInteractiveQuestionPinned extends LiveInteractiveEvent {
  const LiveInteractiveQuestionPinned(this.questionId);

  final String questionId;

  @override
  List<Object?> get props => [questionId];
}

class LiveInteractiveQuestionAnswered extends LiveInteractiveEvent {
  const LiveInteractiveQuestionAnswered(this.questionId);

  final String questionId;

  @override
  List<Object?> get props => [questionId];
}

class LiveInteractiveTreasureBoxCreated extends LiveInteractiveEvent {
  const LiveInteractiveTreasureBoxCreated({
    required this.totalCoins,
    required this.maxClaims,
    this.delaySeconds,
  });

  final int totalCoins;
  final int maxClaims;
  final int? delaySeconds;

  @override
  List<Object?> get props => [totalCoins, maxClaims, delaySeconds];
}

class LiveInteractiveTreasureBoxClaimed extends LiveInteractiveEvent {
  const LiveInteractiveTreasureBoxClaimed(this.boxId);

  final String boxId;

  @override
  List<Object?> get props => [boxId];
}

class LiveInteractiveAuctionCreated extends LiveInteractiveEvent {
  const LiveInteractiveAuctionCreated({
    required this.itemName,
    required this.targetPrice,
    this.itemImageUrl,
    this.startingPrice,
  });

  final String itemName;
  final int targetPrice;
  final String? itemImageUrl;
  final int? startingPrice;

  @override
  List<Object?> get props => [itemName, targetPrice, itemImageUrl, startingPrice];
}

class LiveInteractiveAuctionPinToggled extends LiveInteractiveEvent {
  const LiveInteractiveAuctionPinToggled({
    required this.auctionId,
    required this.pinned,
  });

  final String auctionId;
  final bool pinned;

  @override
  List<Object?> get props => [auctionId, pinned];
}

class LiveInteractiveAuctionsReordered extends LiveInteractiveEvent {
  const LiveInteractiveAuctionsReordered(this.auctionIds);

  final List<String> auctionIds;

  @override
  List<Object?> get props => [auctionIds];
}

class LiveInteractiveSocketEventReceived extends LiveInteractiveEvent {
  const LiveInteractiveSocketEventReceived(this.payload);

  final LiveInteractiveSocketPayload payload;

  @override
  List<Object?> get props => [payload.event, payload.liveId, payload.payload];
}

class LiveInteractiveErrorCleared extends LiveInteractiveEvent {
  const LiveInteractiveErrorCleared();
}
