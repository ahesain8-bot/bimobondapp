import '../../../../core/models/live_battle.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/live_api_client.dart';

/// HTTP access to `/lives` and `/gifts` endpoints documented in mobile-api.md.
class LivesRemoteDataSource {
  LivesRemoteDataSource({LiveApiClient? apiClient})
    : _api = apiClient ?? LiveApiClient();

  final LiveApiClient _api;

  /// `POST /lives` with `startNow: true` → `{ live, token, url, role }`.
  /// Never send [scheduledAt] with `startNow: true`.
  Future<Map<String, dynamic>> createAndStart({
    required String title,
    String? coverUrl,
    String? categoryId,
    String mediaMode = 'VIDEO',
    String? topic,
  }) {
    return _api.post(
      ApiEndpoints.lives,
      body: {
        'title': title,
        'startNow': true,
        'mediaMode': mediaMode,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (categoryId != null) 'categoryId': categoryId,
        if (topic != null && topic.isNotEmpty) 'topic': topic,
      },
    );
  }

  /// `POST /lives` as `PLANNED`. Do not send `startNow: true`.
  Future<Map<String, dynamic>> createPlanned({
    required String title,
    required String scheduledAt,
    String? coverUrl,
    String? categoryId,
    String mediaMode = 'VIDEO',
    String? topic,
  }) {
    return _api.post(
      ApiEndpoints.lives,
      body: {
        'title': title,
        'startNow': false,
        'scheduledAt': scheduledAt,
        'mediaMode': mediaMode,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (categoryId != null) 'categoryId': categoryId,
        if (topic != null && topic.isNotEmpty) 'topic': topic,
      },
    );
  }

  Future<Map<String, dynamic>> end(String liveId) {
    return _api.post(ApiEndpoints.liveEnd(liveId));
  }

  /// `POST /lives/:id/pause` → `{ paused: true, pausedAt }`. Status stays `LIVE`.
  Future<Map<String, dynamic>> pause(String liveId) {
    return _api.post(ApiEndpoints.livePause(liveId));
  }

  /// `POST /lives/:id/resume` → `{ paused: false, pausedAt }`. Socket `livePaused`.
  Future<Map<String, dynamic>> resume(String liveId) {
    return _api.post(ApiEndpoints.liveResume(liveId));
  }

  /// `POST /lives/:id/start` → `{ live, token, url, role: "host" }`.
  Future<Map<String, dynamic>> start(String liveId) {
    return _api.post(ApiEndpoints.liveStart(liveId));
  }

  /// `POST /lives/:id/join` → `{ live, token, url, role, guest }`.
  Future<Map<String, dynamic>> join(String liveId) {
    return _api.post(ApiEndpoints.liveJoin(liveId));
  }

  /// `POST /lives/:id/leave` → `{ success, viewers }`.
  Future<Map<String, dynamic>> leave(String liveId) {
    return _api.post(ApiEndpoints.liveLeave(liveId));
  }

  /// `GET /lives/feed` → `{ data, meta }`.
  Future<Map<String, dynamic>> feed({
    int page = 1,
    int limit = 20,
    String? categoryId,
    bool followingOnly = false,
  }) {
    return _api.get(
      ApiEndpoints.livesFeed,
      auth: true,
      query: {
        'page': '$page',
        'limit': '$limit',
        if (categoryId != null) 'categoryId': categoryId,
        'followingOnly': '$followingOnly',
      },
    );
  }

  Future<Map<String, dynamic>> getById(String liveId) {
    return _api.get(ApiEndpoints.liveById(liveId));
  }

  /// `GET /lives/mine` → `{ data, meta }` (all statuses for the caller).
  Future<Map<String, dynamic>> mine({int page = 1, int limit = 20}) {
    return _api.get(
      ApiEndpoints.livesMine,
      query: {'page': '$page', 'limit': '$limit'},
    );
  }

  Future<Map<String, dynamic>> updateLive(
    String liveId, {
    String? title,
    String? coverUrl,
    String? topic,
  }) {
    return _api.patch(
      ApiEndpoints.liveById(liveId),
      body: {
        if (title != null) 'title': title,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (topic != null) 'topic': topic,
      },
    );
  }

  Future<Map<String, dynamic>> like(String liveId) {
    return _api.post(ApiEndpoints.liveLike(liveId));
  }

  /// `POST /lives/:id/share` → `{ shareUrl, deepLink, shareCount }`.
  Future<Map<String, dynamic>> share(String liveId, {String? channel}) {
    return _api.post(
      ApiEndpoints.liveShare(liveId),
      body: {if (channel != null && channel.isNotEmpty) 'channel': channel},
    );
  }

  Future<Map<String, dynamic>> sendComment({
    required String liveId,
    required String content,
  }) {
    return _api.post(
      ApiEndpoints.liveComments(liveId),
      body: {'content': content},
    );
  }

  Future<Map<String, dynamic>> listComments({
    required String liveId,
    int page = 1,
    int limit = 50,
  }) {
    return _api.get(
      ApiEndpoints.liveComments(liveId),
      query: {'page': '$page', 'limit': '$limit'},
    );
  }

  Future<Map<String, dynamic>> deleteComment({
    required String liveId,
    required String commentId,
  }) {
    return _api.delete(ApiEndpoints.liveCommentById(liveId, commentId));
  }

  Future<Map<String, dynamic>> pinComment({
    required String liveId,
    required String commentId,
  }) {
    return _api.post(ApiEndpoints.liveCommentPin(liveId, commentId));
  }

  Future<Map<String, dynamic>> unpinComment({
    required String liveId,
    required String commentId,
  }) {
    return _api.post(ApiEndpoints.liveCommentUnpin(liveId, commentId));
  }

  Future<Map<String, dynamic>> muteViewerChat({
    required String liveId,
    required String userId,
    String? reason,
  }) {
    return _api.post(
      ApiEndpoints.liveViewerMuteChat(liveId, userId),
      body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
  }

  Future<Map<String, dynamic>> unmuteViewerChat({
    required String liveId,
    required String userId,
  }) {
    return _api.post(ApiEndpoints.liveViewerUnmuteChat(liveId, userId));
  }

  Future<Map<String, dynamic>> banViewer({
    required String liveId,
    required String userId,
    String? reason,
  }) {
    return _api.post(
      ApiEndpoints.liveViewerBan(liveId, userId),
      body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
  }

  Future<Map<String, dynamic>> unbanViewer({
    required String liveId,
    required String userId,
  }) {
    return _api.post(ApiEndpoints.liveViewerUnban(liveId, userId));
  }

  Future<Map<String, dynamic>> updateChatRules({
    required String liveId,
    String? chatMode,
    int? slowModeSeconds,
    List<String>? blockedKeywords,
  }) {
    return _api.patch(
      ApiEndpoints.liveChatRules(liveId),
      body: {
        if (chatMode != null) 'chatMode': chatMode,
        if (slowModeSeconds != null) 'slowModeSeconds': slowModeSeconds,
        if (blockedKeywords != null) 'blockedKeywords': blockedKeywords,
      },
    );
  }

  Future<Map<String, dynamic>> listModerators(String liveId) {
    return _api.get(ApiEndpoints.liveModerators(liveId));
  }

  Future<Map<String, dynamic>> addModerator({
    required String liveId,
    required String userId,
  }) {
    return _api.post(
      ApiEndpoints.liveModerators(liveId),
      body: {'userId': userId},
    );
  }

  Future<Map<String, dynamic>> removeModerator({
    required String liveId,
    required String userId,
  }) {
    return _api.delete(ApiEndpoints.liveModeratorByUser(liveId, userId));
  }

  Future<Map<String, dynamic>> createHouse({required String title}) {
    return _api.post(ApiEndpoints.liveHouses, body: {'title': title});
  }

  Future<Map<String, dynamic>> listHouses() {
    return _api.get(ApiEndpoints.liveHouses);
  }

  Future<Map<String, dynamic>> getHouse(String houseId) {
    return _api.get(ApiEndpoints.liveHouseById(houseId));
  }

  Future<Map<String, dynamic>> attachLiveToHouse({
    required String houseId,
    required String liveId,
  }) {
    return _api.post(
      ApiEndpoints.liveHouseRooms(houseId),
      body: {'liveId': liveId},
    );
  }

  Future<Map<String, dynamic>> closeHouse(String houseId) {
    return _api.patch(ApiEndpoints.liveHouseById(houseId), body: {});
  }

  Future<Map<String, dynamic>> gallery(String liveId) {
    return _api.get(ApiEndpoints.liveGallery(liveId));
  }

  Future<Map<String, dynamic>> pinAuction({
    required String liveId,
    required String auctionId,
    required bool pinned,
  }) {
    return _api.patch(
      ApiEndpoints.liveAuctionPin(liveId, auctionId),
      body: {'pinned': pinned},
    );
  }

  Future<Map<String, dynamic>> reorderAuctions({
    required String liveId,
    required List<String> auctionIds,
  }) {
    return _api.patch(
      ApiEndpoints.liveAuctionsReorder(liveId),
      body: {'auctionIds': auctionIds},
    );
  }

  Future<Map<String, dynamic>> guests(String liveId) {
    return _api.get(ApiEndpoints.liveGuests(liveId));
  }

  Future<Map<String, dynamic>> inviteGuest({
    required String liveId,
    required String userId,
    String role = 'GUEST',
  }) {
    return _api.post(
      ApiEndpoints.liveGuestInvite(liveId),
      body: {'userId': userId, 'role': role},
    );
  }

  /// Invitee accepts their own invite → `{ guest, token, url, role }`.
  Future<Map<String, dynamic>> acceptGuestInvite(String liveId) {
    return _api.post(ApiEndpoints.liveGuestAcceptInvite(liveId));
  }

  /// Viewer asks to come on stage → `{ guest }`.
  Future<Map<String, dynamic>> requestGuestSeat(String liveId) {
    return _api.post(ApiEndpoints.liveGuestRequest(liveId));
  }

  /// Active guest steps off the stage.
  Future<Map<String, dynamic>> leaveGuestStage(String liveId) {
    return _api.post(ApiEndpoints.liveGuestLeave(liveId));
  }

  /// Fresh publish credentials after a requested guest is accepted.
  Future<Map<String, dynamic>> guestStageToken(String liveId) {
    return _api.post(ApiEndpoints.liveGuestToken(liveId));
  }

  Future<Map<String, dynamic>> acceptGuest({
    required String liveId,
    required String userId,
  }) {
    return _api.post(ApiEndpoints.liveGuestAccept(liveId, userId));
  }

  Future<Map<String, dynamic>> rejectGuest({
    required String liveId,
    required String userId,
  }) {
    return _api.post(ApiEndpoints.liveGuestReject(liveId, userId));
  }

  Future<Map<String, dynamic>> kickGuest({
    required String liveId,
    required String userId,
  }) {
    return _api.post(ApiEndpoints.liveGuestKick(liveId, userId));
  }

  Future<Map<String, dynamic>> muteGuest({
    required String liveId,
    required String userId,
  }) {
    return _api.post(ApiEndpoints.liveGuestMute(liveId, userId));
  }

  Future<Map<String, dynamic>> unmuteGuest({
    required String liveId,
    required String userId,
  }) {
    return _api.post(ApiEndpoints.liveGuestUnmute(liveId, userId));
  }

  Future<Map<String, dynamic>> guestCameraOff({
    required String liveId,
    required String userId,
  }) {
    return _api.post(ApiEndpoints.liveGuestCameraOff(liveId, userId));
  }

  Future<Map<String, dynamic>> guestCameraOn({
    required String liveId,
    required String userId,
  }) {
    return _api.post(ApiEndpoints.liveGuestCameraOn(liveId, userId));
  }

  Future<Map<String, dynamic>> promoteGuest({
    required String liveId,
    required String userId,
  }) {
    return _api.post(ApiEndpoints.liveGuestPromote(liveId, userId));
  }

  Future<Map<String, dynamic>> demoteGuest({
    required String liveId,
    required String userId,
  }) {
    return _api.post(ApiEndpoints.liveGuestDemote(liveId, userId));
  }

  Future<Map<String, dynamic>> battle(String liveId) {
    return _api.get(ApiEndpoints.liveBattle(liveId));
  }

  Future<Map<String, dynamic>> battleOpponents(
    String liveId, {
    int limit = 20,
  }) {
    return _api.get(
      ApiEndpoints.liveBattleOpponents(liveId),
      query: {'limit': '$limit'},
    );
  }

  /// `POST /lives/:id/battle`.
  ///
  /// Solo (1v1) stays the default: [mode] is only sent when the caller asked
  /// for TEAM. A 2v2 lobby opens with the two captains — teammate ids are
  /// optional, exactly as `lives/live-p1-parity.md` §7 describes.
  Future<Map<String, dynamic>> startBattle({
    required String liveId,
    required String opponentLiveId,
    int durationSeconds = 300,
    String? mode,
    String? scoringMode,
    String? scoringGiftId,
    int? bestOf,
    String? teammateLiveId,
    String? opponentTeammateLiveId,
  }) {
    if (bestOf != null && bestOf != 1 && bestOf != 3) {
      throw ArgumentError.value(bestOf, 'bestOf', 'Only 1 or 3 are documented.');
    }
    final wireMode = mode?.trim().toUpperCase();
    if (wireMode != null && wireMode != 'TEAM' && wireMode != 'SOLO') {
      throw ArgumentError.value(mode, 'mode', 'Only SOLO or TEAM.');
    }
    if (wireMode != 'TEAM' &&
        (teammateLiveId != null || opponentTeammateLiveId != null)) {
      throw ArgumentError('Teammates belong to a TEAM battle.');
    }
    return _api.post(
      ApiEndpoints.liveBattle(liveId),
      body: {
        'opponentLiveId': opponentLiveId,
        'durationSeconds': durationSeconds,
        if (wireMode != null) 'mode': wireMode,
        if (scoringMode != null && scoringMode.trim().isNotEmpty)
          'scoringMode': scoringMode.trim().toUpperCase(),
        if (scoringGiftId != null && scoringGiftId.trim().isNotEmpty)
          'scoringGiftId': scoringGiftId.trim(),
        if (bestOf != null) 'bestOf': bestOf,
        if (teammateLiveId != null && teammateLiveId.trim().isNotEmpty)
          'teammateLiveId': teammateLiveId.trim(),
        if (opponentTeammateLiveId != null &&
            opponentTeammateLiveId.trim().isNotEmpty)
          'opponentTeammateLiveId': opponentTeammateLiveId.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> matchBattle({
    required String liveId,
    int durationSeconds = 300,
    String? mode,
  }) {
    return _api.post(
      ApiEndpoints.liveBattleMatch(liveId),
      body: {
        'durationSeconds': durationSeconds,
        if (mode != null && mode.trim().isNotEmpty)
          'mode': mode.trim().toUpperCase(),
      },
    );
  }

  /// `GET /lives/:id/battle/open-teams` — lobbies with `openSlots`.
  Future<Map<String, dynamic>> battleOpenTeams(String liveId) {
    return _api.get(ApiEndpoints.liveBattleOpenTeams(liveId));
  }

  /// `POST /lives/:yourLiveId/battle/:battleId/join` `{ "team": 1 }`.
  /// Omitting [team] takes the first open slot, per the contract.
  Future<Map<String, dynamic>> joinBattleTeam({
    required String liveId,
    required String battleId,
    int? team,
  }) {
    if (team != null && team != 1 && team != 2) {
      throw ArgumentError.value(team, 'team', 'Teams are 1 or 2.');
    }
    return _api.post(
      ApiEndpoints.liveBattleJoin(liveId, battleId),
      body: {if (team != null) 'team': team},
    );
  }

  /// `POST /lives/:captainLiveId/battle/:battleId/invite`.
  Future<Map<String, dynamic>> inviteBattleTeammate({
    required String liveId,
    required String battleId,
    required String teammateLiveId,
  }) {
    if (teammateLiveId.trim().isEmpty) {
      throw ArgumentError('A teammate live id is required.');
    }
    return _api.post(
      ApiEndpoints.liveBattleInvite(liveId, battleId),
      body: {'teammateLiveId': teammateLiveId.trim()},
    );
  }

  /// `POST /lives/:teammateLiveId/battle/:battleId/leave` — teammates only;
  /// a captain ends the battle instead.
  Future<Map<String, dynamic>> leaveBattleTeam({
    required String liveId,
    required String battleId,
  }) {
    return _api.post(ApiEndpoints.liveBattleLeave(liveId, battleId));
  }

  /// `POST /lives/:id/battle/:battleId/power-up` `{ "type": "GLOVE" }`.
  Future<Map<String, dynamic>> battlePowerUp({
    required String liveId,
    required String battleId,
    required String type,
  }) {
    final wire = type.trim().toUpperCase();
    if (!LiveBattlePowerUpType.isDocumented(wire)) {
      throw ArgumentError.value(type, 'type', 'STUN, TIME or GLOVE only.');
    }
    return _api.post(
      ApiEndpoints.liveBattlePowerUp(liveId, battleId),
      body: {'type': wire},
    );
  }

  Future<Map<String, dynamic>> activateBattleMultiplier({
    required String liveId,
    required double multiplier,
    required int durationSeconds,
  }) {
    return _api.post(
      ApiEndpoints.liveBattleMultiplier(liveId),
      body: {'multiplier': multiplier, 'durationSeconds': durationSeconds},
    );
  }

  Future<Map<String, dynamic>> endBattle({
    required String liveId,
    required String battleId,
  }) {
    return _api.post(ApiEndpoints.liveBattleEnd(liveId, battleId));
  }

  // ── Multi-room co-host (lives/live-p1-parity.md §6, p2 §2) ──

  /// `GET /lives/:id/cohost/hosts` — hosts that still have a free slot.
  Future<Map<String, dynamic>> cohostHosts(String liveId) {
    return _api.get(ApiEndpoints.liveCohostHosts(liveId));
  }

  /// `GET /lives/:id/cohost` — this room's sessions.
  Future<Map<String, dynamic>> cohostSessions(String liveId) {
    return _api.get(ApiEndpoints.liveCohost(liveId));
  }

  /// `POST /lives/:id/cohost/invite` `{ "guestLiveId": "…" }`.
  Future<Map<String, dynamic>> inviteCohost({
    required String liveId,
    required String guestLiveId,
  }) {
    if (guestLiveId.trim().isEmpty) {
      throw ArgumentError('A partner live id is required.');
    }
    return _api.post(
      ApiEndpoints.liveCohostInvite(liveId),
      body: {'guestLiveId': guestLiveId.trim()},
    );
  }

  /// `POST /lives/:id/cohost/:sessionId/accept`.
  Future<Map<String, dynamic>> acceptCohost({
    required String liveId,
    required String sessionId,
  }) {
    if (sessionId.trim().isEmpty) {
      throw ArgumentError('A co-host session id is required.');
    }
    return _api.post(ApiEndpoints.liveCohostAccept(liveId, sessionId.trim()));
  }

  /// `POST /lives/:id/cohost/:sessionId/end`.
  Future<Map<String, dynamic>> endCohost({
    required String liveId,
    required String sessionId,
  }) {
    if (sessionId.trim().isEmpty) {
      throw ArgumentError('A co-host session id is required.');
    }
    return _api.post(ApiEndpoints.liveCohostEnd(liveId, sessionId.trim()));
  }

  Future<Map<String, dynamic>> hourlyLeaderboard(String liveId) {
    return _api.get(ApiEndpoints.liveHourlyLeaderboard(liveId));
  }

  Future<Map<String, dynamic>> globalHourlyLeaderboard({int limit = 20}) {
    return _api.get(
      ApiEndpoints.livesHourlyLeaderboard,
      query: {'limit': '$limit'},
    );
  }

  Future<Map<String, dynamic>> viewers(
    String liveId, {
    int page = 1,
    int limit = 50,
    bool activeOnly = true,
  }) {
    return _api.get(
      ApiEndpoints.liveViewers(liveId),
      query: {'page': '$page', 'limit': '$limit', 'activeOnly': '$activeOnly'},
    );
  }

  /// `GET /lives/leagues` → `{ tiers: [...] }`.
  /// `GET /lives/:id/replay` — plays the replay and counts one replay view.
  /// The count is the server's; the app never increments it.
  Future<Map<String, dynamic>> replay(String liveId) {
    return _api.get(ApiEndpoints.liveReplay(_seg(liveId)));
  }

  /// `POST /lives/:id/replay` — host fallback when auto-record failed.
  Future<Map<String, dynamic>> publishReplay({
    required String liveId,
    required String replayUrl,
  }) {
    return _api.post(
      ApiEndpoints.liveReplay(_seg(liveId)),
      body: {'replayUrl': replayUrl},
    );
  }

  /// `DELETE /lives/:id/replay` — host takedown.
  Future<Map<String, dynamic>> deleteReplay(String liveId) {
    return _api.delete(ApiEndpoints.liveReplay(_seg(liveId)));
  }

  /// `GET /lives/:id/clips`.
  Future<Map<String, dynamic>> clips(String liveId) {
    return _api.get(ApiEndpoints.liveClips(_seg(liveId)));
  }

  /// `POST /lives/:id/clips` — needs a READY replay (the server enforces it).
  Future<Map<String, dynamic>> createClip({
    required String liveId,
    required num startSeconds,
    required num endSeconds,
    String? title,
    String? clipUrl,
  }) {
    return _api.post(
      ApiEndpoints.liveClips(_seg(liveId)),
      body: {
        'startSeconds': startSeconds,
        'endSeconds': endSeconds,
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        if (clipUrl != null && clipUrl.trim().isNotEmpty)
          'clipUrl': clipUrl.trim(),
      },
    );
  }

  /// `POST /lives/:id/clips/:clipId/post` — idempotent per the contract.
  Future<Map<String, dynamic>> postClip({
    required String liveId,
    required String clipId,
    String? description,
  }) {
    return _api.post(
      ApiEndpoints.liveClipPost(_seg(liveId), _seg(clipId)),
      body: {
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );
  }

  static String _seg(String value) => Uri.encodeComponent(value);

  Future<Map<String, dynamic>> leagues() {
    return _api.get(ApiEndpoints.livesLeagues);
  }

  /// `GET /lives/host-league/:userId` → tier + progress for one creator.
  Future<Map<String, dynamic>> hostLeague(String userId) {
    return _api.get(ApiEndpoints.liveHostLeague(Uri.encodeComponent(userId)));
  }

  Future<Map<String, dynamic>> giftersLeaderboard(
    String liveId, {
    String window = 'hour',
  }) {
    return _api.get(
      ApiEndpoints.liveGiftersLeaderboard(liveId),
      query: {'window': window},
    );
  }

  Future<Map<String, dynamic>> updateSettings(
    String liveId, {
    bool? guestsEnabled,
    String? guestRequestMode,
    int? maxGuests,
    String? layout,
    bool? allowGuestCamera,
    bool? moderatorsCanManageGuests,
    String? topic,
    bool? ageRestricted,
    bool? ticketEnabled,
    int? ticketPriceCoins,
  }) {
    return _api.patch(
      ApiEndpoints.liveSettings(liveId),
      body: {
        if (guestsEnabled != null) 'guestsEnabled': guestsEnabled,
        if (guestRequestMode != null) 'guestRequestMode': guestRequestMode,
        if (maxGuests != null) 'maxGuests': maxGuests,
        if (layout != null) 'layout': layout,
        if (allowGuestCamera != null) 'allowGuestCamera': allowGuestCamera,
        if (moderatorsCanManageGuests != null)
          'moderatorsCanManageGuests': moderatorsCanManageGuests,
        if (topic != null) 'topic': topic,
        if (ageRestricted != null) 'ageRestricted': ageRestricted,
        if (ticketEnabled != null) 'ticketEnabled': ticketEnabled,
        if (ticketPriceCoins != null) 'ticketPriceCoins': ticketPriceCoins,
      },
    );
  }

  /// `GET /lives/:id/studio` — host-only RTMP / recording. Null Ingress is OK.
  Future<Map<String, dynamic>> studio(String liveId) {
    return _api.get(ApiEndpoints.liveStudio(liveId), auth: true);
  }

  /// `PATCH /lives/:id/scene` — persist CAMERA/SCREEN/DUAL + facing.
  Future<Map<String, dynamic>> updateScene(
    String liveId, {
    required String scene,
    required String cameraFacing,
    required bool dualCameraEnabled,
  }) {
    return _api.patch(
      ApiEndpoints.liveScene(liveId),
      body: {
        'scene': scene,
        'cameraFacing': cameraFacing,
        'dualCameraEnabled': dualCameraEnabled,
      },
    );
  }
}
