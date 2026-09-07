import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Only use when the request is known not to have been dispatched. A timeout,
/// HTTP 5xx, or an unrecognized response is NOT proof of non-execution.
class LiveOperationNotSent implements Exception {
  const LiveOperationNotSent(this.message);
  final String message;
  @override
  String toString() => message;
}

class LiveOperationUnresolved implements Exception {
  const LiveOperationUnresolved();
  @override
  String toString() =>
      'The previous operation needs confirmation. It has not been sent again.';
}

/// Use only for a contract-defined rejection that proves no mutation occurred.
/// An HTTP status alone (including 4xx) is insufficient evidence.
class LiveOperationRejected implements Exception {
  const LiveOperationRejected(this.message);
  final String message;
  @override
  String toString() => message;
}

enum LiveOperationOutcome { notSent, rejected, confirmed, unknown }

class LiveOperationRecord {
  const LiveOperationRecord(this.outcome, {this.context = const {}});
  final LiveOperationOutcome outcome;
  final Map<String, dynamic> context;
}

abstract interface class LiveOperationStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class _PreferencesOperationStore implements LiveOperationStore {
  Future<SharedPreferences>? _instance;
  Future<SharedPreferences> get _prefs =>
      _instance ??= SharedPreferences.getInstance();
  @override
  Future<String?> read(String key) async => (await _prefs).getString(key);
  @override
  Future<void> write(String key, String value) async {
    if (!await (await _prefs).setString(key, value)) {
      throw const LiveOperationNotSent('Could not save the operation.');
    }
  }

  @override
  Future<void> remove(String key) async {
    if (!await (await _prefs).remove(key)) {
      throw StateError('Could not update the operation record.');
    }
  }
}

/// A per-account, per-live, per-operation journal shared by independent rooms.
/// Reserve synchronously, persist BEFORE dispatch, retain uncertain outcomes
/// across process restart. Never infer reconciliation from a wallet delta or
/// another viewer's claim. The public boxes list has no personal claim status.
class LiveOperationGuard {
  LiveOperationGuard(this.store);
  static final shared = LiveOperationGuard(_PreferencesOperationStore());

  final LiveOperationStore store;
  final Set<String> _running = {};

  static String keyFor({
    required String userId,
    required String liveId,
    required String operation,
    required String entityId,
  }) =>
      'live.operation.v1.${jsonEncode([userId, liveId, operation, entityId])}';

  Future<LiveOperationRecord> read({
    required String userId,
    required String liveId,
    required String operation,
    required String entityId,
  }) async {
    final value = await store.read(
      keyFor(
        userId: userId,
        liveId: liveId,
        operation: operation,
        entityId: entityId,
      ),
    );
    if (value == null)
      return const LiveOperationRecord(LiveOperationOutcome.notSent);
    if (value == 'confirmed')
      return const LiveOperationRecord(LiveOperationOutcome.confirmed);
    if (value == 'rejected')
      return const LiveOperationRecord(LiveOperationOutcome.rejected);
    try {
      final data = jsonDecode(value);
      if (data is Map && data['context'] is Map) {
        return LiveOperationRecord(
          LiveOperationOutcome.unknown,
          context: Map<String, dynamic>.from(data['context'] as Map),
        );
      }
    } catch (_) {
      /* Legacy pending records remain unresolved. */
    }
    return const LiveOperationRecord(LiveOperationOutcome.unknown);
  }

  /// Caller must first obtain personal, operation-specific server evidence.
  /// This records confirmation, and never authorizes another charge.
  Future<void> confirm({
    required String userId,
    required String liveId,
    required String operation,
    required String entityId,
  }) async {
    final key = keyFor(
      userId: userId,
      liveId: liveId,
      operation: operation,
      entityId: entityId,
    );
    if (userId.isEmpty || _running.contains(key)) return;
    if (await store.read(key) != null) await store.write(key, 'confirmed');
  }

  Future<T> run<T>({
    required String Function() userId,
    required String liveId,
    required String operation,
    required String entityId,
    required Future<T> Function() send,
    bool retainSuccess = true,
    Map<String, dynamic> context = const {},
  }) async {
    final account = userId();
    if (account.isEmpty || liveId.isEmpty || entityId.isEmpty) {
      throw const LiveOperationNotSent('Sign in and select a valid LIVE item.');
    }
    final key = keyFor(
      userId: account,
      liveId: liveId,
      operation: operation,
      entityId: entityId,
    );
    if (!_running.add(key)) throw const LiveOperationUnresolved();
    var dispatched = false;
    var reserved = false;
    try {
      final previous = await store.read(key);
      if (previous != null && previous != 'rejected') {
        throw const LiveOperationUnresolved();
      }
      await store.write(
        key,
        context.isEmpty
            ? 'pending'
            : jsonEncode({'state': 'pending', 'context': context}),
      );
      reserved = true;
      if (account != userId()) {
        throw const LiveOperationNotSent('The signed-in account changed.');
      }
      dispatched = true;
      final result = await send();
      // Failure to save completion still leaves a durable pending record and
      // must not turn a confirmed success into an invitation to send again.
      try {
        if (retainSuccess) {
          await store.write(key, 'confirmed');
        } else {
          await store.remove(key);
        }
      } catch (_) {
        /* Keep the pending record. */
      }
      return result;
    } catch (error) {
      if (reserved && (!dispatched || error is LiveOperationNotSent)) {
        await store.remove(key);
      } else if (reserved && error is LiveOperationRejected) {
        await store.write(key, 'rejected');
      }
      rethrow;
    } finally {
      _running.remove(key);
    }
  }
}
