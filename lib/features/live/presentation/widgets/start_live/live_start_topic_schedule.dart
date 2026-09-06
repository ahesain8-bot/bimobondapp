import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../../core/models/live_topic.dart';
import '../../bloc/start_live/live_bloc.dart';
import '../../bloc/start_live/live_event.dart';
import '../../bloc/start_live/live_state.dart';

Future<void> showLiveTopicDialog(BuildContext context) async {
  final bloc = context.read<LiveBloc>();
  final ready = bloc.state is LiveReady ? bloc.state as LiveReady : null;
  final controller = TextEditingController(text: ready?.topic ?? '');
  final result = await showDialog<String?>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Topic',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: LiveTopic.maxLength,
          maxLines: 2,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Radio / room topic',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
            counterStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(''),
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
  controller.dispose();
  if (result == null) return;
  bloc.add(LiveTopicChanged(LiveTopic.normalize(result)));
}

Future<void> showLiveSchedulePicker(BuildContext context) async {
  final bloc = context.read<LiveBloc>();
  final ready = bloc.state is LiveReady ? bloc.state as LiveReady : null;
  final now = DateTime.now();
  final initial = ready?.scheduledAt?.toLocal() ??
      now.add(const Duration(hours: 1));
  final date = await showDatePicker(
    context: context,
    initialDate: initial.isAfter(now) ? initial : now.add(const Duration(minutes: 5)),
    firstDate: DateTime(now.year, now.month, now.day),
    lastDate: now.add(const Duration(days: 365)),
  );
  if (date == null || !context.mounted) return;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null || !context.mounted) return;
  final local = DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  );
  if (!local.isAfter(DateTime.now())) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Schedule time must be in the future')),
    );
    return;
  }
  bloc.add(LiveScheduleChanged(local));
}

String formatLiveSchedule(DateTime value) {
  return DateFormat.yMMMd().add_jm().format(value.toLocal());
}
