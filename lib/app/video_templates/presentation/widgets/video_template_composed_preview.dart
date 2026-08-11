import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bimobondapp/app/video_templates/engine/layers/layer_engines.dart';
import 'package:bimobondapp/app/video_templates/engine/render/render_engine.dart';
import 'package:bimobondapp/app/video_templates/presentation/utils/template_preview_look.dart';
import 'package:bimobondapp/app/video_templates/preview/media_texture_cache.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Builds a fresh media surface for each collage pane.
///
/// **Critical:** [VideoPlayer] / [MediaStudioPreview] cannot be mounted twice.
/// Layout effects that need multiple copies must call this builder per pane.
typedef TemplateMediaPaneBuilder = Widget Function({
  required String paneKey,
  bool muted,
});

/// TikTok-style local compositor for template preview (server parity).
///
/// Render order: scale/cover → filters → **layout** → motion → overlays.
class VideoTemplateComposedPreview extends StatelessWidget {
  const VideoTemplateComposedPreview({
    super.key,
    required this.frame,
    this.videoController,
    this.imageFile,
    this.decodedImage,
    this.mediaOverride,
    this.mediaPaneBuilder,
    this.isVideoMedia = false,
    this.canvasWidth = 1080,
    this.canvasHeight = 1920,
    this.emptyLabel = 'Add media to preview',
  });

  final PreviewFrame? frame;
  final VideoPlayerController? videoController;
  final File? imageFile;
  final ui.Image? decodedImage;

  /// Single media surface (images / one video without multi-pane layout).
  final Widget? mediaOverride;

  /// Preferred for video + layout effects — one player instance per pane.
  final TemplateMediaPaneBuilder? mediaPaneBuilder;

  /// True when the active slot is video (enables video-safe layout path).
  final bool isVideoMedia;

  final int canvasWidth;
  final int canvasHeight;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final media = _buildMediaSurface(paneKey: 'main', muted: false);
    if (media == null) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            emptyLabel,
            style: const TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    final f = frame;
    final filter = f?.filters.isNotEmpty == true ? f!.filters.first : null;
    final matrix = TemplateFilterMatrices.forName(
      filter?.filterName,
      intensity: filter?.intensity ?? 1,
    );

    final effect = TemplateEffectVisual.resolve(
      (f?.effects ?? const <ResolvedEffect>[]).map(
        (e) => (
          type: e.effectType,
          progress: e.progress,
          params: e.parameters,
        ),
      ),
    );

    final duotoneMatrix = effect.duotone > 0.01
        ? TemplateFilterMatrices.forName('duotone', intensity: effect.duotone)
        : null;

    final transition = _transitionVisual(f);
    final cw = canvasWidth <= 0 ? 1080 : canvasWidth;
    final ch = canvasHeight <= 0 ? 1920 : canvasHeight;
    final hasLayout = effect.collage != TemplateCollageKind.none;

    Widget colorGrade(Widget child) {
      var w = ColorFiltered(
        colorFilter: ColorFilter.matrix(matrix),
        child: child,
      );
      if (duotoneMatrix != null) {
        w = ColorFiltered(
          colorFilter: ColorFilter.matrix(duotoneMatrix),
          child: w,
        );
      }
      return w;
    }

    Widget pane({required String key, bool muted = true}) {
      // Always build a fresh widget per pane — a single VideoPlayer/Image
      // Element cannot be mounted in two places in the tree.
      final raw = _buildMediaSurface(paneKey: key, muted: muted) ?? media;
      return colorGrade(SizedBox.expand(child: raw));
    }

    Widget layered;
    if (hasLayout) {
      layered = _buildLayout(
        effect: effect,
        pane: pane,
        canvasW: cw,
        canvasH: ch,
      );
    } else {
      layered = colorGrade(SizedBox.expand(child: media));
    }

    // Motion — avoid ImageFiltered on live video textures (black frames).
    if (effect.blurSigma > 0.5) {
      if (isVideoMedia) {
        layered = Stack(
          fit: StackFit.expand,
          children: [
            layered,
            ColoredBox(
              color: Colors.black.withValues(
                alpha: (effect.blurSigma / 16).clamp(0.0, 0.55),
              ),
            ),
          ],
        );
      } else {
        layered = ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: effect.blurSigma,
            sigmaY: effect.blurSigma,
          ),
          child: layered,
        );
      }
    }

    if ((effect.rgbSplitPx > 0.5 || effect.vhs > 0.01) && !isVideoMedia) {
      layered = _RgbSplitOverlay(
        offsetPx: math.max(effect.rgbSplitPx, effect.vhs * 6),
        child: layered,
      );
    }

    layered = Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..translateByDouble(
          effect.dx + transition.dx,
          effect.dy + transition.dy,
          0,
          1,
        )
        ..rotateZ(effect.rotation)
        ..scaleByDouble(
          effect.scale * transition.scale,
          effect.scale * transition.scale,
          1,
          1,
        ),
      child: Opacity(
        opacity: (effect.opacity * transition.opacity).clamp(0.0, 1.0),
        child: layered,
      ),
    );

    final composed = ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Colors.black, child: layered),
          RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ..._buildTexts(f, cw, ch),
                ..._buildStickers(f, cw, ch),
                ..._buildOverlays(f),
              ],
            ),
          ),
          if (effect.lightLeak > 0.01)
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.75, -0.65),
                    radius: 1.1,
                    colors: [
                      Color.fromRGBO(255, 170, 60, 0.55 * effect.lightLeak),
                      Color.fromRGBO(255, 90, 40, 0.22 * effect.lightLeak),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.35, 1.0],
                  ),
                ),
              ),
            ),
          if (effect.vhs > 0.01)
            IgnorePointer(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.08 * effect.vhs),
                child: const CustomPaint(painter: _VhsGrainPainter()),
              ),
            ),
          if (effect.flashWhite > 0.01 ||
              transition.flash > 0.01 ||
              effect.filmBurn > 0.01 ||
              transition.burn > 0.01)
            IgnorePointer(
              child: ColoredBox(
                color: Color.lerp(
                  Colors.white,
                  const Color(0xFFFF6A2A),
                  (effect.filmBurn + transition.burn).clamp(0.0, 1.0),
                )!
                    .withValues(
                  alpha: (effect.flashWhite +
                          transition.flash +
                          effect.filmBurn * 0.7 +
                          transition.burn * 0.7)
                      .clamp(0.0, 0.9),
                ),
              ),
            ),
        ],
      ),
    );

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: cw / ch,
          child: composed,
        ),
      ),
    );
  }

  Widget _buildLayout({
    required TemplateEffectVisual effect,
    required Widget Function({required String key, bool muted}) pane,
    required int canvasW,
    required int canvasH,
  }) {
    switch (effect.collage) {
      case TemplateCollageKind.pip:
        final wr = (effect.pipWidthRatio ?? effect.pipInsetScale ?? 0.36)
            .clamp(0.2, 0.95);
        return _PipLayout(
          widthRatio: wr,
          bgBlur: effect.pipBgBlur > 0 ? effect.pipBgBlur : 12,
          isVideo: isVideoMedia,
          circular: false,
          backdrop: pane(key: 'pip-bg', muted: true),
          child: pane(key: 'pip-fg', muted: false),
        );
      case TemplateCollageKind.circlePip:
        final wr = (effect.pipWidthRatio ?? effect.pipInsetScale ?? 0.42)
            .clamp(0.2, 0.95);
        return _PipLayout(
          widthRatio: wr,
          bgBlur: effect.pipBgBlur > 0 ? effect.pipBgBlur : 14,
          isVideo: isVideoMedia,
          circular: true,
          backdrop: pane(key: 'circle-bg', muted: true),
          child: pane(key: 'circle-fg', muted: false),
        );
      case TemplateCollageKind.mirrorStack:
        return _MirrorStackLayout(
          top: pane(key: 'mirror-a', muted: false),
          bottom: pane(key: 'mirror-b', muted: true),
        );
      case TemplateCollageKind.gridTriple:
        return _GridTripleLayout(
          left: pane(key: 'grid-l', muted: false),
          topRight: pane(key: 'grid-tr', muted: true),
          bottomRight: pane(key: 'grid-br', muted: true),
        );
      case TemplateCollageKind.lyricSandwich:
        return _LyricSandwichLayout(
          bandHeightRatio: effect.bandHeightRatio,
          imageCropRatio: effect.imageCropRatio,
          bandColor: Color(effect.bandColor),
          top: pane(key: 'lyric-t', muted: false),
          bottom: pane(key: 'lyric-b', muted: true),
        );
      case TemplateCollageKind.duoSplit:
        return _DuoSplitLayout(
          vertical: effect.duoDirectionVertical,
          a: pane(key: 'duo-a', muted: false),
          b: pane(key: 'duo-b', muted: true),
        );
      case TemplateCollageKind.quadGrid:
        return _QuadGridLayout(
          tl: pane(key: 'quad-tl', muted: false),
          tr: pane(key: 'quad-tr', muted: true),
          bl: pane(key: 'quad-bl', muted: true),
          br: pane(key: 'quad-br', muted: true),
        );
      case TemplateCollageKind.filmStrip:
        return _FilmStripLayout(
          top: pane(key: 'film-t', muted: false),
          mid: pane(key: 'film-m', muted: true),
          bottom: pane(key: 'film-b', muted: true),
        );
      case TemplateCollageKind.diagonalSplit:
        return _DiagonalSplitLayout(
          left: pane(key: 'diag-l', muted: false),
          right: pane(key: 'diag-r', muted: true),
        );
      case TemplateCollageKind.sideBySideMirror:
        return _SideBySideMirrorLayout(
          left: pane(key: 'sbs-l', muted: false),
          right: pane(key: 'sbs-r', muted: true),
        );
      case TemplateCollageKind.shapedCutout:
        return _ShapedCutoutLayout(
          shape: effect.shapedShape,
          backgroundUrl: effect.shapedBgUrl,
          maskUrl: effect.shapedMaskUrl,
          widthRatio: effect.shapedWidthRatio,
          heightRatio: effect.shapedHeightRatio,
          positionX: effect.shapedPosX,
          positionY: effect.shapedPosY,
          cornerRadius: effect.shapedCornerRadius,
          canvasWidth: canvasW,
          canvasHeight: canvasH,
          child: pane(key: 'shaped-fg', muted: false),
        );
      case TemplateCollageKind.none:
        return pane(key: 'main', muted: false);
    }
  }

  Widget? _buildMediaSurface({required String paneKey, required bool muted}) {
    if (mediaPaneBuilder != null && isVideoMedia) {
      return mediaPaneBuilder!(paneKey: paneKey, muted: muted);
    }
    // Never mount one VideoPlayerController in more than one pane.
    final vc = videoController;
    if (vc != null && vc.value.isInitialized && paneKey == 'main') {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: vc.value.size.width,
          height: vc.value.size.height,
          child: VideoPlayer(vc),
        ),
      );
    }
    if (mediaOverride != null && paneKey == 'main') {
      return mediaOverride;
    }
    final texture = decodedImage;
    if (texture != null) {
      return FittedBox(
        key: ValueKey('tpl-tex-$paneKey'),
        fit: BoxFit.cover,
        child: SizedBox(
          width: texture.width.toDouble(),
          height: texture.height.toDouble(),
          child: RawImage(image: texture, fit: BoxFit.cover),
        ),
      );
    }
    final image = imageFile;
    if (image != null && !VideoThumbnailUtils.isVideoFile(image)) {
      // Soft preview: never decode full camera resolution.
      return Image.file(
        image,
        key: ValueKey('tpl-still-$paneKey-${image.path}'),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        cacheWidth: MediaTextureCache.defaultPreviewMaxWidth,
        filterQuality: FilterQuality.low,
      );
    }
    return null;
  }

  _TransitionVisual _transitionVisual(PreviewFrame? f) {
    if (f == null) return const _TransitionVisual();
    var flash = 0.0;
    var burn = 0.0;
    var dx = 0.0;
    var dy = 0.0;
    var scale = 1.0;
    var opacity = 1.0;

    for (final t in f.transitions) {
      final type = t.type.toLowerCase();
      final p = t.progress.clamp(0.0, 1.0);
      if (type.contains('flash') ||
          type == 'glitch' ||
          type == 'match_cut_flash') {
        final mid = 1 - (p - 0.5).abs() * 2;
        flash = math.max(flash, mid.clamp(0.0, 1.0) * 0.85);
      }
      if (type.contains('fade') || type == 'crossfade') {
        final edge = (p < 0.5 ? p : 1 - p) * 2;
        opacity = math.min(opacity, 0.65 + edge * 0.35);
      }
      if (type == 'film_burn') {
        final mid = 1 - (p - 0.5).abs() * 2;
        burn = math.max(burn, mid.clamp(0.0, 1.0) * 0.8);
      }
      if (type == 'zoom_blur' || type == 'blur') {
        scale = math.max(scale, 1 + p * 0.28);
        opacity = math.min(opacity, 1 - p * 0.35);
      }
      if (type == 'push_left' || type == 'slide_left' || type == 'slide') {
        dx -= p * 1080;
      } else if (type == 'push_right' || type == 'slide_right') {
        dx += p * 1080;
      } else if (type == 'push_up') {
        dy -= p * 1920;
      } else if (type == 'push_down') {
        dy += p * 1920;
      } else if (type.contains('zoom')) {
        scale = math.max(scale, 1 + p * 0.35);
      }
    }
    return _TransitionVisual(
      flash: flash,
      burn: burn,
      dx: dx,
      dy: dy,
      scale: scale,
      opacity: opacity,
    );
  }

  List<Widget> _buildTexts(PreviewFrame? f, int cw, int ch) {
    if (f == null) return const [];
    const textEngine = TextEngine();
    return f.texts.map((item) {
      final color = textEngine.parseColor(item.color) ?? Colors.white;
      final align = templateCanvasAlignment(
        item.positionX,
        item.positionY,
        canvasWidth: cw,
        canvasHeight: ch,
      );
      final appear = _animationOpacity(
        item.animationIn,
        f.time,
        item.startTime,
        item.endTime,
      );
      return Align(
        alignment: align,
        child: Opacity(
          opacity: (item.opacity * appear).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: item.scale <= 0 ? 1 : item.scale,
            child: Transform.rotate(
              angle: item.rotation * mathPi / 180,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  item.text ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: (item.fontSize ?? 42).toDouble(),
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    shadows: const [
                      Shadow(
                        color: Colors.black87,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }).toList(growable: false);
  }

  List<Widget> _buildStickers(PreviewFrame? f, int cw, int ch) {
    if (f == null) return const [];
    return f.stickers.map((item) {
      final align = templateCanvasAlignment(
        item.positionX,
        item.positionY,
        canvasWidth: cw,
        canvasHeight: ch,
      );
      final url = item.assetUrl;
      return Align(
        alignment: align,
        child: Opacity(
          opacity: item.opacity.clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: item.rotation * mathPi / 180,
            child: Transform.scale(
              scale: item.scale <= 0 ? 1 : item.scale,
              child: SizedBox(
                width: 96,
                height: 96,
                child: url != null && url.isNotEmpty
                    ? SafeNetworkImage(imageUrl: url, fit: BoxFit.contain)
                    : const Icon(Icons.emoji_emotions, color: Colors.white70),
              ),
            ),
          ),
        ),
      );
    }).toList(growable: false);
  }

  List<Widget> _buildOverlays(PreviewFrame? f) {
    if (f == null) return const [];
    return f.overlays.map((item) {
      final url = item.assetUrl;
      if (url == null || url.isEmpty) return const SizedBox.shrink();
      return Opacity(
        opacity: item.opacity.clamp(0.0, 1.0),
        child: SafeNetworkImage(imageUrl: url, fit: BoxFit.cover),
      );
    }).toList(growable: false);
  }

  double _animationOpacity(
    String? animationIn,
    double time,
    double start,
    double end,
  ) {
    final local = time - start;
    final dur = (end - start).clamp(0.05, 60.0);
    final p = (local / dur).clamp(0.0, 1.0);
    final anim = (animationIn ?? '').toLowerCase();
    if (anim.contains('fade')) {
      return (p / 0.15).clamp(0.0, 1.0);
    }
    if (anim.contains('up') || anim.contains('fadeup')) {
      return (p / 0.2).clamp(0.0, 1.0);
    }
    return 1;
  }
}

const double mathPi = 3.1415926535897932;

class _PipLayout extends StatelessWidget {
  const _PipLayout({
    required this.child,
    required this.backdrop,
    required this.widthRatio,
    required this.bgBlur,
    required this.isVideo,
    this.circular = false,
  });

  final Widget child;
  final Widget backdrop;
  final double widthRatio;
  final double bgBlur;
  final bool isVideo;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final r = widthRatio.clamp(0.2, 0.95);
    final Widget bg;
    if (isVideo) {
      // ImageFiltered blacks out platform video textures — approximate blur.
      bg = ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Color(0x66000000),
          BlendMode.darken,
        ),
        child: Transform.scale(scale: 1.12, child: backdrop),
      );
    } else {
      bg = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: bgBlur.clamp(4, 24),
          sigmaY: bgBlur.clamp(4, 24),
        ),
        child: backdrop,
      );
    }

    final inset = circular
        ? ClipOval(child: child)
        : ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: child,
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        bg,
        Center(
          child: FractionallySizedBox(
            widthFactor: r,
            heightFactor: r,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: circular ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: circular ? null : BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: inset,
            ),
          ),
        ),
      ],
    );
  }
}

class _MirrorStackLayout extends StatelessWidget {
  const _MirrorStackLayout({required this.top, required this.bottom});

  final Widget top;
  final Widget bottom;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        final half = h / 2;

        Widget band(Widget source) {
          return SizedBox(
            width: w,
            height: half,
            child: ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: 0.5,
                child: SizedBox(width: w, height: h, child: source),
              ),
            ),
          );
        }

        return ColoredBox(
          color: Colors.black,
          child: Column(
            children: [
              band(top),
              band(bottom),
            ],
          ),
        );
      },
    );
  }
}

class _GridTripleLayout extends StatelessWidget {
  const _GridTripleLayout({
    required this.left,
    required this.topRight,
    required this.bottomRight,
  });

  final Widget left;
  final Widget topRight;
  final Widget bottomRight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        final leftW = (w / 2).floorToDouble();
        final rightW = w - leftW;
        final halfH = (h / 2).floorToDouble();
        final remH = h - halfH;

        Widget crop({
          required Widget source,
          required Alignment alignment,
          required double width,
          required double height,
          double widthFactor = 1,
          double heightFactor = 1,
        }) {
          return SizedBox(
            width: width,
            height: height,
            child: ClipRect(
              child: Align(
                alignment: alignment,
                widthFactor: widthFactor,
                heightFactor: heightFactor,
                child: SizedBox(width: w, height: h, child: source),
              ),
            ),
          );
        }

        return ColoredBox(
          color: Colors.black,
          child: Row(
            children: [
              crop(
                source: left,
                alignment: Alignment.centerLeft,
                width: leftW,
                height: h,
                widthFactor: 0.5,
              ),
              SizedBox(
                width: rightW,
                height: h,
                child: Column(
                  children: [
                    crop(
                      source: topRight,
                      alignment: Alignment.topRight,
                      width: rightW,
                      height: halfH,
                      widthFactor: 0.5,
                      heightFactor: 0.5,
                    ),
                    crop(
                      source: bottomRight,
                      alignment: Alignment.bottomRight,
                      width: rightW,
                      height: remH,
                      widthFactor: 0.5,
                      heightFactor: 0.5,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LyricSandwichLayout extends StatelessWidget {
  const _LyricSandwichLayout({
    required this.top,
    required this.bottom,
    required this.bandHeightRatio,
    required this.imageCropRatio,
    required this.bandColor,
  });

  final Widget top;
  final Widget bottom;
  final double bandHeightRatio;
  final double imageCropRatio;
  final Color bandColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        final midH = (h * bandHeightRatio.clamp(0.08, 0.35)).roundToDouble();
        final bandH = (h * imageCropRatio.clamp(0.2, 0.7)).roundToDouble();
        final cropFactor = (bandH / h).clamp(0.05, 1.0);

        Widget photoBand(Widget source) {
          return SizedBox(
            width: w,
            height: bandH,
            child: ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: cropFactor,
                child: SizedBox(width: w, height: h, child: source),
              ),
            ),
          );
        }

        return ColoredBox(
          color: Colors.black,
          child: Column(
            children: [
              photoBand(top),
              SizedBox(
                width: w,
                height: midH,
                child: ColoredBox(color: bandColor),
              ),
              photoBand(bottom),
            ],
          ),
        );
      },
    );
  }
}

class _RgbSplitOverlay extends StatelessWidget {
  const _RgbSplitOverlay({required this.child, required this.offsetPx});

  final Widget child;
  final double offsetPx;

  @override
  Widget build(BuildContext context) {
    final o = offsetPx.clamp(1.0, 24.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColorFiltered(
          colorFilter: const ColorFilter.mode(Colors.red, BlendMode.modulate),
          child: Transform.translate(
            offset: Offset(-o, 0),
            child: Opacity(opacity: 0.45, child: child),
          ),
        ),
        ColorFiltered(
          colorFilter: const ColorFilter.mode(Colors.blue, BlendMode.modulate),
          child: Transform.translate(
            offset: Offset(o, 0),
            child: Opacity(opacity: 0.45, child: child),
          ),
        ),
        child,
      ],
    );
  }
}

class _TransitionVisual {
  const _TransitionVisual({
    this.flash = 0,
    this.burn = 0,
    this.dx = 0,
    this.dy = 0,
    this.scale = 1,
    this.opacity = 1,
  });

  final double flash;
  final double burn;
  final double dx;
  final double dy;
  final double scale;
  final double opacity;
}

class _VhsGrainPainter extends CustomPainter {
  const _VhsGrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x22FFFFFF);
    final rng = math.Random(7);
    for (var i = 0; i < 48; i++) {
      final y = rng.nextDouble() * size.height;
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, 1.2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Cover-crop helper: clip a region of a full-bleed source (no letterbox).
Widget _coverCrop({
  required Widget source,
  required Alignment alignment,
  required double width,
  required double height,
  required double fullW,
  required double fullH,
  double widthFactor = 1,
  double heightFactor = 1,
}) {
  return SizedBox(
    width: width,
    height: height,
    child: ClipRect(
      child: Align(
        alignment: alignment,
        widthFactor: widthFactor.clamp(0.05, 1.0),
        heightFactor: heightFactor.clamp(0.05, 1.0),
        child: SizedBox(width: fullW, height: fullH, child: source),
      ),
    ),
  );
}

class _DuoSplitLayout extends StatelessWidget {
  const _DuoSplitLayout({
    required this.vertical,
    required this.a,
    required this.b,
  });

  final bool vertical;
  final Widget a;
  final Widget b;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        if (vertical) {
          final half = (w / 2).floorToDouble();
          final rem = w - half;
          return ColoredBox(
            color: Colors.black,
            child: Row(
              children: [
                _coverCrop(
                  source: a,
                  alignment: Alignment.centerLeft,
                  width: half,
                  height: h,
                  fullW: w,
                  fullH: h,
                  widthFactor: 0.5,
                ),
                _coverCrop(
                  source: b,
                  alignment: Alignment.centerRight,
                  width: rem,
                  height: h,
                  fullW: w,
                  fullH: h,
                  widthFactor: 0.5,
                ),
              ],
            ),
          );
        }
        final half = (h / 2).floorToDouble();
        final rem = h - half;
        return ColoredBox(
          color: Colors.black,
          child: Column(
            children: [
              _coverCrop(
                source: a,
                alignment: Alignment.topCenter,
                width: w,
                height: half,
                fullW: w,
                fullH: h,
                heightFactor: 0.5,
              ),
              _coverCrop(
                source: b,
                alignment: Alignment.bottomCenter,
                width: w,
                height: rem,
                fullW: w,
                fullH: h,
                heightFactor: 0.5,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuadGridLayout extends StatelessWidget {
  const _QuadGridLayout({
    required this.tl,
    required this.tr,
    required this.bl,
    required this.br,
  });

  final Widget tl;
  final Widget tr;
  final Widget bl;
  final Widget br;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        final leftW = (w / 2).floorToDouble();
        final rightW = w - leftW;
        final topH = (h / 2).floorToDouble();
        final botH = h - topH;
        return ColoredBox(
          color: Colors.black,
          child: Column(
            children: [
              SizedBox(
                height: topH,
                child: Row(
                  children: [
                    _coverCrop(
                      source: tl,
                      alignment: Alignment.topLeft,
                      width: leftW,
                      height: topH,
                      fullW: w,
                      fullH: h,
                      widthFactor: 0.5,
                      heightFactor: 0.5,
                    ),
                    _coverCrop(
                      source: tr,
                      alignment: Alignment.topRight,
                      width: rightW,
                      height: topH,
                      fullW: w,
                      fullH: h,
                      widthFactor: 0.5,
                      heightFactor: 0.5,
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: botH,
                child: Row(
                  children: [
                    _coverCrop(
                      source: bl,
                      alignment: Alignment.bottomLeft,
                      width: leftW,
                      height: botH,
                      fullW: w,
                      fullH: h,
                      widthFactor: 0.5,
                      heightFactor: 0.5,
                    ),
                    _coverCrop(
                      source: br,
                      alignment: Alignment.bottomRight,
                      width: rightW,
                      height: botH,
                      fullW: w,
                      fullH: h,
                      widthFactor: 0.5,
                      heightFactor: 0.5,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilmStripLayout extends StatelessWidget {
  const _FilmStripLayout({
    required this.top,
    required this.mid,
    required this.bottom,
  });

  final Widget top;
  final Widget mid;
  final Widget bottom;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        final band = (h / 3).floorToDouble();
        final last = h - band * 2;
        Widget strip(Widget source, Alignment align, double height) {
          return _coverCrop(
            source: source,
            alignment: align,
            width: w,
            height: height,
            fullW: w,
            fullH: h,
            heightFactor: height / h,
          );
        }

        return ColoredBox(
          color: Colors.black,
          child: Column(
            children: [
              strip(top, Alignment.topCenter, band),
              strip(mid, Alignment.center, band),
              strip(bottom, Alignment.bottomCenter, last),
            ],
          ),
        );
      },
    );
  }
}

class _DiagonalSplitLayout extends StatelessWidget {
  const _DiagonalSplitLayout({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipPath(
              clipper: const _DiagonalClipper(leftSide: true),
              child: _coverCrop(
                source: left,
                alignment: const Alignment(-0.35, 0),
                width: w,
                height: h,
                fullW: w,
                fullH: h,
              ),
            ),
            ClipPath(
              clipper: const _DiagonalClipper(leftSide: false),
              child: _coverCrop(
                source: right,
                alignment: const Alignment(0.35, 0),
                width: w,
                height: h,
                fullW: w,
                fullH: h,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DiagonalClipper extends CustomClipper<Path> {
  const _DiagonalClipper({required this.leftSide});

  final bool leftSide;

  @override
  Path getClip(Size size) {
    final path = Path();
    if (leftSide) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width * 0.62, 0)
        ..lineTo(size.width * 0.38, size.height)
        ..lineTo(0, size.height)
        ..close();
    } else {
      path
        ..moveTo(size.width * 0.62, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width * 0.38, size.height)
        ..close();
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _DiagonalClipper oldClipper) =>
      oldClipper.leftSide != leftSide;
}

class _SideBySideMirrorLayout extends StatelessWidget {
  const _SideBySideMirrorLayout({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        final half = (w / 2).floorToDouble();
        final rem = w - half;
        return ColoredBox(
          color: Colors.black,
          child: Row(
            children: [
              _coverCrop(
                source: left,
                alignment: Alignment.centerLeft,
                width: half,
                height: h,
                fullW: w,
                fullH: h,
                widthFactor: 0.5,
              ),
              SizedBox(
                width: rem,
                height: h,
                child: ClipRect(
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
                    child: _coverCrop(
                      source: right,
                      alignment: Alignment.centerLeft,
                      width: rem,
                      height: h,
                      fullW: w,
                      fullH: h,
                      widthFactor: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShapedCutoutLayout extends StatefulWidget {
  const _ShapedCutoutLayout({
    required this.shape,
    required this.backgroundUrl,
    required this.maskUrl,
    required this.widthRatio,
    required this.heightRatio,
    required this.positionX,
    required this.positionY,
    required this.cornerRadius,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.child,
  });

  final String shape;
  final String? backgroundUrl;
  final String? maskUrl;
  final double widthRatio;
  final double heightRatio;
  final double positionX;
  final double positionY;
  final double cornerRadius;
  final int canvasWidth;
  final int canvasHeight;
  final Widget child;

  @override
  State<_ShapedCutoutLayout> createState() => _ShapedCutoutLayoutState();
}

class _ShapedCutoutLayoutState extends State<_ShapedCutoutLayout> {
  VideoPlayerController? _bgVideo;

  @override
  void initState() {
    super.initState();
    _maybeInitBgVideo();
  }

  @override
  void didUpdateWidget(covariant _ShapedCutoutLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backgroundUrl != widget.backgroundUrl) {
      _disposeBg();
      _maybeInitBgVideo();
    }
  }

  @override
  void dispose() {
    _disposeBg();
    super.dispose();
  }

  void _disposeBg() {
    final c = _bgVideo;
    _bgVideo = null;
    c?.dispose();
  }

  Future<void> _maybeInitBgVideo() async {
    final raw = widget.backgroundUrl?.trim() ?? '';
    if (raw.isEmpty) return;
    final url = MediaUtils.resolveAbsoluteUrl(raw);
    final lower = url.toLowerCase();
    final isVideo = lower.contains('.mp4') ||
        lower.contains('.mov') ||
        lower.contains('.webm') ||
        lower.contains('.m3u8') ||
        lower.contains('/video');
    if (!isVideo) return;
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      setState(() => _bgVideo = controller);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final bgUrl = widget.backgroundUrl?.trim();
    final resolved =
        (bgUrl == null || bgUrl.isEmpty) ? null : MediaUtils.resolveAbsoluteUrl(bgUrl);

    Widget background;
    final vc = _bgVideo;
    if (vc != null && vc.value.isInitialized) {
      background = FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: vc.value.size.width,
          height: vc.value.size.height,
          child: VideoPlayer(vc),
        ),
      );
    } else if (resolved != null && resolved.isNotEmpty) {
      background = SafeNetworkImage(imageUrl: resolved, fit: BoxFit.cover);
    } else {
      background = const ColoredBox(color: Color(0xFF1A1A1A));
    }

    final align = templateCanvasAlignment(
      widget.positionX,
      widget.positionY,
      canvasWidth: widget.canvasWidth,
      canvasHeight: widget.canvasHeight,
    );

    final hole = _shapedHole(child: widget.child);

    return Stack(
      fit: StackFit.expand,
      children: [
        background,
        Align(
          alignment: align,
          child: FractionallySizedBox(
            widthFactor: widget.widthRatio.clamp(0.15, 0.95),
            heightFactor: widget.heightRatio.clamp(0.15, 0.95),
            child: hole,
          ),
        ),
      ],
    );
  }

  Widget _shapedHole({required Widget child}) {
    final shape = widget.shape.toLowerCase();
    if (shape == 'circle') {
      return ClipOval(child: child);
    }
    if (shape == 'rect') {
      return ClipRect(child: child);
    }
    if (shape == 'custom' &&
        (widget.maskUrl?.trim().isNotEmpty ?? false)) {
      final mask = MediaUtils.resolveAbsoluteUrl(widget.maskUrl!);
      return ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) {
          // Soft fallback: rounded hole when custom mask can't be decoded here.
          return const LinearGradient(
            colors: [Colors.white, Colors.white],
          ).createShader(bounds);
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.cornerRadius.clamp(0, 120)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              // Keep mask URL referenced for future bitmap mask support.
              Opacity(
                opacity: 0,
                child: SafeNetworkImage(imageUrl: mask, fit: BoxFit.cover),
              ),
            ],
          ),
        ),
      );
    }
    // rounded_rect (default)
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.cornerRadius.clamp(0, 120)),
      child: child,
    );
  }
}
