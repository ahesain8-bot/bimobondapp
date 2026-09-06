/// Host-only LIVE Studio / OBS credentials (`GET /lives/:id/studio`,
/// `lives/live-p1-parity.md`).
///
/// Missing Ingress leaves [rtmpUrl] / [streamKey] null. That must not fail
/// a normal camera live start.
class LiveStudio {
  const LiveStudio({
    this.rtmpUrl,
    this.streamKey,
    this.ingressId,
    this.recordingStatus,
    this.egressId,
    this.autoRecord = false,
    this.canPublishScreen = false,
  });

  final String? rtmpUrl;
  final String? streamKey;
  final String? ingressId;
  final String? recordingStatus;
  final String? egressId;
  final bool autoRecord;
  final bool canPublishScreen;

  bool get hasRtmpCredentials =>
      (rtmpUrl != null && rtmpUrl!.trim().isNotEmpty) &&
      (streamKey != null && streamKey!.trim().isNotEmpty);

  static LiveStudio? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final map = raw.map((key, value) => MapEntry(key.toString(), value));
    final recording = _asMap(map['recording']);
    final screenShare = _asMap(map['screenShare']);
    return LiveStudio(
      rtmpUrl: map['rtmpUrl']?.toString(),
      streamKey: map['streamKey']?.toString() ?? map['rtmpStreamKey']?.toString(),
      ingressId: map['ingressId']?.toString(),
      recordingStatus: recording?['status']?.toString(),
      egressId: recording?['egressId']?.toString(),
      autoRecord: recording?['autoRecord'] == true,
      canPublishScreen: screenShare?['canPublish'] == true,
    );
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is! Map) return null;
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
}
