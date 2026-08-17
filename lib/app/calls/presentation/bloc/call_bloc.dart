import 'dart:async';

import 'package:bimobondapp/app/calls/data/datasources/call_socket_service.dart';
import 'package:bimobondapp/app/calls/domain/entities/call_entity.dart';
import 'package:bimobondapp/app/calls/domain/usecases/accept_call_usecase.dart';
import 'package:bimobondapp/app/calls/domain/usecases/end_call_usecase.dart';
import 'package:bimobondapp/app/calls/domain/usecases/get_active_call_usecase.dart';
import 'package:bimobondapp/app/calls/domain/usecases/get_call_by_id_usecase.dart';
import 'package:bimobondapp/app/calls/domain/usecases/invite_to_call_usecase.dart';
import 'package:bimobondapp/app/calls/domain/usecases/leave_call_usecase.dart';
import 'package:bimobondapp/app/calls/domain/usecases/reject_call_usecase.dart';
import 'package:bimobondapp/app/calls/domain/usecases/start_call_usecase.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_event.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_state.dart';
import 'package:bimobondapp/app/calls/services/livekit_call_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:bimobondapp/app/calls/services/call_ringtone_service.dart';

class CallBloc extends Bloc<CallEvent, CallState> {
  final StartCallUseCase startCallUseCase;
  final GetActiveCallUseCase getActiveCallUseCase;
  final GetCallByIdUseCase getCallByIdUseCase;
  final AcceptCallUseCase acceptCallUseCase;
  final RejectCallUseCase rejectCallUseCase;
  final EndCallUseCase endCallUseCase;
  final LeaveCallUseCase leaveCallUseCase;
  final InviteToCallUseCase inviteToCallUseCase;
  final CallSocketService socketService;
  final LiveKitCallService livekitService;
  final CallRingtoneService ringtoneService;

  StreamSubscription? _incomingSub;
  StreamSubscription? _acceptedSub;
  StreamSubscription? _rejectedSub;
  StreamSubscription? _cancelledSub;
  StreamSubscription? _participantUpdateSub;
  StreamSubscription? _endedSub;

  CallBloc({
    required this.startCallUseCase,
    required this.getActiveCallUseCase,
    required this.getCallByIdUseCase,
    required this.acceptCallUseCase,
    required this.rejectCallUseCase,
    required this.endCallUseCase,
    required this.leaveCallUseCase,
    required this.inviteToCallUseCase,
    required this.socketService,
    required this.livekitService,
    required this.ringtoneService,
  }) : super(const CallInitialState()) {
    _initSocketListeners();

    on<StartCallEvent>(_onStartCall);
    on<AcceptCallEvent>(_onAcceptCall);
    on<RejectCallEvent>(_onRejectCall);
    on<EndCallEvent>(_onEndCall);
    on<LeaveCallEvent>(_onLeaveCall);
    on<InviteToCallEvent>(_onInviteToCall);
    on<CheckActiveCallEvent>(_onCheckActiveCall);
    on<IncomingCallReceivedEvent>(_onIncomingCallReceived);
    on<CallAcceptedReceivedEvent>(_onCallAcceptedReceived);
    on<CallRejectedReceivedEvent>(_onCallRejectedReceived);
    on<CallCancelledReceivedEvent>(_onCallCancelledReceived);
    on<CallParticipantUpdatedEvent>(_onCallParticipantUpdated);
    on<CallEndedReceivedEvent>(_onCallEndedReceived);
    on<ToggleMuteEvent>(_onToggleMute);
    on<ToggleCameraEvent>(_onToggleCamera);
    on<SwitchCameraEvent>(_onSwitchCamera);
    on<ToggleSpeakerEvent>(_onToggleSpeaker);
    on<ClearCallStateEvent>(_onClearCallState);
  }

  void _initSocketListeners() {
    _incomingSub = socketService.onCallIncoming.listen((payload) {
      add(IncomingCallReceivedEvent(call: payload.call));
    });

    _acceptedSub = socketService.onCallAccepted.listen((call) {
      add(CallAcceptedReceivedEvent(call: call));
    });

    _rejectedSub = socketService.onCallRejected.listen((payload) {
      add(
        CallRejectedReceivedEvent(
          call: payload.call,
          rejectedByUserId: payload.rejectedByUserId,
        ),
      );
    });

    _cancelledSub = socketService.onCallCancelled.listen((call) {
      add(CallCancelledReceivedEvent(call: call));
    });

    _participantUpdateSub =
        socketService.onCallParticipantUpdate.listen((payload) {
      add(
        CallParticipantUpdatedEvent(
          callId: payload.callId,
          participant: payload.participant,
        ),
      );
    });

    _endedSub = socketService.onCallEnded.listen((call) {
      add(CallEndedReceivedEvent(call: call));
    });
  }

  Future<void> _onStartCall(
    StartCallEvent event,
    Emitter<CallState> emit,
  ) async {
    emit(const CallInitialState());
    final result = await startCallUseCase(
      chatId: event.chatId,
      type: event.type,
      inviteeIds: event.inviteeIds,
    );

    await result.fold(
      (failure) async {
        emit(CallErrorState(message: failure.message));
      },
      (session) async {
        emit(CallOutgoingRingingState(call: session.call, session: session));
        unawaited(ringtoneService.playOutgoingRingtone());
        // Caller immediately joins LiveKit
        try {
          await livekitService.connect(
            url: session.livekitUrl,
            token: session.token,
            isVideo: session.call.isVideo,
          );
        } catch (e) {
          debugPrint('Failed to connect to LiveKit: $e');
        }
      },
    );
  }

  Future<void> _onAcceptCall(
    AcceptCallEvent event,
    Emitter<CallState> emit,
  ) async {
    unawaited(ringtoneService.stop());
    final result = await acceptCallUseCase(callId: event.callId);

    await result.fold(
      (failure) async {
        emit(CallErrorState(message: failure.message));
      },
      (session) async {
        emit(
          CallActiveState(
            call: session.call,
            session: session,
            livekitService: livekitService,
            isMuted: livekitService.isMuted,
            isCameraOff: livekitService.isCameraOff,
            isSpeakerPhoneOn: livekitService.isSpeakerPhoneOn,
          ),
        );

        // Callee joins LiveKit upon accept
        try {
          await livekitService.connect(
            url: session.livekitUrl,
            token: session.token,
            isVideo: session.call.isVideo,
          );
        } catch (e) {
          debugPrint('Failed to connect LiveKit on accept: $e');
        }
      },
    );
  }

  Future<void> _onRejectCall(
    RejectCallEvent event,
    Emitter<CallState> emit,
  ) async {
    unawaited(ringtoneService.stop());
    final result = await rejectCallUseCase(callId: event.callId);

    result.fold(
      (failure) {
        emit(CallErrorState(message: failure.message));
      },
      (call) {
        emit(CallEndedState(reason: 'Rejected', call: call));
      },
    );
  }

  Future<void> _onEndCall(
    EndCallEvent event,
    Emitter<CallState> emit,
  ) async {
    unawaited(ringtoneService.stop());
    await livekitService.disconnect();
    final result = await endCallUseCase(callId: event.callId);

    result.fold(
      (failure) {
        emit(CallEndedState(reason: failure.message));
      },
      (call) {
        emit(CallEndedState(reason: 'Call ended', call: call));
      },
    );
  }

  Future<void> _onLeaveCall(
    LeaveCallEvent event,
    Emitter<CallState> emit,
  ) async {
    unawaited(ringtoneService.stop());
    await livekitService.disconnect();
    final result = await leaveCallUseCase(callId: event.callId);

    result.fold(
      (failure) {
        emit(CallEndedState(reason: failure.message));
      },
      (call) {
        emit(CallEndedState(reason: 'Left call', call: call));
      },
    );
  }

  Future<void> _onInviteToCall(
    InviteToCallEvent event,
    Emitter<CallState> emit,
  ) async {
    final result = await inviteToCallUseCase(
      callId: event.callId,
      inviteeIds: event.inviteeIds,
    );

    result.fold(
      (failure) {
        if (state is CallActiveState) {
          emit((state as CallActiveState).copyWith(errorMessage: failure.message));
        }
      },
      (updatedCall) {
        if (state is CallActiveState) {
          emit((state as CallActiveState).copyWith(call: updatedCall));
        }
      },
    );
  }

  Future<void> _onCheckActiveCall(
    CheckActiveCallEvent event,
    Emitter<CallState> emit,
  ) async {
    final result = await getActiveCallUseCase(chatId: event.chatId);
    result.fold(
      (failure) {},
      (call) {
        if (call != null && state is CallInitialState) {
          emit(
            CallActiveState(
              call: call,
              livekitService: livekitService,
            ),
          );
        }
      },
    );
  }

  void _onIncomingCallReceived(
    IncomingCallReceivedEvent event,
    Emitter<CallState> emit,
  ) {
    if (state is! CallActiveState && state is! CallOutgoingRingingState) {
      emit(CallIncomingState(call: event.call));
      unawaited(ringtoneService.playIncomingRingtone());
    }
  }

  void _onCallAcceptedReceived(
    CallAcceptedReceivedEvent event,
    Emitter<CallState> emit,
  ) {
    unawaited(ringtoneService.stop());
    if (state is CallOutgoingRingingState) {
      final s = (state as CallOutgoingRingingState).session;
      emit(
        CallActiveState(
          call: event.call,
          session: s,
          livekitService: livekitService,
          isMuted: livekitService.isMuted,
          isCameraOff: livekitService.isCameraOff,
          isSpeakerPhoneOn: livekitService.isSpeakerPhoneOn,
        ),
      );
    } else if (state is CallActiveState) {
      final cur = state as CallActiveState;
      emit(cur.copyWith(call: event.call));
    }
  }

  void _onCallRejectedReceived(
    CallRejectedReceivedEvent event,
    Emitter<CallState> emit,
  ) {
    unawaited(ringtoneService.stop());
    if (event.call.isEnded || event.call.status == 'REJECTED') {
      livekitService.disconnect();
      emit(CallEndedState(reason: 'Call rejected', call: event.call));
    } else if (state is CallActiveState) {
      emit((state as CallActiveState).copyWith(call: event.call));
    }
  }

  void _onCallCancelledReceived(
    CallCancelledReceivedEvent event,
    Emitter<CallState> emit,
  ) {
    unawaited(ringtoneService.stop());
    livekitService.disconnect();
    emit(CallEndedState(reason: 'Call cancelled', call: event.call));
  }

  void _onCallParticipantUpdated(
    CallParticipantUpdatedEvent event,
    Emitter<CallState> emit,
  ) {
    if (state is CallActiveState) {
      final cur = state as CallActiveState;
      final existingParticipants = List<CallParticipantEntity>.from(cur.call.participants);
      final idx = existingParticipants.indexWhere((p) => p.id == event.participant.id || p.userId == event.participant.userId);
      if (idx >= 0) {
        existingParticipants[idx] = event.participant;
      } else {
        existingParticipants.add(event.participant);
      }
      final updatedCall = cur.call.copyWith(participants: existingParticipants);
      emit(cur.copyWith(call: updatedCall));
    }
  }

  void _onCallEndedReceived(
    CallEndedReceivedEvent event,
    Emitter<CallState> emit,
  ) {
    unawaited(ringtoneService.stop());
    livekitService.disconnect();
    emit(CallEndedState(reason: 'Call ended', call: event.call));
  }

  Future<void> _onToggleMute(
    ToggleMuteEvent event,
    Emitter<CallState> emit,
  ) async {
    await livekitService.toggleMute();
    if (state is CallActiveState) {
      final cur = state as CallActiveState;
      emit(cur.copyWith(isMuted: livekitService.isMuted));
    }
  }

  Future<void> _onToggleCamera(
    ToggleCameraEvent event,
    Emitter<CallState> emit,
  ) async {
    await livekitService.toggleCamera();
    if (state is CallActiveState) {
      final cur = state as CallActiveState;
      emit(cur.copyWith(isCameraOff: livekitService.isCameraOff));
    }
  }

  Future<void> _onSwitchCamera(
    SwitchCameraEvent event,
    Emitter<CallState> emit,
  ) async {
    await livekitService.switchCamera();
  }

  Future<void> _onToggleSpeaker(
    ToggleSpeakerEvent event,
    Emitter<CallState> emit,
  ) async {
    await livekitService.toggleSpeaker();
    if (state is CallActiveState) {
      final cur = state as CallActiveState;
      emit(cur.copyWith(isSpeakerPhoneOn: livekitService.isSpeakerPhoneOn));
    }
  }

  void _onClearCallState(
    ClearCallStateEvent event,
    Emitter<CallState> emit,
  ) {
    unawaited(ringtoneService.stop());
    emit(const CallInitialState());
  }

  @override
  Future<void> close() {
    _incomingSub?.cancel();
    _acceptedSub?.cancel();
    _rejectedSub?.cancel();
    _cancelledSub?.cancel();
    _participantUpdateSub?.cancel();
    _endedSub?.cancel();
    ringtoneService.stop();
    livekitService.disconnect();
    return super.close();
  }
}
