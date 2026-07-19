import 'dart:typed_data';

import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Full-screen cropper for a single image. Returns the cropped PNG bytes via
/// [Navigator.pop], or null when cancelled.
class MediaCropScreen extends StatefulWidget {
  const MediaCropScreen({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<MediaCropScreen> createState() => _MediaCropScreenState();
}

class _MediaCropScreenState extends State<MediaCropScreen> {
  final _controller = CropController();
  bool _cropping = false;
  int _ratioIndex = 0;

  static const _ratios = <_CropRatio>[
    _CropRatio('Free', null),
    _CropRatio('1:1', 1),
    _CropRatio('4:5', 4 / 5),
    _CropRatio('3:4', 3 / 4),
    _CropRatio('16:9', 16 / 9),
    _CropRatio('9:16', 9 / 16),
  ];

  void _selectRatio(int index) {
    setState(() => _ratioIndex = index);
    _controller.aspectRatio = _ratios[index].value;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _cropping ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.x, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      l10n.mediaEditorCrop,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _cropping
                        ? null
                        : () {
                            setState(() => _cropping = true);
                            _controller.crop();
                          },
                    icon: const Icon(LucideIcons.check, color: Color(0xFFFE2C55)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Show the photo immediately so there is no black flash while
                  // the Crop widget decodes the same bytes on first frame.
                  Image.memory(
                    widget.imageBytes,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                  ),
                  Crop(
                    image: widget.imageBytes,
                    controller: _controller,
                    aspectRatio: _ratios[_ratioIndex].value,
                    baseColor: Colors.transparent,
                    maskColor: Colors.black.withValues(alpha: 0.55),
                    cornerDotBuilder: (size, edgeAlignment) => const DotControl(
                      color: Colors.white,
                    ),
                    onCropped: (result) {
                      switch (result) {
                        case CropSuccess(:final croppedImage):
                          Navigator.of(context).pop(croppedImage);
                        case CropFailure():
                          if (mounted) setState(() => _cropping = false);
                      }
                    },
                  ),
                  if (_cropping)
                    const ColoredBox(
                      color: Colors.black38,
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _ratios.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final ratio = _ratios[index];
                  final selected = index == _ratioIndex;
                  return GestureDetector(
                    onTap: _cropping ? null : () => _selectRatio(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        ratio.label,
                        style: TextStyle(
                          color: selected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CropRatio {
  const _CropRatio(this.label, this.value);
  final String label;
  final double? value;
}
