import 'package:flutter/material.dart';

/// TikTok-style pre-LIVE info card: cover · title · topic / goal chips.
class LiveStartInfoCard extends StatelessWidget {
  const LiveStartInfoCard({
    super.key,
    required this.titleController,
    this.coverUrl,
    this.topic,
    this.scheduledAt,
    this.onChangeCover,
    this.onAddTopic,
    this.onSchedule,
    this.onAddGoal,
  });

  final TextEditingController titleController;
  final String? coverUrl;
  final String? topic;
  final DateTime? scheduledAt;
  final VoidCallback? onChangeCover;
  final VoidCallback? onAddTopic;
  final VoidCallback? onSchedule;
  final VoidCallback? onAddGoal;

  static const Color _cardFill = Color(0x99000000);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 12),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CoverThumb(
                coverUrl: coverUrl,
                onChange: onChangeCover,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: titleController,
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'Add a title to chat',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          textAlign: TextAlign.left,
                        ),
                      ),
                      Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ChipButton(
                icon: Icons.topic_outlined,
                iconColor: const Color(0xFFFFC107),
                label: (topic != null && topic!.isNotEmpty)
                    ? topic!
                    : 'Add topic',
                onTap: onAddTopic,
              ),
              _ChipButton(
                key: const Key('live_start_schedule_chip'),
                icon: Icons.schedule,
                iconColor: const Color(0xFF80DEEA),
                label: scheduledAt != null
                    ? _formatSchedule(scheduledAt!)
                    : 'Schedule',
                onTap: onSchedule,
              ),
              _ChipButton(
                icon: Icons.emoji_events_outlined,
                iconColor: const Color(0xFFB388FF),
                label: 'Add a LIVE goal',
                onTap: onAddGoal,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({this.coverUrl, this.onChange});

  final String? coverUrl;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('live_start_change_cover'),
      onTap: onChange,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 64,
              height: 64,
              child: coverUrl != null && coverUrl!.isNotEmpty
                  ? Image.network(coverUrl!, fit: BoxFit.cover)
                  : const ColoredBox(
                      color: Color(0xFF2A2A2E),
                      child: Icon(
                        Icons.image_outlined,
                        color: Color(0x73FFFFFF),
                        size: 28,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Change',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: iconColor),
            const SizedBox(width: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatSchedule(DateTime value) {
  final local = value.toLocal();
  final mm = local.month.toString().padLeft(2, '0');
  final dd = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '$mm/$dd $hh:$min';
}
