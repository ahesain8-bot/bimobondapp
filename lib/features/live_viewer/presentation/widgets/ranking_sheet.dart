import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/utils/extensions.dart';
import '../../domain/entities/hourly_ranking_entity.dart';
import '../bloc/hourly_ranking/hourly_ranking_bloc.dart';
import '../bloc/hourly_ranking/hourly_ranking_event.dart';
import '../bloc/hourly_ranking/hourly_ranking_state.dart';
import '../di/live_viewer_injector.dart' as di;
import 'fallback_media.dart';
import 'fan_club_widgets.dart';

/// Row model for the league overlay, which has no backend endpoint yet
/// (`GET /lives/leagues` + `/lives/host-league/:userId` are not wired).
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

/// Opens the hourly ranking sheet for [liveId], backed by
/// `GET /lives/leaderboard/hourly` and `GET /lives/:id/leaderboard/hourly`.
Future<void> showHourlyRankingSheet(
  BuildContext context, {
  required String liveId,
  required String hostName,
  required String? hostAvatar,
  VoidCallback? onJoinFanClub,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => BlocProvider<HourlyRankingBloc>(
      create: (_) =>
          di.sl<HourlyRankingBloc>()
            ..add(HourlyRankingRequested(liveId: liveId)),
      child: HourlyRankingSheet(
        hostName: hostName,
        hostAvatar: hostAvatar,
        onJoinFanClub: onJoinFanClub,
      ),
    ),
  );
}

/// Hourly ranking / Trending stream bottom sheet.
class HourlyRankingSheet extends StatelessWidget {
  final String hostName;
  final String? hostAvatar;
  final VoidCallback? onJoinFanClub;

  const HourlyRankingSheet({
    super.key,
    required this.hostName,
    this.hostAvatar,
    this.onJoinFanClub,
  });

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.72;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: BlocBuilder<HourlyRankingBloc, HourlyRankingState>(
        builder: (context, state) {
          final bloc = context.read<HourlyRankingBloc>();
          return Column(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
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
                      selected: state.tab == HourlyRankingTab.trending,
                      onTap: () => bloc.add(
                        const HourlyRankingTabChanged(
                          HourlyRankingTab.trending,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _TabLabel(
                      label: 'Hourly Ranking',
                      selected: state.tab == HourlyRankingTab.hourly,
                      onTap: () => bloc.add(
                        const HourlyRankingTabChanged(HourlyRankingTab.hourly),
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.videocam_outlined,
                      size: 16,
                      color: Colors.black45,
                    ),
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
                    _RankingRecordChip(rank: state.liveRank?.rank),
                    const Spacer(),
                    _NextUpdateLabel(windowEndsAt: state.windowEndsAt),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: state.isLoading
                          ? null
                          : () =>
                                bloc.add(const HourlyRankingRefreshRequested()),
                      behavior: HitTestBehavior.opaque,
                      child: Icon(
                        Icons.refresh,
                        size: 16,
                        color: state.isLoading
                            ? Colors.black26
                            : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _RankingBody(state: state)),
              FanClubBottomBar(
                hostName: hostName,
                hostAvatar: hostAvatar,
                onJoin: () {
                  Navigator.pop(context);
                  onJoinFanClub?.call();
                },
              ),
            ],
          );
        },
      ),
    ).animate().slideY(begin: 0.12, end: 0, duration: 240.ms);
  }
}

/// Loading / error / empty / list switch for the selected tab.
class _RankingBody extends StatelessWidget {
  const _RankingBody({required this.state});

  final HourlyRankingState state;

  @override
  Widget build(BuildContext context) {
    final entries = state.visibleEntries;

    if (state.isLoading && entries.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }

    final error = state.error;
    if (error != null && entries.isEmpty) {
      return _RankingMessage(
        icon: Icons.wifi_off_rounded,
        message: error.message,
        actionLabel: 'Try again',
        onAction: () => context.read<HourlyRankingBloc>().add(
          const HourlyRankingRefreshRequested(),
        ),
      );
    }

    if (entries.isEmpty) {
      return _RankingMessage(
        icon: Icons.emoji_events_outlined,
        message: state.tab == HourlyRankingTab.trending
            ? 'No trending creators this hour yet.'
            : 'No ranking for this hour yet.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: entries.length,
      itemBuilder: (context, i) => _RankingRow(entry: entries[i]),
    );
  }
}

class _RankingMessage extends StatelessWidget {
  const _RankingMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 34, color: Colors.black26),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Ranking record" chip — shows this stream's real rank once the backend
/// reports one, and stays a plain label while it is unranked this hour.
class _RankingRecordChip extends StatelessWidget {
  const _RankingRecordChip({this.rank});

  final int? rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3D6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite, size: 12, color: Color(0xFFFF8A00)),
          const SizedBox(width: 4),
          Text(
            rank != null ? 'Ranking record · No.$rank' : 'Ranking record',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8A5A00),
            ),
          ),
        ],
      ),
    );
  }
}

/// Counts down to the backend `windowEndsAt`. Renders nothing when the backend
/// did not send a window, rather than inventing a reset time.
class _NextUpdateLabel extends StatefulWidget {
  const _NextUpdateLabel({required this.windowEndsAt});

  final DateTime? windowEndsAt;

  @override
  State<_NextUpdateLabel> createState() => _NextUpdateLabelState();
}

class _NextUpdateLabelState extends State<_NextUpdateLabel> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant _NextUpdateLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.windowEndsAt != widget.windowEndsAt) _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker() {
    _ticker?.cancel();
    if (widget.windowEndsAt == null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final endsAt = widget.windowEndsAt;
    if (endsAt == null) return const SizedBox.shrink();

    final remaining = endsAt.difference(DateTime.now());
    if (remaining.isNegative) {
      return const Row(
        children: [
          Icon(Icons.schedule, size: 14, color: Colors.black45),
          SizedBox(width: 4),
          Text(
            'Updating…',
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      );
    }

    final hours = remaining.inHours.toString().padLeft(2, '0');
    final minutes = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Row(
      children: [
        const Icon(Icons.schedule, size: 14, color: Colors.black45),
        const SizedBox(width: 4),
        Text(
          'Next update: $hours:$minutes:$seconds',
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
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

/// Hosts whose avatar the backend left out still need a face in the list, so
/// the seeded fallback stands in rather than an empty image request.
class _HostAvatar extends StatelessWidget {
  const _HostAvatar({required this.entry});

  final HourlyRankingEntry entry;

  @override
  Widget build(BuildContext context) {
    final fallback = FallbackAvatar(
      seed: entry.hostId.isEmpty ? entry.liveId : entry.hostId,
      name: entry.hostName,
      radius: 22,
    );

    final url = entry.hostAvatarUrl;
    if (url == null || url.isEmpty) return fallback;

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }
}

class _RankingRow extends StatelessWidget {
  final HourlyRankingEntry entry;

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

  /// Second line: the host's league tier and current viewers when the backend
  /// sends them, otherwise the stream title.
  String? get _subtitle {
    final parts = <String>[
      if (entry.hostLeagueTier != null) 'League ${entry.hostLeagueTier}',
      if (entry.viewers > 0) '${entry.viewers.formatNumber} watching',
    ];
    if (parts.isNotEmpty) return parts.join(' · ');
    return entry.title;
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _subtitle;

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
              // Every row of this leaderboard is a stream that is live now.
              border: Border.all(color: const Color(0xFFFF2D55), width: 2.5),
            ),
            child: ClipOval(child: _HostAvatar(entry: entry)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.hostName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
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
