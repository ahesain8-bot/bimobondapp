import '../../domain/entities/fan_club.dart';
import '../../domain/repositories/fan_club_repository.dart';
import '../datasources/fan_club_remote_datasource.dart';

/// Remote Fan Club repository backed by Nest `/creators/:id/fan-club`.
class FanClubRepositoryImpl implements FanClubRepository {
  FanClubRepositoryImpl({required FanClubRemoteDataSource remote})
    : _remote = remote;

  final FanClubRemoteDataSource _remote;

  @override
  Future<FanClub> getClub(String creatorId) async {
    final json = await _remote.getClub(creatorId);
    final nested = json['club'] is Map ? json['club'] as Map : null;
    final map = nested is Map<String, dynamic>
        ? Map<String, dynamic>.from(nested)
        : json;
    return FanClub(
      enabled: map['enabled'] as bool? ?? true,
      name: map['name']?.toString() ?? '',
      memberCount: _asInt(map['memberCount'] ?? map['membersCount']) ?? 0,
      isMember: map['isMember'] as bool? ?? false,
    );
  }

  @override
  Future<FanClub> updateClub(
    String creatorId, {
    bool? enabled,
    String? name,
  }) async {
    final json = await _remote.updateClub(
      creatorId,
      enabled: enabled,
      name: name,
    );
    final nested = json['club'] is Map ? json['club'] as Map : null;
    final map = nested is Map<String, dynamic>
        ? Map<String, dynamic>.from(nested)
        : json;
    return FanClub(
      enabled: map['enabled'] as bool? ?? enabled ?? true,
      name:
          map['name']?.toString() ??
          (name != null && name.trim().isNotEmpty ? name.trim() : ''),
      memberCount: _asInt(map['memberCount'] ?? map['membersCount']) ?? 0,
      isMember: map['isMember'] as bool? ?? false,
    );
  }

  @override
  Future<void> subscribe(String creatorId) async {
    await _remote.subscribe(creatorId);
  }

  @override
  Future<void> unsubscribe(String creatorId) async {
    await _remote.unsubscribe(creatorId);
  }

  @override
  Future<List<FanClubMember>> members(String creatorId) async {
    final json = await _remote.members(creatorId);
    final raw =
        json['data'] ?? json['members'] ?? json['items'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (e) => _memberFromJson(Map<String, dynamic>.from(e)),
        )
        .toList(growable: false);
  }

  @override
  Future<List<FanClubSubscription>> myClubs() async {
    final json = await _remote.myClubs();
    final raw = json['data'] ?? json['items'] ?? json['clubs'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) {
          final map = Map<String, dynamic>.from(e);
          final club = map['club'] is Map
              ? Map<String, dynamic>.from(map['club'] as Map)
              : map;
          final creator =
              map['creator'] is Map
                  ? Map<String, dynamic>.from(map['creator'] as Map)
                  : club;
          return FanClubSubscription(
            creatorId:
                creator['id']?.toString() ??
                map['creatorId']?.toString() ??
                '',
            name: club['name']?.toString() ?? '',
            memberCount:
                _asInt(club['memberCount'] ?? club['membersCount']) ?? 0,
            isMember: map['isMember'] as bool? ?? true,
          );
        })
        .toList(growable: false);
  }

  FanClubMember _memberFromJson(Map<String, dynamic> json) {
    final user =
        json['user'] is Map
            ? Map<String, dynamic>.from(json['user'] as Map)
            : json;
    return FanClubMember(
      userId:
          user['id']?.toString() ??
          json['userId']?.toString() ??
          '',
      fullName: user['fullName']?.toString() ?? '',
      username: user['username']?.toString() ?? '',
      avatarUrl: user['avatarUrl']?.toString(),
      isVerified: user['isVerified'] as bool? ?? false,
      joinedAt: json['joinedAt']?.toString(),
    );
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
