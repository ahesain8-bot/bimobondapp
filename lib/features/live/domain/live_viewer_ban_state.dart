import 'entities/live_viewer.dart';

/// Applies a LIVE-specific viewer ban/unban to the host's known banned set.
///
/// Empty ids are ignored so a malformed `liveModeration` payload cannot
/// wipe or poison the roster actions.
Set<String> applyLiveViewerBanState({
  required Set<String> current,
  required String? userId,
  required bool banned,
}) {
  final id = userId?.trim() ?? '';
  if (id.isEmpty) return current;
  final next = Set<String>.from(current);
  if (banned) {
    next.add(id);
  } else {
    next.remove(id);
  }
  return next;
}

/// Keeps a display name for a banned viewer so Unban stays labeled after
/// they drop off `GET /lives/:id/viewers`.
Map<String, String> applyLiveViewerBanName({
  required Map<String, String> current,
  required String? userId,
  required bool banned,
  String? displayName,
}) {
  final id = userId?.trim() ?? '';
  if (id.isEmpty) return current;
  if (!banned) {
    if (!current.containsKey(id)) return current;
    final next = Map<String, String>.from(current)..remove(id);
    return next;
  }
  final name = displayName?.trim() ?? '';
  if (name.isEmpty) return current;
  if (current[id] == name) return current;
  return {...current, id: name};
}

bool isLiveViewerBanned(Set<String> bannedUserIds, String? userId) {
  final id = userId?.trim() ?? '';
  return id.isNotEmpty && bannedUserIds.contains(id);
}

/// Roster rows the host can Ban/Unban: real viewer ids, never the host,
/// plus banned people who already left the active viewers list.
List<LiveViewer> liveRoomPeopleRosterForModeration({
  required List<LiveViewer> roster,
  required String hostId,
  required Set<String> bannedUserIds,
  Map<String, String> bannedViewerNames = const {},
  String fallbackName = 'مشاهد',
}) {
  final seen = <String>{};
  final rows = <LiveViewer>[];
  for (final viewer in roster) {
    final id = viewer.userId.trim();
    if (id.isEmpty || id == hostId || seen.contains(id)) continue;
    seen.add(id);
    rows.add(viewer);
  }
  for (final id in bannedUserIds) {
    final trimmed = id.trim();
    if (trimmed.isEmpty || trimmed == hostId || seen.contains(trimmed)) {
      continue;
    }
    seen.add(trimmed);
    final name = bannedViewerNames[trimmed]?.trim();
    rows.add(
      LiveViewer(
        userId: trimmed,
        displayName: (name != null && name.isNotEmpty) ? name : fallbackName,
        isActive: false,
      ),
    );
  }
  return rows;
}
