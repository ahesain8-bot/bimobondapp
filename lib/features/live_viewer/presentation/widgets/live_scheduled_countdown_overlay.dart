import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/models/live_topic.dart';
import '../../../../l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/entities/live_entity.dart';

/// Cover / host / title / countdown for `PLANNED` lives. Does not join LiveKit.
class LiveScheduledCountdownOverlay extends StatefulWidget {
  const LiveScheduledCountdownOverlay({
    super.key,
    required this.live,
    required this.reminderSet,
    this.isHost = false,
    this.onRemind,
    this.onShare,
    this.onLeave,
  });

  final LiveEntity live;
  final bool reminderSet;
  final bool isHost;
  final VoidCallback? onRemind;
  final VoidCallback? onShare;
  final VoidCallback? onLeave;

  @override
  State<LiveScheduledCountdownOverlay> createState() =>
      _LiveScheduledCountdownOverlayState();
}

class _LiveScheduledCountdownOverlayState
    extends State<LiveScheduledCountdownOverlay> {
  Timer? _ticker;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _subtitle(AppLocalizations l10n) {
    final scheduledAt = widget.live.scheduledAt;
    if (scheduledAt == null) return l10n.liveStartsSoon;
    final remaining = scheduledAt.toLocal().difference(_now);
    if (remaining.isNegative) return l10n.liveStartsSoon;
    return LiveSchedule.formatLocal(scheduledAt);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final live = widget.live;
    final cover = live.thumbnailUrl;

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cover != null && cover.isNotEmpty)
              Image.network(
                cover,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xCC000000), Color(0x66000000), Colors.black54],
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundImage:
                          live.hostAvatar != null && live.hostAvatar!.isNotEmpty
                          ? NetworkImage(live.hostAvatar!)
                          : null,
                      child:
                          live.hostAvatar == null || live.hostAvatar!.isEmpty
                          ? const Icon(Icons.person, size: 36)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      live.hostName,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      live.title.isEmpty ? l10n.liveScheduledLive : live.title,
                      style: AppTextStyles.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _subtitle(l10n),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (!widget.isHost)
                      ElevatedButton(
                        onPressed: widget.reminderSet ? null : widget.onRemind,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(180, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text(
                          widget.reminderSet
                              ? l10n.liveReminderSet
                              : l10n.liveRemindMe,
                        ),
                      ),
                    if (widget.onShare != null) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: widget.onShare,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                        ),
                        child: Text(l10n.mediaEditorShare),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: widget.onLeave,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                      ),
                      child: Text(l10n.liveLeave),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
