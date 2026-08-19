import 'package:bimobondapp/app/calls/domain/entities/call_entity.dart';
import 'package:bimobondapp/app/calls/services/livekit_call_service.dart';
import 'package:equatable/equatable.dart';

abstract class CallState extends Equatable {
  const CallState();

  @override
  List<Object?> get props => [];
}

class CallInitialState extends CallState {
  const CallInitialState();
}

class CallIncomingState extends CallState {
  final CallEntity call;

  const CallIncomingState({required this.call});

  @override
  List<Object?> get props => [call];
}

class CallOutgoingRingingState extends CallState {
  final CallEntity call;
  final CallSessionEntity? session;

  const CallOutgoingRingingState({
    required this.call,
    this.session,
  });

  @override
  List<Object?> get props => [call, session];
}

class CallConnectingState extends CallState {
  final CallEntity call;

  const CallConnectingState({required this.call});

  @override
  List<Object?> get props => [call];
}

class CallActiveState extends CallState {
  final CallEntity call;
  final CallSessionEntity? session;
  final LiveKitCallService livekitService;
  final bool isMuted;
  final bool isCameraOff;
  final bool isSpeakerPhoneOn;
  final String? errorMessage;

  const CallActiveState({
    required this.call,
    this.session,
    required this.livekitService,
    this.isMuted = false,
    this.isCameraOff = false,
    this.isSpeakerPhoneOn = true,
    this.errorMessage,
  });

  CallActiveState copyWith({
    CallEntity? call,
    CallSessionEntity? session,
    LiveKitCallService? livekitService,
    bool? isMuted,
    bool? isCameraOff,
    bool? isSpeakerPhoneOn,
    String? errorMessage,
  }) {
    return CallActiveState(
      call: call ?? this.call,
      session: session ?? this.session,
      livekitService: livekitService ?? this.livekitService,
      isMuted: isMuted ?? this.isMuted,
      isCameraOff: isCameraOff ?? this.isCameraOff,
      isSpeakerPhoneOn: isSpeakerPhoneOn ?? this.isSpeakerPhoneOn,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        call,
        session,
        livekitService,
        isMuted,
        isCameraOff,
        isSpeakerPhoneOn,
        errorMessage,
      ];
}

class CallEndedState extends CallState {
  final String? reason;
  final CallEntity? call;

  const CallEndedState({this.reason, this.call});

  @override
  List<Object?> get props => [reason, call];
}

class CallErrorState extends CallState {
  final String message;

  const CallErrorState({required this.message});

  @override
  List<Object?> get props => [message];
}

class CallReconnectingState extends CallState {
  final CallEntity call;
  final String message;

  const CallReconnectingState({
    required this.call,
    this.message = 'Reconnecting...',
  });

  @override
  List<Object?> get props => [call, message];
}

class CallTimedOutState extends CallState {
  final CallEntity? call;
  final String reason;

  const CallTimedOutState({
    this.call,
    this.reason = 'No answer',
  });

  @override
  List<Object?> get props => [call, reason];
}
