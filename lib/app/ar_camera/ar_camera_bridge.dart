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
    final path = await _channel.invokeMethod<String>('takePhoto');
    return path;
  }

  static Future<void> startRecording() async {
    await _channel.invokeMethod<void>('startRecording');
  }

  static Future<String?> stopRecording() async {
    final path = await _channel.invokeMethod<String>('stopRecording');
    return path;
  }
}
