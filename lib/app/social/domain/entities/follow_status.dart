enum FollowStatus {
  followed,
  unfollowed;

  static FollowStatus fromApi(String? value) {
    switch (value?.toLowerCase()) {
      case 'followed':
      case 'following':
      case 'true':
        return FollowStatus.followed;
      case 'unfollowed':
      case 'not_following':
      case 'false':
        return FollowStatus.unfollowed;
      default:
        return FollowStatus.unfollowed;
    }
  }

  static FollowStatus fromResponse(Map<String, dynamic> data) {
    final status = data['status']?.toString();
    if (status != null && status.isNotEmpty) {
      return fromApi(status);
    }

    final isFollowing =
        data['isFollowing'] ?? data['isFollowed'] ?? data['following'];
    if (isFollowing is bool) {
      return isFollowing ? FollowStatus.followed : FollowStatus.unfollowed;
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
