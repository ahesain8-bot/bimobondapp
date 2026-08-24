import 'dart:ui' as ui;

import 'package:bimobondapp/core/utils/live_feed_fade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Paints [shader] into a 1-px-wide strip and reads back the alpha column, so
/// the test asserts on what the feed actually looks like rather than on the
/// gradient stops that produced it.
Future<List<int>> alphaColumn(Shader shader, double height) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final rect = Rect.fromLTWH(0, 0, 1, height);
  canvas.drawRect(rect, Paint()..color = Colors.black);
  canvas.saveLayer(rect, Paint()..blendMode = BlendMode.dstIn);
  canvas.drawRect(rect, Paint()..shader = shader);
  canvas.restore();
  final image = await recorder.endRecording().toImage(1, height.round());
  final data = await image.toByteData();
  return [for (var y = 0; y < height.round(); y++) data!.getUint8(y * 4 + 3)];
}

void main() {
  test('a feed shorter than its slot is not faded at all', () async {
    // The reported bug: one comment in a shrink-wrapped feed had the top of
    // its name row dissolved, because the fade was a fraction of the box.
    final shader = liveFeedFadeShader(
      const Rect.fromLTWH(0, 0, 1, 80),
      scrollableHeight: 280,
    );

    final alpha = await alphaColumn(shader, 80);

    expect(
      alpha.every((a) => a == 255),
      isTrue,
      reason: 'nothing has scrolled off the top, so nothing may be dimmed',
    );
  });

  test('a full feed still dissolves its oldest lines', () async {
    final shader = liveFeedFadeShader(
      const Rect.fromLTWH(0, 0, 1, 280),
      scrollableHeight: 280,
    );

    final alpha = await alphaColumn(shader, 280);

    expect(alpha.first, lessThan(20), reason: 'top edge fades out');
    expect(alpha.last, 255, reason: 'newest line stays fully opaque');
  });

  test('the fade never eats more than a fifth of a short slot', () async {
    // PK and multi-guest rooms hand the feed as little as 40px; the old
    // 36px band left almost nothing readable.
    const height = 40.0;
    final shader = liveFeedFadeShader(
      const Rect.fromLTWH(0, 0, 1, height),
      scrollableHeight: height,
    );

    final alpha = await alphaColumn(shader, height);
    final dimmed = alpha.where((a) => a < 250).length;

    expect(
      dimmed / height,
      lessThanOrEqualTo(kLiveFeedFadeMaxFraction + 0.05),
      reason: 'most of a short feed must stay readable',
    );
  });

  test('the band is measured in pixels, not as a share of the box', () async {
    final short = await alphaColumn(
      liveFeedFadeShader(
        const Rect.fromLTWH(0, 0, 1, 200),
        scrollableHeight: 200,
      ),
      200,
    );
    final tall = await alphaColumn(
      liveFeedFadeShader(
        const Rect.fromLTWH(0, 0, 1, 400),
        scrollableHeight: 400,
      ),
      400,
    );

    final shortBand = short.where((a) => a < 250).length;
    final tallBand = tall.where((a) => a < 250).length;

    expect(
      (shortBand - tallBand).abs(),
      lessThanOrEqualTo(4),
      reason: 'doubling the feed height must not double the faded band',
    );
  });

  test('a zero-height feed does not throw', () async {
    expect(
      () => liveFeedFadeShader(const Rect.fromLTWH(0, 0, 1, 0)),
      returnsNormally,
    );
  });
}
