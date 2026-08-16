import 'package:bimobondapp/app/calls/domain/entities/call_entity.dart';
import 'package:equatable/equatable.dart';

abstract class CallEvent extends Equatable {
  const CallEvent();

  @override
  List<Object?> get props => [];
}

class StartCallEvent extends CallEvent {
  final String chatId;
  final String type; // AUDIO, VIDEO
  final List<String>? inviteeIds;

  const StartCallEvent({
    required this.chatId,
    required this.type,
    this.inviteeIds,
  });

  @override
  List<Object?> get props => [chatId, type, inviteeIds];
}

class AcceptCallEvent extends CallEvent {
  final String callId;

  const AcceptCallEvent({required this.callId});

  @override
  List<Object?> get props => [callId];
}

class RejectCallEvent extends CallEvent {
  final String callId;

  const RejectCallEvent({required this.callId});

  @override
  List<Object?> get props => [callId];
}

class EndCallEvent extends CallEvent {
  final String callId;

  const EndCallEvent({required this.callId});

  @override
  List<Object?> get props => [callId];
}

class LeaveCallEvent extends CallEvent {
  final String callId;

  const LeaveCallEvent({required this.callId});

  @override
  List<Object?> get props => [callId];
}

class InviteToCallEvent extends CallEvent {
  final String callId;
  final List<String> inviteeIds;

  const InviteToCallEvent({
    required this.callId,
    required this.inviteeIds,
  });

  @override
  List<Object?> get props => [callId, inviteeIds];
}

class CheckActiveCallEvent extends CallEvent {
  final String chatId;

  const CheckActiveCallEvent({required this.chatId});

  @override
  List<Object?> get props => [chatId];
}

class IncomingCallReceivedEvent extends CallEvent {
  final CallEntity call;

  const IncomingCallReceivedEvent({required this.call});

  @override
  List<Object?> get props => [call];
}

class CallAcceptedReceivedEvent extends CallEvent {
  final CallEntity call;

  const CallAcceptedReceivedEvent({required this.call});

  @override
  List<Object?> get props => [call];
}

class CallRejectedReceivedEvent extends CallEvent {
  final CallEntity call;
  final String? rejectedByUserId;

  const CallRejectedReceivedEvent({
    required this.call,
    this.rejectedByUserId,
  });

  @override
  List<Object?> get props => [call, rejectedByUserId];
}

class CallCancelledReceivedEvent extends CallEvent {
  final CallEntity call;

  const CallCancelledReceivedEvent({required this.call});

  @override
  List<Object?> get props => [call];
}

class CallParticipantUpdatedEvent extends CallEvent {
  final String callId;
  final CallParticipantEntity participant;

  const CallParticipantUpdatedEvent({
    required this.callId,
    required this.participant,
  });

  @override
  List<Object?> get props => [callId, participant];
}

class CallEndedReceivedEvent extends CallEvent {
  final CallEntity call;

  const CallEndedReceivedEvent({required this.call});

  @override
  List<Object?> get props => [call];
}

class ToggleMuteEvent extends CallEvent {
  const ToggleMuteEvent();
}

class ToggleCameraEvent extends CallEvent {
  const ToggleCameraEvent();
}

class SwitchCameraEvent extends CallEvent {
  const SwitchCameraEvent();
}

class ToggleSpeakerEvent extends CallEvent {
  const ToggleSpeakerEvent();
}

class ClearCallStateEvent extends CallEvent {
  const ClearCallStateEvent();
}
