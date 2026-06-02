import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class ChatVoiceRecordingResult {
  const ChatVoiceRecordingResult({
    required this.file,
    required this.duration,
  });

  final File file;
  final Duration duration;
}

enum ChatVoiceRecorderStartFailure {
  permissionDenied,
  permissionPermanentlyDenied,
  pluginUnavailable,
}

class ChatVoiceRecorder {
  ChatVoiceRecorder() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;
  DateTime? _startedAt;
  String? _path;
  bool _isRecordingActive = false;

  /// Returns `true` on success, or a [ChatVoiceRecorderStartFailure].
  Future<Object?> start() async {
    if (_isRecordingActive) {
      await cancel();
    }

    final permissionFailure = await _ensureMicrophonePermission();
    if (permissionFailure != null) {
      return permissionFailure;
    }

    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/chat_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );
    } on MissingPluginException {
      return ChatVoiceRecorderStartFailure.pluginUnavailable;
    }

    _path = path;
    _startedAt = DateTime.now();
    _isRecordingActive = true;
    return true;
  }

  Future<ChatVoiceRecordingResult?> stop() async {
    if (!_isRecordingActive) return null;

    final startedAt = _startedAt;
    final savedPath = _path;
    String? recordedPath;

    try {
      recordedPath = await _recorder.stop();
    } on MissingPluginException {
      recordedPath = null;
    } finally {
      _clearSession();
    }

    final filePath = recordedPath ?? savedPath;
    if (filePath == null || startedAt == null) return null;

    final file = File(filePath);
    if (!await file.exists()) return null;

    final duration = DateTime.now().difference(startedAt);
    if (duration.inMilliseconds < 300) {
      await file.delete();
      return null;
    }

    return ChatVoiceRecordingResult(file: file, duration: duration);
  }

  Future<void> cancel() async {
    if (!_isRecordingActive) {
      _clearSession();
      return;
    }

    try {
      final path = await _recorder.stop();
      final filePath = path ?? _path;
      if (filePath != null) {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } on MissingPluginException {
      // Native plugin not linked — still clear local state.
    } finally {
      _clearSession();
    }
  }

  Future<void> dispose() async {
    await cancel();
    try {
      await _recorder.dispose();
    } on MissingPluginException {
      // No-op when plugin is not registered.
    }
  }

  void _clearSession() {
    _startedAt = null;
    _path = null;
    _isRecordingActive = false;
  }

  Future<ChatVoiceRecorderStartFailure?> _ensureMicrophonePermission() async {
    try {
      var status = await Permission.microphone.status;

      if (!status.isGranted) {
        if (status.isPermanentlyDenied || status.isRestricted) {
          return ChatVoiceRecorderStartFailure.permissionPermanentlyDenied;
        }

        status = await Permission.microphone.request();
      }

      if (status.isGranted) {
        return null;
      }

      if (status.isPermanentlyDenied || status.isRestricted) {
        return ChatVoiceRecorderStartFailure.permissionPermanentlyDenied;
      }

      return ChatVoiceRecorderStartFailure.permissionDenied;
    } on MissingPluginException {
      return ChatVoiceRecorderStartFailure.pluginUnavailable;
    }
  }
}
