import 'package:equatable/equatable.dart';

/// Documented tier slugs (`lives/live-p0-parity.md` §4). The host may price
/// them differently through `FanClubTier` rows, so a slug alone never implies
/// a price — the price always arrives from the server.
class FanClubTierSlug {
  const FanClubTierSlug._();

  static const String basic = 'BASIC';
  static const String plus = 'PLUS';
  static const String premium = 'PREMIUM';

  /// Documented order, cheapest first. Used to compare a viewer's tier with an
  /// emote's `minTier`; an unknown slug has no rank and unlocks nothing.
  static const List<String> ordered = [basic, plus, premium];

  static int? rank(String? slug) {
    final index = ordered.indexOf(slug?.trim().toUpperCase() ?? '');
    return index < 0 ? null : index;
  }

  /// True when [viewerSlug] is at least [minSlug]. Unknown on either side is
  /// false: never unlock a paid emote from an unrecognised value.
  static bool covers(String? viewerSlug, String? minSlug) {
    final viewer = rank(viewerSlug);
    if (viewer == null) return false;
    final min = rank(minSlug);
    if (min == null) return false;
    return viewer >= min;
  }
}

/// One purchasable tier of a creator's fan club.
///
/// [priceCoins] is null when the server did not send a price. The app then
/// shows the tier as unavailable instead of guessing a number — the P0 note
/// that PLUS is "3×" is a backend default, not something the client computes.
class FanClubTier extends Equatable {
  const FanClubTier({
    required this.slug,
    this.name = '',
    this.priceCoins,
    this.durationDays,
  });

  final String slug;
  final String name;
  final int? priceCoins;
  final int? durationDays;

  bool get isPurchasable => priceCoins != null && priceCoins! > 0;

  String get displayName => name.isNotEmpty ? name : slug;

  @override
  List<Object?> get props => [slug, name, priceCoins, durationDays];
}

/// A club emote. Only send emotes whose [minTier] the viewer's tier covers.
class FanClubEmote extends Equatable {
  const FanClubEmote({
    required this.code,
    this.imageUrl,
    this.minTier,
  });

  final String code;
  final String? imageUrl;
  final String? minTier;

  bool unlockedFor(String? viewerTierSlug) {
    // No documented minimum means the club made it available to every member.
    if (minTier == null || minTier!.trim().isEmpty) {
      return viewerTierSlug != null && viewerTierSlug.trim().isNotEmpty;
    }
    return FanClubTierSlug.covers(viewerTierSlug, minTier);
  }

  @override
  List<Object?> get props => [code, imageUrl, minTier];
}

/// The signed-in viewer's membership in this club (`membership` in the
/// documented `GET /creators/:id/fan-club` response).
class FanClubMembership extends Equatable {
  const FanClubMembership({
    this.tierSlug,
    this.loyalty,
    this.startDate,
    this.expiresAt,
  });

  final String? tierSlug;

  /// Loyalty badge from the server: `new`, `3`, `6` or `12` months. Kept as the
  /// server's own string so an unexpected value is displayed, not rounded.
  final String? loyalty;
  final String? startDate;
  final String? expiresAt;

  bool get isActive => tierSlug != null && tierSlug!.trim().isNotEmpty;

  @override
  List<Object?> get props => [tierSlug, loyalty, startDate, expiresAt];
}

/// Fan Club of a creator (lives/mobile-api.md §20, lives/live-p0-parity.md §4).
class FanClub extends Equatable {
  const FanClub({
    this.enabled = true,
    this.name = '',
    this.memberCount = 0,
    this.isMember = false,
    this.priceCoins,
    this.tiers = const [],
    this.emotes = const [],
    this.membership,
  });

  final bool enabled;
  final String name;
  final int memberCount;
  final bool isMember;

  /// `User.fanClubPriceCoins` — the BASIC price as the server reports it.
  final int? priceCoins;
  final List<FanClubTier> tiers;
  final List<FanClubEmote> emotes;
  final FanClubMembership? membership;

  /// Tiers the app may actually charge for: the server priced them.
  List<FanClubTier> get purchasableTiers =>
      tiers.where((t) => t.isPurchasable).toList(growable: false);

  /// True when the club is joinable but no tier carries a server price. The UI
  /// says so plainly instead of offering a purchase at an invented price.
  bool get hasUnpricedOffer => enabled && purchasableTiers.isEmpty;

  String? get myTierSlug => membership?.tierSlug;

  FanClubTier? tierBySlug(String slug) {
    final wanted = slug.trim().toUpperCase();
    for (final tier in tiers) {
      if (tier.slug.trim().toUpperCase() == wanted) return tier;
    }
    return null;
  }

  /// A same-or-higher active tier is a no-op on the server (`alreadyMember`),
  /// so the app does not send that purchase at all.
  bool alreadyCovers(String slug) =>
      FanClubTierSlug.covers(myTierSlug, slug) ||
      (myTierSlug?.trim().toUpperCase() == slug.trim().toUpperCase() &&
          (membership?.isActive ?? false));

  FanClub copyWith({
    bool? enabled,
    String? name,
    int? memberCount,
    bool? isMember,
    int? priceCoins,
    List<FanClubTier>? tiers,
    List<FanClubEmote>? emotes,
    FanClubMembership? membership,
  }) {
    return FanClub(
      enabled: enabled ?? this.enabled,
      name: name ?? this.name,
      memberCount: memberCount ?? this.memberCount,
      isMember: isMember ?? this.isMember,
      priceCoins: priceCoins ?? this.priceCoins,
      tiers: tiers ?? this.tiers,
      emotes: emotes ?? this.emotes,
      membership: membership ?? this.membership,
    );
  }

  @override
  List<Object?> get props => [
    enabled,
    name,
    memberCount,
    isMember,
    priceCoins,
    tiers,
    emotes,
    membership,
  ];
}

/// A single member of a fan club.
class FanClubMember extends Equatable {
  const FanClubMember({
    required this.userId,
    this.fullName = '',
    this.username = '',
    this.avatarUrl,
    this.isVerified = false,
    this.joinedAt,
    this.tierSlug,
    this.loyalty,
  });

  final String userId;
  final String fullName;
  final String username;
  final String? avatarUrl;
  final bool isVerified;
  final String? joinedAt;
  final String? tierSlug;
  final String? loyalty;

  String get displayName => fullName.isNotEmpty ? fullName : username;

  @override
  List<Object?> get props => [
    userId,
    fullName,
    username,
    avatarUrl,
    isVerified,
    joinedAt,
    tierSlug,
    loyalty,
  ];
}

/// A fan club the signed-in user has joined.
class FanClubSubscription extends Equatable {
  const FanClubSubscription({
    this.creatorId = '',
    this.name = '',
    this.memberCount = 0,
    this.isMember = true,
    this.tierSlug,
    this.loyalty,
  });

  final String creatorId;
  final String name;
  final int memberCount;
  final bool isMember;
  final String? tierSlug;
  final String? loyalty;

  @override
  List<Object?> get props => [
    creatorId,
    name,
    memberCount,
    isMember,
    tierSlug,
    loyalty,
  ];
}

/// Outcome of `POST /creators/:id/fan-club/subscribe`.
///
/// [alreadyMember] is the documented no-op for a same-or-higher active tier:
/// nothing was charged.
class FanClubSubscribeResult extends Equatable {
  const FanClubSubscribeResult({
    this.alreadyMember = false,
    this.membership,
  });

  final bool alreadyMember;
  final FanClubMembership? membership;

  @override
  List<Object?> get props => [alreadyMember, membership];
}

/// Raised before any request when the chosen tier has no server-sent price.
/// Money is never spent on a locally derived number.
class FanClubPriceUnverified implements Exception {
  const FanClubPriceUnverified(this.tierSlug);

  final String tierSlug;

  @override
  String toString() =>
      'This membership has no price from the server yet, so it cannot be '
      'purchased. ($tierSlug)';
}
