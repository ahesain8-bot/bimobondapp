import 'dart:async';

import 'package:bimobondapp/app/marketplace/presentation/theme/marketplace_theme.dart';
import 'package:flutter/material.dart';

class AuctionCountdown extends StatefulWidget {
  const AuctionCountdown({
    required this.endsAt,
    this.style,
    this.prefix,
    super.key,
  });

  final DateTime? endsAt;
  final TextStyle? style;
  final String? prefix;

  @override
  State<AuctionCountdown> createState() => _AuctionCountdownState();
}

class _AuctionCountdownState extends State<AuctionCountdown> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(AuctionCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endsAt != widget.endsAt) _tick();
  }

  void _tick() {
    final end = widget.endsAt?.toUtc();
    if (end == null) {
      setState(() => _remaining = Duration.zero);
      return;
    }
    final now = DateTime.now().toUtc();
    setState(() {
      _remaining = end.isAfter(now) ? end.difference(now) : Duration.zero;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final h = d.inHours.remainder(100).toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = MarketplaceTheme.of(context);
    final ended = _remaining <= Duration.zero;
    final text = ended ? '00:00:00' : _format(_remaining);
    final prefix = widget.prefix;

    return Text(
      prefix == null ? text : '$prefix $text',
      style:
          widget.style ??
          TextStyle(
            color: theme.auctionAccent,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
    );
  }
}
