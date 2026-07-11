import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_detected_face.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effect_asset_loader.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effect_image_painter.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effect_placement.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effects_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_face_detection.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_face_effect_mapper.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/home_tab_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Dev screen: face detection + sunglasses AR on a bundled person photo.
class CameraEffectTestScreen extends StatefulWidget {
  const CameraEffectTestScreen({super.key});

  static const personAsset = 'assets/images/person2.jpg';
  static const sunglassesAsset = 'assets/images/sunglasses.png';

  static final CameraEffectDefinition sunglassesEffect = CameraEffectDefinition(
    slug: 'sunglasses',
    emoji: '😎',
    previewColor: const Color(0xFF37474F),
    placement: CameraEffectPlacementDefaults.sunglasses,
    assetUrl: sunglassesAsset,
    requiresFaceDetection: true,
  );

  @override
  State<CameraEffectTestScreen> createState() => _CameraEffectTestScreenState();
}

class _CameraEffectTestScreenState extends State<CameraEffectTestScreen> {
  bool _loading = true;
  bool _effectEnabled = true;
  bool _showFaceBox = false;
  String? _error;
  List<CameraDetectedFace> _faces = const [];
  Size _imageSize = Size.zero;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _runDetection();
  }

  Future<void> _runDetection() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await CameraEffectAssetLoader.preload(CameraEffectTestScreen.sunglassesAsset);

      final data = await rootBundle.load(CameraEffectTestScreen.personAsset);
      final result = await CameraFaceDetection.detectAccurateFromBytes(
        data.buffer.asUint8List(),
      );
      if (!mounted) return;

      setState(() {
        _faces = result.faces;
        _imageSize = result.imageSize;
        _imageBytes = result.imageBytes;
        _loading = false;
        if (result.faces.isEmpty) {
          _error = 'No face detected in the sample image.';
        }
      });
    } catch (e, st) {
      debugPrint('Effect test detection failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: HomeTabAppBar(
        title: 'Effect Test',
        centerTitle: true,
        leading: HomeTabGlassIconButton(
          icon: LucideIcons.arrowLeft,
          onTap: () => context.pop(),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ColoredBox(
                  color: Colors.black,
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : _EffectTestPreview(
                          imageBytes: _imageBytes,
                          faces: _faces,
                          imageSize: _imageSize,
                          effect: CameraEffectTestScreen.sunglassesEffect,
                          showEffect: _effectEnabled,
                          showFaceBox: _showFaceBox,
                        ),
                ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              _loading
                  ? 'Running accurate face detection…'
                  : '${_faces.length} face(s) · ${_imageSize.width.toInt()}×${_imageSize.height.toInt()} px · photo mode',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
          _ControlTile(
            icon: LucideIcons.glasses,
            label: 'Sunglasses effect',
            value: _effectEnabled,
            onChanged: (value) => setState(() => _effectEnabled = value),
          ),
          _ControlTile(
            icon: LucideIcons.scanFace,
            label: 'Show face box',
            value: _showFaceBox,
            onChanged: (value) => setState(() => _showFaceBox = value),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: FilledButton.icon(
              onPressed: _loading ? null : _runDetection,
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: const Text('Re-run detection'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EffectTestPreview extends StatefulWidget {
  const _EffectTestPreview({
    this.imageBytes,
    required this.faces,
    required this.imageSize,
    required this.effect,
    required this.showEffect,
    required this.showFaceBox,
  });

  final Uint8List? imageBytes;

  final List<CameraDetectedFace> faces;
  final Size imageSize;
  final CameraEffectDefinition effect;
  final bool showEffect;
  final bool showFaceBox;

  @override
  State<_EffectTestPreview> createState() => _EffectTestPreviewState();
}

class _EffectTestPreviewState extends State<_EffectTestPreview> {
  @override
  void initState() {
    super.initState();
    _ensureAssetLoaded();
  }

  @override
  void didUpdateWidget(_EffectTestPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.effect.assetUrl != widget.effect.assetUrl) {
      _ensureAssetLoaded();
    }
  }

  Future<void> _ensureAssetLoaded() async {
    await CameraEffectAssetLoader.preload(widget.effect.assetUrl);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          fit: StackFit.expand,
          children: [
            if (widget.imageBytes != null && widget.imageBytes!.isNotEmpty)
              Image.memory(
                widget.imageBytes!,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              )
            else
              Image.asset(
                CameraEffectTestScreen.personAsset,
                fit: BoxFit.contain,
              ),
            if (widget.showEffect && widget.faces.isNotEmpty)
              Positioned.fill(
                child: CustomPaint(
                  painter: _SunglassesOverlayPainter(
                    faces: widget.faces,
                    imageSize: widget.imageSize,
                    canvasSize: canvasSize,
                    effect: widget.effect,
                  ),
                ),
              ),
            if (widget.showFaceBox && widget.faces.isNotEmpty)
              Positioned.fill(
                child: CustomPaint(
                  painter: _FaceBoxPainter(
                    faces: widget.faces,
                    imageSize: widget.imageSize,
                    canvasSize: canvasSize,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SunglassesOverlayPainter extends CustomPainter {
  _SunglassesOverlayPainter({
    required this.faces,
    required this.imageSize,
    required this.canvasSize,
    required this.effect,
  });

  final List<CameraDetectedFace> faces;
  final Size imageSize;
  final Size canvasSize;
  final CameraEffectDefinition effect;

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize == Size.zero) return;

    final mapped = CameraFaceEffectMapper.mapForBoxFit(
      faces: faces,
      imageSize: imageSize,
      canvasSize: size,
      fit: BoxFit.contain,
    );
    CameraEffectImagePainter.paintArScreenSpace(canvas, mapped, effect);
  }

  @override
  bool shouldRepaint(_SunglassesOverlayPainter oldDelegate) {
    return oldDelegate.faces != faces ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.canvasSize != canvasSize ||
        oldDelegate.effect != effect;
  }
}

class _FaceBoxPainter extends CustomPainter {
  _FaceBoxPainter({
    required this.faces,
    required this.imageSize,
    required this.canvasSize,
  });

  final List<CameraDetectedFace> faces;
  final Size imageSize;
  final Size canvasSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize == Size.zero) return;

    final mapped = CameraFaceEffectMapper.mapForBoxFit(
      faces: faces,
      imageSize: imageSize,
      canvasSize: size,
      fit: BoxFit.contain,
    );

    final boxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.greenAccent;

    final landmarkPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.yellowAccent;

    for (final face in mapped) {
      canvas.drawRect(face.boundingBox, boxPaint);
      for (final point in face.landmarks.values) {
        canvas.drawCircle(point, 4, landmarkPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_FaceBoxPainter oldDelegate) {
    return oldDelegate.faces != faces ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.canvasSize != canvasSize;
  }
}

class _ControlTile extends StatelessWidget {
  const _ControlTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, size: 22),
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }
}
