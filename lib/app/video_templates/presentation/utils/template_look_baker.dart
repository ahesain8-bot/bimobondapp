import 'dart:io';
import 'dart:ui' as ui;

import 'package:bimobondapp/app/video_templates/composition/template_composition_engine.dart';
import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/engine/layers/layer_engines.dart';
import 'package:bimobondapp/app/video_templates/engine/render/render_engine.dart';
import 'package:bimobondapp/app/video_templates/engine/slot/slot_engine.dart';
import 'package:bimobondapp/app/video_templates/presentation/utils/template_preview_look.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/utils/native_video_processor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Alignment;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Bakes the **same** look as [VideoTemplateComposedPreview] into stills.
///
/// Uses [TemplateCompositionEngine.sample] / [PreviewFrame] so filters, effects,
/// texts, stickers, and overlays match the live preview — not a parallel path.
class TemplateLookBaker {
  TemplateLookBaker._();

  /// Bake [input] with the recipe look at [timeSeconds] (slot mid-point).
  /// Returns null when look rasterization fails (never silently returns the raw still).
  static Future<File?> bakeImageFile({
    required File input,
    required VideoTemplateRecipeEntity recipe,
    VideoTemplateSlotEntity? slot,
    double? timeSeconds,
    List<File>? allSources,
  }) async {
    try {
      final sources = (allSources != null && allSources.isNotEmpty)
          ? allSources
          : <File>[input];
      final engine = TemplateCompositionEngine();
      final session = engine.open(recipe);
      var fills = SlotEngine(recipe: recipe).fillsFromFiles(sources);
      fills = SlotEngine(recipe: recipe).applyBeatSyncTrims(fills);
      session.fills = fills;
      await session.prepareSources();

      final timeline = engine.buildTimeline(session);
      final t = timeSeconds ??
          _midTimeForSlot(timeline.totalDuration, recipe, slot);
      final frame = engine.sample(session, t);

      final bytes = await input.readAsBytes();
      final baked = await bakeFromPreviewFrame(
        imageBytes: bytes,
        frame: frame,
        recipe: recipe,
      );
      await session.dispose();
      if (baked == null || baked.isEmpty) return null;

      final dir = await getTemporaryDirectory();
      final out = File(
        '${dir.path}/tpl_look_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await out.writeAsBytes(baked);
      return out;
    } catch (e, st) {
      debugPrint('TemplateLookBaker.bakeImageFile: $e\n$st');
      return null;
    }
  }

  static double _midTimeForSlot(
    double total,
    VideoTemplateRecipeEntity recipe,
    VideoTemplateSlotEntity? slot,
  ) {
    if (slot == null) return (total * 0.45).clamp(0.0, total);
    // Approximate: slotIndex / count * total + half slot.
    final n = recipe.applySlotCount.clamp(1, 99);
    final i = slot.slotIndex.clamp(0, n - 1);
    final slotLen = total / n;
    return (i * slotLen + slotLen * 0.45).clamp(0.0, total);
  }

  /// Rasterize [frame] layers onto [imageBytes] (JPEG out).
  static Future<Uint8List?> bakeFromPreviewFrame({
    required Uint8List imageBytes,
    required PreviewFrame frame,
    required VideoTemplateRecipeEntity recipe,
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(imageBytes);
      final next = await codec.getNextFrame();
      final source = next.image;
      final width = source.width;
      final height = source.height;
      if (width <= 0 || height <= 0) {
        source.dispose();
        return null;
      }

      final filter = frame.filters.isNotEmpty ? frame.filters.first : null;
      final matrix = TemplateFilterMatrices.forName(
        filter?.filterName,
        intensity: filter?.intensity ?? 1,
      );
      final effect = TemplateEffectVisual.resolve(
        frame.effects.map(
          (e) => (
            type: e.effectType,
            progress: e.progress,
            params: e.parameters,
          ),
        ),
      );

      final size = ui.Size(width.toDouble(), height.toDouble());
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      canvas.drawRect(
        ui.Offset.zero & size,
        ui.Paint()..color = const ui.Color(0xFF000000),
      );

      canvas.save();
      canvas.translate(size.width / 2, size.height / 2);
      canvas.translate(effect.dx, effect.dy);
      canvas.rotate(effect.rotation);
      canvas.scale(effect.scale.clamp(0.5, 2.5));
      canvas.translate(-size.width / 2, -size.height / 2);

      final paint = ui.Paint()
        ..colorFilter = ui.ColorFilter.matrix(matrix)
        ..isAntiAlias = true;

      final srcW = width.toDouble();
      final srcH = height.toDouble();
      final src = ui.Rect.fromLTWH(0, 0, srcW, srcH);
      switch (effect.collage) {
        case TemplateCollageKind.pip:
          // Blurred full-frame bg + sharp centered inset (9:16).
          final blur = effect.pipBgBlur > 0 ? effect.pipBgBlur : 12.0;
          final bgPaint = ui.Paint()
            ..colorFilter = ui.ColorFilter.matrix(matrix)
            ..imageFilter = ui.ImageFilter.blur(
              sigmaX: blur.clamp(4, 24),
              sigmaY: blur.clamp(4, 24),
            );
          canvas.drawImageRect(source, src, ui.Offset.zero & size, bgPaint);
          final wr = (effect.pipWidthRatio ?? effect.pipInsetScale ?? 0.36)
              .clamp(0.2, 0.95);
          final iw = size.width * wr;
          final ih = iw * (size.height / size.width); // preserve canvas aspect
          final left = (size.width - iw) / 2 + effect.pipInsetX;
          final top = (size.height - ih) / 2 + effect.pipInsetY;
          canvas.drawImageRect(
            source,
            src,
            ui.Rect.fromLTWH(left, top, iw, ih),
            paint,
          );
        case TemplateCollageKind.mirrorStack:
          // Same top-half crop on both bands (not a flip).
          final half = size.height / 2;
          final topCrop = ui.Rect.fromLTWH(0, 0, srcW, srcH / 2);
          canvas.drawImageRect(
            source,
            topCrop,
            ui.Rect.fromLTWH(0, 0, size.width, half),
            paint,
          );
          canvas.drawImageRect(
            source,
            topCrop,
            ui.Rect.fromLTWH(0, half, size.width, half),
            paint,
          );
        case TemplateCollageKind.gridTriple:
          final leftW = (size.width / 2).floorToDouble();
          final rightW = size.width - leftW;
          final halfH = (size.height / 2).floorToDouble();
          final remH = size.height - halfH;
          canvas.drawImageRect(
            source,
            ui.Rect.fromLTWH(0, 0, srcW / 2, srcH),
            ui.Rect.fromLTWH(0, 0, leftW, size.height),
            paint,
          );
          canvas.drawImageRect(
            source,
            ui.Rect.fromLTWH(srcW / 2, 0, srcW / 2, srcH / 2),
            ui.Rect.fromLTWH(leftW, 0, rightW, halfH),
            paint,
          );
          canvas.drawImageRect(
            source,
            ui.Rect.fromLTWH(srcW / 2, srcH / 2, srcW / 2, srcH / 2),
            ui.Rect.fromLTWH(leftW, halfH, rightW, remH),
            paint,
          );
        case TemplateCollageKind.lyricSandwich:
          final midH = size.height * effect.bandHeightRatio.clamp(0.08, 0.35);
          final bandH = size.height * effect.imageCropRatio.clamp(0.2, 0.7);
          final faceCrop = ui.Rect.fromLTWH(
            0,
            0,
            srcW,
            srcH * effect.imageCropRatio.clamp(0.2, 0.7),
          );
          canvas.drawImageRect(
            source,
            faceCrop,
            ui.Rect.fromLTWH(0, 0, size.width, bandH),
            paint,
          );
          canvas.drawRect(
            ui.Rect.fromLTWH(0, bandH, size.width, midH),
            ui.Paint()..color = ui.Color(effect.bandColor),
          );
          canvas.drawImageRect(
            source,
            faceCrop,
            ui.Rect.fromLTWH(0, bandH + midH, size.width, bandH),
            paint,
          );
        case TemplateCollageKind.duoSplit:
          if (effect.duoDirectionVertical) {
            final half = size.width / 2;
            canvas.drawImageRect(
              source,
              ui.Rect.fromLTWH(0, 0, srcW / 2, srcH),
              ui.Rect.fromLTWH(0, 0, half, size.height),
              paint,
            );
            canvas.drawImageRect(
              source,
              ui.Rect.fromLTWH(srcW / 2, 0, srcW / 2, srcH),
              ui.Rect.fromLTWH(half, 0, half, size.height),
              paint,
            );
          } else {
            final half = size.height / 2;
            canvas.drawImageRect(
              source,
              ui.Rect.fromLTWH(0, 0, srcW, srcH / 2),
              ui.Rect.fromLTWH(0, 0, size.width, half),
              paint,
            );
            canvas.drawImageRect(
              source,
              ui.Rect.fromLTWH(0, srcH / 2, srcW, srcH / 2),
              ui.Rect.fromLTWH(0, half, size.width, half),
              paint,
            );
          }
        case TemplateCollageKind.quadGrid:
          final hw = size.width / 2;
          final hh = size.height / 2;
          final cells = <(ui.Rect, ui.Rect)>[
            (
              ui.Rect.fromLTWH(0, 0, srcW / 2, srcH / 2),
              ui.Rect.fromLTWH(0, 0, hw, hh),
            ),
            (
              ui.Rect.fromLTWH(srcW / 2, 0, srcW / 2, srcH / 2),
              ui.Rect.fromLTWH(hw, 0, hw, hh),
            ),
            (
              ui.Rect.fromLTWH(0, srcH / 2, srcW / 2, srcH / 2),
              ui.Rect.fromLTWH(0, hh, hw, hh),
            ),
            (
              ui.Rect.fromLTWH(srcW / 2, srcH / 2, srcW / 2, srcH / 2),
              ui.Rect.fromLTWH(hw, hh, hw, hh),
            ),
          ];
          for (final cell in cells) {
            canvas.drawImageRect(source, cell.$1, cell.$2, paint);
          }
        case TemplateCollageKind.circlePip:
          final blur = effect.pipBgBlur > 0 ? effect.pipBgBlur : 14.0;
          final bgPaint = ui.Paint()
            ..colorFilter = ui.ColorFilter.matrix(matrix)
            ..imageFilter = ui.ImageFilter.blur(
              sigmaX: blur.clamp(4, 24),
              sigmaY: blur.clamp(4, 24),
            );
          canvas.drawImageRect(source, src, ui.Offset.zero & size, bgPaint);
          final wr = (effect.pipWidthRatio ?? 0.42).clamp(0.2, 0.95);
          final iw = size.width * wr;
          final ih = iw;
          final left = (size.width - iw) / 2;
          final top = (size.height - ih) / 2;
          canvas.save();
          canvas.clipPath(
            ui.Path()
              ..addOval(ui.Rect.fromLTWH(left, top, iw, ih)),
          );
          canvas.drawImageRect(
            source,
            src,
            ui.Rect.fromLTWH(left, top, iw, ih),
            paint,
          );
          canvas.restore();
        case TemplateCollageKind.filmStrip:
          final band = size.height / 3;
          for (var i = 0; i < 3; i++) {
            final sy = srcH * (i / 3);
            canvas.drawImageRect(
              source,
              ui.Rect.fromLTWH(0, sy, srcW, srcH / 3),
              ui.Rect.fromLTWH(0, band * i, size.width, band),
              paint,
            );
          }
        case TemplateCollageKind.diagonalSplit:
          canvas.save();
          canvas.clipPath(
            ui.Path()
              ..moveTo(0, 0)
              ..lineTo(size.width * 0.62, 0)
              ..lineTo(size.width * 0.38, size.height)
              ..lineTo(0, size.height)
              ..close(),
          );
          canvas.drawImageRect(source, src, ui.Offset.zero & size, paint);
          canvas.restore();
          canvas.save();
          canvas.clipPath(
            ui.Path()
              ..moveTo(size.width * 0.62, 0)
              ..lineTo(size.width, 0)
              ..lineTo(size.width, size.height)
              ..lineTo(size.width * 0.38, size.height)
              ..close(),
          );
          canvas.drawImageRect(source, src, ui.Offset.zero & size, paint);
          canvas.restore();
        case TemplateCollageKind.sideBySideMirror:
          final half = size.width / 2;
          canvas.drawImageRect(
            source,
            ui.Rect.fromLTWH(0, 0, srcW / 2, srcH),
            ui.Rect.fromLTWH(0, 0, half, size.height),
            paint,
          );
          canvas.save();
          canvas.translate(size.width, 0);
          canvas.scale(-1.0, 1.0);
          canvas.drawImageRect(
            source,
            ui.Rect.fromLTWH(0, 0, srcW / 2, srcH),
            ui.Rect.fromLTWH(0, 0, half, size.height),
            paint,
          );
          canvas.restore();
        case TemplateCollageKind.shapedCutout:
          // Soft bake: user media in shaped hole over black (bg asset is live-only).
          canvas.drawRect(
            ui.Offset.zero & size,
            ui.Paint()..color = const ui.Color(0xFF1A1A1A),
          );
          final wr = effect.shapedWidthRatio.clamp(0.15, 0.95);
          final hr = effect.shapedHeightRatio.clamp(0.15, 0.95);
          final iw = size.width * wr;
          final ih = size.height * hr;
          final cx = size.width / 2 + effect.shapedPosX;
          final cy = size.height / 2 + effect.shapedPosY;
          final hole = ui.Rect.fromCenter(
            center: ui.Offset(cx, cy),
            width: iw,
            height: ih,
          );
          canvas.save();
          if (effect.shapedShape == 'circle') {
            canvas.clipPath(ui.Path()..addOval(hole));
          } else {
            canvas.clipRRect(
              ui.RRect.fromRectAndRadius(
                hole,
                ui.Radius.circular(effect.shapedCornerRadius.clamp(0, 120)),
              ),
            );
          }
          canvas.drawImageRect(source, src, hole, paint);
          canvas.restore();
        case TemplateCollageKind.none:
          canvas.drawImage(source, ui.Offset.zero, paint);
      }
      canvas.restore();

      if (effect.rgbSplitPx > 0.5) {
        final o = effect.rgbSplitPx;
        canvas.drawImage(
          source,
          ui.Offset(o, 0),
          ui.Paint()
            ..blendMode = ui.BlendMode.plus
            ..colorFilter = const ui.ColorFilter.mode(
              ui.Color(0x55FF0000),
              ui.BlendMode.srcATop,
            ),
        );
        canvas.drawImage(
          source,
          ui.Offset(-o, 0),
          ui.Paint()
            ..blendMode = ui.BlendMode.plus
            ..colorFilter = const ui.ColorFilter.mode(
              ui.Color(0x5500FFFF),
              ui.BlendMode.srcATop,
            ),
        );
      }

      // Overlays (full-bleed).
      for (final item in frame.overlays) {
        final url = item.assetUrl;
        if (url == null || url.isEmpty) continue;
        final overlay = await _decodeNetworkImage(url);
        if (overlay == null) continue;
        final op = ui.Paint()..color = ui.Color.fromRGBO(255, 255, 255, item.opacity.clamp(0.0, 1.0));
        canvas.drawImageRect(
          overlay,
          ui.Rect.fromLTWH(0, 0, overlay.width.toDouble(), overlay.height.toDouble()),
          ui.Rect.fromLTWH(0, 0, size.width, size.height),
          op,
        );
        overlay.dispose();
      }

      // Stickers (canvas alignment, same as preview).
      for (final item in frame.stickers) {
        final url = item.assetUrl;
        if (url == null || url.isEmpty) continue;
        final sticker = await _decodeNetworkImage(url);
        if (sticker == null) continue;
        final align = templateCanvasAlignment(item.positionX, item.positionY);
        final box = 96.0 * (item.scale <= 0 ? 1 : item.scale);
        final center = _alignmentOffset(align, size, ui.Size(box, box));
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(item.rotation * 3.141592653589793 / 180);
        final op = ui.Paint()
          ..color = ui.Color.fromRGBO(255, 255, 255, item.opacity.clamp(0.0, 1.0));
        canvas.drawImageRect(
          sticker,
          ui.Rect.fromLTWH(0, 0, sticker.width.toDouble(), sticker.height.toDouble()),
          ui.Rect.fromCenter(center: ui.Offset.zero, width: box, height: box),
          op,
        );
        canvas.restore();
        sticker.dispose();
      }

      // Texts (canvas alignment).
      const textEngine = TextEngine();
      for (final item in frame.texts) {
        final text = item.text?.trim() ?? '';
        if (text.isEmpty) continue;
        final color = textEngine.parseColor(item.color) ?? const ui.Color(0xFFFFFFFF);
        final fontSize = ((item.fontSize ?? 42).toDouble()).clamp(12.0, 120.0);
        final builder = ui.ParagraphBuilder(
          ui.ParagraphStyle(textAlign: ui.TextAlign.center, maxLines: 4),
        )
          ..pushStyle(
            ui.TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: ui.FontWeight.w800,
            ),
          )
          ..addText(text);
        final paragraph = builder.build()
          ..layout(ui.ParagraphConstraints(width: size.width * 0.85));
        final align = templateCanvasAlignment(item.positionX, item.positionY);
        final center = _alignmentOffset(
          align,
          size,
          ui.Size(paragraph.width, paragraph.height),
        );
        canvas.drawParagraph(
          paragraph,
          ui.Offset(
            center.dx - paragraph.width / 2,
            center.dy - paragraph.height / 2,
          ),
        );
      }

      if (effect.flashWhite > 0.01) {
        canvas.drawRect(
          ui.Offset.zero & size,
          ui.Paint()
            ..color = ui.Color.fromRGBO(
              255,
              255,
              255,
              effect.flashWhite.clamp(0.0, 0.85),
            ),
        );
      }

      source.dispose();
      final picture = recorder.endRecording();
      final out = await picture.toImage(width, height);
      picture.dispose();
      final raw = await out.toByteData(format: ui.ImageByteFormat.rawRgba);
      out.dispose();
      if (raw == null) return null;

      final encoded = img.encodeJpg(
        img.Image.fromBytes(
          width: width,
          height: height,
          bytes: raw.buffer,
          numChannels: 4,
        ),
        quality: 92,
      );
      return encoded.isEmpty ? null : Uint8List.fromList(encoded);
    } catch (e, st) {
      debugPrint('TemplateLookBaker.bakeFromPreviewFrame: $e\n$st');
      return null;
    }
  }

  static ui.Offset _alignmentOffset(
    Alignment align,
    ui.Size canvas,
    ui.Size child,
  ) {
    final x = (canvas.width - child.width) / 2 + align.x * (canvas.width - child.width) / 2;
    final y = (canvas.height - child.height) / 2 + align.y * (canvas.height - child.height) / 2;
    return ui.Offset(x + child.width / 2, y + child.height / 2);
  }

  static Future<ui.Image?> _decodeNetworkImage(String rawUrl) async {
    try {
      final url = MediaUtils.resolveAbsoluteUrl(rawUrl);
      if (url.isEmpty) return null;
      final res = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 8),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final codec = await ui.instantiateImageCodec(res.bodyBytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      debugPrint('TemplateLookBaker network image: $e');
      return null;
    }
  }

  /// Apply recipe color grade onto a finished MP4 (best-effort).
  static Future<File> bakeVideoColorGrade({
    required File input,
    required VideoTemplateRecipeEntity recipe,
    VideoTemplateSlotEntity? slot,
  }) async {
    try {
      final engine = TemplateCompositionEngine();
      final session = engine.open(recipe);
      final fills = SlotEngine(recipe: recipe).emptyFills();
      session.fills = fills;
      final frame = engine.sample(session, 0.45);
      await session.dispose();
      final filter = frame.filters.isNotEmpty ? frame.filters.first : null;
      final name = filter?.filterName.trim().toLowerCase();
      if (name == null || name.isEmpty || name == 'none') return input;
      final matrix = TemplateFilterMatrices.forName(
        filter!.filterName,
        intensity: filter.intensity,
      );
      if (identical(matrix, TemplateFilterMatrices.identity)) return input;
      final graded = await NativeVideoProcessor.applyColorMatrix(
        input: input,
        matrix: matrix,
      );
      if (graded != null && await graded.exists()) return graded;
    } catch (e, st) {
      debugPrint('TemplateLookBaker.bakeVideoColorGrade: $e\n$st');
    }
    return input;
  }
}
