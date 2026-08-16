import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

class LiveKitCallService {
  Room? _room;
  EventsListener<RoomEvent>? _listener;

  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerPhoneOn = true;

  final _participantsController =
      StreamController<List<Participant>>.broadcast();
  final _roomStateController = StreamController<ConnectionState>.broadcast();

  Room? get room => _room;
  bool get isMuted => _isMuted;
  bool get isCameraOff => _isCameraOff;
  bool get isSpeakerPhoneOn => _isSpeakerPhoneOn;
  bool get isConnected => _room?.connectionState == ConnectionState.connected;

  Stream<List<Participant>> get onParticipantsChanged =>
      _participantsController.stream;
  Stream<ConnectionState> get onRoomStateChanged =>
      _roomStateController.stream;

  List<Participant> get allParticipants {
    if (_room == null) return [];
    final list = <Participant>[];
    if (_room!.localParticipant != null) {
      list.add(_room!.localParticipant!);
    }
    list.addAll(_room!.remoteParticipants.values);
    return list;
  }

  Future<void> _requestPermissions(bool isVideo) async {
    try {
      final micStatus = await Permission.microphone.request();
      debugPrint('LiveKitCallService: mic permission status = $micStatus');
      if (isVideo) {
        final camStatus = await Permission.camera.request();
        debugPrint('LiveKitCallService: camera permission status = $camStatus');
      }
    } catch (e) {
      debugPrint('LiveKitCallService permission request error: $e');
    }
  }

  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
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
      await session.setActive(true);
    } catch (e) {
      debugPrint('LiveKitCallService audio session error: $e');
    }
  }

  Future<void> connect({
    required String url,
    required String token,
    required bool isVideo,
  }) async {
    await disconnect();
    await _requestPermissions(isVideo);
    await _configureAudioSession();

    try {
      final roomOptions = const RoomOptions(
        defaultAudioPublishOptions: AudioPublishOptions(
          name: 'microphone',
        ),
        defaultVideoPublishOptions: VideoPublishOptions(
          name: 'camera',
          simulcast: true,
        ),
      );

      _room = Room(roomOptions: roomOptions);
      _listener = _room!.createListener();

      _setupListeners();

      await _room!.connect(url, token);
      debugPrint('LiveKitCallService: connected to room ${_room?.name}');

      // Configure media devices
      _isMuted = false;
      _isCameraOff = !isVideo;

      await _room!.localParticipant?.setMicrophoneEnabled(true);
      if (isVideo) {
        await _room!.localParticipant?.setCameraEnabled(true);
      } else {
        await _room!.localParticipant?.setCameraEnabled(false);
      }

      _updateState();
    } catch (e) {
      debugPrint('LiveKitCallService connection error: $e');
      rethrow;
    }
  }

  void _setupListeners() {
    if (_listener == null) return;

    _listener!
      ..on<RoomConnectedEvent>((_) {
        _roomStateController.add(ConnectionState.connected);
        _updateState();
      })
      ..on<RoomDisconnectedEvent>((_) {
        _roomStateController.add(ConnectionState.disconnected);
        _updateState();
      })
      ..on<RoomReconnectingEvent>((_) {
        _roomStateController.add(ConnectionState.reconnecting);
      })
      ..on<RoomReconnectedEvent>((_) {
        _roomStateController.add(ConnectionState.connected);
        _updateState();
      })
      ..on<ParticipantConnectedEvent>((_) => _updateState())
      ..on<ParticipantDisconnectedEvent>((_) => _updateState())
      ..on<TrackSubscribedEvent>((_) => _updateState())
      ..on<TrackUnsubscribedEvent>((_) => _updateState())
      ..on<TrackMutedEvent>((_) => _updateState())
      ..on<TrackUnmutedEvent>((_) => _updateState());
  }

  void _updateState() {
    _participantsController.add(allParticipants);
  }

  Future<void> toggleMute() async {
    if (_room == null || _room!.localParticipant == null) return;
    _isMuted = !_isMuted;
    await _room!.localParticipant?.setMicrophoneEnabled(!_isMuted);
    _updateState();
  }

  Future<void> toggleCamera() async {
    if (_room == null || _room!.localParticipant == null) return;
    _isCameraOff = !_isCameraOff;
    if (!_isCameraOff) {
      try {
        await Permission.camera.request();
      } catch (e) {
        debugPrint('LiveKitCallService camera request error: $e');
      }
      // Ensure microphone is active when video is enabled
      await _room!.localParticipant?.setMicrophoneEnabled(!_isMuted);
    }
    await _room!.localParticipant?.setCameraEnabled(!_isCameraOff);
    _updateState();
  }

  bool _isFrontCamera = true;

  Future<void> switchCamera() async {
    if (_room == null || _room!.localParticipant == null) return;
    final track =
        _room!.localParticipant?.videoTrackPublications.firstOrNull?.track;
    if (track is LocalVideoTrack) {
      _isFrontCamera = !_isFrontCamera;
      final newPosition =
          _isFrontCamera ? CameraPosition.front : CameraPosition.back;
      await track.setCameraPosition(newPosition);
    }
  }

  Future<void> toggleSpeaker() async {
    _isSpeakerPhoneOn = !_isSpeakerPhoneOn;
    _updateState();
  }

  Future<void> disconnect() async {
    try {
      _listener?.dispose();
      _listener = null;
      if (_room != null) {
        await _room!.disconnect();
        await _room!.dispose();
        _room = null;
      }
    } catch (e) {
      debugPrint('LiveKitCallService disconnect error: $e');
    }
  }

  void dispose() {
    disconnect();
    _participantsController.close();
    _roomStateController.close();
  }
}
