import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/live_api_client.dart';
import '../../domain/entities/live_entity.dart';
import '../../domain/entities/live_session_entity.dart';
import '../mappers/live_mapper.dart';
import 'live_remote_datasource.dart';

/// Real REST implementation of [LiveRemoteDataSource].
///
/// Maps to the backend endpoints documented in `lives/mobile-api.md`:
/// - `GET  /lives/feed`            → feed
/// - `GET  /lives/:id`             → details
/// - `POST /lives/:id/join`        → join (returns LiveKit url + token)
/// - `POST /lives/:id/leave`       → leave
/// - `POST /creators/:id/fan-club/subscribe`  (follow)
/// - `DELETE /creators/:id/fan-club/subscribe` (unfollow)
class HttpLiveRemoteDataSource implements LiveRemoteDataSource {
  HttpLiveRemoteDataSource({LiveApiClient? apiClient})
    : _api = apiClient ?? _defaultApiClient();

  final LiveApiClient _api;

  static LiveApiClient _defaultApiClient() {
    final client = LiveApiClient();
    client.idTokenProvider = () async {
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      return user.getIdToken();
    };
    return client;
  }

  @override
  Future<List<LiveEntity>> getLiveFeed({
    int page = 1,
    int limit = 10,
    String? category,
  }) async {
    final payload = await _api.get(
      ApiEndpoints.livesFeed,
      auth: true,
      query: {
        'page': '$page',
        'limit': '$limit',
        if (category != null && category.isNotEmpty) 'categoryId': category,
      },
    );
    return LiveMapper.listFromPayload(payload);
  }

  @override
  Future<LiveEntity> getLiveById(String liveId) async {
    final payload = await _api.get(ApiEndpoints.liveById(liveId));
    final live = LiveMapper.fromJson(payload);
    if (live.id.isEmpty) {
      // Backend may return { live: {...} } wrapping.
      final nested = payload['live'];
      if (nested is Map<String, dynamic>) {
        return LiveMapper.fromJson(nested);
      }
    }
    return live;
  }

  @override
  Future<JoinLiveResult> joinLive(String liveId) async {
    // POST /lives/:id/join → { live, token, url, role, guest }
    final payload = await _api.post(ApiEndpoints.liveJoin(liveId));

    final nestedLive = payload['live'];
    final liveJson = nestedLive is Map<String, dynamic> ? nestedLive : payload;

    final live = LiveMapper.fromJson(liveJson);
    final liveKitUrl = payload['url']?.toString() ?? '';
    final liveKitToken = payload['token']?.toString() ?? '';

    if (live.status == LiveStatus.banned) {
      throw Exception('BANNED');
    }
    if (live.status == LiveStatus.ended) {
      throw Exception('ENDED');
    }
    if (liveKitUrl.isEmpty || liveKitToken.isEmpty) {
      throw Exception('INVALID_JOIN_RESPONSE');
    }

    // The socket handshake uses the Firebase ID token itself — no separate
    // socket token from the backend. Keep a placeholder for contract parity.
    final socketToken =
        await _api.idTokenProvider?.call() ??
        'socket_${liveId}_${DateTime.now().millisecondsSinceEpoch}';

    return JoinLiveResult(
      liveId: liveId,
      socketToken: socketToken,
      liveKitToken: liveKitToken,
      liveKitUrl: liveKitUrl,
      live: live.copyWith(
        streamUrl: liveJson['streamUrl']?.toString() ?? live.streamUrl,
      ),
    );
  }

  @override
  Future<void> leaveLive(String liveId) async {
    // POST /lives/:id/leave → { success, viewers }
    await _api.post(ApiEndpoints.liveLeave(liveId));
  }

  @override
  Future<List<String>> getTrendingCategories() async {
    try {
      final payload = await _api.get(
        ApiEndpoints.livesFeed,
        auth: true,
        query: {'page': '1', 'limit': '50'},
      );
      final categories = LiveMapper.categoriesFromPayload(payload);
      if (categories.isNotEmpty) return categories;
    } catch (_) {
      // Fall through to defaults when the feed is unreachable.
    }
    return const [
      'Music',
      'Gaming',
      'Talk Show',
      'Food',
      'Fashion',
      'Sports',
      'Education',
      'Comedy',
      'Dance',
    ];
  }

  @override
  Future<void> followHost(String hostId) async {
    await _api.post(ApiEndpoints.creatorsFanClubSubscribe(hostId));
  }

  @override
  Future<void> unfollowHost(String hostId) async {
    await _api.delete(ApiEndpoints.creatorsFanClubSubscribe(hostId));
  }

  @override
  Future<void> banViewer({
    required String liveId,
    required String userId,
    String? reason,
  }) async {
    final body = <String, dynamic>{};
    if (reason != null && reason.isNotEmpty) body['reason'] = reason;
    await _api.post(ApiEndpoints.liveViewerBan(liveId, userId), body: body);
  }

  @override
  Future<void> unbanViewer({
    required String liveId,
    required String userId,
  }) async {
    await _api.post(ApiEndpoints.liveViewerUnban(liveId, userId));
  }

  @override
  Future<void> muteViewerChat({
    required String liveId,
    required String userId,
    String? reason,
  }) async {
    final body = <String, dynamic>{};
    if (reason != null && reason.isNotEmpty) body['reason'] = reason;
    await _api.post(
      ApiEndpoints.liveViewerMuteChat(liveId, userId),
      body: body,
    );
  }

  @override
  Future<void> unmuteViewerChat({
    required String liveId,
    required String userId,
  }) async {
    await _api.post(ApiEndpoints.liveViewerUnmuteChat(liveId, userId));
  }
}
