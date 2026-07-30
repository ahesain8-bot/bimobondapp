import 'dart:ui';

import 'package:bimobondapp/app/posts/domain/entities/post_auction_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';

String formatAuctionPricingCoins(num value, Locale locale) {
  final text = value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);
  return LocaleFormatUtils.localizeDigits(text, locale);
}

/// Coin goal for the target segment on auction price cards.
///
/// Uses the same coin basis as [PostAuctionEntity.displayHighestPriceCoins]
/// (host earnings / gift total goal), not bidder spend estimates.
int? resolveAuctionTargetPriceCoins(
  PostAuctionEntity? auction, {
  int? overrideCoins,
}) {
  if (overrideCoins != null && overrideCoins > 0) return overrideCoins;
  if (auction == null) return null;
  if (auction.targetPriceCoins > 0) return auction.targetPriceCoins;

  final hostGoal = auction.pricing?.estimatedHostEarningsCoins;
  if (hostGoal != null && hostGoal > 0) return hostGoal;

  final rate = auction.pricing?.coinsPerPriceUnit ?? 0;
  if (rate > 0 && auction.targetPrice > 0) {
    return (auction.targetPrice * rate).round();
  }
  return null;
}

/// Same `{amount} {currency}` pattern as the highest-price row on the card.
String formatAuctionLiveCoinsLabel(
  AppLocalizations l10n,
  Locale locale,
  int coins,
) {
  return l10n.liveHighestBidAmount(
    formatAuctionPricingCoins(coins, locale),
    l10n.coinsUnit,
  );
}

String? formatAuctionTargetPriceLabel({
  required PostAuctionEntity? auction,
  required AppLocalizations l10n,
  required Locale locale,
  int? overrideCoins,
}) {
  final coins = resolveAuctionTargetPriceCoins(
    auction,
    overrideCoins: overrideCoins,
  );
  if (coins == null || coins <= 0) return null;
  return formatAuctionLiveCoinsLabel(l10n, locale, coins);
}

/// Ordered media items for auction detail screens (images and videos).
List<PostMediaEntity> resolveAuctionDisplayMedia(PostEntity post) {
  final items = <PostMediaEntity>[];
  final seen = <String>{};

  void addItem(String url, String mediaType, int order) {
    final resolved = MediaUtils.resolveAbsoluteUrl(url);
    if (resolved.isEmpty || seen.contains(resolved)) return;
    seen.add(resolved);
    items.add(
      PostMediaEntity(url: resolved, mediaType: mediaType, order: order),
    );
  }

  final sortedMedia = [...post.media]
    ..sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
  for (final item in sortedMedia) {
    if (item.url.isEmpty) continue;
    addItem(item.url, item.mediaType, item.order ?? items.length);
  }

  if (items.isEmpty) {
    final videoUrl = post.videoUrl ?? post.hlsUrl;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      addItem(videoUrl, 'VIDEO', 0);
    }
  }

  if (items.isEmpty) {
    final auctionImage = post.auction?.itemImageUrl;
    if (auctionImage != null && auctionImage.isNotEmpty) {
      addItem(auctionImage, 'IMAGE', 0);
    }
  }

  if (items.isEmpty) {
    final thumb = post.thumbnailUrl;
    if (thumb != null && thumb.isNotEmpty) {
      addItem(thumb, 'IMAGE', 0);
    }
  }

  return items;
}
