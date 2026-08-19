import 'dart:async';

import 'package:bimobondapp/app/calls/data/datasources/call_socket_service.dart';
import 'package:bimobondapp/app/calls/domain/entities/call_entity.dart';
import 'package:bimobondapp/app/calls/domain/repositories/calls_repository.dart';
import 'package:bimobondapp/app/calls/domain/session/call_session.dart';
import 'package:bimobondapp/app/calls/domain/session/call_session_event.dart';
import 'package:bimobondapp/app/calls/domain/session/call_session_manager.dart';
import 'package:bimobondapp/app/calls/domain/session/call_session_state.dart';
import 'package:bimobondapp/app/calls/services/audio_route_manager.dart';
import 'package:bimobondapp/app/calls/services/call_ringtone_service.dart';
import 'package:bimobondapp/app/calls/services/callkit_service.dart';
import 'package:bimobondapp/app/calls/services/keyguard_service.dart';
import 'package:bimobondapp/app/calls/services/device_lifecycle_manager.dart';
import 'package:bimobondapp/app/calls/services/livekit_call_service.dart';
import 'package:bimobondapp/app/calls/services/network_quality_observer.dart';
import 'package:flutter/widgets.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

class CallController {
  final CallSessionManager sessionManager;
  final CallSocketService socketService;
  final CallkitService callkitService;
  final LiveKitCallService livekitService;
  final AudioRouteManager audioRouteManager;
  final DeviceLifecycleManager lifecycleManager;
  final NetworkQualityObserver qualityObserver;
  final CallRingtoneService ringtoneService;
  final CallsRepository callsRepository;

  StreamSubscription? _socketIncomingSub;
  StreamSubscription? _socketAcceptedSub;
  StreamSubscription? _socketRejectedSub;
  StreamSubscription? _socketCancelledSub;
  StreamSubscription? _socketEndedSub;
  StreamSubscription? _livekitStateSub;
  StreamSubscription? _qualitySub;
  StreamSubscription? _sessionStateSub;

  Timer? _outgoingTimeoutTimer;
  bool _isInitialized = false;

  CallController({
    required this.sessionManager,
    required this.socketService,
    required this.callkitService,
    required this.livekitService,
    required this.audioRouteManager,
    required this.lifecycleManager,
    required this.qualityObserver,
    required this.ringtoneService,
    required this.callsRepository,
  });

  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    _initCallkitHandlers();
    _initSocketListeners();
    _initSubServices();
  }

  void _initCallkitHandlers() {
    callkitService.initialize(
      onAccept: (extra) async {
        final callId = extra['callId']?.toString() ?? extra['id']?.toString();
        debugPrint('CallController: CallKit Accepted for callId=$callId');
        if (callId != null && callId.isNotEmpty) {
          await acceptCall(callId);
        }
      },
      onDecline: (extra) async {
        final callId = extra['callId']?.toString() ?? extra['id']?.toString();
        debugPrint('CallController: CallKit Declined for callId=$callId');
        if (callId != null && callId.isNotEmpty) {
          await rejectCall(callId);
        }
      },
    );
  }

  void _initSocketListeners() {
    _socketIncomingSub = socketService.onCallIncoming.listen((payload) {
      _handleIncomingSocketCall(payload.call);
    });

    _socketAcceptedSub = socketService.onCallAccepted.listen((call) {
      _handleCallAcceptedSocket(call);
    });

    _socketRejectedSub = socketService.onCallRejected.listen((payload) {
      _handleCallRejectedSocket(payload.call);
    });

    _socketCancelledSub = socketService.onCallCancelled.listen((call) {
      _handleCallCancelledSocket(call);
    });

    _socketEndedSub = socketService.onCallEnded.listen((call) {
      _handleCallEndedSocket(call);
    });

    _livekitStateSub = livekitService.onRoomStateChanged.listen((roomState) {
      final session = sessionManager.activeSession;
      if (session == null) return;

      if (roomState == lk.ConnectionState.connecting) {
        session.dispatch(const MediaConnectingCallSessionEvent());
      } else if (roomState == lk.ConnectionState.connected) {
        session.dispatch(const MediaConnectedCallSessionEvent());
      } else if (roomState == lk.ConnectionState.reconnecting) {
        session.dispatch(const MediaReconnectingCallSessionEvent());
      } else if (roomState == lk.ConnectionState.disconnected) {
        session.dispatch(const MediaDisconnectedCallSessionEvent());
      }
    });
  }

  void _initSubServices() {
    qualityObserver.onQualityChanged.listen((quality) {
      sessionManager.activeSession
          ?.dispatch(UpdateNetworkQualitySessionEvent(quality));
    });

    audioRouteManager.onRouteChanged.listen((route) {
      sessionManager.activeSession
          ?.dispatch(UpdateAudioRouteSessionEvent(route));
    });

    lifecycleManager.startObserving(
      onPaused: () async {
        final session = sessionManager.activeSession;
        if (session != null && session.state.isConnected) {
          debugPrint(
              'CallController: App paused while connected. Pausing local camera hardware.');
          await livekitService.room?.localParticipant?.setCameraEnabled(false);
        }
      },
      onResumed: () async {
        final session = sessionManager.activeSession;
        if (session != null &&
            session.state.isConnected &&
            !session.state.isCameraOff) {
          debugPrint(
              'CallController: App resumed while connected. Restoring local camera track.');
          await livekitService.room?.localParticipant?.setCameraEnabled(true);
        }
      },
    );
  }

  // --- Signaling Commands ---

  Future<CallSession?> startCall({
    required String chatId,
    required String type, // 'AUDIO' or 'VIDEO'
    List<String>? inviteeIds,
  }) async {
    ringtoneService.playOutgoingRingtone();

    final result = await callsRepository.startCall(
      chatId: chatId,
      type: type,
      inviteeIds: inviteeIds,
    );

    return result.fold(
      (failure) {
        ringtoneService.stop();
        return null;
      },
      (sessionEntity) {
        final session = sessionManager.createSession(
          callId: sessionEntity.call.id,
          call: sessionEntity.call,
          livekitUrl: sessionEntity.livekitUrl,
          token: sessionEntity.token,
          isOutgoing: true,
          initialStatus: CallSessionStatus.outgoingCalling,
        );

        _bindSessionListeners(session);
        _startOutgoingTimeout(session.callId);
        socketService.joinCall(session.callId);

        return session;
      },
    );
  }

  Future<void> _handleIncomingSocketCall(CallEntity incomingCall) async {
    if (sessionManager.hasActiveCall) {
      debugPrint(
          'CallController: Active call exists. Replying busy for incoming ${incomingCall.id}');
      return;
    }

    var call = incomingCall;
    var callerName = call.initiatedBy.displayName;
    if (callerName == 'User' ||
        callerName == 'Incoming Call' ||
        callerName == 'مكالمة واردة' ||
        callerName.trim().isEmpty) {
      debugPrint(
          'CallController: Caller name is unresolved ($callerName). Fetching call details from backend before showing card...');
      final callResult = await callsRepository.getCallById(callId: call.id);
      if (callResult.isRight()) {
        final fullCall = callResult.getOrElse(() => call);
        if (fullCall.initiatedBy.displayName != 'User' &&
            fullCall.initiatedBy.displayName != 'Incoming Call' &&
            fullCall.initiatedBy.displayName != 'مكالمة واردة' &&
            fullCall.initiatedBy.displayName.trim().isNotEmpty) {
          call = fullCall;
          callerName = fullCall.initiatedBy.displayName;
        }
      }
    }

    if (callerName == 'User' ||
        callerName == 'Incoming Call' ||
        callerName == 'مكالمة واردة' ||
        callerName.trim().isEmpty) {
      debugPrint(
          'CallController: SUPPRESSING in-app call card because caller name could not be resolved for callId=${call.id}');
      return;
    }

    final session = sessionManager.createSession(
      callId: call.id,
      call: call,
      isOutgoing: false,
      initialStatus: CallSessionStatus.incomingRinging,
    );

    _bindSessionListeners(session);
    ringtoneService.playIncomingRingtone();

    // Show native top notification banner ONLY when app is in background/locked.
    // When app is in foreground, in-app Flutter IncomingCallScreen handles UI exclusively.
    final isAppForeground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (!isAppForeground) {
      callkitService.showIncomingCall(call.toCallkitData());
    }

    socketService.joinCall(call.id);
  }

  Future<void> acceptCall(String callId) async {
    await KeyguardService.instance.setShowWhenLocked(true);
    ringtoneService.stop();
    await callkitService.endCall(callId);
    await callkitService.endAllCalls();

    var session = sessionManager.activeSession;
    if (session == null || session.callId != callId) {
      debugPrint('CallController: Fetching session details to accept $callId');
      final callResult = await callsRepository.getCallById(callId: callId);
      if (callResult.isRight()) {
        final call = callResult.getOrElse(() => throw Exception());
        session = sessionManager.createSession(
          callId: call.id,
          call: call,
          isOutgoing: false,
          initialStatus: CallSessionStatus.incomingRinging,
        );
        _bindSessionListeners(session);
      }
    }

    if (session == null) return;

    session.dispatch(const AcceptCallSessionEvent());

    final acceptResult = await callsRepository.acceptCall(callId: callId);
    acceptResult.fold(
      (failure) {
        session?.dispatch(MediaFailedCallSessionEvent(failure.message));
      },
      (sessionEntity) async {
        _connectWebRTC(
          url: sessionEntity.livekitUrl,
          token: sessionEntity.token,
          isVideo: sessionEntity.call.isVideo,
        );
      },
    );
  }

  Future<void> rejectCall(String callId) async {
    ringtoneService.stop();
    await callkitService.endCall(callId);
    await callkitService.endAllCalls();

    final session = sessionManager.activeSession;
    if (session != null && session.callId == callId) {
      session.dispatch(const RejectCallSessionEvent());
    }

    await callsRepository.rejectCall(callId: callId);
    socketService.leaveCall(callId);
    sessionManager.clearSession(callId);
  }

  Future<void> endCall(String callId) async {
    _outgoingTimeoutTimer?.cancel();
    ringtoneService.stop();
    await callkitService.endCall(callId);
    await callkitService.endAllCalls();

    final session = sessionManager.activeSession;
    if (session != null && session.callId == callId) {
      session.dispatch(const EndCallSessionEvent());
    }

    await callsRepository.endCall(callId: callId);
    await disconnectWebRTC();
    socketService.leaveCall(callId);
    sessionManager.clearSession(callId);
  }

  void _handleCallAcceptedSocket(CallEntity call) {
    _outgoingTimeoutTimer?.cancel();
    ringtoneService.stop();
    callkitService.endAllCalls();

    final session = sessionManager.activeSession;
    if (session != null && session.callId == call.id) {
      session.dispatch(const AcceptCallSessionEvent());
      if (session.livekitUrl != null && session.token != null) {
        _connectWebRTC(
          url: session.livekitUrl!,
          token: session.token!,
          isVideo: session.call.isVideo,
        );
      }
    }
  }

  void _handleCallRejectedSocket(CallEntity call) {
    _outgoingTimeoutTimer?.cancel();
    ringtoneService.stop();
    callkitService.endAllCalls();

    final session = sessionManager.activeSession;
    if (session != null && session.callId == call.id) {
      session.dispatch(const RejectCallSessionEvent());
      Future.delayed(const Duration(seconds: 2), () {
        sessionManager.clearSession(call.id);
      });
    }
  }

  void _handleCallCancelledSocket(CallEntity call) {
    ringtoneService.stop();
    callkitService.endAllCalls();

    final session = sessionManager.activeSession;
    if (session != null && session.callId == call.id) {
      session.dispatch(const CancelCallSessionEvent());
      sessionManager.clearSession(call.id);
    }
  }

  void _handleCallEndedSocket(CallEntity call) {
    ringtoneService.stop();
    callkitService.endAllCalls();

    final session = sessionManager.activeSession;
    if (session != null && session.callId == call.id) {
      session.dispatch(const EndCallSessionEvent());
      disconnectWebRTC();
      sessionManager.clearSession(call.id);
    }
  }

  void _bindSessionListeners(CallSession session) {
    _sessionStateSub?.cancel();
    _sessionStateSub = session.onStateChanged.listen((state) {
      if (state.isTerminated) {
        _outgoingTimeoutTimer?.cancel();
        ringtoneService.stop();
      }
    });
  }

  Future<void> _connectWebRTC({
    required String url,
    required String token,
    required bool isVideo,
  }) async {
    await audioRouteManager.initializeAudioSession();
    try {
      await livekitService.connect(url: url, token: token, isVideo: isVideo);
      if (livekitService.room != null) {
        qualityObserver.attachToRoom(livekitService.room!);
      }
    } catch (e) {
      debugPrint('CallController: WebRTC connect error: $e');
      sessionManager.activeSession
          ?.dispatch(MediaFailedCallSessionEvent(e.toString()));
    }
  }

  Future<void> disconnectWebRTC() async {
    qualityObserver.detach();
    await livekitService.disconnect();
    await audioRouteManager.releaseAudioSession();
  }

  void _startOutgoingTimeout(String callId) {
    _outgoingTimeoutTimer?.cancel();
    _outgoingTimeoutTimer = Timer(const Duration(seconds: 35), () {
      final session = sessionManager.activeSession;
      if (session != null &&
          session.callId == callId &&
          session.state.isOutgoing) {
        debugPrint('CallController: Outgoing call timeout reached for $callId');
        endCall(callId);
      }
    });
  }

  void dispose() {
    _outgoingTimeoutTimer?.cancel();
    _socketIncomingSub?.cancel();
    _socketAcceptedSub?.cancel();
    _socketRejectedSub?.cancel();
    _socketCancelledSub?.cancel();
    _socketEndedSub?.cancel();
    _livekitStateSub?.cancel();
    _sessionStateSub?.cancel();
    _qualitySub?.cancel();
    lifecycleManager.stopObserving();
    qualityObserver.dispose();
  }
}
