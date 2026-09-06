import 'package:flutter/material.dart';

import 'live_start_info_card.dart';

/// TikTok Go LIVE top chrome: close + cover/title info card.
class StatusBarArea extends StatelessWidget {
  const StatusBarArea({
    super.key,
    required this.onClose,
    required this.titleController,
    this.topic,
    this.scheduledAt,
    this.onChangeCover,
    this.onAddTopic,
    this.onSchedule,
    this.onAddGoal,
  });

  final VoidCallback onClose;
  final TextEditingController titleController;
  final String? topic;
  final DateTime? scheduledAt;
  final VoidCallback? onChangeCover;
  final VoidCallback? onAddTopic;
  final VoidCallback? onSchedule;
  final VoidCallback? onAddGoal;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: onClose,
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 26,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ),
          ),
          LiveStartInfoCard(
            titleController: titleController,
            topic: topic,
            scheduledAt: scheduledAt,
            onChangeCover: onChangeCover,
            onAddTopic: onAddTopic,
            onSchedule: onSchedule,
            onAddGoal: onAddGoal,
          ),
        ],
      ),
    );
  }
}
