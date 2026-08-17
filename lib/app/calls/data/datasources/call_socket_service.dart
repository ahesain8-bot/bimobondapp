import 'dart:async';

import 'package:bimobondapp/app/calls/data/models/call_model.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class CallSocketEvent {
  CallSocketEvent._();

  static const joinUser = 'joinUser';
  static const joinChat = 'joinChat';
  static const leaveChat = 'leaveChat';
  static const joinCall = 'joinCall';
  static const leaveCall = 'leaveCall';

  static const callIncoming = 'callIncoming';
  static const callAccepted = 'callAccepted';
  static const callRejected = 'callRejected';
  static const callCancelled = 'callCancelled';
  static const callParticipantUpdate = 'callParticipantUpdate';
  static const callEnded = 'callEnded';
}

class CallIncomingSocketPayload {
  final CallModel call;
  final String? forUserId;

  const CallIncomingSocketPayload({
    required this.call,
    this.forUserId,
  });
}

class CallRejectedSocketPayload {
  final CallModel call;
  final String? rejectedByUserId;

  const CallRejectedSocketPayload({
    required this.call,
    this.rejectedByUserId,
  });
}

class CallParticipantUpdateSocketPayload {
  final String callId;
  final CallParticipantModel participant;

  const CallParticipantUpdateSocketPayload({
    required this.callId,
    required this.participant,
  });
}

class CallSocketService {
  io.Socket? _socket;
  String? _currentUserId;

  final _callIncomingController =
      StreamController<CallIncomingSocketPayload>.broadcast();
  final _callAcceptedController = StreamController<CallModel>.broadcast();
  final _callRejectedController =
      StreamController<CallRejectedSocketPayload>.broadcast();
  final _callCancelledController = StreamController<CallModel>.broadcast();
  final _callParticipantUpdateController =
      StreamController<CallParticipantUpdateSocketPayload>.broadcast();
  final _callEndedController = StreamController<CallModel>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<CallIncomingSocketPayload> get onCallIncoming =>
      _callIncomingController.stream;
  Stream<CallModel> get onCallAccepted => _callAcceptedController.stream;
  Stream<CallRejectedSocketPayload> get onCallRejected =>
      _callRejectedController.stream;
  Stream<CallModel> get onCallCancelled => _callCancelledController.stream;
  Stream<CallParticipantUpdateSocketPayload> get onCallParticipantUpdate =>
      _callParticipantUpdateController.stream;
  Stream<CallModel> get onCallEnded => _callEndedController.stream;
  Stream<bool> get onConnectionChanged => _connectionController.stream;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect(String userId) async {
    _currentUserId = userId;
    if (_socket?.connected == true) {
      if (userId.isNotEmpty) {
        joinUser(userId);
      }
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final token = user != null ? await user.getIdToken() : null;

    _socket?.dispose();
    _socket = io.io(
      ApiConstants.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!
      ..onConnect((_) {
        debugPrint('CallSocketService: connected');
        _connectionController.add(true);
        if (_currentUserId != null && _currentUserId!.isNotEmpty) {
          joinUser(_currentUserId!);
        }
      })
      ..onDisconnect((_) {
        debugPrint('CallSocketService: disconnected');
        _connectionController.add(false);
      })
      ..on(CallSocketEvent.callIncoming, _handleCallIncoming)
      ..on(CallSocketEvent.callAccepted, _handleCallAccepted)
      ..on(CallSocketEvent.callRejected, _handleCallRejected)
      ..on(CallSocketEvent.callCancelled, _handleCallCancelled)
      ..on(CallSocketEvent.callParticipantUpdate, _handleCallParticipantUpdate)
      ..on(CallSocketEvent.callEnded, _handleCallEnded);

    _socket!.connect();
  }

  void joinUser(String userId) {
    if (userId.isEmpty) return;
    _currentUserId = userId;
    _socket?.emit(CallSocketEvent.joinUser, {'userId': userId});
  }

  void joinChat(String chatId) {
    if (chatId.isEmpty) return;
    _socket?.emit(CallSocketEvent.joinChat, {'chatId': chatId});
  }

  void leaveChat(String chatId) {
    if (chatId.isEmpty) return;
    _socket?.emit(CallSocketEvent.leaveChat, {'chatId': chatId});
  }

  void joinCall(String callId) {
    if (callId.isEmpty) return;
    _socket?.emit(CallSocketEvent.joinCall, {'callId': callId});
  }

  void leaveCall(String callId) {
    if (callId.isEmpty) return;
    _socket?.emit(CallSocketEvent.leaveCall, {'callId': callId});
  }

  void _handleCallIncoming(dynamic data) {
    if (data is! Map) return;
    try {
      final map = Map<String, dynamic>.from(data);
      final callModel = CallModel.fromJson(map);
      final forUserId = map['forUserId']?.toString();

      // Filter: if forUserId is present and doesn't match current user, ignore
      if (forUserId != null &&
          _currentUserId != null &&
          _currentUserId!.isNotEmpty &&
          forUserId != _currentUserId) {
        return;
      }

      _callIncomingController.add(
        CallIncomingSocketPayload(
          call: callModel,
          forUserId: forUserId,
        ),
      );
    } catch (e) {
      debugPrint('CallSocketService error parsing callIncoming: $e');
    }
  }

  void _handleCallAccepted(dynamic data) {
    if (data is! Map) return;
    try {
      final map = Map<String, dynamic>.from(data);
      final callModel = CallModel.fromJson(map);
      _callAcceptedController.add(callModel);
    } catch (e) {
      debugPrint('CallSocketService error parsing callAccepted: $e');
    }
  }

  void _handleCallRejected(dynamic data) {
    if (data is! Map) return;
    try {
      final map = Map<String, dynamic>.from(data);
      final callModel = CallModel.fromJson(map);
      final rejectedByUserId = map['rejectedByUserId']?.toString();
      _callRejectedController.add(
        CallRejectedSocketPayload(
          call: callModel,
          rejectedByUserId: rejectedByUserId,
        ),
      );
    } catch (e) {
      debugPrint('CallSocketService error parsing callRejected: $e');
    }
  }

  void _handleCallCancelled(dynamic data) {
    if (data is! Map) return;
    try {
      final map = Map<String, dynamic>.from(data);
      final callModel = CallModel.fromJson(map);
      _callCancelledController.add(callModel);
    } catch (e) {
      debugPrint('CallSocketService error parsing callCancelled: $e');
    }
  }

  void _handleCallParticipantUpdate(dynamic data) {
    if (data is! Map) return;
    try {
      final map = Map<String, dynamic>.from(data);
      final callId = map['callId']?.toString() ?? '';
      final rawParticipant = map['participant'];
      if (rawParticipant is Map) {
        final participantModel = CallParticipantModel.fromJson(
          Map<String, dynamic>.from(rawParticipant),
        );
        _callParticipantUpdateController.add(
          CallParticipantUpdateSocketPayload(
            callId: callId,
            participant: participantModel,
          ),
        );
      }
    } catch (e) {
      debugPrint('CallSocketService error parsing callParticipantUpdate: $e');
    }
  }

  void _handleCallEnded(dynamic data) {
    if (data is! Map) return;
    try {
      final map = Map<String, dynamic>.from(data);
      final callModel = CallModel.fromJson(map);
      _callEndedController.add(callModel);
    } catch (e) {
      debugPrint('CallSocketService error parsing callEnded: $e');
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connectionController.add(false);
  }

  void dispose() {
    disconnect();
    _callIncomingController.close();
    _callAcceptedController.close();
    _callRejectedController.close();
    _callCancelledController.close();
    _callParticipantUpdateController.close();
    _callEndedController.close();
    _connectionController.close();
  }
}
