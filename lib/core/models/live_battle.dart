import 'package:equatable/equatable.dart';

/// Server-authoritative PK battle snapshot (`lives/mobile-api.md` section 12).
///
/// A battle connects two *different* live rooms. The score, phase and timer
/// come from Nest/Socket.IO; LiveKit is only responsible for the two videos.
class LiveBattle extends Equatable {
  const LiveBattle({
    required this.id,
    required this.live1Id,
    required this.live2Id,
    required this.live1Score,
    required this.live2Score,
    required this.status,
    required this.phase,
    this.multiplier = 1,
    this.multiplierEndsAt,
    this.startTime,
    this.endTime,
    this.winnerLiveId,
  });

  final String id;
  final String live1Id;
  final String live2Id;
  final int live1Score;
  final int live2Score;
  final String status;
  final String phase;
  final double multiplier;
  final DateTime? multiplierEndsAt;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? winnerLiveId;

  bool get isActive => status.toUpperCase() == 'ACTIVE';
  bool get isFinished => status.toUpperCase() == 'FINISHED';

  String opponentLiveId(String currentLiveId) =>
      live1Id == currentLiveId ? live2Id : live1Id;

  int scoreFor(String liveId) => live1Id == liveId ? live1Score : live2Score;

  int opponentScoreFor(String liveId) =>
      live1Id == liveId ? live2Score : live1Score;

  Duration remaining([DateTime? now]) {
    final end = endTime;
    if (end == null) return Duration.zero;
    final value = end.difference(now ?? DateTime.now());
    return value.isNegative ? Duration.zero : value;
  }

  factory LiveBattle.fromJson(Map<String, dynamic> json) {
    final nested = _map(json['battle']);
    final source = nested ?? json;
    return LiveBattle(
      id: source['id']?.toString() ?? '',
      live1Id: source['live1Id']?.toString() ?? '',
      live2Id: source['live2Id']?.toString() ?? '',
      live1Score: _integer(source['live1Score']),
      live2Score: _integer(source['live2Score']),
      status: source['status']?.toString() ?? 'ACTIVE',
      phase: source['phase']?.toString() ?? 'BATTLE',
      multiplier: _decimal(source['multiplier'], fallback: 1),
      multiplierEndsAt: _date(source['multiplierEndsAt']),
      startTime: _date(source['startTime']),
      endTime: _date(source['endTime']),
      winnerLiveId: source['winnerLiveId']?.toString(),
    );
  }

  LiveBattle copyWith({
    int? live1Score,
    int? live2Score,
    String? status,
    String? phase,
    double? multiplier,
    DateTime? multiplierEndsAt,
    DateTime? startTime,
    DateTime? endTime,
    String? winnerLiveId,
  }) {
    return LiveBattle(
      id: id,
      live1Id: live1Id,
      live2Id: live2Id,
      live1Score: live1Score ?? this.live1Score,
      live2Score: live2Score ?? this.live2Score,
      status: status ?? this.status,
      phase: phase ?? this.phase,
      multiplier: multiplier ?? this.multiplier,
      multiplierEndsAt: multiplierEndsAt ?? this.multiplierEndsAt,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      winnerLiveId: winnerLiveId ?? this.winnerLiveId,
    );
  }

  /// Keeps timing fields that partial multiplier/end responses omit.
  LiveBattle withTimingFrom(LiveBattle? previous) {
    if (previous == null || previous.id != id) return this;
    return copyWith(
      startTime: startTime ?? previous.startTime,
      endTime: endTime ?? previous.endTime,
      multiplierEndsAt: multiplierEndsAt ?? previous.multiplierEndsAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    live1Id,
    live2Id,
    live1Score,
    live2Score,
    status,
    phase,
    multiplier,
    multiplierEndsAt,
    startTime,
    endTime,
    winnerLiveId,
  ];
}

class LiveBattleOpponent extends Equatable {
  const LiveBattleOpponent({
    required this.liveId,
    required this.title,
    required this.hostId,
    required this.hostName,
    this.hostAvatar,
    this.viewers = 0,
  });

  final String liveId;
  final String title;
  final String hostId;
  final String hostName;
  final String? hostAvatar;
  final int viewers;

  factory LiveBattleOpponent.fromJson(Map<String, dynamic> json) {
    final live = _map(json['live']) ?? json;
    final user = _map(live['user']) ?? _map(live['host']) ?? const {};
    final fullName = user['fullName']?.toString().trim();
    final username = user['username']?.toString().trim();
    return LiveBattleOpponent(
      liveId: live['id']?.toString() ?? '',
      title: live['title']?.toString() ?? 'بث مباشر',
      hostId: user['id']?.toString() ?? live['userId']?.toString() ?? '',
      hostName: fullName?.isNotEmpty == true
          ? fullName!
          : (username?.isNotEmpty == true ? username! : 'مضيف'),
      hostAvatar:
          user['avatarUrl']?.toString() ??
          user['profilePicture']?.toString() ??
          live['coverUrl']?.toString(),
      viewers: _integer(live['viewers'] ?? live['viewerCount']),
    );
  }

  @override
  List<Object?> get props => [
    liveId,
    title,
    hostId,
    hostName,
    hostAvatar,
    viewers,
  ];
}

Map<String, dynamic>? _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

int _integer(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

double _decimal(Object? value, {double fallback = 0}) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? fallback;

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toLocal();
