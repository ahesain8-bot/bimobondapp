import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/live_interactive.dart';
import '../bloc/admin_live/admin_live_bloc.dart';
import '../di/live_admin_injector.dart';

class AdminLiveDashboardPage extends StatelessWidget {
  const AdminLiveDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => createAdminLiveBloc()
        ..add(const AdminLivesRequested()),
      child: const _AdminLiveDashboardBody(),
    );
  }
}

class _AdminLiveDashboardBody extends StatefulWidget {
  const _AdminLiveDashboardBody();

  @override
  State<_AdminLiveDashboardBody> createState() => _AdminLiveDashboardBodyState();
}

class _AdminLiveDashboardBodyState extends State<_AdminLiveDashboardBody> {
  final _search = TextEditingController();
  final _userId = TextEditingController();
  String? _status;
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    _userId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live administration')),
      body: BlocConsumer<AdminLiveBloc, AdminLiveState>(
        listenWhen: (previous, current) => previous.error != current.error,
        listener: (context, state) {
          if (state.error == null) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!)),
          );
          context.read<AdminLiveBloc>().add(const AdminLiveErrorCleared());
        },
        builder: (context, state) {
          if (!state.permissionsLoaded || state.permissionsLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!state.canRead) {
            return const Center(
              child: Text('You do not have permission to view live administration.'),
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _search,
                        onChanged: (_) {
                          _searchDebounce?.cancel();
                          _searchDebounce = Timer(
                            const Duration(milliseconds: 350),
                            () {
                              if (mounted) _reload(context);
                            },
                          );
                        },
                        onSubmitted: (_) => _reload(context),
                        decoration: const InputDecoration(
                          labelText: 'Search lives',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _userId,
                        onSubmitted: (_) => _reload(context),
                        decoration: const InputDecoration(
                          labelText: 'Host user ID',
                          prefixIcon: Icon(Icons.person_search),
                        ),
                      ),
                    ),
                    DropdownButton<String?>(
                        value: _status,
                        hint: const Text('All'),
                        items: const [
                          DropdownMenuItem<String?>(value: null, child: Text('All')),
                          DropdownMenuItem(value: 'PLANNED', child: Text('Planned')),
                          DropdownMenuItem(value: 'LIVE', child: Text('Live')),
                          DropdownMenuItem(value: 'ENDED', child: Text('Ended')),
                          DropdownMenuItem(value: 'BANNED', child: Text('Banned')),
                        ],
                        onChanged: (value) {
                          setState(() => _status = value);
                          _reload(context);
                        },
                      ),
                  ],
                ),
              ),
              if (state.isLoading && state.page == null)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else
                Expanded(
                  child: ListView(
                    children: [
                      if (state.page?.items.isNotEmpty == true)
                        Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Title / host')),
                                DataColumn(label: Text('Category')),
                                DataColumn(label: Text('Viewers')),
                                DataColumn(label: Text('Likes')),
                                DataColumn(label: Text('Coins')),
                                DataColumn(label: Text('Started')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: [
                                for (final live in state.page!.items)
                                  DataRow(
                                    cells: [
                                      DataCell(_StatusBadge(live.status)),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundImage: (live.user?['avatarUrl'] ?? live.user?['avatar']) is String &&
                                                      ((live.user?['avatarUrl'] ?? live.user?['avatar']) as String).isNotEmpty
                                                  ? NetworkImage((live.user?['avatarUrl'] ?? live.user?['avatar']) as String)
                                                  : null,
                                              child: const Icon(Icons.person, size: 16),
                                            ),
                                            const SizedBox(width: 8),
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 220),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(live.title, overflow: TextOverflow.ellipsis),
                                                  Text(
                                                    '${live.user?['username'] ?? live.user?['fullName'] ?? live.userId}${live.user?['isVerified'] == true ? ' ✓' : ''}',
                                                    style: Theme.of(context).textTheme.bodySmall,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      DataCell(Text(live.category?['name']?.toString() ?? live.categoryId ?? '—')),
                                      DataCell(Text('${live.viewers}')),
                                      DataCell(Text('${live.likeCount}')),
                                      DataCell(Text('${live.totalEarnedCoins}')),
                                      DataCell(Text(_formatDate(live.startedAt))),
                                      DataCell(
                                        TextButton(
                                          onPressed: () => context.read<AdminLiveBloc>().add(
                                            AdminLiveDetailRequested(live.id),
                                          ),
                                          child: const Text('Inspect'),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        )
                      else if (!state.isLoading)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('No live streams found.')),
                        ),
                      if (state.page != null && state.page!.totalPages > 1)
                        _AdminPagination(
                          page: state.page!.page,
                          totalPages: state.page!.totalPages,
                          onPageChanged: (page) => context.read<AdminLiveBloc>().add(
                            AdminLivesRequested(
                              page: page,
                              status: _status,
                              userId: _userId.text,
                              search: _search.text,
                            ),
                          ),
                        ),
                      if (state.selected != null)
                        _AdminLiveActions(
                          live: state.selected!,
                          guests: state.guests,
                          comments: state.comments,
                          battle: state.battle,
                          questions: state.questions,
                          treasureBoxes: state.treasureBoxes,
                          auctions: state.auctions,
                          gifters: state.gifters,
                          poll: state.poll,
                          hourlyRank: state.hourlyRank?.rank,
                          realtimeEvent: state.realtimeEvent,
                          isBusy: state.isActionBusy,
                          canModerate: state.canModerate,
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  void _reload(BuildContext context) {
    context.read<AdminLiveBloc>().add(
      AdminLivesRequested(
        status: _status,
        userId: _userId.text.trim().isEmpty ? null : _userId.text.trim(),
        search: _search.text,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase();
    final MaterialColor color = switch (normalized) {
      'LIVE' => Colors.green,
      'BANNED' => Colors.red,
      'PLANNED' => Colors.orange,
      _ => Colors.grey,
    };
    return Chip(
      label: Text(normalized),
      labelStyle: TextStyle(color: color.shade700, fontSize: 11),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _AdminPagination extends StatelessWidget {
  const _AdminPagination({
    required this.page,
    required this.totalPages,
    required this.onPageChanged,
  });

  final int page;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Previous page',
            onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('$page / $totalPages'),
          IconButton(
            tooltip: 'Next page',
            onPressed: page < totalPages ? () => onPageChanged(page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _AdminLiveActions extends StatelessWidget {
  const _AdminLiveActions({
    required this.live,
    required this.guests,
    required this.comments,
    required this.battle,
    required this.questions,
    required this.treasureBoxes,
    required this.auctions,
    required this.gifters,
    required this.poll,
    required this.hourlyRank,
    required this.realtimeEvent,
    required this.isBusy,
    required this.canModerate,
  });

  final AdminLive live;
  final List<Map<String, dynamic>> guests;
  final List<Map<String, dynamic>> comments;
  final Map<String, dynamic>? battle;
  final List<LiveQA> questions;
  final List<LiveTreasureBox> treasureBoxes;
  final List<LiveAuction> auctions;
  final List<LiveGifterLeaderboardEntry> gifters;
  final LivePoll? poll;
  final int? hourlyRank;
  final String? realtimeEvent;
  final bool isBusy;
  final bool canModerate;

  bool get hasBattle => battle != null;
  int get questionCount => questions.length;
  int get treasureBoxCount => treasureBoxes.length;
  int get auctionCount => auctions.length;
  int get gifterCount => gifters.length;

  String _formatDate(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final status = live.status.toUpperCase();
    final isTerminal = status == 'ENDED' || status == 'BANNED';
    final isLive = status == 'LIVE';
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(live.title, style: Theme.of(context).textTheme.titleLarge),
            Text('Live ID: ${live.id}'),
            Text('Status: ${live.status}'),
            Text('Coins: ${live.totalEarnedCoins}'),
            if (live.banReason?.isNotEmpty == true)
              Text('Ban reason: ${live.banReason}'),
            if (live.feedBoostUntil != null)
              Text('Feed boost until: ${_formatDate(live.feedBoostUntil)}'),
            Text(
              'Guests: ${guests.length} · Comments: ${comments.length} · '
              'Battle: ${battle == null ? 'none' : 'active'}',
            ),
            Text(
              'Poll: ${poll == null ? 'none' : poll!.status} · Q&A: $questionCount · '
              'Boxes: $treasureBoxCount · Auctions: $auctionCount · Gifters: $gifterCount'
              '${hourlyRank == null ? '' : ' · Hourly rank: #$hourlyRank'}',
            ),
            if (live.pinnedComment != null)
              _InspectionTile(
                title: 'Pinned comment',
                children: [Text(jsonEncode(live.pinnedComment))],
              ),
            if (guests.isNotEmpty)
              _InspectionTile(
                title: 'Guest list (${guests.length})',
                children: [
                  for (final guest in guests.take(50))
                    ListTile(
                      dense: true,
                      title: Text(_mapText(guest, const ['username', 'displayName', 'userId'])),
                      subtitle: Text(
                        'status: ${_mapText(guest, const ['status', 'state'])} '
                        'muted: ${_mapText(guest, const ['muted', 'isMuted'])}',
                      ),
                    ),
                ],
              ),
            if (comments.isNotEmpty)
              _InspectionTile(
                title: 'Chat history (${comments.length})',
                children: [
                  for (final comment in comments.take(50))
                    ListTile(
                      dense: true,
                      title: Text(_mapText(comment, const ['content', 'text', 'message'])),
                      subtitle: Text(_mapText(comment, const ['username', 'userId', 'createdAt'])),
                    ),
                ],
              ),
            if (battle != null)
              _InspectionTile(
                title: 'Active battle',
                children: [Text(jsonEncode(battle))],
              ),
            if (poll != null)
              _InspectionTile(
                title: 'Poll: ${poll!.question}',
                children: [
                  for (final option in poll!.options)
                    ListTile(
                      dense: true,
                      title: Text(option.text),
                      trailing: Text(
                        '${option.votes} (${option.percentage.toStringAsFixed(1)}%)',
                      ),
                    ),
                ],
              ),
            if (questions.isNotEmpty)
              _InspectionTile(
                title: 'Q&A (${questions.length})',
                children: [
                  for (final question in questions.take(50))
                    ListTile(
                      dense: true,
                      title: Text(question.question),
                      subtitle: Text(
                        '${question.username} · ${question.isAnswered ? 'answered' : 'open'}',
                      ),
                    ),
                ],
              ),
            if (treasureBoxes.isNotEmpty)
              _InspectionTile(
                title: 'Treasure boxes (${treasureBoxes.length})',
                children: [
                  for (final box in treasureBoxes)
                    ListTile(
                      dense: true,
                      title: Text('${box.remainingCoins}/${box.totalCoins} coins'),
                      subtitle: Text(
                        '${box.claimedCount}/${box.maxClaims} claims · ${box.status}',
                      ),
                    ),
                ],
              ),
            if (auctions.isNotEmpty)
              _InspectionTile(
                title: 'Auctions (${auctions.length})',
                children: [
                  for (final auction in auctions)
                    ListTile(
                      dense: true,
                      title: Text(auction.itemName),
                      subtitle: Text(
                        '${auction.currentPrice}/${auction.targetPrice} · ${auction.status}',
                      ),
                    ),
                ],
              ),
            if (gifters.isNotEmpty)
              _InspectionTile(
                title: 'Top gifters (${gifters.length})',
                children: [
                  for (final gifter in gifters)
                    ListTile(
                      dense: true,
                      title: Text(_mapText(gifter.user, const ['username', 'fullName', 'id'])),
                      trailing: Text('${gifter.totalCoins} coins'),
                    ),
                ],
              ),
            if (realtimeEvent != null)
              Text(
                'Realtime: $realtimeEvent',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            if (canModerate)
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: isBusy || !isLive ? null : () => _boost(context),
                    child: const Text('Boost 60 min'),
                  ),
                  FilledButton.tonal(
                    onPressed: isBusy || isTerminal ? null : () => _confirmEnd(context),
                    child: const Text('End live'),
                  ),
                  FilledButton.tonal(
                    onPressed: isBusy || isTerminal ? null : () => _ban(context),
                    child: const Text('Ban live'),
                  ),
                  FilledButton.tonal(
                    onPressed: isBusy || isTerminal ? null : () => _kickGuest(context),
                    child: const Text('Kick guest'),
                  ),
                ],
              )
            else
              const Text('Moderation actions require lives.admin.moderate.'),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmEnd(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End live stream?'),
        content: const Text(
          'This will end the stream for all viewers and close its live session.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('End live'),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;
    context.read<AdminLiveBloc>().add(AdminLiveEnded(live.id));
  }

  Future<void> _boost(BuildContext context) async {
    final controller = TextEditingController(text: '60');
    final duration = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Boost live'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Duration in minutes (1–10080)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value < 1 || value > 10080) return;
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Boost'),
          ),
        ],
      ),
    );
    if (!context.mounted || duration == null) return;
    context.read<AdminLiveBloc>().add(
      AdminLiveBoosted(liveId: live.id, durationMinutes: duration),
    );
  }

  void _ban(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ban live'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(dialogContext);
              context.read<AdminLiveBloc>().add(
                AdminLiveBanned(liveId: live.id, reason: reason),
              );
            },
            child: const Text('Ban'),
          ),
        ],
      ),
    );
  }

  void _kickGuest(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kick guest'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Guest user ID'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final userId = controller.text.trim();
              if (userId.isEmpty) return;
              Navigator.pop(dialogContext);
              context.read<AdminLiveBloc>().add(
                AdminGuestKicked(liveId: live.id, userId: userId),
              );
            },
            child: const Text('Kick'),
          ),
        ],
      ),
    );
  }
}

class _InspectionTile extends StatelessWidget {
  const _InspectionTile({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(title),
      children: children,
    );
  }
}

String _mapText(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value != null && value.toString().isNotEmpty) return value.toString();
  }
  return '—';
}
