import 'dart:async';

import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

typedef ChatVoicePlaybackListener = void Function();

/// Voice playback via [VideoPlayerController] (already used elsewhere in the app).
class ChatVoicePlayback {
  ChatVoicePlayback._();

  static final ChatVoicePlayback instance = ChatVoicePlayback._();

  static const Duration _initTimeout = Duration(seconds: 20);

  VideoPlayerController? _controller;
  VoidCallback? _listener;
  final List<ChatVoicePlaybackListener> _listeners = [];
  String? _activeMessageId;
  bool _handlingComplete = false;

  String? get activeMessageId => _activeMessageId;

  void addListener(ChatVoicePlaybackListener listener) {
    _listeners.add(listener);
  }

  void removeListener(ChatVoicePlaybackListener listener) {
    _listeners.remove(listener);
  }

  bool isPlaying(String messageId) {
    return _activeMessageId == messageId &&
        (_controller?.value.isPlaying ?? false);
  }

  bool isActive(String messageId) => _activeMessageId == messageId;

  bool isPaused(String messageId) {
    return _activeMessageId == messageId &&
        _controller != null &&
        _controller!.value.isInitialized &&
        !_controller!.value.isPlaying;
  }

  /// 0.0–1.0 while this message is loaded; null otherwise.
  double? playbackProgress(String messageId) {
    if (_activeMessageId != messageId || _controller == null) return null;
    final value = _controller!.value;
    if (!value.isInitialized || value.duration.inMilliseconds <= 0) {
      return null;
    }
    return (value.position.inMilliseconds / value.duration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  Duration? playbackPosition(String messageId) {
    if (_activeMessageId != messageId || _controller == null) return null;
    final value = _controller!.value;
    if (!value.isInitialized) return null;
    return value.position;
  }

  Future<void> toggle(String messageId, String url) async {
    if (_activeMessageId == messageId &&
        _controller != null &&
        _controller!.value.isInitialized) {
      if (_controller!.value.isPlaying) {
        await _controller!.pause();
      } else {
        await _controller!.play();
      }
      _notify();
      return;
    }

    await _start(messageId, url);
  }

  Future<void> stop() async {
    await _disposeController();
    _activeMessageId = null;
    _notify();
  }

  Future<void> dispose() async {
    await stop();
    _listeners.clear();
  }

  Future<void> _start(String messageId, String url) async {
    await _disposeController();
    _activeMessageId = messageId;
    _handlingComplete = false;

    final resolved = MediaUtils.resolveAbsoluteUrl(url.trim());
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(resolved),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = controller;

    void onUpdate() {
      final value = controller.value;
      if (!_handlingComplete &&
          value.isInitialized &&
          value.duration > Duration.zero &&
          value.position >= value.duration - const Duration(milliseconds: 250)) {
        _handlingComplete = true;
        unawaited(_onPlaybackComplete());
      }
      _notify();
    }

    _listener = onUpdate;
    controller.addListener(onUpdate);

    try {
      await controller.initialize().timeout(_initTimeout);
      await controller.setVolume(1);
      await controller.play();
      _notify();
    } catch (_) {
      await _disposeController();
      _activeMessageId = null;
      _notify();
      rethrow;
    }
  }

  Future<void> _onPlaybackComplete() async {
    final completedId = _activeMessageId;
    await _disposeController();
    _activeMessageId = null;
    if (completedId != null) {
      _notify();
    }
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;

    final listener = _listener;
    _listener = null;
    if (listener != null) {
      controller.removeListener(listener);
    }
    await controller.dispose();
  }

  void _notify() {
    for (final listener in List<ChatVoicePlaybackListener>.from(_listeners)) {
      listener();
    }
  }
}
