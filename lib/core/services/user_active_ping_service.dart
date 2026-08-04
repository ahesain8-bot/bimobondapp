import 'dart:async';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service to handle mobile active heartbeats (`POST /users/me/active`).
/// Periodically pings the server to keep user's `isOnline` & `lastSeenAt` fresh.
class UserActivePingService {
  final ApiClient apiClient;
  Timer? _pingTimer;
  bool _isPinging = false;

  UserActivePingService({required this.apiClient});

  /// Starts periodic heartbeat pings (every 2 minutes).
  void startPeriodicPing({Duration interval = const Duration(minutes: 2)}) {
    stopPeriodicPing();
    pingActive();
    _pingTimer = Timer.periodic(interval, (_) => pingActive());
  }

  /// Stops periodic heartbeat pings.
  void stopPeriodicPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// Sends a single active ping to `POST /users/me/active`.
  Future<bool> pingActive() async {
    if (_isPinging) return false;
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return false;

    _isPinging = true;
    try {
      final token = await firebaseUser.getIdToken();
      final response = await apiClient.dio.post(
        ApiConstants.userActivePing,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    } finally {
      _isPinging = false;
    }
  }
}
