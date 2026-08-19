import 'package:equatable/equatable.dart';

enum CallSessionStatus {
  idle,
  outgoingCalling,
  outgoingRinging,
  incomingRinging,
  connecting,
  connected,
  reconnecting,
  ended,
  rejected,
  busy,
  failed,
}

enum NetworkQualityLevel {
  unknown,
  excellent,
  good,
  poor,
  reconnecting,
}

enum CallAudioRoute {
  earpiece,
  speaker,
  bluetooth,
  headset,
}

class CallSessionState extends Equatable {
  final CallSessionStatus status;
  final NetworkQualityLevel networkQuality;
  final CallAudioRoute audioRoute;
  final bool isMuted;
  final bool isCameraOff;
  final String? errorMessage;

  const CallSessionState({
    required this.status,
    this.networkQuality = NetworkQualityLevel.unknown,
    this.audioRoute = CallAudioRoute.speaker,
    this.isMuted = false,
    this.isCameraOff = false,
    this.errorMessage,
  });

  bool get isIdle => status == CallSessionStatus.idle;
  bool get isOutgoing => status == CallSessionStatus.outgoingCalling || status == CallSessionStatus.outgoingRinging;
  bool get isRinging => status == CallSessionStatus.outgoingRinging || status == CallSessionStatus.incomingRinging;
  bool get isIncomingRinging => status == CallSessionStatus.incomingRinging;
  bool get isConnecting => status == CallSessionStatus.connecting;
  bool get isConnected => status == CallSessionStatus.connected;
  bool get isReconnecting => status == CallSessionStatus.reconnecting;
  bool get isTerminated =>
      status == CallSessionStatus.ended ||
      status == CallSessionStatus.rejected ||
      status == CallSessionStatus.busy ||
      status == CallSessionStatus.failed;

  CallSessionState copyWith({
    CallSessionStatus? status,
    NetworkQualityLevel? networkQuality,
    CallAudioRoute? audioRoute,
    bool? isMuted,
    bool? isCameraOff,
    String? errorMessage,
  }) {
    return CallSessionState(
      status: status ?? this.status,
      networkQuality: networkQuality ?? this.networkQuality,
      audioRoute: audioRoute ?? this.audioRoute,
      isMuted: isMuted ?? this.isMuted,
      isCameraOff: isCameraOff ?? this.isCameraOff,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        networkQuality,
        audioRoute,
        isMuted,
        isCameraOff,
        errorMessage,
      ];
}
