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
    this.mode = LiveBattleMode.solo,
    this.live3Id,
    this.live4Id,
    this.openSlots = const [],
    this.likeScore1,
    this.likeScore2,
    this.scoringMode,
    this.scoringGiftId,
    this.bestOf = 1,
    this.roundNumber,
    this.wins1,
    this.wins2,
    this.powerUps,
    this.hasRosterPayload = false,
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

  /// Solo (1v1) unless the server says `mode: "TEAM"`
  /// (`lives/live-p1-parity.md` §7).
  final LiveBattleMode mode;

  /// Team 1 is `live1Id` (captain) + [live3Id] (teammate);
  /// team 2 is `live2Id` (captain) + [live4Id].
  final String? live3Id;
  final String? live4Id;

  /// Teams with a free teammate slot, as the server reports them. Empty is not
  /// "full" — it is simply what the payload said.
  final List<int> openSlots;

  /// Heart taps per team. Null means the server did not send them; the UI
  /// shows nothing rather than a zero it invented.
  final int? likeScore1;
  final int? likeScore2;

  /// `ALL` | `GIFTS` | `LIKES` | `SPECIFIC_GIFT`, as sent.
  final String? scoringMode;
  final String? scoringGiftId;

  /// Best-of series (`1` default or `3`).
  final int bestOf;
  final int? roundNumber;
  final int? wins1;
  final int? wins2;
  final LiveBattlePowerUps? powerUps;

  /// True when the payload this snapshot came from actually carried roster
  /// fields (`mode`, `live3Id`, `live4Id` or `teams`).
  ///
  /// A `score` tick omits them, and merging such a tick must not clear a team
  /// that is still seated. It is deliberately not part of [props]: it describes
  /// the payload, not the battle.
  final bool hasRosterPayload;

  bool get isTeamMode => mode == LiveBattleMode.team;

  /// Every live currently seated in this battle, captains first.
  List<String> get participantLiveIds => [
    live1Id,
    live2Id,
    if (live3Id != null && live3Id!.isNotEmpty) live3Id!,
    if (live4Id != null && live4Id!.isNotEmpty) live4Id!,
  ].where((id) => id.isNotEmpty).toList(growable: false);

  /// 1 or 2 for a live seated in this battle, null for anyone else.
  int? teamOf(String liveId) {
    if (liveId.isEmpty) return null;
    if (liveId == live1Id || liveId == live3Id) return 1;
    if (liveId == live2Id || liveId == live4Id) return 2;
    return null;
  }

  /// The teammate sitting with [liveId], when the server seated one.
  String? teammateOf(String liveId) {
    final team = teamOf(liveId);
    if (team == null) return null;
    final captain = team == 1 ? live1Id : live2Id;
    final teammate = team == 1 ? live3Id : live4Id;
    final other = liveId == captain ? teammate : captain;
    return (other == null || other.isEmpty) ? null : other;
  }

  /// The two opposing lives of [liveId] — one in solo, up to two in TEAM.
  List<String> opponentLiveIds(String liveId) {
    final team = teamOf(liveId);
    if (team == null) return const [];
    final ids = team == 1
        ? [live2Id, live4Id]
        : [live1Id, live3Id];
    return ids
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  int scoreForTeam(int team) => team == 1 ? live1Score : live2Score;

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
      mode: LiveBattleMode.parse(source['mode']),
      live3Id: _seat(source, 'live3Id', teamKey: 'team1'),
      live4Id: _seat(source, 'live4Id', teamKey: 'team2'),
      openSlots: _teamSlots(source['openSlots']),
      likeScore1: _integerOrNull(source['likeScore1']),
      likeScore2: _integerOrNull(source['likeScore2']),
      scoringMode: _text(source['scoringMode']),
      scoringGiftId: _text(source['scoringGiftId']),
      bestOf: _integerOrNull(source['bestOf']) ?? 1,
      roundNumber: _integerOrNull(source['roundNumber']),
      wins1: _integerOrNull(source['wins1']),
      wins2: _integerOrNull(source['wins2']),
      powerUps: LiveBattlePowerUps.fromJson(_map(source['powerUps'])),
      hasRosterPayload:
          source.containsKey('mode') ||
          source.containsKey('live3Id') ||
          source.containsKey('live4Id') ||
          source.containsKey('teams'),
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
    LiveBattleMode? mode,
    String? live3Id,
    String? live4Id,
    List<int>? openSlots,
    int? likeScore1,
    int? likeScore2,
    String? scoringMode,
    String? scoringGiftId,
    int? bestOf,
    int? roundNumber,
    int? wins1,
    int? wins2,
    LiveBattlePowerUps? powerUps,
    bool? hasRosterPayload,
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
      mode: mode ?? this.mode,
      live3Id: live3Id ?? this.live3Id,
      live4Id: live4Id ?? this.live4Id,
      openSlots: openSlots ?? this.openSlots,
      likeScore1: likeScore1 ?? this.likeScore1,
      likeScore2: likeScore2 ?? this.likeScore2,
      scoringMode: scoringMode ?? this.scoringMode,
      scoringGiftId: scoringGiftId ?? this.scoringGiftId,
      bestOf: bestOf ?? this.bestOf,
      roundNumber: roundNumber ?? this.roundNumber,
      wins1: wins1 ?? this.wins1,
      wins2: wins2 ?? this.wins2,
      powerUps: powerUps ?? this.powerUps,
      hasRosterPayload: hasRosterPayload ?? this.hasRosterPayload,
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

    // A `score` tick carries no roster. Keeping the previous team seats stops
    // a 2v2 from collapsing into a 1v1 between two score updates.
    final keepRoster = !incoming.hasRosterPayload && previous.hasRosterPayload;
    return incoming
        .copyWith(
          status: incoming.status.isEmpty ? previous.status : incoming.status,
          startTime: incoming.startTime ?? previous.startTime,
          endTime: incoming.endTime ?? previous.endTime,
          multiplierEndsAt:
              incoming.multiplierEndsAt ?? previous.multiplierEndsAt,
          mode: keepRoster ? previous.mode : incoming.mode,
          live3Id: keepRoster ? previous.live3Id : incoming.live3Id,
          live4Id: keepRoster ? previous.live4Id : incoming.live4Id,
          openSlots: keepRoster ? previous.openSlots : incoming.openSlots,
          hasRosterPayload:
              incoming.hasRosterPayload || previous.hasRosterPayload,
          // Series state and scoring rules also only arrive on fuller payloads.
          scoringMode: incoming.scoringMode ?? previous.scoringMode,
          scoringGiftId: incoming.scoringGiftId ?? previous.scoringGiftId,
          bestOf: incoming.bestOf > 1 ? incoming.bestOf : previous.bestOf,
          roundNumber: incoming.roundNumber ?? previous.roundNumber,
          wins1: incoming.wins1 ?? previous.wins1,
          wins2: incoming.wins2 ?? previous.wins2,
          powerUps: incoming.powerUps ?? previous.powerUps,
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
    mode,
    live3Id,
    live4Id,
    openSlots,
    likeScore1,
    likeScore2,
    scoringMode,
    scoringGiftId,
    bestOf,
    roundNumber,
    wins1,
    wins2,
    powerUps,
  ];
}

/// `mode` on the battle object. Solo is the documented default when the field
/// is absent, so an unknown value never silently becomes TEAM.
enum LiveBattleMode {
  solo('SOLO'),
  team('TEAM');

  const LiveBattleMode(this.wireValue);
  final String wireValue;

  static LiveBattleMode parse(Object? value) =>
      value?.toString().trim().toUpperCase() == 'TEAM' ? team : solo;
}

/// Documented power-up types (`lives/live-p2-parity.md` §3).
class LiveBattlePowerUpType {
  const LiveBattlePowerUpType._();

  static const String stun = 'STUN';
  static const String time = 'TIME';
  static const String glove = 'GLOVE';

  static const List<String> values = [stun, time, glove];

  static bool isDocumented(String? type) =>
      values.contains(type?.trim().toUpperCase());
}

/// The `powerUps` block of a BO3 battle. Every field is nullable: an absent
/// value means the server said nothing, not that the effect is off.
class LiveBattlePowerUps extends Equatable {
  const LiveBattlePowerUps({
    this.stunTeam,
    this.stunEndsAt,
    this.gloveTeam,
    this.gloveCharges,
  });

  final int? stunTeam;
  final DateTime? stunEndsAt;
  final int? gloveTeam;
  final int? gloveCharges;

  static LiveBattlePowerUps? fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return null;
    return LiveBattlePowerUps(
      stunTeam: _integerOrNull(json['stunTeam']),
      stunEndsAt: _date(json['stunEndsAt']),
      gloveTeam: _integerOrNull(json['gloveTeam']),
      gloveCharges: _integerOrNull(json['gloveCharges']),
    );
  }

  /// A stun is only in effect while the server's own end time is in the future.
  bool stunActiveFor(int team, [DateTime? now]) {
    final ends = stunEndsAt;
    if (stunTeam != team || ends == null) return false;
    return ends.isAfter(now ?? DateTime.now());
  }

  @override
  List<Object?> get props => [stunTeam, stunEndsAt, gloveTeam, gloveCharges];
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

/// Reads a teammate seat from the flat `live3Id`/`live4Id` field, falling back
/// to the `teams` block. Returns null for an absent or empty slot — an empty
/// string would look like a seated live to callers.
String? _seat(
  Map<String, dynamic> source,
  String flatKey, {
  required String teamKey,
}) {
  final flat = _text(source[flatKey]);
  if (flat != null) return flat;
  final teams = _map(source['teams']);
  final team = teams == null ? null : _map(teams[teamKey]);
  return team == null ? null : _text(team['teammateLiveId']);
}

/// `openSlots` carries team numbers; anything outside 1/2 is dropped.
List<int> _teamSlots(Object? value) {
  if (value is! List) return const [];
  final slots = <int>[];
  for (final entry in value) {
    final parsed = _integerOrNull(entry);
    if (parsed == 1 || parsed == 2) slots.add(parsed!);
  }
  return List.unmodifiable(slots);
}

String? _text(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? _integerOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
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
