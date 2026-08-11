import 'dart:async';

import 'package:bimobondapp/app/camera_engine/native_camera_controller.dart';
import 'package:bimobondapp/app/camera_engine/native_camera_preview.dart';
import 'package:bimobondapp/app/camera_engine/remote/remote_effect_models.dart';
import 'package:bimobondapp/app/camera_engine/remote/remote_effect_service.dart';
import 'package:bimobondapp/app/sounds/presentation/utils/sound_audio_preview.dart';
import 'package:bimobondapp/app/sounds/presentation/utils/sound_local_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

/// Phase 1–11 harness: record → music mix → export/compress.
class NativeCameraPhase1Screen extends StatefulWidget {
  const NativeCameraPhase1Screen({super.key});

  @override
  State<NativeCameraPhase1Screen> createState() =>
      _NativeCameraPhase1ScreenState();
}

class _NativeCameraPhase1ScreenState extends State<NativeCameraPhase1Screen>
    with WidgetsBindingObserver {
  final NativeCameraController _controller = NativeCameraController();
  late final RemoteEffectService _remoteEffects =
      RemoteEffectService(controller: _controller);
  bool _starting = true;
  String? _error;
  bool _busy = false;

  double _intensity = 0.55;
  bool _filterOn = true;
  bool _faceTrackingOn = false;
  bool _landmarkDebugOn = false;
  String? _activeEffectId;
  List<RemoteEffect> _effects = const [];
  String _catalogVersion = '';
  Timer? _recordPollTimer;
  String? _lastSavedPath;
  String? _lastExportPath;
  final TextEditingController _musicUrlController = TextEditingController();
  double _musicVolume = 0.8;
  double _originalVolume = 0.2;
  String? _musicLabel;

  bool _beautyOn = true;
  double _skinSmooth = 0.45;
  double _beautyBrightness = 0.2;
  double _skinTone = 0.15;
  double _sharpen = 0.1;
  double _eyeEnhance = 0.2;

  bool _warpOn = true;
  double _faceSlim = 0.25;
  double _bigEyes = 0.15;
  double _smallNose = 0.1;
  double _bigLips = 0.12;
  double _jaw = 0.12;
  double _chin = 0.1;

  bool _makeupOn = true;
  double _lipstick = 0.55;
  double _blush = 0.4;
  double _eyeliner = 0.45;
  double _eyeshadow = 0.35;

  Timer? _facePollTimer;
  Timer? _effectDebounce;
  Future<void> _lifecycleChain = Future.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onControllerChanged);
    _open();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopFacePoll();
    _stopRecordPoll();
    _effectDebounce?.cancel();
    unawaited(SoundAudioPreview.stop());
    _musicUrlController.dispose();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _enqueueLifecycle(Future<void> Function() action) {
    _lifecycleChain = _lifecycleChain.then((_) async {
      if (!mounted) return;
      await action();
    }).catchError((_) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
        // Brief OS transitions (notifications, dialogs) — do not tear camera/GL.
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _enqueueLifecycle(_onAppBackground);
        break;
      case AppLifecycleState.resumed:
        _enqueueLifecycle(_onAppForeground);
        break;
    }
  }

  Future<void> _onAppBackground() async {
    _stopFacePoll();
    _stopRecordPoll();
    if (_controller.state.recording) {
      await _controller.cancelRecording();
    }
    await SoundAudioPreview.stop();
    await _controller.stop();
  }

  Future<void> _onAppForeground() async {
    await _open();
  }

  void _startFacePoll() {
    _facePollTimer?.cancel();
    _facePollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if ((!_faceTrackingOn && _activeEffectId == null) || !mounted) return;
      _controller.getState();
    });
  }

  void _stopFacePoll() {
    _facePollTimer?.cancel();
    _facePollTimer = null;
  }

  void _startRecordPoll() {
    _recordPollTimer?.cancel();
    _recordPollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!_controller.state.recording || !mounted) return;
      _controller.getState();
    });
  }

  void _stopRecordPoll() {
    _recordPollTimer?.cancel();
    _recordPollTimer = null;
  }

  Future<void> _toggleRecording() async {
    await _run(() async {
      if (_controller.state.recording) {
        await SoundAudioPreview.stop();
        final state = await _controller.stopRecording();
        _stopRecordPoll();
        final path = state.recordingPath;
        if (!mounted) return;
        setState(() => _lastSavedPath = path);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              path == null ? 'Recording failed' : 'Saved: $path',
            ),
          ),
        );
      } else {
        final mic = await Permission.microphone.request();
        final musicPath = _controller.state.musicPath;
        final url = _musicUrlController.text.trim();
        if (musicPath != null && url.isNotEmpty) {
          unawaited(
            SoundAudioPreview.playAt(
              'phase10_monitor',
              url,
              startOffset:
                  Duration(milliseconds: _controller.state.musicOffsetMs),
              window: const Duration(seconds: 60),
              loop: true,
            ),
          );
        }
        await _controller.startRecording(withAudio: mic.isGranted);
        _startRecordPoll();
      }
    });
  }

  Future<void> _cancelRecording() async {
    await _run(() async {
      await SoundAudioPreview.stop();
      await _controller.cancelRecording();
      _stopRecordPoll();
      if (!mounted) return;
      setState(() => _lastSavedPath = null);
    });
  }

  Future<void> _loadMusicFromUrl() async {
    await _run(() async {
      final url = _musicUrlController.text.trim();
      if (url.isEmpty) {
        throw StateError('Paste a music URL first');
      }
      final file = await SoundLocalFile.resolve(url);
      if (file == null) {
        throw StateError('Failed to download music');
      }
      await _controller.setMusic(
        path: file.path,
        offsetMs: 0,
        musicVolume: _musicVolume,
        originalVolume: _originalVolume,
      );
      if (!mounted) return;
      setState(() => _musicLabel = file.path.split(RegExp(r'[\\/]')).last);
      await SoundAudioPreview.playAt(
        'phase10_preview',
        url,
        window: const Duration(seconds: 8),
      );
    });
  }

  Future<void> _clearMusic() async {
    await _run(() async {
      await SoundAudioPreview.stop();
      await _controller.clearMusic();
      if (!mounted) return;
      setState(() => _musicLabel = null);
    });
  }

  Future<void> _exportLastRecording({bool force = false}) async {
    await _run(() async {
      final input = _lastSavedPath ?? _controller.state.recordingPath;
      if (input == null || input.isEmpty) {
        throw StateError('Record a clip first');
      }
      final state = await _controller.exportVideo(path: input, force: force);
      if (!mounted) return;
      setState(() => _lastExportPath = state.exportPath);
      final mode = state.exportPassthrough ? 'passthrough' : 'transcoded';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.exportPath == null
                ? 'Export failed'
                : 'Export ($mode): ${state.exportPath}',
          ),
        ),
      );
    });
  }

  Future<void> _open() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        throw PlatformException(
          code: 'camera_permission_denied',
          message: 'Camera permission is required',
        );
      }
      await _controller.start();
      await _controller.setColorFilter(
        enabled: _filterOn,
        intensity: _intensity,
      );
      await _controller.setBeauty(
        skinSmooth: _skinSmooth,
        brightness: _beautyBrightness,
        skinTone: _skinTone,
        sharpen: _sharpen,
        eyeEnhancement: _eyeEnhance,
        enabled: _beautyOn,
      );
      await _controller.setWarp(
        faceSlim: _faceSlim,
        bigEyes: _bigEyes,
        smallNose: _smallNose,
        bigLips: _bigLips,
        jaw: _jaw,
        chin: _chin,
        enabled: _warpOn,
      );
      await _controller.setMakeup(
        lipstick: _lipstick,
        blush: _blush,
        eyeliner: _eyeliner,
        eyeshadow: _eyeshadow,
        enabled: _makeupOn,
      );
      if ((_beautyOn &&
              (_skinSmooth > 0.01 ||
                  _skinTone > 0.01 ||
                  _sharpen > 0.01 ||
                  _eyeEnhance > 0.01)) ||
          (_warpOn &&
              (_faceSlim > 0.01 ||
                  _bigEyes > 0.01 ||
                  _smallNose > 0.01 ||
                  _bigLips > 0.01 ||
                  _jaw > 0.01 ||
                  _chin > 0.01)) ||
          (_makeupOn &&
              (_lipstick > 0.01 ||
                  _blush > 0.01 ||
                  _eyeliner > 0.01 ||
                  _eyeshadow > 0.01))) {
        _faceTrackingOn = true;
        _startFacePoll();
      }
      final catalog = await _remoteEffects.refresh(forceNetwork: true);
      _effects = catalog.effects;
      _catalogVersion = catalog.version;
      if (_activeEffectId != null) {
        await _remoteEffects.activate(
          _activeEffectId,
          controller: _controller,
        );
        _faceTrackingOn = true;
        _startFacePoll();
      } else if (_faceTrackingOn) {
        await _controller.setFaceTracking(
          enabled: true,
          landmarkDebug: _landmarkDebugOn,
        );
        _startFacePoll();
      }
      if (!mounted) return;
      setState(() => _starting = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleFaceTracking(bool enabled) async {
    setState(() => _faceTrackingOn = enabled);
    if (!enabled && _activeEffectId == null) _stopFacePoll();
    await _run(() async {
      await _controller.setFaceTracking(
        enabled: enabled || _activeEffectId != null,
        landmarkDebug: _landmarkDebugOn,
      );
      if (enabled || _activeEffectId != null) {
        _startFacePoll();
      }
    });
  }

  Future<void> _toggleLandmarkDebug(bool enabled) async {
    setState(() => _landmarkDebugOn = enabled);
    if (!_faceTrackingOn && _activeEffectId == null) return;
    await _run(() async {
      await _controller.setFaceTracking(
        enabled: true,
        landmarkDebug: enabled,
      );
    });
  }

  Future<void> _selectEffect(String? effectId) async {
    setState(() => _activeEffectId = effectId);
    await _run(() async {
      await _remoteEffects.activate(effectId, controller: _controller);
      final tracking = effectId != null || _faceTrackingOn;
      if (effectId != null) {
        setState(() => _faceTrackingOn = true);
      }
      if (tracking) {
        _startFacePoll();
      } else {
        _stopFacePoll();
      }
    });
  }

  Future<void> _refreshCatalog() async {
    await _run(() async {
      final catalog = await _remoteEffects.refresh(forceNetwork: true);
      if (!mounted) return;
      setState(() {
        _effects = catalog.effects;
        _catalogVersion = catalog.version;
      });
      if (_activeEffectId != null &&
          !_effects.any((e) => e.id == _activeEffectId)) {
        _activeEffectId = null;
        await _remoteEffects.activate(null, controller: _controller);
      }
    });
  }

  void _pushBeauty() {
    _debounceEffect(_pushBeautyNow);
  }

  void _pushBeautyNow() {
    _controller.previewBeauty(
      skinSmooth: _skinSmooth,
      brightness: _beautyBrightness,
      skinTone: _skinTone,
      sharpen: _sharpen,
      eyeEnhancement: _eyeEnhance,
      enabled: _beautyOn,
    );
    _ensureTrackingForEffects();
  }

  void _pushWarp() {
    _debounceEffect(_pushWarpNow);
  }

  void _pushWarpNow() {
    _controller.previewWarp(
      faceSlim: _faceSlim,
      bigEyes: _bigEyes,
      smallNose: _smallNose,
      bigLips: _bigLips,
      jaw: _jaw,
      chin: _chin,
      enabled: _warpOn,
    );
    _ensureTrackingForEffects();
  }

  void _pushMakeup() {
    _debounceEffect(_pushMakeupNow);
  }

  void _pushMakeupNow() {
    _controller.previewMakeup(
      lipstick: _lipstick,
      blush: _blush,
      eyeliner: _eyeliner,
      eyeshadow: _eyeshadow,
      enabled: _makeupOn,
    );
    _ensureTrackingForEffects();
  }

  void _debounceEffect(void Function() apply) {
    _effectDebounce?.cancel();
    _effectDebounce = Timer(const Duration(milliseconds: 50), apply);
  }

  void _ensureTrackingForEffects() {
    final needsTrack = (_beautyOn &&
            (_skinSmooth > 0.01 ||
                _skinTone > 0.01 ||
                _sharpen > 0.01 ||
                _eyeEnhance > 0.01)) ||
        (_warpOn &&
            (_faceSlim > 0.01 ||
                _bigEyes > 0.01 ||
                _smallNose > 0.01 ||
                _bigLips > 0.01 ||
                _jaw > 0.01 ||
                _chin > 0.01)) ||
        (_makeupOn &&
            (_lipstick > 0.01 ||
                _blush > 0.01 ||
                _eyeliner > 0.01 ||
                _eyeshadow > 0.01));
    if (needsTrack && !_faceTrackingOn) {
      setState(() => _faceTrackingOn = true);
      _startFacePoll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final activeId = _activeEffectId ?? state.activeFaceEffectId;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _open, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          else if (_starting)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else
            NativeCameraPreview(controller: _controller),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(LucideIcons.x, color: Colors.white),
                  ),
                  const Spacer(),
                  Text(
                    state.recording
                        ? 'REC · ${_formatDuration(state.recordingDurationMs)}'
                        : 'Phase 11 · export · tex ${state.textureId ?? '—'}'
                            '${state.faceTrackingEnabled ? ' · faces ${state.faceCount}' : ''}',
                    style: TextStyle(
                      color: state.recording ? Colors.redAccent : Colors.white70,
                      fontSize: 12,
                      fontWeight:
                          state.recording ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (state.recording)
            const Positioned(
              top: 72,
              left: 0,
              right: 0,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xAAB71C1C),
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Text(
                      'Recording',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (!_starting && _error == null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 28,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.52,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _EffectChip(
                          label: 'None',
                          selected: activeId == null,
                          onTap: _busy ? null : () => _selectEffect(null),
                        ),
                        ..._effects.map(
                          (e) => _EffectChip(
                            label: e.name,
                            selected: activeId == e.id,
                            onTap: _busy ? null : () => _selectEffect(e.id),
                          ),
                        ),
                        _EffectChip(
                          label: _catalogVersion.isEmpty
                              ? '↻'
                              : '↻ $_catalogVersion',
                          selected: false,
                          onTap: _busy ? null : _refreshCatalog,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Color filter',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Switch(
                              value: _filterOn,
                              onChanged: (v) {
                                setState(() => _filterOn = v);
                                _controller.unawaitedSetColorFilter(
                                  enabled: v,
                                  intensity: _intensity,
                                );
                              },
                            ),
                          ],
                        ),
                        Slider(
                          value: _intensity,
                          onChanged: _filterOn
                              ? (v) {
                                  setState(() => _intensity = v);
                                  _debounceEffect(
                                    () => _controller.previewFilterIntensity(v),
                                  );
                                }
                              : null,
                        ),
                        const Divider(color: Colors.white24, height: 8),
                        Row(
                          children: [
                            const Text(
                              'Beauty',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Switch(
                              value: _beautyOn,
                              onChanged: (v) {
                                setState(() => _beautyOn = v);
                                _pushBeauty();
                              },
                            ),
                          ],
                        ),
                        _BeautySlider(
                          label: 'Smooth',
                          value: _skinSmooth,
                          enabled: _beautyOn,
                          onChanged: (v) {
                            setState(() => _skinSmooth = v);
                            _pushBeauty();
                          },
                        ),
                        _BeautySlider(
                          label: 'Bright',
                          value: _beautyBrightness,
                          enabled: _beautyOn,
                          onChanged: (v) {
                            setState(() => _beautyBrightness = v);
                            _pushBeauty();
                          },
                        ),
                        _BeautySlider(
                          label: 'Tone',
                          value: _skinTone,
                          enabled: _beautyOn,
                          onChanged: (v) {
                            setState(() => _skinTone = v);
                            _pushBeauty();
                          },
                        ),
                        _BeautySlider(
                          label: 'Sharpen',
                          value: _sharpen,
                          enabled: _beautyOn,
                          onChanged: (v) {
                            setState(() => _sharpen = v);
                            _pushBeauty();
                          },
                        ),
                        _BeautySlider(
                          label: 'Eyes',
                          value: _eyeEnhance,
                          enabled: _beautyOn,
                          onChanged: (v) {
                            setState(() => _eyeEnhance = v);
                            _pushBeauty();
                          },
                        ),
                        const Divider(color: Colors.white24, height: 8),
                        Row(
                          children: [
                            const Text(
                              'Face warp',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Switch(
                              value: _warpOn,
                              onChanged: (v) {
                                setState(() => _warpOn = v);
                                _pushWarp();
                              },
                            ),
                          ],
                        ),
                        _BeautySlider(
                          label: 'Slim',
                          value: _faceSlim,
                          enabled: _warpOn,
                          onChanged: (v) {
                            setState(() => _faceSlim = v);
                            _pushWarp();
                          },
                        ),
                        _BeautySlider(
                          label: 'Eyes+',
                          value: _bigEyes,
                          enabled: _warpOn,
                          onChanged: (v) {
                            setState(() => _bigEyes = v);
                            _pushWarp();
                          },
                        ),
                        _BeautySlider(
                          label: 'Nose-',
                          value: _smallNose,
                          enabled: _warpOn,
                          onChanged: (v) {
                            setState(() => _smallNose = v);
                            _pushWarp();
                          },
                        ),
                        _BeautySlider(
                          label: 'Lips+',
                          value: _bigLips,
                          enabled: _warpOn,
                          onChanged: (v) {
                            setState(() => _bigLips = v);
                            _pushWarp();
                          },
                        ),
                        _BeautySlider(
                          label: 'Jaw',
                          value: _jaw,
                          enabled: _warpOn,
                          onChanged: (v) {
                            setState(() => _jaw = v);
                            _pushWarp();
                          },
                        ),
                        _BeautySlider(
                          label: 'Chin',
                          value: _chin,
                          enabled: _warpOn,
                          onChanged: (v) {
                            setState(() => _chin = v);
                            _pushWarp();
                          },
                        ),
                        const Divider(color: Colors.white24, height: 8),
                        Row(
                          children: [
                            const Text(
                              'Makeup',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Switch(
                              value: _makeupOn,
                              onChanged: (v) {
                                setState(() => _makeupOn = v);
                                _pushMakeup();
                              },
                            ),
                          ],
                        ),
                        _BeautySlider(
                          label: 'Lips',
                          value: _lipstick,
                          enabled: _makeupOn,
                          onChanged: (v) {
                            setState(() => _lipstick = v);
                            _pushMakeup();
                          },
                        ),
                        _BeautySlider(
                          label: 'Blush',
                          value: _blush,
                          enabled: _makeupOn,
                          onChanged: (v) {
                            setState(() => _blush = v);
                            _pushMakeup();
                          },
                        ),
                        _BeautySlider(
                          label: 'Liner',
                          value: _eyeliner,
                          enabled: _makeupOn,
                          onChanged: (v) {
                            setState(() => _eyeliner = v);
                            _pushMakeup();
                          },
                        ),
                        _BeautySlider(
                          label: 'Shadow',
                          value: _eyeshadow,
                          enabled: _makeupOn,
                          onChanged: (v) {
                            setState(() => _eyeshadow = v);
                            _pushMakeup();
                          },
                        ),
                        const Divider(color: Colors.white24, height: 8),
                        const Text(
                          'Music + mic',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _musicUrlController,
                          enabled: !_busy && !state.recording,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Music URL (mp3/m4a)',
                            hintStyle: TextStyle(color: Colors.white38),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _musicLabel ??
                                    (state.musicPath != null
                                        ? 'Music ready'
                                        : 'No music'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _busy || state.recording
                                  ? null
                                  : _loadMusicFromUrl,
                              child: const Text('Load'),
                            ),
                            TextButton(
                              onPressed: _busy ||
                                      state.recording ||
                                      state.musicPath == null
                                  ? null
                                  : _clearMusic,
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                        _BeautySlider(
                          label: 'Music',
                          value: _musicVolume,
                          enabled: !state.recording,
                          onChanged: (v) {
                            setState(() => _musicVolume = v);
                            _controller.previewMusicVolumes(
                              musicVolume: v,
                              originalVolume: _originalVolume,
                            );
                          },
                        ),
                        _BeautySlider(
                          label: 'Mic',
                          value: _originalVolume,
                          enabled: !state.recording,
                          onChanged: (v) {
                            setState(() => _originalVolume = v);
                            _controller.previewMusicVolumes(
                              musicVolume: _musicVolume,
                              originalVolume: v,
                            );
                          },
                        ),
                        const Divider(color: Colors.white24, height: 8),
                        Row(
                          children: [
                            const Text(
                              'Face tracking',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Switch(
                              value: _faceTrackingOn,
                              onChanged: _busy ? null : _toggleFaceTracking,
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              _faceTrackingOn || activeId != null
                                  ? 'Landmarks · ${state.faceCount} face'
                                      '${state.faceCount == 1 ? '' : 's'}'
                                  : 'Landmark debug',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const Spacer(),
                            Switch(
                              value: _landmarkDebugOn,
                              onChanged:
                                  (_faceTrackingOn || activeId != null) &&
                                          !_busy
                                      ? _toggleLandmarkDebug
                                      : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _RoundAction(
                        icon: state.torchEnabled
                            ? LucideIcons.zap
                            : LucideIcons.zapOff,
                        label: 'Flash',
                        onTap: state.recording
                            ? null
                            : state.torchAvailable
                                ? () => _run(() async {
                                    await _controller.setFlash(
                                      !state.torchEnabled,
                                    );
                                  })
                                : null,
                      ),
                      _RoundAction(
                        icon: LucideIcons.refreshCw,
                        label: 'Flip',
                        onTap: state.recording
                            ? null
                            : () => _run(() async {
                                await _controller.switchCamera();
                                if (_activeEffectId != null) {
                                  await _remoteEffects.activate(
                                    _activeEffectId,
                                    controller: _controller,
                                  );
                                } else if (_faceTrackingOn) {
                                  await _controller.setFaceTracking(
                                    enabled: true,
                                    landmarkDebug: _landmarkDebugOn,
                                  );
                                }
                              }),
                      ),
                      _RoundAction(
                        icon: state.recording
                            ? LucideIcons.square
                            : LucideIcons.circle,
                        label: state.recording
                            ? _formatDuration(state.recordingDurationMs)
                            : 'Rec',
                        onTap: _busy ? null : _toggleRecording,
                      ),
                      if (state.recording)
                        _RoundAction(
                          icon: LucideIcons.x,
                          label: 'Cancel',
                          onTap: _busy ? null : _cancelRecording,
                        ),
                      _RoundAction(
                        icon: LucideIcons.download,
                        label: 'Export',
                        onTap: _busy ||
                                state.recording ||
                                (_lastSavedPath == null &&
                                    state.recordingPath == null)
                            ? null
                            : () => _exportLastRecording(),
                      ),
                      _RoundAction(
                        icon: LucideIcons.circleStop,
                        label: 'Stop',
                        onTap: state.recording
                            ? null
                            : () => _run(() async {
                                _stopFacePoll();
                                await _controller.stop();
                                if (mounted) setState(() {});
                              }),
                      ),
                    ],
                  ),
                  if (_lastSavedPath != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Rec: $_lastSavedPath',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (_lastExportPath != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Exp: $_lastExportPath',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.lightGreenAccent,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(int ms) {
    final totalSec = (ms / 1000).floor();
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _BeautySlider extends StatelessWidget {
  const _BeautySlider({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 58,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ],
    );
  }
}

class _EffectChip extends StatelessWidget {
  const _EffectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: onTap == null ? null : (_) => onTap!(),
        selectedColor: Colors.white24,
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.white70,
          fontSize: 12,
        ),
        backgroundColor: Colors.white12,
        side: BorderSide(color: selected ? Colors.white54 : Colors.white24),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.white24,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(
                icon,
                color: enabled ? Colors.white : Colors.white38,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: enabled ? Colors.white70 : Colors.white38,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
