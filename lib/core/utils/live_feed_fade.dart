import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Height of the band at the top of a live comment feed where older lines
/// dissolve instead of ending on a hard cut against the video.
const double kLiveFeedFadeHeight = 28;

/// Never let the fade eat more than this share of the feed, however short the
/// slot is. A PK or multi-guest room can hand the feed 40 logical pixels, and a
/// fixed 28px band there would have swallowed most of the newest comment.
const double kLiveFeedFadeMaxFraction = 0.22;

/// Builds the `dstIn` shader that dissolves older lines at the top of a feed.
///
/// [bounds] is the box actually painted, and [scrollableHeight] is the largest
/// the feed is allowed to grow. When the content is shorter than that limit
/// nothing has scrolled off the top, so there is nothing to dissolve and the
/// feed is left fully opaque — the previous version faded a fixed *fraction*
/// of a shrink-wrapped box, so with only one or two comments on screen it cut
/// the top off the newest one.
Shader liveFeedFadeShader(Rect bounds, {double? scrollableHeight}) {
  final height = bounds.height;
  final fits = scrollableHeight == null || height < scrollableHeight - 0.5;
  if (height <= 0 || fits) {
    return const LinearGradient(
      colors: [Colors.black, Colors.black],
    ).createShader(bounds);
  }

  final band = math.min(kLiveFeedFadeHeight, height * kLiveFeedFadeMaxFraction);
  final stop = (band / height).clamp(0.0, 1.0);
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: const [Colors.transparent, Colors.black, Colors.black],
    stops: [0.0, stop, 1.0],
  ).createShader(bounds);
}
