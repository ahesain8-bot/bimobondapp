import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/live_api_client.dart';
import '../../../../core/models/live_media_hints.dart';
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
    int limit = 20,
    String? category,
    bool followingOnly = false,
  }) async {
    final payload = await _api.get(
      ApiEndpoints.livesFeed,
      auth: true,
      query: {
        'page': '$page',
        'limit': '$limit',
        if (category != null && category.isNotEmpty) 'categoryId': category,
        // The API documents followingOnly as optional and defaults it to
        // false. Omitting false is important because query values arrive at
        // Nest as strings; a server that checks the raw value would treat
        // the string "false" as truthy and incorrectly return Following.
        if (followingOnly) 'followingOnly': 'true',
      },
    );
    final lives = LiveMapper.listFromPayload(payload);
    if (kDebugMode) {
      final data = payload['data'];
      final ids = data is List
          ? data
                .whereType<Map>()
                .map((item) => item['id']?.toString() ?? '')
                .where((id) => id.isNotEmpty)
                .toList(growable: false)
          : const <String>[];
      final statuses = data is List
          ? data
                .whereType<Map>()
                .map((item) => item['status']?.toString() ?? '(missing)')
                .toList(growable: false)
          : const <String>[];
      debugPrint(
        '[LiveFeed] GET ${ApiEndpoints.livesFeed} '
        'page=$page limit=$limit category=${category ?? "none"} '
        'followingOnly=$followingOnly rawCount=${data is List ? data.length : 0} '
        'mappedCount=${lives.length} ids=$ids statuses=$statuses',
      );
      // Decides "the server sent one live" versus "the client lost one"
      // without a second run: `meta` carries the server's own total, and the
      // payload keys expose a response envelope this mapper does not read.
      if (data is! List || data.length != lives.length) {
        debugPrint(
          '[LiveFeed] payload shape payloadKeys=${payload.keys.toList()}'
          ' dataType=${data.runtimeType}'
          ' meta=${payload['meta']}',
        );
      }
    }
    return lives;
  }

  @override
  Future<LiveEntity> getLiveById(String liveId) async {
    final payload = await _api.get(ApiEndpoints.liveById(liveId));
    var live = LiveMapper.fromJson(payload);
    if (live.id.isEmpty) {
      // Backend may return { live: {...} } wrapping.
      final nested = payload['live'];
      if (nested is Map<String, dynamic>) {
        live = LiveMapper.fromJson(nested);
      }
    }
    if (kDebugMode) {
      final auctions = live.metadata?['activeAuctions'];
      debugPrint(
        '[ViewerLive] detail success liveId=$liveId'
        ' mappedId=${live.id}'
        ' status=${live.status.name}'
        ' activeAuctions=${auctions is List ? auctions.length : 0}'
        ' pinnedComment=${live.metadata?['pinnedComment'] != null}'
        ' isPopular=${live.metadata?['isPopular'] == true}',
      );
    }
    return live;
  }

  @override
  Future<JoinLiveResult> joinLive(String liveId) async {
    if (kDebugMode) {
      debugPrint('[ViewerLive] join started liveId=$liveId');
    }
    // POST /lives/:id/join → { live, token, url, role, guest }
    final payload = await _api.post(ApiEndpoints.liveJoin(liveId));

    final nestedLive = payload['live'];
    final liveJson = nestedLive is Map<String, dynamic> ? nestedLive : payload;

    final live = LiveMapper.fromJson(liveJson);
    final liveKitUrl = payload['url']?.toString() ?? '';
    final liveKitToken = payload['token']?.toString() ?? '';
    if (kDebugMode) {
      final auctions = live.metadata?['activeAuctions'];
      debugPrint(
        '[ViewerLive] join response liveId=$liveId'
        ' mappedId=${live.id}'
        ' status=${live.status.name}'
        ' urlPresent=${liveKitUrl.isNotEmpty}'
        ' tokenPresent=${liveKitToken.isNotEmpty}'
        ' activeAuctions=${auctions is List ? auctions.length : 0}'
        ' pinnedComment=${live.metadata?['pinnedComment'] != null}'
        ' isPopular=${live.metadata?['isPopular'] == true}',
      );
    }

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
      mediaHints: LiveMediaHints.fromPayload(payload, fallbackRole: 'viewer'),
    );
  }

  @override
  Future<void> leaveLive(String liveId) async {
    // POST /lives/:id/leave → { success, viewers }
    await _api.post(ApiEndpoints.liveLeave(liveId));
  }

  @override
  Future<List<String>> getTrendingCategories() async {
    final payload = await _api.get(
      ApiEndpoints.livesFeed,
      auth: true,
      query: {'page': '1', 'limit': '50'},
    );
    return LiveMapper.categoriesFromPayload(payload);
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
