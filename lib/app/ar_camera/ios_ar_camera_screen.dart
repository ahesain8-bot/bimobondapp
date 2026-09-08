import 'dart:async';
import 'dart:io';

import 'package:bimobondapp/app/home/presentation/utils/media_item_edit_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:bimobondapp/app/ar_camera/ar_camera_bridge.dart';
import 'package:bimobondapp/app/ar_camera/ar_camera_constants.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_gallery_import_flow.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_gallery_picker.dart';

class IosArCameraScreen extends StatefulWidget {
  final bool isStory;

  const IosArCameraScreen({super.key, this.isStory = false});

  @override
  State<IosArCameraScreen> createState() => _IosArCameraScreenState();
}

class _IosArCameraScreenState extends State<IosArCameraScreen> {
  bool _isCapturing = false;
  bool _isFlipping = false;
  bool _isFrontCamera = true;
  bool _isFlashOn = false;

  Future<void> _flip() async {
    if (_isFlipping) return;
    setState(() => _isFlipping = true);
    final isFront = await ArCameraBridge.flipCamera();
    if (!mounted) return;
    setState(() {
      _isFlipping = false;
      _isFrontCamera = isFront;
    });
  }

  Future<void> _toggleFlash() async {
    final next = !_isFlashOn;
    setState(() => _isFlashOn = next);
    await ArCameraBridge.setFlash(next);
  }

  Future<void> _capture() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);
    try {
      final path = await ArCameraBridge.takePhoto();
      if (!mounted) return;
      if (path == null || path.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('camera_capture_error: no_frame')),
        );
        return;
      }
      await _openCapturedMediaEditor(File(path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('camera_capture_error: $e')));
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<void> _openCapturedMediaEditor(File file) async {
    unawaited(ArCameraBridge.suspendPreview());
    final MediaStudioExportResult? edited;
    try {
      final items = [GalleryMediaItem(file: file, type: 'IMAGE')];
      if (!mounted) return;
      edited = await MediaGalleryImportFlow.openBatchEditor(
        context,
        items: items,
        isStory: widget.isStory,
      );
    } finally {
      unawaited(ArCameraBridge.resumePreview());
    }
    if (!mounted || edited == null || edited.files.isEmpty) return;

    final postFiles = MediaGalleryImportFlow.composerFiles(edited);
    context.pushReplacementNamed(
      'add_post',
      extra: {
        'files': postFiles,
        'type': MediaGalleryImportFlow.composerType(edited),
        'isStory': widget.isStory,
        'initialSound': edited.sound,
        'initialSoundOffset': edited.soundOffset,
        'initialSoundWindow': edited.soundWindow,
        'initialSoundDidTrim': edited.soundDidTrim,
        'initialSoundSegmentId': edited.soundSegmentId,
        if (edited.filterName != null) 'filterName': edited.filterName,
        'filterCategory': edited.filterCategory.name,
        if (edited.effectSlug != null) 'effectSlug': edited.effectSlug,
        'beautyEnabled': edited.beautyEnabled,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const Positioned.fill(
            child: UiKitView(
              viewType: ArCameraConstants.viewType,
              layoutDirection: TextDirection.ltr,
              creationParamsCodec: StandardMessageCodec(),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 35,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Column(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.autorenew_rounded,
                          color: Colors.white,
                          size: 35,
                        ),
                        onPressed: _isFlipping ? null : _flip,
                      ),
                      IconButton(
                        icon: Icon(
                          _isFlashOn ? Icons.flash_on : Icons.flash_off,
                          color: Colors.white,
                          size: 35,
                        ),
                        onPressed: _toggleFlash,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: GestureDetector(
                  onTap: _isCapturing ? null : _capture,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: _isCapturing ? Colors.white24 : Colors.white38,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
