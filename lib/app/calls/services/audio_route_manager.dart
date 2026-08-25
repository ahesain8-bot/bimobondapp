import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:bimobondapp/app/calls/domain/session/call_session_state.dart';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

class AudioRouteManager {
  AudioSession? _audioSession;
  StreamSubscription? _routeChangeSub;

  final _routeController = StreamController<CallAudioRoute>.broadcast();
  CallAudioRoute _currentRoute = CallAudioRoute.speaker;

  CallAudioRoute get currentRoute => _currentRoute;
  Stream<CallAudioRoute> get onRouteChanged => _routeController.stream;

  Future<void> initializeAudioSession() async {
    try {
      _audioSession = await AudioSession.instance;
      await _audioSession?.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      ));
      await _audioSession?.setActive(true);

      _routeChangeSub = _audioSession?.devicesChangedEventStream.listen((event) {
        debugPrint('AudioRouteManager: audio device route changed -> $event');
        _evaluateAudioRoute();
      });
    } catch (e) {
      debugPrint('AudioRouteManager initialize error: $e');
    }
  }

  void _evaluateAudioRoute() {
    // Basic route resolution
    _routeController.add(_currentRoute);
  }

  Future<void> setSpeakerphone(bool isSpeakerOn) async {
    try {
      await AudioManager.instance.setSpeakerOutputPreferred(isSpeakerOn);
      _currentRoute = isSpeakerOn ? CallAudioRoute.speaker : CallAudioRoute.earpiece;
      _routeController.add(_currentRoute);
      debugPrint('AudioRouteManager: speaker preferred set to $isSpeakerOn');
    } catch (e) {
      debugPrint('AudioRouteManager setSpeakerphone error: $e');
    }
  }

  Future<void> releaseAudioSession() async {
    try {
      await _routeChangeSub?.cancel();
      _routeChangeSub = null;
      await _audioSession?.setActive(false);
    } catch (e) {
      debugPrint('AudioRouteManager release error: $e');
    }
  }
}
