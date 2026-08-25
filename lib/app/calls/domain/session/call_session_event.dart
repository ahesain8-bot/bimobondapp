import 'package:bimobondapp/app/calls/domain/session/call_session_state.dart';

abstract class CallSessionEvent {
  const CallSessionEvent();
}

class StartOutgoingCallSessionEvent extends CallSessionEvent {
  const StartOutgoingCallSessionEvent();
}

class ReceiveIncomingCallSessionEvent extends CallSessionEvent {
  const ReceiveIncomingCallSessionEvent();
}

class RemoteRingingCallSessionEvent extends CallSessionEvent {
  const RemoteRingingCallSessionEvent();
}

class AcceptCallSessionEvent extends CallSessionEvent {
  const AcceptCallSessionEvent();
}

class RejectCallSessionEvent extends CallSessionEvent {
  final String? reason;
  const RejectCallSessionEvent({this.reason});
}

class CancelCallSessionEvent extends CallSessionEvent {
  const CancelCallSessionEvent();
}

class MediaConnectingCallSessionEvent extends CallSessionEvent {
  const MediaConnectingCallSessionEvent();
}

class MediaConnectedCallSessionEvent extends CallSessionEvent {
  const MediaConnectedCallSessionEvent();
}

class MediaDisconnectedCallSessionEvent extends CallSessionEvent {
  const MediaDisconnectedCallSessionEvent();
}

class MediaReconnectingCallSessionEvent extends CallSessionEvent {
  const MediaReconnectingCallSessionEvent();
}

class MediaFailedCallSessionEvent extends CallSessionEvent {
  final String message;
  const MediaFailedCallSessionEvent(this.message);
}

class EndCallSessionEvent extends CallSessionEvent {
  const EndCallSessionEvent();
}

class TimeoutCallSessionEvent extends CallSessionEvent {
  const TimeoutCallSessionEvent();
}

class UpdateAudioRouteSessionEvent extends CallSessionEvent {
  final CallAudioRoute audioRoute;
  const UpdateAudioRouteSessionEvent(this.audioRoute);
}

class UpdateNetworkQualitySessionEvent extends CallSessionEvent {
  final NetworkQualityLevel quality;
  const UpdateNetworkQualitySessionEvent(this.quality);
}

class ToggleMuteSessionEvent extends CallSessionEvent {
  final bool? isMuted;
  const ToggleMuteSessionEvent({this.isMuted});
}

class ToggleCameraSessionEvent extends CallSessionEvent {
  final bool? isCameraOff;
  const ToggleCameraSessionEvent({this.isCameraOff});
}
