import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the same alpha ramp the overlay uses, over a stand-in "live feed",
/// so the softness of the transition can be eyeballed. Throwaway.
const _ramp = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0x00000000),
    Color(0x26000000),
    Color(0x8C000000),
    Color(0xFF000000),
    Color(0xFF000000),
  ],
  stops: [0.0, 0.12, 0.22, 0.34, 1.0],
);

/// Old behaviour for reference: no mask at all on a video stage.
Widget _stage({required bool masked}) {
  // Stand-in for the gift's own opaque frame (an MP4 has no alpha).
  const gift = DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1B5E20), Color(0xFF66BB6A), Color(0xFF2E7D32)],
      ),
    ),
    child: Center(
      child: Icon(Icons.pets, size: 140, color: Colors.white),
    ),
  );
  if (!masked) return gift;
  return ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (bounds) => _ramp.createShader(bounds),
    child: gift,
  );
}

void main() {
  testWidgets('dump blend preview', (tester) async {
    tester.view.physicalSize = const Size(760, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          child: Row(
            children: [
              for (final masked in <bool>[false, true])
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Stand-in for the live video behind the gift.
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF8D6E63),
                              Color(0xFF4E342E),
                              Color(0xFF212121),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 108,
                        height: 380,
                        child: _stage(masked: masked),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final boundary =
        tester.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first,
        );
    // `toImage()` needs the real rasterizer, so it must run outside the test's
    // fake-async zone; awaiting it directly just hangs until the 10min timeout.
    final out = File('${Directory.systemTemp.path}/gift_blend_preview.png');
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await out.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    // ignore: avoid_print
    print('PREVIEW: ${out.path}');
  });
}
