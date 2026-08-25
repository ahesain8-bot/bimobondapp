import 'dart:async';

import 'package:bimobondapp/app/calls/data/datasources/call_socket_service.dart';
import 'package:bimobondapp/app/calls/domain/entities/call_entity.dart';
import 'package:bimobondapp/app/calls/domain/session/call_controller.dart';
import 'package:bimobondapp/app/calls/domain/session/call_session.dart';
import 'package:bimobondapp/app/calls/domain/session/call_session_event.dart';
import 'package:bimobondapp/app/calls/domain/session/call_session_manager.dart';
import 'package:bimobondapp/app/calls/domain/session/call_session_state.dart';
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
import 'package:bimobondapp/app/calls/services/call_ringtone_service.dart';
import 'package:bimobondapp/app/calls/services/livekit_call_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  final CallController callController;
  final CallSessionManager sessionManager;

  StreamSubscription? _sessionManagerSub;
  StreamSubscription? _sessionStateSub;

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
    required this.callController,
    required this.sessionManager,
  }) : super(const CallInitialState()) {
    callController.initialize();
    _subscribeToSessionManager();

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
    on<LiveKitRoomStateChangedEvent>(_onLiveKitRoomStateChanged);
    on<SessionStateUpdatedEvent>(_onSessionStateUpdated);
  }

  void _subscribeToSessionManager() {
    _sessionManagerSub = sessionManager.onActiveSessionChanged.listen((session) {
      if (session == null) {
        if (state is! CallEndedState && state is! CallInitialState) {
          add(const ClearCallStateEvent());
        }
        return;
      }
      _listenToSession(session);
    });
  }

  void _listenToSession(CallSession session) {
    _sessionStateSub?.cancel();
    _sessionStateSub = session.onStateChanged.listen((fsmState) {
      add(SessionStateUpdatedEvent(session: session, fsmState: fsmState));
    });
    add(SessionStateUpdatedEvent(session: session, fsmState: session.state));
  }

  void _onSessionStateUpdated(
    SessionStateUpdatedEvent event,
    Emitter<CallState> emit,
  ) {
    final session = event.session as CallSession;
    final fsmState = event.fsmState as CallSessionState;

    switch (fsmState.status) {
      case CallSessionStatus.idle:
        emit(const CallInitialState());
        break;
      case CallSessionStatus.outgoingCalling:
      case CallSessionStatus.outgoingRinging:
        emit(CallOutgoingRingingState(call: session.call));
        break;
      case CallSessionStatus.incomingRinging:
        emit(CallIncomingState(call: session.call));
        break;
      case CallSessionStatus.connecting:
        emit(CallConnectingState(call: session.call));
        break;
      case CallSessionStatus.connected:
        emit(CallActiveState(
          call: session.call,
          livekitService: livekitService,
          isMuted: fsmState.isMuted,
          isCameraOff: fsmState.isCameraOff,
          isSpeakerPhoneOn: fsmState.audioRoute == CallAudioRoute.speaker,
        ));
        break;
      case CallSessionStatus.reconnecting:
        emit(CallReconnectingState(call: session.call));
        break;
      case CallSessionStatus.ended:
        emit(CallEndedState(reason: 'Call ended', call: session.call));
        break;
      case CallSessionStatus.rejected:
        emit(CallEndedState(reason: 'Rejected', call: session.call));
        break;
      case CallSessionStatus.busy:
        emit(CallEndedState(reason: 'Busy', call: session.call));
        break;
      case CallSessionStatus.failed:
        emit(CallErrorState(message: fsmState.errorMessage ?? 'Call failed'));
        break;
    }
  }

  Future<void> _onStartCall(
    StartCallEvent event,
    Emitter<CallState> emit,
  ) async {
    emit(const CallInitialState());
    final session = await callController.startCall(
      chatId: event.chatId,
      type: event.type,
      inviteeIds: event.inviteeIds,
    );
    if (session == null) {
      emit(const CallErrorState(message: 'Failed to start call'));
    }
  }

  Future<void> _onAcceptCall(
    AcceptCallEvent event,
    Emitter<CallState> emit,
  ) async {
    await callController.acceptCall(event.callId);
  }

  Future<void> _onRejectCall(
    RejectCallEvent event,
    Emitter<CallState> emit,
  ) async {
    await callController.rejectCall(event.callId);
  }

  Future<void> _onEndCall(EndCallEvent event, Emitter<CallState> emit) async {
    await callController.endCall(event.callId);
  }

  Future<void> _onLeaveCall(
    LeaveCallEvent event,
    Emitter<CallState> emit,
  ) async {
    await callController.endCall(event.callId);
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
    result.fold((failure) {}, (call) {
      if (call != null && state is CallInitialState) {
        emit(CallActiveState(call: call, livekitService: livekitService));
      }
    });
  }

  void _onIncomingCallReceived(
    IncomingCallReceivedEvent event,
    Emitter<CallState> emit,
  ) {}

  void _onCallAcceptedReceived(
    CallAcceptedReceivedEvent event,
    Emitter<CallState> emit,
  ) {}

  void _onCallRejectedReceived(
    CallRejectedReceivedEvent event,
    Emitter<CallState> emit,
  ) {}

  void _onCallCancelledReceived(
    CallCancelledReceivedEvent event,
    Emitter<CallState> emit,
  ) {}

  void _onCallParticipantUpdated(
    CallParticipantUpdatedEvent event,
    Emitter<CallState> emit,
  ) {
    if (state is CallActiveState) {
      final cur = state as CallActiveState;
      final existingParticipants = List<CallParticipantEntity>.from(
        cur.call.participants,
      );
      final idx = existingParticipants.indexWhere(
        (p) =>
            p.id == event.participant.id ||
            p.userId == event.participant.userId,
      );
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
  ) {}

  void _onLiveKitRoomStateChanged(
    LiveKitRoomStateChangedEvent event,
    Emitter<CallState> emit,
  ) {}

  Future<void> _onToggleMute(
    ToggleMuteEvent event,
    Emitter<CallState> emit,
  ) async {
    await livekitService.toggleMute();
    sessionManager.activeSession?.dispatch(
      ToggleMuteSessionEvent(isMuted: livekitService.isMuted),
    );
  }

  Future<void> _onToggleCamera(
    ToggleCameraEvent event,
    Emitter<CallState> emit,
  ) async {
    await livekitService.toggleCamera();
    sessionManager.activeSession?.dispatch(
      ToggleCameraSessionEvent(isCameraOff: livekitService.isCameraOff),
    );
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
    final nextSpeaker = !livekitService.isSpeakerPhoneOn;
    await callController.audioRouteManager.setSpeakerphone(nextSpeaker);
  }

  void _onClearCallState(ClearCallStateEvent event, Emitter<CallState> emit) {
    emit(const CallInitialState());
  }

  @override
  Future<void> close() {
    _sessionManagerSub?.cancel();
    _sessionStateSub?.cancel();
    return super.close();
  }
}
