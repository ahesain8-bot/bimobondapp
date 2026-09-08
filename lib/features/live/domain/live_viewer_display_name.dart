/// Resolves a LIVE viewer display name from a socket/API user object.
///
/// Order matches the rest of LIVE chat/gifts: [fullName], then
/// [displayName] / [name], then [username]. Returns null when nothing real
/// is present so UI can apply a localized fallback.
String? liveViewerDisplayNameFrom(Map<String, dynamic>? user) {
  if (user == null) return null;
  const keys = ['fullName', 'displayName', 'name', 'username'];
  for (final key in keys) {
    final value = user[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

/// Host skips the host's own join; a viewer skips their own join.
bool shouldInsertLiveJoinSystemMessage({
  required String joinerId,
  required String skipUserId,
}) {
  return joinerId.isNotEmpty && joinerId != skipUserId;
}
