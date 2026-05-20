import 'dart:async';

import 'package:bimobondapp/app/home/presentation/widgets/auctions/auction_bid_stat_column.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auction_countdown_utils.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/auction_countdown_parts.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AuctionCardCountdownStat extends StatefulWidget {
  const AuctionCardCountdownStat({
    required this.startedAt,
    required this.endedAt,
    super.key,
  });

  final DateTime startedAt;
  final DateTime endedAt;

  @override
  State<AuctionCardCountdownStat> createState() =>
      _AuctionCardCountdownStatState();
}

class _AuctionCardCountdownStatState extends State<AuctionCardCountdownStat> {
  Timer? _timer;
  late AuctionCountdownParts _parts;

  @override
  void initState() {
    super.initState();
    _parts = computeAuctionCountdownParts(
      startedAt: widget.startedAt,
      endedAt: widget.endedAt,
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(AuctionCardCountdownStat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startedAt != widget.startedAt ||
        oldWidget.endedAt != widget.endedAt) {
      _tick();
    }
  }

  void _tick() {
    if (!mounted) return;
    final next = computeAuctionCountdownParts(
      startedAt: widget.startedAt,
      endedAt: widget.endedAt,
    );
    if (next.isFinished) {
      _timer?.cancel();
      _timer = null;
    }
    if (next.days == _parts.days &&
        next.hours == _parts.hours &&
        next.minutes == _parts.minutes &&
        next.seconds == _parts.seconds &&
        next.isUpcoming == _parts.isUpcoming &&
        next.isFinished == _parts.isFinished) {
      return;
    }
    setState(() => _parts = next);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);

    return AuctionBidStatColumn(
      label: auctionCountdownLabel(l10n, _parts),
      value: formatAuctionCountdownDisplay(l10n, locale, _parts),
      alignEnd: false,
      leadingIcon: LucideIcons.clock,
    );
  }
}
