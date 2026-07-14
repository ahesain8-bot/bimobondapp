import 'dart:async';

import 'package:flutter/services.dart';
import 'package:bimobondapp/app/ar_camera/ar_camera_constants.dart';

class ArCameraBridge {
  ArCameraBridge._();

  static const _channel = MethodChannel(ArCameraConstants.channelName);

  static Future<void> warmup() async {
    await _channel.invokeMethod<void>('warmup');
  }

  static Future<void> prepareShaderPipeline() async {
    await _channel.invokeMethod<void>('prepareShaderPipeline');
  }

  static void setFilter(String filter, {double intensity = 1.0}) {
    _channel.invokeMethod<void>('setFilter', {
      'filter': filter,
      'intensity': intensity,
    });
  }

  static void setFilterIntensity(double intensity) {
    _channel.invokeMethod<void>('setFilterIntensity', {
      'intensity': intensity.clamp(0.0, 1.0),
    });
  }

  static Future<String?> takePhoto() async {
    final path = await _channel
        .invokeMethod<String>('takePhoto')
        .timeout(const Duration(seconds: 10));
    return path;
  }

  static Future<void> startRecording() async {
    await _channel.invokeMethod<void>('startRecording');
  }

  static Future<String?> stopRecording() async {
    final path = await _channel.invokeMethod<String>('stopRecording');
    return path;
  }

  static Future<String?> mergeVideoSegments(List<String> paths) async {
    if (paths.isEmpty) return null;
    if (paths.length == 1) return paths.first;
    final path = await _channel.invokeMethod<String>('mergeVideoSegments', {
      'paths': paths,
    });
    return path;
  }

  /// Toggles front ↔ back. Returns whether the active camera is front.
  static Future<bool> flipCamera() async {
    final isFront = await _channel.invokeMethod<bool>('flipCamera');
    return isFront ?? true;
  }
}
