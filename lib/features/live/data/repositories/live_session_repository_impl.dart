import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../domain/entities/live_chat_message.dart';
import '../../domain/entities/live_gallery_item.dart';
import '../../domain/entities/live_guest.dart';
import '../../domain/entities/live_leaderboard_entry.dart';
import '../../domain/entities/live_session.dart';
import '../../domain/repositories/live_session_repository.dart';
import '../datasources/lives_media_datasource.dart';
import '../datasources/lives_remote_datasource.dart';
import '../datasources/lives_socket_datasource.dart';
import '../mappers/live_host_extras_mapper.dart';
import '../mappers/live_session_mapper.dart';
import '../../domain/entities/live_viewer.dart';

/// Remote live-session repository backed by Nest `/lives` + Socket.IO + LiveKit.
class LiveSessionRepositoryImpl implements LiveSessionRepository {
  LiveSessionRepositoryImpl({
    required LivesRemoteDataSource remote,
    required LivesSocketDataSource socket,
    required LivesMediaDataSource media,
  })  : _remote = remote,
        _socket = socket,
        _media = media;

  final LivesRemoteDataSource _remote;
  final LivesSocketDataSource _socket;
  final LivesMediaDataSource _media;

  @override
  Stream<LiveHudEvent> get hudEvents => _socket.events;

  @override
  bool get isMediaConnected => _media.isConnected;

  @override
  Object? get localPreviewTrack => _media.localVideoTrack;

  @override
  Future<LiveSession> startHostSession({required String title}) async {
    final trimmed = title.trim().isEmpty ? 'بث مباشر' : title.trim();
    try {
      return await _createLive(trimmed);
    } on BadRequestException catch (e) {
      // Server refuses: "You already have an active live." (stale live left
      // from a previous session). End it automatically, then retry ONCE so
      // the host is never blocked by a ghost live.
      if (!_isStaleActiveLiveError(e)) rethrow;
      debugPrint('Stale active live detected, ending it before retry: $e');
      final stale = await findActiveHostLive();
      if (stale != null) {
        await endSession(stale.id);
      }
      return _createLive(trimmed);
    }
  }

  Future<LiveSession> _createLive(String title) async {
    final response = await _remote.createAndStart(title: title);

    final liveMap = (response['live'] as Map<String, dynamic>?) ?? response;
    final token = response['token']?.toString();
    final url = response['url']?.toString();
    final role = response['role']?.toString() ?? 'host';

    // Camera/LiveKit publish and HUD enrichment are intentionally NOT done
    // here — the BLoC starts the local preview immediately and connects
    // LiveKit / loads enrichment after the preview is on screen.
    return LiveSessionMapper.fromLiveJson(
      liveMap,
      liveKitToken: token,
      liveKitUrl: url,
      liveKitRole: role,
    );
  }

  bool _isStaleActiveLiveError(ApiException e) {
    final msg = e.message.toLowerCase();
    return msg.contains('active live') ||
        msg.contains('already have a live') ||
        msg.contains('start another');
  }

  @override
  Future<LiveSession> reconnectHostSession(String liveId) async {
    final response = await _remote.start(liveId);
    final liveMap = (response['live'] as Map<String, dynamic>?) ?? response;
    return LiveSessionMapper.fromLiveJson(
      liveMap,
      liveKitToken: response['token']?.toString(),
      liveKitUrl: response['url']?.toString(),
      liveKitRole: response['role']?.toString() ?? 'host',
    );
  }

  @override
  Future<LiveSession?> findActiveHostLive() async {
    final json = await _remote.mine(limit: 50);
    final raw = json['data'];
    if (raw is! List) return null;
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      if (map['status']?.toString() == 'LIVE') {
        return LiveSessionMapper.fromLiveJson(map);
      }
    }
    return null;
  }

  @override
  Future<void> endSession(String sessionId) async {
    try {
      await _remote.end(sessionId);
    } finally {
      await disconnectRealtime();
      await disconnectMedia();
    }
  }

  @override
  Future<List<LiveChatMessage>> loadComments(
    String liveId, {
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final json = await _remote.listComments(
        liveId: liveId,
        page: page,
        limit: limit,
      );
      final raw = json['data'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map(
            (e) => LiveSessionMapper.commentFromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(growable: false)
          .reversed
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<LiveChatMessage> sendComment({
    required String liveId,
    required String content,
  }) async {
    final json = await _remote.sendComment(
      liveId: liveId,
      content: content,
    );
    final map = (json['id'] != null)
        ? json
        : (json['data'] as Map<String, dynamic>? ?? json);
    return LiveSessionMapper.commentFromJson(map);
  }

  @override
  Future<void> deleteComment({
    required String liveId,
    required String commentId,
  }) {
    return _remote.deleteComment(liveId: liveId, commentId: commentId);
  }

  @override
  Future<void> pinComment({
    required String liveId,
    required String commentId,
  }) {
    return _remote.pinComment(liveId: liveId, commentId: commentId);
  }

  @override
  Future<void> unpinComment({
    required String liveId,
    required String commentId,
  }) {
    return _remote.unpinComment(liveId: liveId, commentId: commentId);
  }

  @override
  Future<void> muteViewerChat({
    required String liveId,
    required String userId,
    String? reason,
  }) {
    return _remote.muteViewerChat(
      liveId: liveId,
      userId: userId,
      reason: reason,
    );
  }

  @override
  Future<void> unmuteViewerChat({
    required String liveId,
    required String userId,
  }) {
    return _remote.unmuteViewerChat(liveId: liveId, userId: userId);
  }

  @override
  Future<void> banViewer({
    required String liveId,
    required String userId,
    String? reason,
  }) {
    return _remote.banViewer(liveId: liveId, userId: userId, reason: reason);
  }

  @override
  Future<void> unbanViewer({
    required String liveId,
    required String userId,
  }) {
    return _remote.unbanViewer(liveId: liveId, userId: userId);
  }

  @override
  Future<int> like(String liveId) async {
    final json = await _remote.like(liveId);
    final count = json['likeCount'];
    if (count is int) return count;
    if (count is num) return count.toInt();
    return int.tryParse(count?.toString() ?? '') ?? 0;
  }

  @override
  Future<LiveSession> updateTitle({
    required String liveId,
    required String title,
  }) async {
    final live = await _remote.updateLive(liveId, title: title);
    return LiveSessionMapper.fromLiveJson(live);
  }

  @override
  Future<LiveSession> updateSettings({
    required String liveId,
    bool? guestsEnabled,
    String? guestRequestMode,
    int? maxGuests,
    String? layout,
    bool? allowGuestCamera,
    bool? moderatorsCanManageGuests,
  }) async {
    final live = await _remote.updateSettings(
      liveId,
      guestsEnabled: guestsEnabled,
      guestRequestMode: guestRequestMode,
      maxGuests: maxGuests,
      layout: layout,
      allowGuestCamera: allowGuestCamera,
      moderatorsCanManageGuests: moderatorsCanManageGuests,
    );
    final map = (live['id'] != null)
        ? live
        : (live['data'] as Map<String, dynamic>? ?? live);
    return LiveSessionMapper.fromLiveJson(map);
  }

  @override
  Future<({int current, int total})> loadGalleryCounts(String liveId) async {
    try {
      final items = await loadGalleryItems(liveId);
      return (current: items.length, total: items.length);
    } catch (_) {
      return (current: 0, total: 0);
    }
  }

  @override
  Future<List<LiveGalleryItem>> loadGalleryItems(String liveId) async {
    final json = await _remote.gallery(liveId);
    final raw = json['data'] ?? json['items'] ?? json['gallery'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (e) => LiveHostExtrasMapper.galleryItemFromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .where((e) => e.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> pinGalleryItem({
    required String liveId,
    required String auctionId,
    required bool pinned,
  }) {
    return _remote.pinAuction(
      liveId: liveId,
      auctionId: auctionId,
      pinned: pinned,
    );
  }

  @override
  Future<int> loadGuestPendingCount(String liveId) async {
    try {
      final guests = await loadGuests(liveId);
      return guests.where((g) => g.isPending).length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<List<LiveGuest>> loadGuests(String liveId) async {
    final json = await _remote.guests(liveId);
    final raw = json['data'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (e) => LiveHostExtrasMapper.guestFromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> inviteGuest({
    required String liveId,
    required String userId,
    String role = 'GUEST',
  }) {
    return _remote.inviteGuest(liveId: liveId, userId: userId, role: role);
  }

  @override
  Future<void> acceptGuest({
    required String liveId,
    required String userId,
  }) {
    return _remote.acceptGuest(liveId: liveId, userId: userId);
  }

  @override
  Future<void> rejectGuest({
    required String liveId,
    required String userId,
  }) {
    return _remote.rejectGuest(liveId: liveId, userId: userId);
  }

  @override
  Future<void> kickGuest({
    required String liveId,
    required String userId,
  }) {
    return _remote.kickGuest(liveId: liveId, userId: userId);
  }

  @override
  Future<void> muteGuest({
    required String liveId,
    required String userId,
  }) {
    return _remote.muteGuest(liveId: liveId, userId: userId);
  }

  @override
  Future<void> unmuteGuest({
    required String liveId,
    required String userId,
  }) {
    return _remote.unmuteGuest(liveId: liveId, userId: userId);
  }

  @override
  Future<void> setGuestCameraOff({
    required String liveId,
    required String userId,
  }) {
    return _remote.guestCameraOff(liveId: liveId, userId: userId);
  }

  @override
  Future<void> setGuestCameraOn({
    required String liveId,
    required String userId,
  }) {
    return _remote.guestCameraOn(liveId: liveId, userId: userId);
  }

  @override
  Future<void> promoteGuest({
    required String liveId,
    required String userId,
  }) {
    return _remote.promoteGuest(liveId: liveId, userId: userId);
  }

  @override
  Future<void> demoteGuest({
    required String liveId,
    required String userId,
  }) {
    return _remote.demoteGuest(liveId: liveId, userId: userId);
  }

  @override
  Future<({int? rank, String label, int? score, int? coins})> loadHourlyRank(
    String liveId,
  ) async {
    try {
      final json = await _remote.hourlyLeaderboard(liveId);
      final nested = json['data'];
      final map = nested is Map<String, dynamic> ? nested : json;
      final rank = _asInt(map['hourlyRank'] ?? map['rank']);
      final score = _asInt(map['hourlyScore'] ?? map['score']);
      final coins = _asInt(map['hourlyCoins'] ?? map['coins']);
      if (rank != null) {
        return (
          rank: rank,
          label: 'ترتيب #$rank',
          score: score,
          coins: coins,
        );
      }
      return (
        rank: null,
        label: 'ترتيب كل ساعة',
        score: score,
        coins: coins,
      );
    } catch (_) {
      return (
        rank: null,
        label: 'ترتيب كل ساعة',
        score: null,
        coins: null,
      );
    }
  }

  @override
  Future<List<LiveLeaderboardEntry>> loadGlobalHourlyLeaderboard({
    int limit = 20,
  }) async {
    final json = await _remote.globalHourlyLeaderboard(limit: limit);
    final raw = json['data'] ?? json['items'];
    if (raw is! List) {
      // Some backends return a single object for this-live; wrap if list missing.
      if (json['hourlyRank'] != null || json['rank'] != null) {
        return [
          LiveHostExtrasMapper.leaderboardEntryFromJson(json, fallbackRank: 1),
        ];
      }
      return const [];
    }
    var i = 0;
    return raw
        .whereType<Map>()
        .map((e) {
          i++;
          return LiveHostExtrasMapper.leaderboardEntryFromJson(
            Map<String, dynamic>.from(e),
            fallbackRank: i,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<List<LiveLeaderboardEntry>> loadGiftersLeaderboard(
    String liveId, {
    String window = 'hour',
  }) async {
    final json = await _remote.giftersLeaderboard(liveId, window: window);
    final raw = json['data'] ?? json['items'];
    if (raw is! List) return const [];
    var i = 0;
    return raw
        .whereType<Map>()
        .map((e) {
          i++;
          return LiveHostExtrasMapper.leaderboardEntryFromJson(
            Map<String, dynamic>.from(e),
            fallbackRank: i,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<List<LiveViewer>> loadViewers(String liveId) async {
    final json = await _remote.viewers(liveId);
    final raw = json['data'] ?? json['items'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (e) => LiveHostExtrasMapper.viewerFromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> connectRealtime(String liveId) =>
      _socket.connectAndJoin(liveId);

  @override
  Future<void> disconnectRealtime() => _socket.disconnect();

  @override
  Future<void> connectMedia({
    required String url,
    required String token,
    bool useFrontCamera = true,
  }) =>
      _media.connectAndPublish(
        url: url,
        token: token,
        cameraPosition:
            useFrontCamera ? CameraPosition.front : CameraPosition.back,
      );

  @override
  Future<void> connectMediaSubscribe({
    required String url,
    required String token,
  }) =>
      _media.connectAndSubscribe(url: url, token: token);

  @override
  Future<void> disconnectMedia() => _media.disconnect();

  @override
  Future<void> setMicrophoneEnabled(bool enabled) =>
      _media.setMicrophoneEnabled(enabled);

  @override
  Future<void> flipMediaCamera({required bool useFront}) async {
    await _media.flipCamera(useFront: useFront);
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
