import 'package:bimobondapp/app/camera_engine/native_camera_constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Snapshot of the native camera engine state (Phase 1–11).
class NativeCameraState {
  const NativeCameraState({
    required this.ok,
    this.textureId,
    this.width = 0,
    this.height = 0,
    this.isFront = true,
    this.torchEnabled = false,
    this.torchAvailable = false,
    this.filterEnabled = true,
    this.filterIntensity = 0.55,
    this.faceTrackingEnabled = false,
    this.landmarkDebugEnabled = false,
    this.faceCount = 0,
    this.pitchDeg = 0,
    this.yawDeg = 0,
    this.rollDeg = 0,
    this.activeFaceEffectId,
    this.beautyEnabled = true,
    this.beautySkinSmooth = 0,
    this.beautyBrightness = 0,
    this.beautySkinTone = 0,
    this.beautySharpen = 0,
    this.beautyEyeEnhancement = 0,
    this.warpEnabled = true,
    this.warpFaceSlim = 0,
    this.warpBigEyes = 0,
    this.warpSmallNose = 0,
    this.warpBigLips = 0,
    this.warpJaw = 0,
    this.warpChin = 0,
    this.makeupEnabled = true,
    this.makeupLipstick = 0,
    this.makeupBlush = 0,
    this.makeupEyeliner = 0,
    this.makeupEyeshadow = 0,
    this.recording = false,
    this.recordingPath,
    this.recordingDurationMs = 0,
    this.musicPath,
    this.musicOffsetMs = 0,
    this.musicVolume = 0.8,
    this.originalVolume = 0.2,
    this.exporting = false,
    this.exportPath,
    this.exportProgress = 0,
    this.exportPassthrough = false,
    this.bound = false,
    this.error,
  });

  factory NativeCameraState.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return const NativeCameraState(ok: false, error: 'null_state');
    }
    final textureRaw = map['textureId'];
    final textureId = textureRaw is int
        ? textureRaw
        : textureRaw is num
        ? textureRaw.toInt()
        : null;
    return NativeCameraState(
      ok: map['ok'] == true,
      textureId: textureId,
      width: (map['width'] as num?)?.toInt() ?? 0,
      height: (map['height'] as num?)?.toInt() ?? 0,
      isFront: map['isFront'] != false,
      torchEnabled: map['torchEnabled'] == true,
      torchAvailable: map['torchAvailable'] == true,
      filterEnabled: map['filterEnabled'] != false,
      filterIntensity: (map['filterIntensity'] as num?)?.toDouble() ?? 0.55,
      faceTrackingEnabled: map['faceTrackingEnabled'] == true,
      landmarkDebugEnabled: map['landmarkDebugEnabled'] == true,
      faceCount: (map['faceCount'] as num?)?.toInt() ?? 0,
      pitchDeg: (map['pitchDeg'] as num?)?.toDouble() ?? 0,
      yawDeg: (map['yawDeg'] as num?)?.toDouble() ?? 0,
      rollDeg: (map['rollDeg'] as num?)?.toDouble() ?? 0,
      activeFaceEffectId: map['activeFaceEffectId']?.toString(),
      beautyEnabled: map['beautyEnabled'] != false,
      beautySkinSmooth: (map['beautySkinSmooth'] as num?)?.toDouble() ?? 0,
      beautyBrightness: (map['beautyBrightness'] as num?)?.toDouble() ?? 0,
      beautySkinTone: (map['beautySkinTone'] as num?)?.toDouble() ?? 0,
      beautySharpen: (map['beautySharpen'] as num?)?.toDouble() ?? 0,
      beautyEyeEnhancement:
          (map['beautyEyeEnhancement'] as num?)?.toDouble() ?? 0,
      warpEnabled: map['warpEnabled'] != false,
      warpFaceSlim: (map['warpFaceSlim'] as num?)?.toDouble() ?? 0,
      warpBigEyes: (map['warpBigEyes'] as num?)?.toDouble() ?? 0,
      warpSmallNose: (map['warpSmallNose'] as num?)?.toDouble() ?? 0,
      warpBigLips: (map['warpBigLips'] as num?)?.toDouble() ?? 0,
      warpJaw: (map['warpJaw'] as num?)?.toDouble() ?? 0,
      warpChin: (map['warpChin'] as num?)?.toDouble() ?? 0,
      makeupEnabled: map['makeupEnabled'] != false,
      makeupLipstick: (map['makeupLipstick'] as num?)?.toDouble() ?? 0,
      makeupBlush: (map['makeupBlush'] as num?)?.toDouble() ?? 0,
      makeupEyeliner: (map['makeupEyeliner'] as num?)?.toDouble() ?? 0,
      makeupEyeshadow: (map['makeupEyeshadow'] as num?)?.toDouble() ?? 0,
      recording: map['recording'] == true,
      recordingPath: map['recordingPath']?.toString(),
      recordingDurationMs: (map['recordingDurationMs'] as num?)?.toInt() ?? 0,
      musicPath: map['musicPath']?.toString(),
      musicOffsetMs: (map['musicOffsetMs'] as num?)?.toInt() ?? 0,
      musicVolume: (map['musicVolume'] as num?)?.toDouble() ?? 0.8,
      originalVolume: (map['originalVolume'] as num?)?.toDouble() ?? 0.2,
      exporting: map['exporting'] == true,
      exportPath: map['exportPath']?.toString(),
      exportProgress: (map['exportProgress'] as num?)?.toInt() ?? 0,
      exportPassthrough: map['exportPassthrough'] == true,
      bound: map['bound'] == true,
      error: map['error']?.toString(),
    );
  }

  final bool ok;
  final int? textureId;
  final int width;
  final int height;
  final bool isFront;
  final bool torchEnabled;
  final bool torchAvailable;
  final bool filterEnabled;
  final double filterIntensity;
  final bool faceTrackingEnabled;
  final bool landmarkDebugEnabled;
  final int faceCount;
  final double pitchDeg;
  final double yawDeg;
  final double rollDeg;
  final String? activeFaceEffectId;
  final bool beautyEnabled;
  final double beautySkinSmooth;
  final double beautyBrightness;
  final double beautySkinTone;
  final double beautySharpen;
  final double beautyEyeEnhancement;
  final bool warpEnabled;
  final double warpFaceSlim;
  final double warpBigEyes;
  final double warpSmallNose;
  final double warpBigLips;
  final double warpJaw;
  final double warpChin;
  final bool makeupEnabled;
  final double makeupLipstick;
  final double makeupBlush;
  final double makeupEyeliner;
  final double makeupEyeshadow;
  final bool recording;
  final String? recordingPath;
  final int recordingDurationMs;
  final String? musicPath;
  final int musicOffsetMs;
  final double musicVolume;
  final double originalVolume;
  final bool exporting;
  final String? exportPath;
  final int exportProgress;
  final bool exportPassthrough;
  final bool bound;
  final String? error;

  bool get hasTexture => textureId != null;

  NativeCameraState copyWith({
    bool? ok,
    int? textureId,
    int? width,
    int? height,
    bool? isFront,
    bool? torchEnabled,
    bool? torchAvailable,
    bool? filterEnabled,
    double? filterIntensity,
    bool? faceTrackingEnabled,
    bool? landmarkDebugEnabled,
    int? faceCount,
    double? pitchDeg,
    double? yawDeg,
    double? rollDeg,
    String? activeFaceEffectId,
    bool? beautyEnabled,
    double? beautySkinSmooth,
    double? beautyBrightness,
    double? beautySkinTone,
    double? beautySharpen,
    double? beautyEyeEnhancement,
    bool? warpEnabled,
    double? warpFaceSlim,
    double? warpBigEyes,
    double? warpSmallNose,
    double? warpBigLips,
    double? warpJaw,
    double? warpChin,
    bool? makeupEnabled,
    double? makeupLipstick,
    double? makeupBlush,
    double? makeupEyeliner,
    double? makeupEyeshadow,
    bool? recording,
    String? recordingPath,
    int? recordingDurationMs,
    String? musicPath,
    int? musicOffsetMs,
    double? musicVolume,
    double? originalVolume,
    bool? exporting,
    String? exportPath,
    int? exportProgress,
    bool? exportPassthrough,
    bool? bound,
    String? error,
    bool clearActiveFaceEffect = false,
    bool clearRecordingPath = false,
    bool clearMusicPath = false,
    bool clearExportPath = false,
  }) {
    return NativeCameraState(
      ok: ok ?? this.ok,
      textureId: textureId ?? this.textureId,
      width: width ?? this.width,
      height: height ?? this.height,
      isFront: isFront ?? this.isFront,
      torchEnabled: torchEnabled ?? this.torchEnabled,
      torchAvailable: torchAvailable ?? this.torchAvailable,
      filterEnabled: filterEnabled ?? this.filterEnabled,
      filterIntensity: filterIntensity ?? this.filterIntensity,
      faceTrackingEnabled: faceTrackingEnabled ?? this.faceTrackingEnabled,
      landmarkDebugEnabled: landmarkDebugEnabled ?? this.landmarkDebugEnabled,
      faceCount: faceCount ?? this.faceCount,
      pitchDeg: pitchDeg ?? this.pitchDeg,
      yawDeg: yawDeg ?? this.yawDeg,
      rollDeg: rollDeg ?? this.rollDeg,
      activeFaceEffectId: clearActiveFaceEffect
          ? null
          : (activeFaceEffectId ?? this.activeFaceEffectId),
      beautyEnabled: beautyEnabled ?? this.beautyEnabled,
      beautySkinSmooth: beautySkinSmooth ?? this.beautySkinSmooth,
      beautyBrightness: beautyBrightness ?? this.beautyBrightness,
      beautySkinTone: beautySkinTone ?? this.beautySkinTone,
      beautySharpen: beautySharpen ?? this.beautySharpen,
      beautyEyeEnhancement: beautyEyeEnhancement ?? this.beautyEyeEnhancement,
      warpEnabled: warpEnabled ?? this.warpEnabled,
      warpFaceSlim: warpFaceSlim ?? this.warpFaceSlim,
      warpBigEyes: warpBigEyes ?? this.warpBigEyes,
      warpSmallNose: warpSmallNose ?? this.warpSmallNose,
      warpBigLips: warpBigLips ?? this.warpBigLips,
      warpJaw: warpJaw ?? this.warpJaw,
      warpChin: warpChin ?? this.warpChin,
      makeupEnabled: makeupEnabled ?? this.makeupEnabled,
      makeupLipstick: makeupLipstick ?? this.makeupLipstick,
      makeupBlush: makeupBlush ?? this.makeupBlush,
      makeupEyeliner: makeupEyeliner ?? this.makeupEyeliner,
      makeupEyeshadow: makeupEyeshadow ?? this.makeupEyeshadow,
      recording: recording ?? this.recording,
      recordingPath: clearRecordingPath
          ? null
          : (recordingPath ?? this.recordingPath),
      recordingDurationMs: recordingDurationMs ?? this.recordingDurationMs,
      musicPath: clearMusicPath ? null : (musicPath ?? this.musicPath),
      musicOffsetMs: musicOffsetMs ?? this.musicOffsetMs,
      musicVolume: musicVolume ?? this.musicVolume,
      originalVolume: originalVolume ?? this.originalVolume,
      exporting: exporting ?? this.exporting,
      exportPath: clearExportPath ? null : (exportPath ?? this.exportPath),
      exportProgress: exportProgress ?? this.exportProgress,
      exportPassthrough: exportPassthrough ?? this.exportPassthrough,
      bound: bound ?? this.bound,
      error: error,
    );
  }
}

class NativeFaceEffectInfo {
  const NativeFaceEffectInfo({
    required this.id,
    required this.name,
    this.version = 1,
    this.remote = false,
  });

  final String id;
  final String name;
  final int version;
  final bool remote;
}

/// Flutter control plane for [NativeCameraEngine] (Android).
///
/// Commands/state only — camera frames never cross the MethodChannel.
class NativeCameraController extends ChangeNotifier {
  NativeCameraController();

  static const _channel = MethodChannel(NativeCameraConstants.channelName);

  NativeCameraState _state = const NativeCameraState(ok: false);
  NativeCameraState get state => _state;

  bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;

  Future<NativeCameraState> start() async {
    _ensureAndroid();
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('start');
    _state = NativeCameraState.fromMap(raw);
    notifyListeners();
    if (!_state.ok || !_state.hasTexture) {
      throw PlatformException(
        code: 'start_failed',
        message: _state.error ?? 'No textureId returned',
      );
    }
    return _state;
  }

  Future<NativeCameraState> stop() async {
    _ensureAndroid();
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('stop');
    _state = NativeCameraState.fromMap(raw);
    notifyListeners();
    return _state;
  }

  Future<NativeCameraState> switchCamera() async {
    _ensureAndroid();
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'switchCamera',
    );
    _state = NativeCameraState.fromMap(raw);
    notifyListeners();
    if (!_state.ok) {
      throw PlatformException(
        code: 'switch_failed',
        message: _state.error ?? 'switchCamera failed',
      );
    }
    return _state;
  }

  Future<NativeCameraState> setFlash(bool enabled) async {
    _ensureAndroid();
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'setFlash',
      {'enabled': enabled},
    );
    _state = NativeCameraState.fromMap(raw);
    notifyListeners();
    if (!_state.ok) {
      throw PlatformException(
        code: 'flash_failed',
        message: _state.error ?? 'setFlash failed',
      );
    }
    return _state;
  }

  /// Phase 2 GPU color filter. Native applies on the GL thread — no texture rebuild.
  Future<NativeCameraState> setColorFilter({
    required bool enabled,
    required double intensity,
  }) async {
    _ensureAndroid();
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'setColorFilter',
      {
        'enabled': enabled,
        'intensity': intensity.clamp(0.0, 1.0),
      },
    );
    _state = NativeCameraState.fromMap(raw);
    // Optimistic local update for smooth slider (avoids waiting on channel).
    _state = _state.copyWith(
      filterEnabled: enabled,
      filterIntensity: intensity.clamp(0.0, 1.0),
    );
    notifyListeners();
    if (!_state.ok) {
      throw PlatformException(
        code: 'filter_failed',
        message: _state.error ?? 'setColorFilter failed',
      );
    }
    return _state;
  }

  /// Local-only intensity nudge for continuous slider without channel spam.
  void previewFilterIntensity(double intensity) {
    _state = _state.copyWith(filterIntensity: intensity.clamp(0.0, 1.0));
    notifyListeners();
    // Fire-and-forget native update.
    unawaitedSetColorFilter(
      enabled: _state.filterEnabled,
      intensity: intensity,
    );
  }

  void unawaitedSetColorFilter({
    required bool enabled,
    required double intensity,
  }) {
    _channel.invokeMethod<void>('setColorFilter', {
      'enabled': enabled,
      'intensity': intensity.clamp(0.0, 1.0),
    });
  }

  /// Phase 3: MediaPipe face tracking. Landmarks stay native; optional GPU debug dots.
  Future<NativeCameraState> setFaceTracking({
    required bool enabled,
    bool landmarkDebug = false,
  }) async {
    _ensureAndroid();
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'setFaceTracking',
      {
        'enabled': enabled,
        'landmarkDebug': landmarkDebug,
      },
    );
    _state = NativeCameraState.fromMap(raw);
    notifyListeners();
    if (!_state.ok) {
      throw PlatformException(
        code: 'face_tracking_failed',
        message: _state.error ?? 'setFaceTracking failed',
      );
    }
    return _state;
  }

  /// Phase 4: 2D face sticker effect. Pass null / `'none'` to clear.
  Future<NativeCameraState> setFaceEffect(String? effectId) async {
    _ensureAndroid();
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'setFaceEffect',
      {'effectId': effectId},
    );
    _state = NativeCameraState.fromMap(raw);
    notifyListeners();
    if (!_state.ok) {
      throw PlatformException(
        code: 'face_effect_failed',
        message: _state.error ?? 'setFaceEffect failed',
      );
    }
    return _state;
  }

  Future<List<NativeFaceEffectInfo>> listFaceEffects() async {
    _ensureAndroid();
    final raw = await _channel.invokeMethod<List<dynamic>>('listFaceEffects');
    if (raw == null) return const [];
    return raw.map((e) {
      final map = Map<dynamic, dynamic>.from(e as Map);
      final versionRaw = map['version'];
      final version = versionRaw is int
          ? versionRaw
          : versionRaw is num
              ? versionRaw.toInt()
              : int.tryParse(versionRaw?.toString() ?? '') ?? 1;
      return NativeFaceEffectInfo(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        version: version,
        remote: map['remote'] == true,
      );
    }).where((e) => e.id.isNotEmpty).toList();
  }

  /// Phase 8: install a downloaded remote face effect on native GPU.
  Future<void> installFaceEffect({
    required String id,
    required String name,
    required int version,
    required List<Map<String, dynamic>> layers,
    bool force = false,
  }) async {
    _ensureAndroid();
    await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'installFaceEffect',
      {
        'id': id,
        'name': name,
        'version': version,
        'force': force,
        'layers': layers,
      },
    );
  }

  /// Phase 8: release native resources for remote effect ids.
  Future<void> unloadFaceEffects(List<String> ids) async {
    _ensureAndroid();
    if (ids.isEmpty) return;
    await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'unloadFaceEffects',
      {'ids': ids},
    );
  }

  /// Phase 5: masked GPU beauty. Intensities are 0.0–1.0.
  Future<NativeCameraState> setBeauty({
    double skinSmooth = 0,
    double brightness = 0,
    double skinTone = 0,
    double sharpen = 0,
    double eyeEnhancement = 0,
    bool enabled = true,
  }) async {
    _ensureAndroid();
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'setBeauty',
      {
        'skinSmooth': skinSmooth.clamp(0.0, 1.0),
        'brightness': brightness.clamp(0.0, 1.0),
        'skinTone': skinTone.clamp(0.0, 1.0),
        'sharpen': sharpen.clamp(0.0, 1.0),
        'eyeEnhancement': eyeEnhancement.clamp(0.0, 1.0),
        'enabled': enabled,
      },
    );
    _state = NativeCameraState.fromMap(raw);
    _state = _state.copyWith(
      beautyEnabled: enabled,
      beautySkinSmooth: skinSmooth.clamp(0.0, 1.0),
      beautyBrightness: brightness.clamp(0.0, 1.0),
      beautySkinTone: skinTone.clamp(0.0, 1.0),
      beautySharpen: sharpen.clamp(0.0, 1.0),
      beautyEyeEnhancement: eyeEnhancement.clamp(0.0, 1.0),
    );
    notifyListeners();
    if (!_state.ok) {
      throw PlatformException(
        code: 'beauty_failed',
        message: _state.error ?? 'setBeauty failed',
      );
    }
    return _state;
  }

  /// Fire-and-forget beauty update for continuous sliders.
  void previewBeauty({
    required double skinSmooth,
    required double brightness,
    required double skinTone,
    required double sharpen,
    required double eyeEnhancement,
    bool enabled = true,
  }) {
    _state = _state.copyWith(
      beautyEnabled: enabled,
      beautySkinSmooth: skinSmooth.clamp(0.0, 1.0),
      beautyBrightness: brightness.clamp(0.0, 1.0),
      beautySkinTone: skinTone.clamp(0.0, 1.0),
      beautySharpen: sharpen.clamp(0.0, 1.0),
      beautyEyeEnhancement: eyeEnhancement.clamp(0.0, 1.0),
    );
    notifyListeners();
    _channel.invokeMethod<void>('setBeauty', {
      'skinSmooth': skinSmooth.clamp(0.0, 1.0),
      'brightness': brightness.clamp(0.0, 1.0),
      'skinTone': skinTone.clamp(0.0, 1.0),
      'sharpen': sharpen.clamp(0.0, 1.0),
      'eyeEnhancement': eyeEnhancement.clamp(0.0, 1.0),
      'enabled': enabled,
    });
  }

  /// Phase 6: GPU face mesh deformation. Intensities are 0.0–1.0.
  Future<NativeCameraState> setWarp({
    double faceSlim = 0,
    double bigEyes = 0,
    double smallNose = 0,
    double bigLips = 0,
    double jaw = 0,
    double chin = 0,
    bool enabled = true,
  }) async {
    _ensureAndroid();
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'setWarp',
      {
        'faceSlim': faceSlim.clamp(0.0, 1.0),
        'bigEyes': bigEyes.clamp(0.0, 1.0),
        'smallNose': smallNose.clamp(0.0, 1.0),
        'bigLips': bigLips.clamp(0.0, 1.0),
        'jaw': jaw.clamp(0.0, 1.0),
        'chin': chin.clamp(0.0, 1.0),
        'enabled': enabled,
      },
    );
    _state = NativeCameraState.fromMap(raw);
    _state = _state.copyWith(
      warpEnabled: enabled,
      warpFaceSlim: faceSlim.clamp(0.0, 1.0),
      warpBigEyes: bigEyes.clamp(0.0, 1.0),
      warpSmallNose: smallNose.clamp(0.0, 1.0),
      warpBigLips: bigLips.clamp(0.0, 1.0),
      warpJaw: jaw.clamp(0.0, 1.0),
      warpChin: chin.clamp(0.0, 1.0),
    );
    notifyListeners();
    if (!_state.ok) {
      throw PlatformException(
        code: 'warp_failed',
        message: _state.error ?? 'setWarp failed',
      );
    }
    return _state;
  }

  void previewWarp({
    required double faceSlim,
    required double bigEyes,
    required double smallNose,
    required double bigLips,
    required double jaw,
    required double chin,
    bool enabled = true,
  }) {
    _state = _state.copyWith(
      warpEnabled: enabled,
      warpFaceSlim: faceSlim.clamp(0.0, 1.0),
      warpBigEyes: bigEyes.clamp(0.0, 1.0),
      warpSmallNose: smallNose.clamp(0.0, 1.0),
      warpBigLips: bigLips.clamp(0.0, 1.0),
      warpJaw: jaw.clamp(0.0, 1.0),
      warpChin: chin.clamp(0.0, 1.0),
    );
    notifyListeners();
    _channel.invokeMethod<void>('setWarp', {
      'faceSlim': faceSlim.clamp(0.0, 1.0),
      'bigEyes': bigEyes.clamp(0.0, 1.0),
      'smallNose': smallNose.clamp(0.0, 1.0),
      'bigLips': bigLips.clamp(0.0, 1.0),
      'jaw': jaw.clamp(0.0, 1.0),
      'chin': chin.clamp(0.0, 1.0),
      'enabled': enabled,
    });
  }

  /// Phase 7: GPU region-masked makeup. Intensities are 0.0–1.0.
  Future<NativeCameraState> setMakeup({
    double lipstick = 0,
    double blush = 0,
    double eyeliner = 0,
    double eyeshadow = 0,
    List<double>? lipstickColor,
    List<double>? blushColor,
    List<double>? eyelinerColor,
    List<double>? eyeshadowColor,
    bool enabled = true,
  }) async {
    _ensureAndroid();
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'setMakeup',
      {
        'lipstick': lipstick.clamp(0.0, 1.0),
        'blush': blush.clamp(0.0, 1.0),
        'eyeliner': eyeliner.clamp(0.0, 1.0),
        'eyeshadow': eyeshadow.clamp(0.0, 1.0),
        'lipstickColor': ?lipstickColor,
        'blushColor': ?blushColor,
        'eyelinerColor': ?eyelinerColor,
        'eyeshadowColor': ?eyeshadowColor,
        'enabled': enabled,
      },
    );
    _state = NativeCameraState.fromMap(raw);
    _state = _state.copyWith(
      makeupEnabled: enabled,
      makeupLipstick: lipstick.clamp(0.0, 1.0),
      makeupBlush: blush.clamp(0.0, 1.0),
      makeupEyeliner: eyeliner.clamp(0.0, 1.0),
      makeupEyeshadow: eyeshadow.clamp(0.0, 1.0),
    );
    notifyListeners();
    if (!_state.ok) {
      throw PlatformException(
        code: 'makeup_failed',
        message: _state.error ?? 'setMakeup failed',
      );
    }
    return _state;
  }

  void previewMakeup({
    required double lipstick,
    required double blush,
    required double eyeliner,
    required double eyeshadow,
    bool enabled = true,
  }) {
    _state = _state.copyWith(
      makeupEnabled: enabled,
      makeupLipstick: lipstick.clamp(0.0, 1.0),
      makeupBlush: blush.clamp(0.0, 1.0),
      makeupEyeliner: eyeliner.clamp(0.0, 1.0),
      makeupEyeshadow: eyeshadow.clamp(0.0, 1.0),
    );
    notifyListeners();
    _channel.invokeMethod<void>('setMakeup', {
      'lipstick': lipstick.clamp(0.0, 1.0),
      'blush': blush.clamp(0.0, 1.0),
      'eyeliner': eyeliner.clamp(0.0, 1.0),
      'eyeshadow': eyeshadow.clamp(0.0, 1.0),
      'enabled': enabled,
    });
  }

  /// Phase 9: start hardware H.264 recording of the GPU-composited preview.
  Future<NativeCameraState> startRecording({bool withAudio = true}) async {
    _ensureAndroid();
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'startRecording',
      {'withAudio': withAudio},
    );
    _state = NativeCameraState.fromMap(raw);
    notifyListeners();
    if (!_state.ok) {
      throw PlatformException(
        code: 'start_recording_failed',
        message: _state.error ?? 'startRecording failed',
      );
    }
    return _state;
  }

  /// Phase 9: finish recording and return state with [NativeCameraState.recordingPath].
  Future<NativeCameraState> stopRecording() async {
    _ensureAndroid();
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'stopRecording',
    );
    _state = NativeCameraState.fromMap(raw);
    notifyListeners();
    if (!_state.ok) {
      throw PlatformException(
        code: 'stop_recording_failed',
        message: _state.error ?? 'stopRecording failed',
      );
    }
    return _state;
  }

  /// Phase 9: abort recording and delete partial files.
  Future<NativeCameraState> cancelRecording() async {
    _ensureAndroid();
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'cancelRecording',
    );
    _state = NativeCameraState.fromMap(raw);
    notifyListeners();
    return _state;
  }

  /// Phase 10: set local music file for the next recording mix.
  ///
  /// [musicVolume] / [originalVolume] are 0.0–1.0 (e.g. music 0.8, mic 0.2).
  /// Pass null [path] to clear music.
  Future<NativeCameraState> setMusic({
    String? path,
    int offsetMs = 0,
    double musicVolume = 0.8,
    double originalVolume = 0.2,
  }) async {
    _ensureAndroid();
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'setMusic',
      {
        'path': path,
        'offsetMs': offsetMs,
        'musicVolume': musicVolume.clamp(0.0, 1.0),
        'originalVolume': originalVolume.clamp(0.0, 1.0),
      },
    );
    _state = NativeCameraState.fromMap(raw);
    notifyListeners();
    return _state;
  }

  Future<NativeCameraState> clearMusic() async {
    _ensureAndroid();
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'clearMusic',
    );
    _state = NativeCameraState.fromMap(raw);
    notifyListeners();
    return _state;
  }

  /// Fire-and-forget volume nudge while music is already set.
  void previewMusicVolumes({
    required double musicVolume,
    required double originalVolume,
  }) {
    _state = _state.copyWith(
      musicVolume: musicVolume.clamp(0.0, 1.0),
      originalVolume: originalVolume.clamp(0.0, 1.0),
    );
    notifyListeners();
    _channel.invokeMethod<void>('setMusic', {
      'path': _state.musicPath,
      'offsetMs': _state.musicOffsetMs,
      'musicVolume': musicVolume.clamp(0.0, 1.0),
      'originalVolume': originalVolume.clamp(0.0, 1.0),
    });
  }

  /// Phase 11: export last recording (or [path]) to ≤1080p H.264 @ ~8 Mbps.
  ///
  /// Passthrough when already within profile unless [force] is true.
  Future<NativeCameraState> exportVideo({
    String? path,
    bool force = false,
  }) async {
    _ensureAndroid();
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'exportVideo',
      {
        'path': path,
        'force': force,
      },
    );
    _state = NativeCameraState.fromMap(raw);
    notifyListeners();
    if (!_state.ok) {
      throw PlatformException(
        code: 'export_failed',
        message: _state.error ?? 'exportVideo failed',
      );
    }
    return _state;
  }

  Future<NativeCameraState> cancelExport() async {
    _ensureAndroid();
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'cancelExport',
    );
    _state = NativeCameraState.fromMap(raw);
    notifyListeners();
    return _state;
  }

  Future<NativeCameraState> getState() async {
    _ensureAndroid();
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('getState');
    _state = NativeCameraState.fromMap(raw);
    notifyListeners();
    return _state;
  }

  Future<void> releaseNative() async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod<void>('dispose');
    } catch (_) {}
    _state = const NativeCameraState(ok: false);
  }

  @override
  void dispose() {
    if (isAndroid) {
      _channel.invokeMethod<void>('dispose');
    }
    _state = const NativeCameraState(ok: false);
    super.dispose();
  }

  void _ensureAndroid() {
    if (!isAndroid) {
      throw UnsupportedError('NativeCameraController is Android-only');
    }
  }
}
