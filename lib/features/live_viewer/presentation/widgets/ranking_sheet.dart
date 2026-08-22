import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/utils/extensions.dart';
import 'fallback_media.dart';
import 'fan_club_widgets.dart';

class RankingEntry {
  final int rank;
  final String userId;
  final String username;
  final String? subtitle;
  final String? avatarUrl;
  final int score;
  final bool isLive;

  const RankingEntry({
    required this.rank,
    required this.userId,
    required this.username,
    this.subtitle,
    this.avatarUrl,
    required this.score,
    this.isLive = false,
  });
}

Future<void> showHourlyRankingSheet(
  BuildContext context, {
  required String hostName,
  required String? hostAvatar,
  required List<RankingEntry> entries,
  VoidCallback? onJoinFanClub,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => HourlyRankingSheet(
      hostName: hostName,
      hostAvatar: hostAvatar,
      entries: entries,
      onJoinFanClub: onJoinFanClub,
    ),
  );
}

/// Hourly ranking / Trending stream bottom sheet.
class HourlyRankingSheet extends StatefulWidget {
  final String hostName;
  final String? hostAvatar;
  final List<RankingEntry> entries;
  final VoidCallback? onJoinFanClub;

  const HourlyRankingSheet({
    super.key,
    required this.hostName,
    this.hostAvatar,
    required this.entries,
    this.onJoinFanClub,
  });

  @override
  State<HourlyRankingSheet> createState() => _HourlyRankingSheetState();
}

class _HourlyRankingSheetState extends State<HourlyRankingSheet> {
  int _tab = 0; // 0 trending, 1 hourly

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.72;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          // League promo banner (screenshot)
          Container(
            margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: const Color(0xFF1A0A2E),
            child: const Row(
              children: [
                Text('💎', style: TextStyle(fontSize: 22)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Discover creators like you in the league',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.white54, size: 18),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _TabLabel(
                  label: 'Trending',
                  selected: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
              ),
              Expanded(
                child: _TabLabel(
                  label: 'Hourly Ranking',
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.videocam_outlined, size: 16, color: Colors.black45),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Top 10 creators appear in search results in real time.',
                    style: TextStyle(fontSize: 11.5, color: Colors.black54),
                  ),
                ),
                Icon(Icons.chevron_left, size: 18, color: Colors.black38),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3D6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.favorite, size: 12, color: Color(0xFFFF8A00)),
                      SizedBox(width: 4),
                      Text(
                        'Ranking record',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF8A5A00),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Icon(Icons.schedule, size: 14, color: Colors.black45),
                const SizedBox(width: 4),
                const Text(
                  'Next update: 08:09:42',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.info_outline, size: 14, color: Colors.black38),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: widget.entries.length,
              itemBuilder: (context, i) =>
                  _RankingRow(entry: widget.entries[i]),
            ),
          ),
          FanClubBottomBar(
            hostName: widget.hostName,
            hostAvatar: widget.hostAvatar,
            onJoin: () {
              Navigator.pop(context);
              widget.onJoinFanClub?.call();
            },
          ),
        ],
      ),
    ).animate().slideY(begin: 0.12, end: 0, duration: 240.ms);
  }
}

class _TabLabel extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabLabel({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? Colors.black87 : Colors.black38,
              ),
            ),
          ),
          Container(
            height: 3,
            width: 48,
            decoration: BoxDecoration(
              color: selected ? Colors.black87 : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  final RankingEntry entry;

  const _RankingRow({required this.entry});

  Color get _rankColor {
    switch (entry.rank) {
      case 1:
        return const Color(0xFFFFC107);
      case 2:
        return const Color(0xFF4A90E2);
      case 3:
        return const Color(0xFFFF8A65);
      default:
        return const Color(0xFFE0E0E0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: entry.rank <= 3 ? _rankColor : Colors.transparent,
              shape: BoxShape.circle,
              border: entry.rank > 3
                  ? null
                  : Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1,
                    ),
              boxShadow: entry.rank <= 3
                  ? [
                      BoxShadow(
                        color: _rankColor.withValues(alpha: 0.45),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              '${entry.rank}',
              style: TextStyle(
                color: entry.rank <= 3 ? Colors.white : Colors.black45,
                fontWeight: FontWeight.w800,
                fontSize: entry.rank <= 3 ? 13 : 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: entry.isLive
                  ? Border.all(color: const Color(0xFFFF2D55), width: 2.5)
                  : (entry.rank <= 3
                        ? Border.all(color: const Color(0xFFFF2D55), width: 2)
                        : null),
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: entry.avatarUrl ?? '',
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => FallbackAvatar(
                  seed: entry.userId,
                  name: entry.username,
                  radius: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                if (entry.subtitle != null)
                  Text(
                    entry.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Colors.black45,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            entry.score.formatNumber,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
