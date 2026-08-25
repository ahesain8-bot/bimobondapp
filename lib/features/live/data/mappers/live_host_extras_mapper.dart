import '../../domain/entities/live_gallery_item.dart';
import '../../domain/entities/live_guest.dart';
import '../../domain/entities/live_host.dart';
import '../../domain/entities/live_leaderboard_entry.dart';
import '../../domain/entities/live_viewer.dart';

/// Maps guest / leaderboard / gallery JSON from lives/mobile-api.md.
class LiveHostExtrasMapper {
  const LiveHostExtrasMapper._();

  static LiveGuest guestFromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return LiveGuest(
      id: json['id']?.toString() ?? '',
      liveId: json['liveId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? user?['id']?.toString() ?? '',
      role: json['role']?.toString() ?? 'GUEST',
      status: json['status']?.toString() ?? '',
      mutedByHost: json['mutedByHost'] == true,
      cameraOffByHost: json['cameraOffByHost'] == true,
      displayName: user?['fullName']?.toString() ??
          user?['username']?.toString() ??
          'Guest',
      avatarUrl: user?['avatarUrl']?.toString(),
      username: user?['username']?.toString(),
    );
  }

  static LiveLeaderboardEntry leaderboardEntryFromJson(
    Map<String, dynamic> json, {
    int? fallbackRank,
  }) {
    final user = json['user'] as Map<String, dynamic>?;
    final host = user == null
        ? null
        : LiveHost(
            id: user['id']?.toString() ?? '',
            displayName: user['fullName']?.toString() ??
                user['username']?.toString() ??
                'Host',
            avatarUrl: user['avatarUrl']?.toString(),
            username: user['username']?.toString(),
            isVerified: user['isVerified'] == true,
          );
    return LiveLeaderboardEntry(
      rank: _asInt(json['hourlyRank'] ?? json['rank']) ?? fallbackRank,
      score: _asInt(json['hourlyScore'] ?? json['score']),
      coins: _asInt(json['hourlyCoins'] ?? json['coins'] ?? json['totalCoins']),
      liveId: json['liveId']?.toString() ?? json['id']?.toString(),
      title: json['title']?.toString(),
      viewers: _asInt(json['viewers']),
      host: host,
      userId: json['userId']?.toString() ?? user?['id']?.toString(),
      displayName: host?.displayName ??
          json['username']?.toString() ??
          json['fullName']?.toString(),
      avatarUrl: host?.avatarUrl ?? json['avatarUrl']?.toString(),
    );
  }

  static LiveGalleryItem galleryItemFromJson(Map<String, dynamic> json) {
    return LiveGalleryItem(
      id: json['id']?.toString() ??
          json['auctionId']?.toString() ??
          '',
      itemName: json['itemName']?.toString() ??
          json['title']?.toString() ??
          'عنصر',
      itemImageUrl:
          json['itemImageUrl']?.toString() ?? json['imageUrl']?.toString(),
      pinned: json['pinned'] == true,
      status: json['status']?.toString(),
      targetPrice: _asNum(json['targetPrice']),
      currentPrice: _asNum(json['currentPrice'] ?? json['startingPrice']),
    );
  }

  static LiveViewer viewerFromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final fullName = user?['fullName']?.toString();
    final handle = user?['username']?.toString();
    return LiveViewer(
      userId: user?['id']?.toString() ?? json['userId']?.toString() ?? '',
      displayName: (fullName != null && fullName.trim().isNotEmpty)
          ? fullName.trim()
          : (handle ?? 'مشاهد'),
      username: handle,
      avatarUrl: user?['avatarUrl']?.toString(),
      isVerified: user?['isVerified'] == true,
      gifterLevel: _asInt(user?['gifterLevel']),
      isActive: json['leftAt'] == null,
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static num? _asNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString());
  }
}
