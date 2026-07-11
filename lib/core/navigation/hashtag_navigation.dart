import 'package:bimobondapp/core/navigation/feed_navigation.dart';
import 'package:flutter/material.dart';

/// Opens the hashtag feed for [tagName] (with or without `#` prefix).
void openHashtagFeed(BuildContext context, String tagName) {
  var normalized = tagName.trim();
  if (normalized.startsWith('#')) {
    normalized = normalized.substring(1);
  }
  normalized = normalized.toLowerCase();
  if (normalized.isEmpty) return;

  context.pushFromFeed(
    'hashtag_feed',
    queryParameters: {'name': normalized},
  );
}
