import 'dart:async';

import 'package:bimobondapp/app/calls/domain/entities/call_entity.dart';
import 'package:bimobondapp/app/calls/domain/session/call_session.dart';
import 'package:bimobondapp/app/calls/domain/session/call_session_state.dart';
import 'package:flutter/foundation.dart';

class CallSessionManager {
  CallSession? _activeSession;
  final _activeSessionController = StreamController<CallSession?>.broadcast();

  CallSession? get activeSession => _activeSession;
  Stream<CallSession?> get onActiveSessionChanged =>
      _activeSessionController.stream;

  bool get hasActiveCall =>
      _activeSession != null && !_activeSession!.state.isTerminated;

  CallSession createSession({
    required String callId,
    required CallEntity call,
    String? livekitUrl,
    String? token,
    required bool isOutgoing,
    CallSessionStatus initialStatus = CallSessionStatus.idle,
  }) {
    if (hasActiveCall && _activeSession!.callId != callId) {
      debugPrint(
          'CallSessionManager: Existing active session ${_activeSession!.callId} present. Replacing or ignoring callId=$callId');
    }

    _activeSession?.dispose();

    final session = CallSession(
      callId: callId,
      call: call,
      livekitUrl: livekitUrl,
      token: token,
      isOutgoing: isOutgoing,
      initialStatus: initialStatus,
    );

    _activeSession = session;
    _activeSessionController.add(_activeSession);
    return session;
  }

  void clearSession(String callId) {
    if (_activeSession?.callId == callId) {
      debugPrint('CallSessionManager: Clearing active session for $callId');
      _activeSession?.dispose();
      _activeSession = null;
      _activeSessionController.add(null);
    }
  }

  void dispose() {
    _activeSession?.dispose();
    _activeSessionController.close();
  }
}
