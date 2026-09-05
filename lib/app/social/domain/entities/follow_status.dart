enum FollowStatus {
  followed,
  unfollowed;

  static const _followedTokens = {
    'followed',
    'following',
    'true',
    '1',
    'friends',
    'friend',
    'mutual',
  };

  static const _unfollowedTokens = {
    'unfollowed',
    'not_following',
    'false',
    '0',
  };

  static FollowStatus fromApi(String? value) {
    final token = value?.toLowerCase().trim();
    if (token == null || token.isEmpty) return FollowStatus.unfollowed;
    if (_followedTokens.contains(token)) return FollowStatus.followed;
    if (_unfollowedTokens.contains(token)) return FollowStatus.unfollowed;
    return FollowStatus.unfollowed;
  }

  static bool _isKnownFollowToken(String? value) {
    final token = value?.toLowerCase().trim();
    if (token == null || token.isEmpty) return false;
    return _followedTokens.contains(token) || _unfollowedTokens.contains(token);
  }

  static bool? _parseExplicitFollowing(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      if (!_isKnownFollowToken(value)) return null;
      return fromApi(value) == FollowStatus.followed;
    }
    return null;
  }

  static FollowStatus fromResponse(Map<String, dynamic> data) {
    // Prefer explicit relationship fields. Never treat generic envelope
    // values like status:"success" / status:"ok" as unfollow.
    final explicit = _parseExplicitFollowing(
      data['isFollowing'] ??
          data['isFollowed'] ??
          data['viewerIsFollowing'] ??
          data['youFollow'] ??
          data['followedByMe'] ??
          data['amIFollowing'] ??
          data['iFollow'],
    );
    if (explicit != null) {
      return explicit ? FollowStatus.followed : FollowStatus.unfollowed;
    }

    if (data['isFriend'] == true ||
        data['isMutual'] == true ||
        _parseExplicitFollowing(data['friendshipStatus']) == true) {
      return FollowStatus.followed;
    }

    // Some APIs use `following: true` on follow-status (not a count).
    final followingField = data['following'];
    if (followingField is bool) {
      return followingField ? FollowStatus.followed : FollowStatus.unfollowed;
    }
    if (followingField is String && _isKnownFollowToken(followingField)) {
      return fromApi(followingField);
    }

    final status = data['status']?.toString();
    if (_isKnownFollowToken(status)) {
      return fromApi(status);
    }

    return FollowStatus.unfollowed;
  }

  /// Maps a toggle API result to the next follow state.
  /// When the API omits follow status, keeps the optimistic toggle result.
  static bool resolveIsFollowing({
    required bool wasFollowing,
    required FollowStatus status,
  }) {
    if (status == FollowStatus.followed) return true;
    if (status == FollowStatus.unfollowed && wasFollowing) return false;
    return !wasFollowing;
  }
}
