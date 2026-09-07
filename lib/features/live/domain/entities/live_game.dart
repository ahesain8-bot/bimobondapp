import 'package:equatable/equatable.dart';

/// Official in-LIVE games (`lives/live-p3-parity.md` §3).
///
/// The server owns every outcome: which wheel prize is picked, the lucky-draw
/// winner, and when a quiz answer becomes visible. Nothing here decides a
/// result locally, and an animation is never treated as one.

/// Documented types. Anything else is shown as unsupported rather than guessed.
enum LiveGameType {
  quiz('QUIZ'),
  wheel('WHEEL'),
  luckyDraw('LUCKY_DRAW'),
  unknown('UNKNOWN');

  const LiveGameType(this.wireValue);
  final String wireValue;

  static LiveGameType parse(String? value) {
    final upper = value?.trim().toUpperCase();
    for (final type in values) {
      if (type != unknown && type.wireValue == upper) return type;
    }
    return unknown;
  }
}

/// `ACTIVE` and `ENDED` are the two states the contract describes ("one ACTIVE
/// game per live", "close game"). Any other value stays unknown and is never
/// treated as playable.
enum LiveGameStatus {
  active('ACTIVE'),
  ended('ENDED'),
  unknown('UNKNOWN');

  const LiveGameStatus(this.wireValue);
  final String wireValue;

  static LiveGameStatus parse(String? value) {
    final upper = value?.trim().toUpperCase();
    for (final status in values) {
      if (status != unknown && status.wireValue == upper) return status;
    }
    return unknown;
  }
}

/// One entry of `GET /lives/games/catalog`.
class LiveGameCatalogEntry extends Equatable {
  const LiveGameCatalogEntry({
    required this.type,
    this.name = '',
    this.description,
    this.iconUrl,
  });

  final LiveGameType type;
  final String name;
  final String? description;
  final String? iconUrl;

  String get displayName => name.isNotEmpty ? name : type.wireValue;

  @override
  List<Object?> get props => [type, name, description, iconUrl];
}

/// One viewer's play in the active game.
class LiveGamePlay extends Equatable {
  const LiveGamePlay({
    required this.userId,
    this.username,
    this.avatarUrl,
    this.optionIndex,
    this.score,
    this.prize,
    this.isWinner = false,
  });

  final String userId;
  final String? username;
  final String? avatarUrl;

  /// Quiz answer. Null when the server withholds it.
  final int? optionIndex;

  /// Lucky-draw score. Null is unknown, not zero.
  final num? score;
  final String? prize;
  final bool isWinner;

  @override
  List<Object?> get props => [
    userId,
    username,
    avatarUrl,
    optionIndex,
    score,
    prize,
    isWinner,
  ];
}

/// The current game of a LIVE.
class LiveGame extends Equatable {
  const LiveGame({
    required this.id,
    required this.type,
    required this.status,
    this.question,
    this.options = const [],
    this.correctIndex,
    this.prizes = const [],
    this.plays = const [],
    this.myPlayed = false,
    this.myOptionIndex,
    this.winnerUserId,
    this.winnerName,
    this.resultPrize,
    this.playCount,
  });

  final String id;
  final LiveGameType type;
  final LiveGameStatus status;

  final String? question;
  final List<String> options;

  /// Quiz answer. The contract hides it until the host ends the game, so a
  /// null here means "not revealed yet", never "option 0".
  final int? correctIndex;

  final List<String> prizes;
  final List<LiveGamePlay> plays;

  /// Whether this viewer already played — one play per viewer.
  final bool myPlayed;
  final int? myOptionIndex;

  final String? winnerUserId;
  final String? winnerName;

  /// The wheel prize or lucky-draw result as the server reported it.
  final String? resultPrize;
  final int? playCount;

  bool get isActive => status == LiveGameStatus.active;
  bool get isEnded => status == LiveGameStatus.ended;

  /// A quiz answer is only shown once the server actually sent it.
  bool get answerRevealed => correctIndex != null;

  /// The viewer may play an active game of a supported type exactly once.
  bool get canPlay => isActive && !myPlayed && type != LiveGameType.unknown;

  LiveGame copyWith({
    LiveGameStatus? status,
    List<LiveGamePlay>? plays,
    bool? myPlayed,
    int? myOptionIndex,
    int? correctIndex,
    String? winnerUserId,
    String? winnerName,
    String? resultPrize,
    int? playCount,
  }) {
    return LiveGame(
      id: id,
      type: type,
      status: status ?? this.status,
      question: question,
      options: options,
      correctIndex: correctIndex ?? this.correctIndex,
      prizes: prizes,
      plays: plays ?? this.plays,
      myPlayed: myPlayed ?? this.myPlayed,
      myOptionIndex: myOptionIndex ?? this.myOptionIndex,
      winnerUserId: winnerUserId ?? this.winnerUserId,
      winnerName: winnerName ?? this.winnerName,
      resultPrize: resultPrize ?? this.resultPrize,
      playCount: playCount ?? this.playCount,
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    status,
    question,
    options,
    correctIndex,
    prizes,
    plays,
    myPlayed,
    myOptionIndex,
    winnerUserId,
    winnerName,
    resultPrize,
    playCount,
  ];
}
