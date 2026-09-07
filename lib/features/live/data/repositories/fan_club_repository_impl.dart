import '../../domain/entities/fan_club.dart';
import '../../domain/repositories/fan_club_repository.dart';
import '../datasources/fan_club_remote_datasource.dart';

/// Remote Fan Club repository backed by Nest `/creators/:id/fan-club`.
///
/// Every price rendered or charged comes from the server. When a tier arrives
/// without a price the tier stays unbuyable — the "PLUS = 3×" note in
/// `lives/live-p0-parity.md` describes a backend default, not client maths.
class FanClubRepositoryImpl implements FanClubRepository {
  FanClubRepositoryImpl({required FanClubRemoteDataSource remote})
    : _remote = remote;

  final FanClubRemoteDataSource _remote;

  @override
  Future<FanClub> getClub(String creatorId) async {
    return _clubFromPayload(await _remote.getClub(creatorId));
  }

  @override
  Future<FanClub> updateClub(
    String creatorId, {
    bool? enabled,
    String? name,
    int? priceCoins,
  }) async {
    final json = await _remote.updateClub(
      creatorId,
      enabled: enabled,
      name: name,
      priceCoins: priceCoins,
    );
    final club = _clubFromPayload(json);
    // A PATCH response that echoes nothing must not blank the host's own edit.
    return club.copyWith(
      enabled: club.enabled,
      name: club.name.isNotEmpty
          ? club.name
          : (name != null && name.trim().isNotEmpty ? name.trim() : ''),
      priceCoins: club.priceCoins ?? priceCoins,
    );
  }

  @override
  Future<FanClubSubscribeResult> subscribe(
    String creatorId, {
    required String tierSlug,
    required int expectedPriceCoins,
  }) async {
    if (expectedPriceCoins <= 0) {
      // Reached only if a caller skipped the tier check; refuse to spend.
      throw FanClubPriceUnverified(tierSlug);
    }
    final json = await _remote.subscribe(creatorId, tierSlug: tierSlug);
    final map = _unwrap(json);
    final membership = _membershipFromJson(
      map['membership'] ?? json['membership'],
    );
    return FanClubSubscribeResult(
      alreadyMember:
          map['alreadyMember'] == true || json['alreadyMember'] == true,
      membership: membership,
    );
  }

  @override
  Future<void> unsubscribe(String creatorId) async {
    await _remote.unsubscribe(creatorId);
  }

  @override
  Future<FanClub> addEmote(
    String creatorId, {
    required String code,
    required String imageUrl,
    String? minTier,
  }) async {
    await _remote.addEmote(
      creatorId,
      code: code,
      imageUrl: imageUrl,
      minTier: minTier,
    );
    // The POST response shape for one emote is not documented, so the club is
    // re-read instead of patching a local list from a guessed envelope.
    return getClub(creatorId);
  }

  @override
  Future<List<FanClubMember>> members(String creatorId) async {
    final json = await _remote.members(creatorId);
    final raw = json['data'] ?? json['members'] ?? json['items'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => _memberFromJson(Map<String, dynamic>.from(e)))
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
          final creator = map['creator'] is Map
              ? Map<String, dynamic>.from(map['creator'] as Map)
              : club;
          final membership = _membershipFromJson(map['membership']);
          return FanClubSubscription(
            creatorId:
                creator['id']?.toString() ?? map['creatorId']?.toString() ?? '',
            name: club['name']?.toString() ?? '',
            memberCount:
                _asInt(club['memberCount'] ?? club['membersCount']) ?? 0,
            isMember: map['isMember'] as bool? ?? true,
            tierSlug:
                membership?.tierSlug ?? _string(map['tierSlug'] ?? map['tier']),
            loyalty: membership?.loyalty ?? _string(map['loyalty']),
          );
        })
        .toList(growable: false);
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    final nested = json['club'] ?? json['fanClub'] ?? json['data'];
    if (nested is Map) return Map<String, dynamic>.from(nested);
    return json;
  }

  FanClub _clubFromPayload(Map<String, dynamic> json) {
    final map = _unwrap(json);
    final membership = _membershipFromJson(
      map['membership'] ?? json['membership'],
    );
    final tiers = _tiersFromJson(map['tiers'] ?? json['tiers']);
    final basicPrice = _asInt(
      map['priceCoins'] ?? map['fanClubPriceCoins'] ?? json['priceCoins'],
    );
    return FanClub(
      enabled: map['enabled'] as bool? ?? true,
      name: map['name']?.toString() ?? '',
      memberCount: _asInt(map['memberCount'] ?? map['membersCount']) ?? 0,
      isMember:
          map['isMember'] as bool? ??
          json['isMember'] as bool? ??
          (membership?.isActive ?? false),
      priceCoins: basicPrice,
      tiers: _withBasicPrice(tiers, basicPrice),
      emotes: _emotesFromJson(map['emotes'] ?? json['emotes']),
      membership: membership,
    );
  }

  /// `User.fanClubPriceCoins` is the documented BASIC price. It fills in only
  /// when the tier list itself carried no price for BASIC.
  List<FanClubTier> _withBasicPrice(List<FanClubTier> tiers, int? basicPrice) {
    if (basicPrice == null || basicPrice <= 0) return tiers;
    if (tiers.isEmpty) {
      return [FanClubTier(slug: FanClubTierSlug.basic, priceCoins: basicPrice)];
    }
    return tiers
        .map(
          (t) =>
              t.slug.toUpperCase() == FanClubTierSlug.basic &&
                  t.priceCoins == null
              ? FanClubTier(
                  slug: t.slug,
                  name: t.name,
                  priceCoins: basicPrice,
                  durationDays: t.durationDays,
                )
              : t,
        )
        .toList(growable: false);
  }

  List<FanClubTier> _tiersFromJson(dynamic raw) {
    if (raw is! List) return const [];
    final tiers = <FanClubTier>[];
    for (final entry in raw.whereType<Map>()) {
      final map = Map<String, dynamic>.from(entry);
      final slug = _string(map['slug'] ?? map['tierSlug'] ?? map['tier']);
      if (slug == null || slug.isEmpty) continue;
      tiers.add(
        FanClubTier(
          slug: slug.toUpperCase(),
          name: _string(map['name'] ?? map['title']) ?? '',
          priceCoins: _positiveInt(map['priceCoins'] ?? map['coins']),
          durationDays: _positiveInt(map['durationDays'] ?? map['days']),
        ),
      );
    }
    // Documented order first, anything unrecognised keeps server order after.
    tiers.sort((a, b) {
      final ra = FanClubTierSlug.rank(a.slug) ?? FanClubTierSlug.ordered.length;
      final rb = FanClubTierSlug.rank(b.slug) ?? FanClubTierSlug.ordered.length;
      return ra.compareTo(rb);
    });
    return List.unmodifiable(tiers);
  }

  List<FanClubEmote> _emotesFromJson(dynamic raw) {
    if (raw is! List) return const [];
    final emotes = <FanClubEmote>[];
    for (final entry in raw.whereType<Map>()) {
      final map = Map<String, dynamic>.from(entry);
      final code = _string(map['code'] ?? map['name']);
      if (code == null || code.isEmpty) continue;
      emotes.add(
        FanClubEmote(
          code: code,
          imageUrl: _string(map['imageUrl'] ?? map['url']),
          minTier: _string(map['minTier'] ?? map['tierSlug'])?.toUpperCase(),
        ),
      );
    }
    return List.unmodifiable(emotes);
  }

  FanClubMembership? _membershipFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final tier = _string(map['tierSlug'] ?? map['tier'])?.toUpperCase();
    final loyalty = _string(map['loyalty'] ?? map['loyaltyBadge']);
    final start = _string(map['startDate'] ?? map['startedAt']);
    final expires = _string(map['expiresAt'] ?? map['endDate']);
    if (tier == null && loyalty == null && start == null && expires == null) {
      return null;
    }
    return FanClubMembership(
      tierSlug: tier,
      loyalty: loyalty,
      startDate: start,
      expiresAt: expires,
    );
  }

  FanClubMember _memberFromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : json;
    final membership = _membershipFromJson(json['membership']);
    return FanClubMember(
      userId: user['id']?.toString() ?? json['userId']?.toString() ?? '',
      fullName: user['fullName']?.toString() ?? '',
      username: user['username']?.toString() ?? '',
      avatarUrl: user['avatarUrl']?.toString(),
      isVerified: user['isVerified'] as bool? ?? false,
      joinedAt: json['joinedAt']?.toString(),
      tierSlug:
          membership?.tierSlug ??
          _string(json['tierSlug'] ?? json['tier'])?.toUpperCase(),
      loyalty: membership?.loyalty ?? _string(json['loyalty']),
    );
  }

  String? _string(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  int? _positiveInt(dynamic value) {
    final parsed = _asInt(value);
    return parsed != null && parsed > 0 ? parsed : null;
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
