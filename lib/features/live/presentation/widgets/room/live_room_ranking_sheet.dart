import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/live_leaderboard_entry.dart';
import '../../../domain/repositories/live_session_repository.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_state.dart';
import 'live_room_host_sheet_chrome.dart';

/// Hourly ranking + top gifters sheet (lives/mobile-api.md §20).
class LiveRoomRankingSheet {
  const LiveRoomRankingSheet._();

  static Future<void> show(BuildContext context) {
    final bloc = context.read<LiveRoomBloc>();
    final repo = context.read<LiveSessionRepository>();
    final state = bloc.state;
    if (state is! LiveRoomReady) return Future.value();

    return LiveRoomHostSheetChrome.show(
      context: context,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: RepositoryProvider.value(
          value: repo,
          child: _LiveRoomRankingSheetBody(
            liveId: state.session.id,
            currentRank: state.session.hourlyRank,
            currentLabel: state.session.hourlyRankingLabel,
          ),
        ),
      ),
    );
  }
}

class _LiveRoomRankingSheetBody extends StatefulWidget {
  const _LiveRoomRankingSheetBody({
    required this.liveId,
    required this.currentRank,
    required this.currentLabel,
  });

  final String liveId;
  final int? currentRank;
  final String currentLabel;

  @override
  State<_LiveRoomRankingSheetBody> createState() =>
      _LiveRoomRankingSheetBodyState();
}

class _LiveRoomRankingSheetBodyState extends State<_LiveRoomRankingSheetBody>
    with LiveRoomHostSheetMixin, SingleTickerProviderStateMixin {
  late final TabController _tabs;
  var _loading = true;
  String? _error;
  List<LiveLeaderboardEntry> _global = const [];
  List<LiveLeaderboardEntry> _gifters = const [];
  ({int? rank, String label, int? score, int? coins})? _thisLive;

  @override
  LiveSessionRepository get repository => context.read<LiveSessionRepository>();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        repository.loadHourlyRank(widget.liveId),
        repository.loadGlobalHourlyLeaderboard(),
        repository.loadGiftersLeaderboard(widget.liveId, window: 'hour'),
      ]);
      if (!mounted) return;
      setState(() {
        _thisLive =
            results[0] as ({int? rank, String label, int? score, int? coins});
        _global = results[1] as List<LiveLeaderboardEntry>;
        _gifters = results[2] as List<LiveLeaderboardEntry>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final thisLive = _thisLive;
    return LiveRoomHostSheetChrome(
      title: 'ترتيب كل ساعة',
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh, color: Colors.white70),
        ),
      ],
      child: Column(
        children: [
          if (thisLive != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      thisLive.label.isNotEmpty
                          ? thisLive.label
                          : widget.currentLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (thisLive.score != null || thisLive.coins != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        [
                          if (thisLive.score != null) 'النقاط: ${thisLive.score}',
                          if (thisLive.coins != null) 'العملات: ${thisLive.coins}',
                        ].join(' · '),
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          TabBar(
            controller: _tabs,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicatorColor: const Color(0xFFFFC107),
            tabs: const [
              Tab(text: 'المضيفون'),
              Tab(text: 'أوائل الداعمين'),
            ],
          ),
          Expanded(
            child: _loading
                ? const LiveRoomSheetStatus.loading()
                : _error != null
                    ? LiveRoomSheetStatus.error(message: _error!)
                    : TabBarView(
                        controller: _tabs,
                        children: [
                          _LeaderboardList(
                            entries: _global,
                            emptyMessage: 'لا يوجد ترتيب لهذه الساعة بعد',
                            scoreLabel: 'نقاط',
                          ),
                          _LeaderboardList(
                            entries: _gifters,
                            emptyMessage: 'لا يوجد داعمون بعد',
                            scoreLabel: 'عملات',
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  const _LeaderboardList({
    required this.entries,
    required this.emptyMessage,
    required this.scoreLabel,
  });

  final List<LiveLeaderboardEntry> entries;
  final String emptyMessage;
  final String scoreLabel;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return LiveRoomSheetStatus.empty(message: emptyMessage);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final e = entries[index];
        final name = e.displayName ?? e.host?.displayName ?? '—';
        final value = e.coins ?? e.score;
        return ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: Colors.white10,
          leading: CircleAvatar(
            backgroundColor: Colors.white24,
            backgroundImage:
                e.avatarUrl != null ? NetworkImage(e.avatarUrl!) : null,
            child: e.avatarUrl == null
                ? Text(
                    '${e.rank ?? index + 1}',
                    style: const TextStyle(color: Colors.white),
                  )
                : null,
          ),
          title: Text(
            name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          subtitle: e.title == null
              ? null
              : Text(e.title!, style: const TextStyle(color: Colors.white54)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '#${e.rank ?? index + 1}',
                style: const TextStyle(
                  color: Color(0xFFFFC107),
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (value != null)
                Text(
                  '$scoreLabel $value',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
            ],
          ),
        );
      },
    );
  }
}
