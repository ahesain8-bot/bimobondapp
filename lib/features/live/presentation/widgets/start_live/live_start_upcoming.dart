import 'package:flutter/material.dart';

import '../../../../../core/models/live_media_mode.dart';
import '../../../../../core/models/live_topic.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../data/datasources/lives_remote_datasource.dart';
import '../../../data/mappers/live_session_mapper.dart';
import '../../../domain/entities/live_session.dart';
import '../../../domain/live_planned_scheduling.dart';
import 'live_start_topic_schedule.dart';

/// Compact Upcoming list on the host start page (`GET /lives/mine`, PLANNED).
class LiveStartUpcomingLives extends StatefulWidget {
  const LiveStartUpcomingLives({
    super.key,
    required this.refreshNonce,
    required this.onGoLive,
  });

  final int refreshNonce;
  final Future<void> Function(LiveSession live) onGoLive;

  @override
  State<LiveStartUpcomingLives> createState() => _LiveStartUpcomingLivesState();
}

class _LiveStartUpcomingLivesState extends State<LiveStartUpcomingLives> {
  final _remote = LivesRemoteDataSource();
  var _loading = false;
  List<LiveSession> _items = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(LiveStartUpcomingLives oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshNonce != widget.refreshNonce) {
      _reload();
    }
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final json = await _remote.mine(limit: 50);
      final items = LivePlannedScheduling.plannedMapsFromMinePayload(json)
          .map(LiveSessionMapper.fromLiveJson)
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _patch({
    required String liveId,
    String? title,
    String? mediaMode,
    DateTime? scheduledAt,
    bool clearScheduledAt = false,
  }) async {
    if (clearScheduledAt) {
      await _remote.updateLive(liveId, scheduledAt: null);
    } else {
      await _remote.updateLive(
        liveId,
        title: title,
        mediaMode: mediaMode,
        scheduledAt: scheduledAt,
      );
    }
    await _reload();
  }

  Future<void> _openActions(LiveSession live) async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  live.title?.trim().isNotEmpty == true
                      ? live.title!
                      : l10n.liveScheduledLive,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  live.scheduledAt == null
                      ? l10n.liveScheduledDraft
                      : LiveSchedule.formatLocal(live.scheduledAt!),
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.white),
                title: Text(
                  l10n.liveReview,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _review(live);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: Text(
                  l10n.liveEditTitle,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _editTitle(live);
                },
              ),
              ListTile(
                leading: const Icon(Icons.schedule, color: Colors.white),
                title: Text(
                  l10n.liveReschedule,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _reschedule(live);
                },
              ),
              ListTile(
                leading: const Icon(Icons.event_busy, color: Colors.white),
                title: Text(
                  l10n.liveClearScheduledTime,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _patch(liveId: live.id, clearScheduledAt: true);
                },
              ),
              ListTile(
                leading: Icon(
                  live.isAudioOnly ? Icons.videocam : Icons.mic,
                  color: Colors.white,
                ),
                title: Text(
                  live.isAudioOnly
                      ? l10n.liveSwitchToVideo
                      : l10n.liveSwitchToAudio,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _patch(
                    liveId: live.id,
                    mediaMode: live.isAudioOnly
                        ? LiveMediaMode.video
                        : LiveMediaMode.audio,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.podcasts, color: Color(0xFFFE2C55)),
                title: Text(
                  l10n.cameraGoLive,
                  style: const TextStyle(
                    color: Color(0xFFFE2C55),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onGoLive(live);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _review(LiveSession live) async {
    final l10n = AppLocalizations.of(context)!;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: Text(
            live.title?.trim().isNotEmpty == true
                ? live.title!
                : l10n.liveScheduledLive,
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            live.scheduledAt == null
                ? l10n.liveScheduledDraft
                : LiveSchedule.formatLocal(live.scheduledAt!),
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.lpBack),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editTitle(LiveSession live) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: live.title ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: Text(
            l10n.liveEditTitle,
            style: const TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.lpBack),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: Text(l10n.liveSave),
            ),
          ],
        );
      },
    );
    controller.dispose();
    final title = result?.trim();
    if (title == null || title.isEmpty) return;
    await _patch(liveId: live.id, title: title);
  }

  Future<void> _reschedule(LiveSession live) async {
    final picked = await pickLiveScheduleDateTime(
      context,
      initial: live.scheduledAt,
    );
    if (picked == null) return;
    await _patch(liveId: live.id, scheduledAt: picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!_loading && _items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.liveUpcomingTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (_loading && _items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            ..._items.take(8).map((live) {
              final when = live.scheduledAt == null
                  ? l10n.liveScheduledDraft
                  : LiveSchedule.formatLocal(live.scheduledAt!);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    dense: true,
                    onTap: () => _openActions(live),
                    title: Text(
                      live.title?.trim().isNotEmpty == true
                          ? live.title!
                          : l10n.liveScheduledLive,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      when,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    trailing: TextButton(
                      onPressed: () => widget.onGoLive(live),
                      child: Text(
                        l10n.cameraGoLive,
                        style: const TextStyle(
                          color: Color(0xFFFE2C55),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
