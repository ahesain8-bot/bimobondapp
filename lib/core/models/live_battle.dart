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

  bool get isActive {
    final s = status.toUpperCase();
    if (s == 'FINISHED' || s == 'ENDED' || s == 'CANCELLED') return false;
    if (_isTerminalPhase(phase)) return false;
    return s == 'ACTIVE';
  }

  bool get isFinished {
    final s = status.toUpperCase();
    return s == 'FINISHED' ||
        s == 'ENDED' ||
        s == 'CANCELLED' ||
        _isTerminalPhase(phase);
  }

  static bool _isTerminalPhase(String phase) {
    switch (phase.toUpperCase()) {
      case 'RESULT':
      case 'RESULTS':
      case 'ENDED':
      case 'FINISHED':
      case 'VICTORY_LAP':
      case 'VICTORY':
      case 'DEFEAT':
        return true;
      default:
        return false;
    }
  }

  /// Marks a snapshot as finished when the socket/API only signals end via
  /// [type] or a terminal [phase] without a FINISHED status.
  LiveBattle normalizedForUpdate({String? updateType}) {
    final type = (updateType ?? '').toLowerCase();
    final typeSaysEnded =
        type.contains('finish') ||
        type == 'ended' ||
        type == 'end' ||
        type == 'result' ||
        type == 'results';
    if (typeSaysEnded || _isTerminalPhase(phase)) {
      if (status.toUpperCase() == 'FINISHED') return this;
      return copyWith(status: 'FINISHED');
    }
    return this;
  }

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
      // Missing status is not proof that a battle started. Treating any stale
      // battle object as ACTIVE is what made accepted guests open the PK UI.
      status: source['status']?.toString() ?? '',
      phase: source['phase']?.toString() ?? 'BATTLE',
      multiplier: _decimal(source['multiplier'], fallback: 1),
      multiplierEndsAt: _date(source['multiplierEndsAt']),
      startTime: _date(source['startTime']),
      endTime: _date(source['endTime']),
      winnerLiveId: source['winnerLiveId']?.toString(),
    ).normalizedForUpdate();
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
  ///
  /// Never resurrects a finished battle from a score tick that omitted
  /// `status`, and never keeps ACTIVE when the new phase/type says ended.
  LiveBattle withTimingFrom(LiveBattle? previous, {String? updateType}) {
    final incoming = normalizedForUpdate(updateType: updateType);
    if (previous == null || previous.id != incoming.id) return incoming;

    // Finished snapshots win over partial ACTIVE leftovers.
    if (incoming.isFinished) return incoming;
    if (previous.isFinished && incoming.status.isEmpty) {
      return previous.normalizedForUpdate();
    }

    return incoming
        .copyWith(
          status: incoming.status.isEmpty ? previous.status : incoming.status,
          startTime: incoming.startTime ?? previous.startTime,
          endTime: incoming.endTime ?? previous.endTime,
          multiplierEndsAt:
              incoming.multiplierEndsAt ?? previous.multiplierEndsAt,
        )
        .normalizedForUpdate(updateType: updateType);
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
    // Prefer a nested `live` only when it actually carries an id. An empty
    // `{}` wrapper used to steal the flat payload and drop every opponent.
    final nested = _map(json['live']);
    final nestedId = nested == null
        ? null
        : (nested['id'] ?? nested['liveId'])?.toString();
    final live = (nested != null && nestedId != null && nestedId.isNotEmpty)
        ? nested
        : json;
    final user =
        _map(live['user']) ??
        _map(live['host']) ??
        _map(json['user']) ??
        _map(json['host']) ??
        const {};
    final fullName = user['fullName']?.toString().trim();
    final username = user['username']?.toString().trim();
    final liveId =
        live['id']?.toString() ??
        live['liveId']?.toString() ??
        json['id']?.toString() ??
        json['liveId']?.toString() ??
        json['opponentLiveId']?.toString() ??
        '';
    return LiveBattleOpponent(
      liveId: liveId,
      title: live['title']?.toString() ?? json['title']?.toString() ?? 'بث مباشر',
      hostId:
          user['id']?.toString() ??
          live['userId']?.toString() ??
          json['userId']?.toString() ??
          '',
      hostName: fullName?.isNotEmpty == true
          ? fullName!
          : (username?.isNotEmpty == true ? username! : 'مضيف'),
      hostAvatar:
          user['avatarUrl']?.toString() ??
          user['profilePicture']?.toString() ??
          live['coverUrl']?.toString() ??
          json['coverUrl']?.toString(),
      viewers: _integer(
        live['viewers'] ?? live['viewerCount'] ?? json['viewers'],
      ),
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
