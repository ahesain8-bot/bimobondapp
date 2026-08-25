import 'dart:async';

import 'package:bimobondapp/app/calls/domain/session/call_session_state.dart';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

class NetworkQualityObserver {
  EventsListener<RoomEvent>? _roomListener;
  final _qualityController = StreamController<NetworkQualityLevel>.broadcast();

  NetworkQualityLevel _currentLevel = NetworkQualityLevel.unknown;

  NetworkQualityLevel get currentLevel => _currentLevel;
  Stream<NetworkQualityLevel> get onQualityChanged => _qualityController.stream;

  void attachToRoom(Room room) {
    detach();
    _roomListener = room.createListener();
    _roomListener?.on<ParticipantConnectionQualityUpdatedEvent>((event) {
      if (event.participant == room.localParticipant) {
        final level = _mapQuality(event.connectionQuality);
        if (_currentLevel != level) {
          _currentLevel = level;
          debugPrint('NetworkQualityObserver: Local quality updated to $level');
          _qualityController.add(_currentLevel);
        }
      }
    });
  }

  NetworkQualityLevel _mapQuality(ConnectionQuality quality) {
    switch (quality) {
      case ConnectionQuality.excellent:
        return NetworkQualityLevel.excellent;
      case ConnectionQuality.good:
        return NetworkQualityLevel.good;
      case ConnectionQuality.poor:
        return NetworkQualityLevel.poor;
      case ConnectionQuality.lost:
      case ConnectionQuality.unknown:
        return NetworkQualityLevel.poor;
    }
  }

  void updateQuality(NetworkQualityLevel level) {
    if (_currentLevel != level) {
      _currentLevel = level;
      _qualityController.add(_currentLevel);
    }
  }

  void detach() {
    _roomListener?.dispose();
    _roomListener = null;
  }

  void dispose() {
    detach();
    _qualityController.close();
  }
}
