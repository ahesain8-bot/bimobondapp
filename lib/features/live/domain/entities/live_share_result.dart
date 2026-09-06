/// Analytics `channel` values for `POST /lives/:id/share`.
class LiveShareChannel {
  const LiveShareChannel._();

  static const copyLink = 'COPY_LINK';
  static const external = 'EXTERNAL';
  static const messages = 'MESSAGES';
  static const story = 'STORY';
}

/// Host/viewer result of `POST /lives/:id/share`
/// (`lives/enhanced-live-performance.md` §6).
class LiveShareResult {
  const LiveShareResult({
    required this.liveId,
    this.shareUrl,
    this.deepLink,
    this.shareCount = 0,
    this.title,
  });

  final String liveId;
  final String? shareUrl;
  final String? deepLink;
  final int shareCount;
  final String? title;

  static LiveShareResult fromJson(Map<String, dynamic> json, {String? liveId}) {
    final count = json['shareCount'];
    return LiveShareResult(
      liveId: json['liveId']?.toString() ?? liveId ?? '',
      shareUrl: json['shareUrl']?.toString(),
      deepLink: json['deepLink']?.toString(),
      shareCount: count is int
          ? count
          : count is num
          ? count.toInt()
          : int.tryParse(count?.toString() ?? '') ?? 0,
      title: json['title']?.toString(),
    );
  }
}
