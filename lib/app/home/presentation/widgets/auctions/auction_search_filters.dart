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

class AuctionSearchFilters extends Equatable {
  const AuctionSearchFilters({
    this.categoryIds = const {},
    this.minPriceUsd,
    this.maxPriceUsd,
    this.timeRemaining = AuctionTimeRemainingFilter.any,
  });

  final Set<String> categoryIds;
  final double? minPriceUsd;
  final double? maxPriceUsd;
  final AuctionTimeRemainingFilter timeRemaining;

  static const empty = AuctionSearchFilters();

  bool get hasActiveFilters =>
      categoryIds.isNotEmpty ||
      minPriceUsd != null ||
      maxPriceUsd != null ||
      timeRemaining != AuctionTimeRemainingFilter.any;

  int get activeFilterCount {
    var count = categoryIds.length;
    if (minPriceUsd != null) count++;
    if (maxPriceUsd != null) count++;
    if (timeRemaining != AuctionTimeRemainingFilter.any) count++;
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
  }) {
    return AuctionSearchFilters(
      categoryIds: categoryIds ?? this.categoryIds,
      minPriceUsd: clearMinPrice ? null : (minPriceUsd ?? this.minPriceUsd),
      maxPriceUsd: clearMaxPrice ? null : (maxPriceUsd ?? this.maxPriceUsd),
      timeRemaining: timeRemaining ?? this.timeRemaining,
    );
  }

  AuctionSearchFilters cleared() => AuctionSearchFilters.empty;

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

  FeedAuctionQuery _toAuctionQuery() {
    final now = DateTime.now().toUtc();
    DateTime? targetDateFrom;
    DateTime? targetDateTo;

    if (timeRemaining != AuctionTimeRemainingFilter.any) {
      targetDateFrom = now;
      targetDateTo = now.add(_maxDurationFor(timeRemaining));
    }

    return FeedAuctionQuery(
      isAuctionable: true,
      priceLower: minPriceUsd,
      priceUpper: maxPriceUsd,
      targetDateFrom: targetDateFrom,
      targetDateTo: targetDateTo,
    );
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
      ];
}
