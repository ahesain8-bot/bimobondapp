import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/utils/app_colors.dart';
import '../../../../../core/utils/app_sizes.dart';
import '../../../../../core/utils/app_text_styles.dart';
import 'live_room_pill.dart';

/// Counts up the live session elapsed time (00:00 → 00:01 → …).
///
/// Only mounted once the room is `LiveRoomReady`, so it starts ticking right
/// when the stream actually begins.
class LiveRoomElapsedTimer extends StatefulWidget {
  const LiveRoomElapsedTimer({super.key});

  @override
  State<LiveRoomElapsedTimer> createState() => _LiveRoomElapsedTimerState();
}

class _LiveRoomElapsedTimerState extends State<LiveRoomElapsedTimer> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  late final DateTime _startedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed = DateTime.now().difference(_startedAt));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formatted {
    String two(int value) => value.toString().padLeft(2, '0');
    final hours = _elapsed.inHours;
    final minutes = _elapsed.inMinutes % 60;
    final seconds = _elapsed.inSeconds % 60;
    return hours > 0
        ? '${two(hours)}:${two(minutes)}:${two(seconds)}'
        : '${two(minutes)}:${two(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    return LiveRoomPill(
      height: AppSizes.roomChipHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: AppColors.overlayPillSoft,
      child: Text('⏱ $_formatted', style: AppTextStyles.roomChip),
    );
  }
}
