import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';

/// Creates a LiveKit track from the already-running native AR camera renderer.
///
/// The Android side only receives the renderer's output surface. It never opens
/// another lens and never replaces the CameraX configuration used by the app's
/// existing Kotlin camera.
class ArCameraLiveTrack {
  const ArCameraLiveTrack._();

  static const _channel = MethodChannel('com.dubai.bimobondapp/ar_camera_live');

  static bool get isSupported => Platform.isAndroid;

  static Future<bool> isAvailable() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<LocalVideoTrack> create({
    required int width,
    required int height,
    required int fps,
    required int maxBitrate,
    required CameraPosition cameraPosition,
  }) async {
    final stream = await rtc.createLocalMediaStream('ar_camera_live');
    try {
      await _channel.invokeMapMethod<String, dynamic>('attach', {
        'streamId': stream.id,
        'width': width,
        'height': height,
        'fps': fps,
      });
      // flutter_webrtc has no non-deprecated refresh API for tracks that a
      // native producer inserts into an existing stream.
      // ignore: deprecated_member_use
      await stream.getMediaTracks();
      final videoTracks = stream.getVideoTracks();
      if (videoTracks.isEmpty) {
        throw StateError('Native AR camera did not create a video track');
      }

      final options = CameraCaptureOptions(
        cameraPosition: cameraPosition,
        params: VideoParameters(
          dimensions: VideoDimensions(width, height),
          encoding: VideoEncoding(maxBitrate: maxBitrate, maxFramerate: fps),
        ),
      );

      // LiveKit exposes this constructor for native/custom camera sources.
      // ignore: invalid_use_of_internal_member
      return LocalVideoTrack(
        TrackSource.camera,
        stream,
        videoTracks.first,
        options,
      );
    } catch (_) {
      await detach();
      await stream.dispose();
      rethrow;
    }
  }

  /// Native, stage-by-stage state of the frame path.
  ///
  /// Camera -> renderer -> encoder surface -> SurfaceTexture -> WebRTC track.
  /// Read this when a publish reports no frames: `surfaceBound == false` with
  /// a `trackId` set means the renderer never received the output surface, so
  /// waiting longer on sender stats cannot help.
  static Future<Map<String, dynamic>> diagnostics() async {
    if (!isSupported) return const {};
    try {
      return await _channel.invokeMapMethod<String, dynamic>('diagnostics') ??
          const {};
    } catch (_) {
      return const {};
    }
  }

  static Future<void> detach() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('detach');
    } catch (_) {
      // The platform view may already have released the same output surface.
    }
  }
}
