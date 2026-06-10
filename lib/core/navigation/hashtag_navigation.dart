import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Opens the hashtag feed for [tagName] (with or without `#` prefix).
void openHashtagFeed(BuildContext context, String tagName) {
  var normalized = tagName.trim();
  if (normalized.startsWith('#')) {
    normalized = normalized.substring(1);
  }
  normalized = normalized.toLowerCase();
  if (normalized.isEmpty) return;

  context.pushNamed(
    'hashtag_feed',
    queryParameters: {'name': normalized},
  );
}
