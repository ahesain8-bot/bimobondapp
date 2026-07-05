import 'dart:ui';

import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';

String formatAuctionPricingCoins(num value, Locale locale) {
  final text = value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);
  return LocaleFormatUtils.localizeDigits(text, locale);
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
