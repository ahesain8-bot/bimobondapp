import 'package:bimobondapp/app/calls/data/models/call_model.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:dio/dio.dart';

abstract class CallsRemoteDataSource {
  Future<CallSessionModel> startCall({
    required String chatId,
    required String type,
    List<String>? inviteeIds,
  });

  Future<CallModel?> getActiveCall({
    required String chatId,
  });

  Future<CallModel> getCallById({
    required String callId,
  });

  Future<CallSessionModel> acceptCall({
    required String callId,
  });

  Future<CallModel> rejectCall({
    required String callId,
  });

  Future<CallModel> endCall({
    required String callId,
  });

  Future<CallModel> leaveCall({
    required String callId,
  });

  Future<CallModel> inviteToCall({
    required String callId,
    required List<String> inviteeIds,
  });
}

class CallsRemoteDataSourceImpl implements CallsRemoteDataSource {
  final ApiClient apiClient;

  CallsRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<CallSessionModel> startCall({
    required String chatId,
    required String type,
    List<String>? inviteeIds,
  }) async {
    try {
      final body = <String, dynamic>{'type': type};
      if (inviteeIds != null && inviteeIds.isNotEmpty) {
        body['inviteeIds'] = inviteeIds;
      }

      final response = await apiClient.dio.post(
        '/chats/$chatId/calls',
        data: body,
      );

      if (response.data is Map) {
        return CallSessionModel.fromJson(
          Map<String, dynamic>.from(response.data),
        );
      }
      throw ServerException(message: 'Invalid response format');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<CallModel?> getActiveCall({
    required String chatId,
  }) async {
    try {
      final response = await apiClient.dio.get('/chats/$chatId/calls/active');
      if (response.data == null || response.data == '') return null;
      if (response.data is Map) {
        final dataMap = Map<String, dynamic>.from(response.data);
        if (dataMap.isEmpty) return null;
        return CallModel.fromJson(dataMap);
      }
      return null;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        return null;
      }
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<CallModel> getCallById({
    required String callId,
  }) async {
    try {
      final response = await apiClient.dio.get('/calls/$callId');
      if (response.data is Map) {
        return CallModel.fromJson(Map<String, dynamic>.from(response.data));
      }
      throw ServerException(message: 'Invalid response format');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<CallSessionModel> acceptCall({
    required String callId,
  }) async {
    try {
      final response = await apiClient.dio.post('/calls/$callId/accept');
      if (response.data is Map) {
        return CallSessionModel.fromJson(
          Map<String, dynamic>.from(response.data),
        );
      }
      throw ServerException(message: 'Invalid response format');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<CallModel> rejectCall({
    required String callId,
  }) async {
    try {
      final response = await apiClient.dio.post('/calls/$callId/reject');
      if (response.data is Map) {
        return CallModel.fromJson(Map<String, dynamic>.from(response.data));
      }
      throw ServerException(message: 'Invalid response format');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<CallModel> endCall({
    required String callId,
  }) async {
    try {
      final response = await apiClient.dio.post('/calls/$callId/end');
      if (response.data is Map) {
        return CallModel.fromJson(Map<String, dynamic>.from(response.data));
      }
      throw ServerException(message: 'Invalid response format');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<CallModel> leaveCall({
    required String callId,
  }) async {
    try {
      final response = await apiClient.dio.post('/calls/$callId/leave');
      if (response.data is Map) {
        return CallModel.fromJson(Map<String, dynamic>.from(response.data));
      }
      throw ServerException(message: 'Invalid response format');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<CallModel> inviteToCall({
    required String callId,
    required List<String> inviteeIds,
  }) async {
    try {
      final response = await apiClient.dio.post(
        '/calls/$callId/invite',
        data: {'inviteeIds': inviteeIds},
      );
      if (response.data is Map) {
        return CallModel.fromJson(Map<String, dynamic>.from(response.data));
      }
      throw ServerException(message: 'Invalid response format');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(message: e.toString());
    }
  }
}
