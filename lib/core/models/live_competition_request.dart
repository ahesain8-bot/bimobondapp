/// The exact chat payload used as a lightweight signal when an active guest
/// asks the host to start a server-backed PK match.
///
/// The current LIVE API only lets the owner create a battle, while comments
/// are broadcast to everyone in the room. Keeping one shared value prevents
/// the viewer and host implementations from silently drifting apart.
const String liveCompetitionRequestContent = '⚔️ أطلب بدء جولة منافسة';

bool isLiveCompetitionRequest(String? content) =>
    content?.trim() == liveCompetitionRequestContent;

/// A competition decision waiting for the host.
class LiveCompetitionRequest {
  const LiveCompetitionRequest({
    required this.commentId,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
  });

  final String commentId;
  final String userId;
  final String displayName;
  final String? avatarUrl;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiveCompetitionRequest &&
          other.commentId == commentId &&
          other.userId == userId &&
          other.displayName == displayName &&
          other.avatarUrl == avatarUrl;

  @override
  int get hashCode => Object.hash(commentId, userId, displayName, avatarUrl);
}
