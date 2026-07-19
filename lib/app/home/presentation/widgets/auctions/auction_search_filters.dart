import 'package:bimobondapp/app/categories/presentation/utils/category_lookup.dart';
import 'package:bimobondapp/app/posts/domain/entities/feed_auction_query.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_feed_usecase.dart';
import 'package:equatable/equatable.dart';

enum AuctionTimeRemainingFilter {
  any,
  endingWithin1Hour,
  endingWithin6Hours,
  endingWithin24Hours,
  endingWithin7Days,
  endingWithin30Days,
}

enum AuctionLiveStatusFilter {
  any,
  live,
  ended,
}

class AuctionSearchFilters extends Equatable {
  const AuctionSearchFilters({
    this.categoryIds = const {},
    this.minPriceUsd,
    this.maxPriceUsd,
    this.timeRemaining = AuctionTimeRemainingFilter.any,
    this.liveStatus = AuctionLiveStatusFilter.any,
  });

  final Set<String> categoryIds;
  final double? minPriceUsd;
  final double? maxPriceUsd;
  final AuctionTimeRemainingFilter timeRemaining;
  final AuctionLiveStatusFilter liveStatus;

  static const empty = AuctionSearchFilters();

  bool get hasActiveFilters =>
      categoryIds.isNotEmpty ||
      minPriceUsd != null ||
      maxPriceUsd != null ||
      timeRemaining != AuctionTimeRemainingFilter.any ||
      liveStatus != AuctionLiveStatusFilter.any;

  int get activeFilterCount {
    var count = categoryIds.length;
    if (minPriceUsd != null) count++;
    if (maxPriceUsd != null) count++;
    if (timeRemaining != AuctionTimeRemainingFilter.any) count++;
    if (liveStatus != AuctionLiveStatusFilter.any) count++;
    return count;
  }

  bool get needsClientCategoryFilter => categoryIds.length > 1;

  AuctionSearchFilters copyWith({
    Set<String>? categoryIds,
    double? minPriceUsd,
    bool clearMinPrice = false,
    double? maxPriceUsd,
    bool clearMaxPrice = false,
    AuctionTimeRemainingFilter? timeRemaining,
    AuctionLiveStatusFilter? liveStatus,
  }) {
    return AuctionSearchFilters(
      categoryIds: categoryIds ?? this.categoryIds,
      minPriceUsd: clearMinPrice ? null : (minPriceUsd ?? this.minPriceUsd),
      maxPriceUsd: clearMaxPrice ? null : (maxPriceUsd ?? this.maxPriceUsd),
      timeRemaining: timeRemaining ?? this.timeRemaining,
      liveStatus: liveStatus ?? this.liveStatus,
    );
  }

  AuctionSearchFilters cleared() => AuctionSearchFilters.empty;

  /// Filters excluding fixed ended/live status (for client-side ended scans).
  AuctionSearchFilters withoutLiveStatus() {
    return AuctionSearchFilters(
      categoryIds: categoryIds,
      minPriceUsd: minPriceUsd,
      maxPriceUsd: maxPriceUsd,
      // Time-remaining windows target future end dates; drop for ended scans.
      timeRemaining: AuctionTimeRemainingFilter.any,
    );
  }

  bool get hasUserFilters =>
      categoryIds.isNotEmpty ||
      minPriceUsd != null ||
      maxPriceUsd != null ||
      timeRemaining != AuctionTimeRemainingFilter.any;

  GetFeedParams toFeedParams({
    required int page,
    required int limit,
    String? search,
  }) {
    return GetFeedParams(
      page: page,
      limit: limit,
      categoryId: categoryIds.length == 1 ? categoryIds.first : null,
      search: search,
      isStory: false,
      auctionQuery: _toAuctionQuery(),
    );
  }

  /// Only used when multiple categories are selected (API supports one at a time).
  bool matchesClientCategory(PostEntity post) {
    if (!needsClientCategoryFilter) return true;
    return CategoryLookup.matchesId(post.categoryId, categoryIds);
  }

  bool matchesClientLiveStatus(PostEntity post) {
    if (liveStatus == AuctionLiveStatusFilter.any) return true;
    final auction = post.auction;
    if (auction == null) return false;

    return switch (liveStatus) {
      AuctionLiveStatusFilter.any => true,
      AuctionLiveStatusFilter.live => isPostLive(post),
      AuctionLiveStatusFilter.ended => isPostEnded(post),
    };
  }

  /// API / backend finished statuses (early close, sold, etc.).
  static bool isAuctionStatusEnded(String? status) {
    switch (status?.trim().toUpperCase()) {
      case 'ENDED':
      case 'FINISHED':
      case 'COMPLETED':
      case 'CLOSED':
        return true;
      default:
        return false;
    }
  }

  static bool isPostLive(PostEntity post) {
    if (isPostEnded(post)) return false;
    final auction = post.auction;
    if (auction == null) return false;
    final now = DateTime.now().toUtc();
    final startedAt = auction.startedAt.toUtc();
    final endedAt = auction.endedAt.toUtc();
    return !startedAt.isAfter(now) && endedAt.isAfter(now);
  }

  static bool isPostEnded(PostEntity post) {
    final auction = post.auction;
    if (auction == null) return false;
    if (isAuctionStatusEnded(auction.status)) return true;
    final now = DateTime.now().toUtc();
    return !auction.endedAt.toUtc().isAfter(now);
  }

  /// Client-side text match for title / description / host when API search
  /// is incomplete for ended auctions.
  static bool matchesSearchQuery(PostEntity post, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final auction = post.auction;
    final haystacks = <String?>[
      auction?.itemName,
      post.description,
      post.user?.username,
      post.user?.fullName,
    ];
    for (final value in haystacks) {
      final text = value?.trim().toLowerCase();
      if (text != null && text.isNotEmpty && text.contains(q)) {
        return true;
      }
    }
    return false;
  }

  FeedAuctionQuery _toAuctionQuery() {
    final now = DateTime.now().toUtc();
    DateTime? targetDateFrom;
    DateTime? targetDateTo;

    // Time-remaining filters only apply to live / upcoming auctions.
    if (liveStatus != AuctionLiveStatusFilter.ended &&
        timeRemaining != AuctionTimeRemainingFilter.any) {
      targetDateFrom = now;
      targetDateTo = now.add(_maxDurationFor(timeRemaining));
    }

    if (liveStatus == AuctionLiveStatusFilter.live) {
      targetDateFrom = targetDateFrom ?? now;
    }

    return FeedAuctionQuery(
      isAuctionable: true,
      priceLower: minPriceUsd,
      priceUpper: maxPriceUsd,
      targetDateFrom: targetDateFrom,
      targetDateTo: targetDateTo,
      auctionStatus: _auctionStatusForApi(),
      startedAtTo: switch (liveStatus) {
        AuctionLiveStatusFilter.live => now,
        // Avoid date windows that conflict with ENDED+search on some backends.
        AuctionLiveStatusFilter.ended => null,
        AuctionLiveStatusFilter.any => null,
      },
    );
  }

  String? _auctionStatusForApi() {
    return switch (liveStatus) {
      AuctionLiveStatusFilter.any => null,
      AuctionLiveStatusFilter.live => 'LIVE',
      AuctionLiveStatusFilter.ended => 'ENDED',
    };
  }

  Duration _maxDurationFor(AuctionTimeRemainingFilter filter) {
    switch (filter) {
      case AuctionTimeRemainingFilter.any:
        return const Duration(days: 36500);
      case AuctionTimeRemainingFilter.endingWithin1Hour:
        return const Duration(hours: 1);
      case AuctionTimeRemainingFilter.endingWithin6Hours:
        return const Duration(hours: 6);
      case AuctionTimeRemainingFilter.endingWithin24Hours:
        return const Duration(hours: 24);
      case AuctionTimeRemainingFilter.endingWithin7Days:
        return const Duration(days: 7);
      case AuctionTimeRemainingFilter.endingWithin30Days:
        return const Duration(days: 30);
    }
  }

  @override
  List<Object?> get props => [
        categoryIds,
        minPriceUsd,
        maxPriceUsd,
        timeRemaining,
        liveStatus,
      ];
}
