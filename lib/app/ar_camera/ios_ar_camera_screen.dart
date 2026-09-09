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
import 'package:bimobondapp/l10n/app_localizations.dart';

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

  int _timerSeconds = 0; 
  int? _countdownValue;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

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

  Future<void> _openCountdownSheet() async {
    if (_countdownValue != null) return; 
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _IosCountdownSheetBody(
          l10n: l10n,
          initialSeconds: _timerSeconds,
          onTurnOff: () {
            if (!mounted) return;
            setState(() => _timerSeconds = 0);
          },
          onStart: (seconds) {
            if (!mounted) return;
            setState(() => _timerSeconds = seconds);
          },
        );
      },
    );
  }

  void _onShutterTap() {
    if (_countdownValue != null) {
      _countdownTimer?.cancel();
      _countdownTimer = null;
      setState(() => _countdownValue = null);
      return;
    }
    if (_isCapturing) return;
    if (_timerSeconds > 0) {
      _runCountdown();
    } else {
      unawaited(_capture());
    }
  }

  void _runCountdown() {
    setState(() => _countdownValue = _timerSeconds);
    HapticFeedback.selectionClick();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final current = _countdownValue;
      if (current == null) {
        timer.cancel();
        return;
      }
      if (current <= 1) {
        timer.cancel();
        _countdownTimer = null;
        // زي الأندرويد: التايمر بيتقفل لوحده بعد ما يستخدم مرة.
        setState(() {
          _countdownValue = null;
          _timerSeconds = 0;
        });
        unawaited(_capture());
      } else {
        final next = current - 1;
        setState(() => _countdownValue = next);
        if (next <= 1) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.selectionClick();
        }
      }
    });
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
                      IconButton(
                        icon: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              _timerSeconds == 0
                                  ? Icons.timer_outlined
                                  : Icons.timer,
                              color: _timerSeconds == 0
                                  ? Colors.white
                                  : Colors.amber,
                              size: 35,
                            ),
                            if (_timerSeconds > 0)
                              Positioned(
                                bottom: -2,
                                child: Text(
                                  '$_timerSeconds',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onPressed: _openCountdownSheet,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_countdownValue != null)
            Center(
              child: Text(
                '$_countdownValue',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 96,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 12, color: Colors.black54)],
                ),
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: GestureDetector(
                  onTap: _onShutterTap,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _countdownValue != null
                            ? Colors.amber
                            : Colors.white,
                        width: 4,
                      ),
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

class _IosCountdownSheetBody extends StatefulWidget {
  const _IosCountdownSheetBody({
    required this.l10n,
    required this.initialSeconds,
    required this.onTurnOff,
    required this.onStart,
  });

  final AppLocalizations l10n;
  final int initialSeconds;
  final VoidCallback onTurnOff;
  final ValueChanged<int> onStart;

  @override
  State<_IosCountdownSheetBody> createState() => _IosCountdownSheetBodyState();
}

class _IosCountdownSheetBodyState extends State<_IosCountdownSheetBody> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSeconds == 10
        ? 10
        : (widget.initialSeconds == 3 ? 3 : 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.fromLTRB(16, 14, 16, 12 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.l10n.cameraSetCountdown,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _IosCountdownSegment(
                selected: _selected,
                offLabel: widget.l10n.settingsOff,
                onChanged: (v) => setState(() => _selected = v),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  if (_selected == 0) {
                    widget.onTurnOff();
                  } else {
                    widget.onStart(_selected);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      _selected == 0
                          ? widget.l10n.settingsOff
                          : widget.l10n.cameraStartCountdown,
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
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

class _IosCountdownSegment extends StatelessWidget {
  const _IosCountdownSegment({
    required this.selected,
    required this.offLabel,
    required this.onChanged,
  });

  final int selected;
  final String offLabel;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [_seg(0, offLabel), _seg(3, '3s'), _seg(10, '10s')],
      ),
    );
  }

  Widget _seg(int seconds, String label) {
    final active = selected == seconds;
    return GestureDetector(
      onTap: () => onChanged(seconds),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
