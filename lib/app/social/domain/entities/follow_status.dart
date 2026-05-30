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

    final isFollowing = data['isFollowing'] ?? data['isFollowed'] ?? data['following'];
    if (isFollowing is bool) {
      return isFollowing ? FollowStatus.followed : FollowStatus.unfollowed;
    }

    return FollowStatus.unfollowed;
  }
}
