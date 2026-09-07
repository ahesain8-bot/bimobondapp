import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../../core/constants/live_traffic_source.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/live_api_client.dart';
import '../../../../core/models/live_media_hints.dart';
import '../../domain/entities/live_entity.dart';
import '../../domain/entities/live_feed_page_result.dart';
import '../../domain/entities/live_session_entity.dart';
import '../../../live/domain/entities/live_moderator.dart';
import '../../../live/domain/entities/live_share_result.dart';
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
  Future<LiveFeedPageResult> getLiveFeed({
    int page = 1,
    int limit = 10,
    String? category,
    bool followingOnly = false,
    bool audioOnly = false,
    String? topic,
  }) async {
    final payload = await _api.get(
      audioOnly ? ApiEndpoints.livesAudio : ApiEndpoints.livesFeed,
      auth: true,
      query: {
        'page': '$page',
        'limit': '$limit',
        if (followingOnly) 'followingOnly': 'true',
        if (category != null && category.isNotEmpty) 'categoryId': category,
        if (audioOnly) 'audioOnly': 'true',
        if (topic != null && topic.trim().isNotEmpty) 'topic': topic.trim(),
      },
    );
    return LiveMapper.pageFromPayload(
      payload,
      requestedPage: page,
      requestedLimit: limit,
    );
  }

  @override
  Future<LiveFeedPageResult> getNearbyFeed({
    int page = 1,
    int limit = 10,
    required double latitude,
    required double longitude,
    int? radiusKm,
  }) async {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      throw ArgumentError('Nearby needs valid coordinates');
    }
    final payload = await _api.get(
      ApiEndpoints.livesNearby,
      auth: true,
      query: {
        'page': '$page',
        'limit': '$limit',
        'latitude': '$latitude',
        'longitude': '$longitude',
        // Documented default 50, max 150. The server still decides.
        if (radiusKm != null) 'radiusKm': '${radiusKm.clamp(1, 150)}',
      },
    );
    return LiveMapper.pageFromPayload(
      payload,
      requestedPage: page,
      requestedLimit: limit,
    );
  }

  @override
  Future<LiveFeedPageResult> getAudioFeed({
    int page = 1,
    int limit = 10,
    String? topic,
  }) async {
    final payload = await _api.get(
      ApiEndpoints.livesAudio,
      auth: true,
      query: {
        'page': '$page',
        'limit': '$limit',
        if (topic != null && topic.trim().isNotEmpty) 'topic': topic.trim(),
      },
    );
    return LiveMapper.pageFromPayload(
      payload,
      requestedPage: page,
      requestedLimit: limit,
    );
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
  Future<JoinLiveResult> joinLive(
    String liveId, {
    String? campaignId,
    String? trafficSource,
  }) async {
    // POST /lives/:id/join → { live, token, url, role, guest }
    final attribution = campaignId?.trim();
    final bucket = LiveTrafficSource.normalise(trafficSource);
    final body = <String, dynamic>{
      if (attribution != null && attribution.isNotEmpty)
        'campaignId': attribution,
      // Omitted with a campaignId means PROMOTE on the server, so a promoted
      // open sends no bucket of its own unless the caller named one.
      'trafficSource': ?bucket,
    };
    final payload = await _api.post(
      ApiEndpoints.liveJoin(liveId),
      body: body.isEmpty ? null : body,
    );

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
    // socket token from the backend. Never fabricate credentials.
    final socketToken = await _api.idTokenProvider?.call() ?? '';
    if (socketToken.isEmpty) throw Exception('INVALID_JOIN_RESPONSE');

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

  @override
  Future<LiveShareResult> shareLive(String liveId, {String? channel}) async {
    final payload = await _api.post(
      ApiEndpoints.liveShare(liveId),
      body: {if (channel != null && channel.isNotEmpty) 'channel': channel},
    );
    return LiveShareResult.fromJson(payload, liveId: liveId);
  }

  @override
  Future<void> reportLive(String liveId, {required String reason}) async {
    await _api.post(ApiEndpoints.liveReport(liveId), body: {'reason': reason});
  }

  @override
  Future<List<LiveModerator>> listModerators(String liveId) async {
    final payload = await _api.get(ApiEndpoints.liveModerators(liveId));
    return LiveModerator.listFromPayload(payload);
  }
}
