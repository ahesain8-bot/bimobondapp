import 'dart:async';

import 'package:bimobondapp/app/calls/domain/entities/call_entity.dart';
import 'package:bimobondapp/app/calls/domain/session/call_session_event.dart';
import 'package:bimobondapp/app/calls/domain/session/call_session_state.dart';
import 'package:flutter/foundation.dart';

class CallSession {
  final String callId;
  final CallEntity call;
  final String? livekitUrl;
  final String? token;
  final bool isOutgoing;
  final DateTime createdAt;

  CallSessionState _state;
  final _stateController = StreamController<CallSessionState>.broadcast();

  CallSession({
    required this.callId,
    required this.call,
    this.livekitUrl,
    this.token,
    required this.isOutgoing,
    CallSessionStatus initialStatus = CallSessionStatus.idle,
  })  : createdAt = DateTime.now(),
        _state = CallSessionState(
          status: initialStatus,
          isCameraOff: call.isAudio,
        );

  CallSessionState get state => _state;
  Stream<CallSessionState> get onStateChanged => _stateController.stream;

  /// Deterministically process an event using the FSM transition matrix.
  void dispatch(CallSessionEvent event) {
    if (_state.isTerminated &&
        event is! UpdateAudioRouteSessionEvent &&
        event is! UpdateNetworkQualitySessionEvent) {
      debugPrint(
          'CallSession [$callId]: Event ${event.runtimeType} ignored because state is already terminated (${_state.status}).');
      return;
    }

    final nextState = _reduceState(_state, event);
    if (nextState != _state) {
      debugPrint(
          'CallSession [$callId]: Transitioning from ${_state.status} -> ${nextState.status} via ${event.runtimeType}');
      _state = nextState;
      _stateController.add(_state);
    }
  }

  CallSessionState _reduceState(CallSessionState current, CallSessionEvent event) {
    // Handle global quality & route events regardless of main status
    if (event is UpdateAudioRouteSessionEvent) {
      return current.copyWith(audioRoute: event.audioRoute);
    }
    if (event is UpdateNetworkQualitySessionEvent) {
      return current.copyWith(networkQuality: event.quality);
    }
    if (event is ToggleMuteSessionEvent) {
      return current.copyWith(isMuted: event.isMuted ?? !current.isMuted);
    }
    if (event is ToggleCameraSessionEvent) {
      return current.copyWith(isCameraOff: event.isCameraOff ?? !current.isCameraOff);
    }

    switch (current.status) {
      case CallSessionStatus.idle:
        if (event is StartOutgoingCallSessionEvent) {
          return current.copyWith(status: CallSessionStatus.outgoingCalling);
        }
        if (event is ReceiveIncomingCallSessionEvent) {
          return current.copyWith(status: CallSessionStatus.incomingRinging);
        }
        break;

      case CallSessionStatus.outgoingCalling:
        if (event is RemoteRingingCallSessionEvent) {
          return current.copyWith(status: CallSessionStatus.outgoingRinging);
        }
        if (event is AcceptCallSessionEvent || event is MediaConnectingCallSessionEvent) {
          return current.copyWith(status: CallSessionStatus.connecting);
        }
        if (event is RejectCallSessionEvent) {
          return current.copyWith(status: CallSessionStatus.rejected);
        }
        if (event is CancelCallSessionEvent || event is EndCallSessionEvent || event is TimeoutCallSessionEvent) {
          return current.copyWith(status: CallSessionStatus.ended);
        }
        break;

      case CallSessionStatus.outgoingRinging:
        if (event is AcceptCallSessionEvent || event is MediaConnectingCallSessionEvent) {
          return current.copyWith(status: CallSessionStatus.connecting);
        }
        if (event is RejectCallSessionEvent) {
          return current.copyWith(status: CallSessionStatus.rejected);
        }
        if (event is CancelCallSessionEvent || event is EndCallSessionEvent || event is TimeoutCallSessionEvent) {
          return current.copyWith(status: CallSessionStatus.ended);
        }
        break;

      case CallSessionStatus.incomingRinging:
        if (event is AcceptCallSessionEvent) {
          return current.copyWith(status: CallSessionStatus.connecting);
        }
        if (event is RejectCallSessionEvent) {
          return current.copyWith(status: CallSessionStatus.rejected);
        }
        if (event is CancelCallSessionEvent || event is EndCallSessionEvent || event is TimeoutCallSessionEvent) {
          return current.copyWith(status: CallSessionStatus.ended);
        }
        break;

      case CallSessionStatus.connecting:
        if (event is MediaConnectedCallSessionEvent) {
          return current.copyWith(status: CallSessionStatus.connected);
        }
        if (event is MediaFailedCallSessionEvent) {
          return current.copyWith(
            status: CallSessionStatus.failed,
            errorMessage: event.message,
          );
        }
        if (event is EndCallSessionEvent || event is CancelCallSessionEvent) {
          return current.copyWith(status: CallSessionStatus.ended);
        }
        break;

      case CallSessionStatus.connected:
        if (event is MediaDisconnectedCallSessionEvent || event is MediaReconnectingCallSessionEvent) {
          return current.copyWith(
            status: CallSessionStatus.reconnecting,
            networkQuality: NetworkQualityLevel.reconnecting,
          );
        }
        if (event is EndCallSessionEvent || event is CancelCallSessionEvent) {
          return current.copyWith(status: CallSessionStatus.ended);
        }
        break;

      case CallSessionStatus.reconnecting:
        if (event is MediaConnectedCallSessionEvent) {
          return current.copyWith(
            status: CallSessionStatus.connected,
            networkQuality: NetworkQualityLevel.good,
          );
        }
        if (event is MediaFailedCallSessionEvent || event is TimeoutCallSessionEvent) {
          return current.copyWith(
            status: CallSessionStatus.failed,
            errorMessage: event is MediaFailedCallSessionEvent ? event.message : 'Connection timed out',
          );
        }
        if (event is EndCallSessionEvent || event is CancelCallSessionEvent) {
          return current.copyWith(status: CallSessionStatus.ended);
        }
        break;

      case CallSessionStatus.ended:
      case CallSessionStatus.rejected:
      case CallSessionStatus.busy:
      case CallSessionStatus.failed:
        // Terminal states - ignoring non-metric events
        break;
    }

    return current;
  }

  void dispose() {
    _stateController.close();
  }
}
