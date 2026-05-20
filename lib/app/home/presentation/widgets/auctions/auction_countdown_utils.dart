import 'package:bimobondapp/app/home/presentation/widgets/live_details/auction_countdown_parts.dart';
import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

AuctionCountdownParts computeAuctionCountdownParts({
  required DateTime startedAt,
  required DateTime endedAt,
  DateTime? now,
}) {
  final current = (now ?? DateTime.now()).toUtc();
  final start = startedAt.toUtc();
  final end = endedAt.toUtc();

  if (end.isBefore(current) || end.isAtSameMomentAs(current)) {
    return const AuctionCountdownParts.finished();
  }

  final isUpcoming = start.isAfter(current);
  final diff = (isUpcoming ? start : end).difference(current);
  return AuctionCountdownParts(
    days: diff.inDays,
    hours: diff.inHours.remainder(24),
    minutes: diff.inMinutes.remainder(60),
    seconds: diff.inSeconds.remainder(60),
    isUpcoming: isUpcoming,
    isActive: !isUpcoming,
  );
}

String formatAuctionCountdownDisplay(
  AppLocalizations l10n,
  Locale locale,
  AuctionCountdownParts parts,
) {
  if (parts.isFinished) {
    return LocaleFormatUtils.localizeDigits('--:--:--', locale);
  }

  final hours = parts.hours.toString().padLeft(2, '0');
  final minutes = parts.minutes.toString().padLeft(2, '0');
  final seconds = parts.seconds.toString().padLeft(2, '0');
  final time = LocaleFormatUtils.localizeDigits(
    '$hours:$minutes:$seconds',
    locale,
  );

  if (parts.days > 0) {
    final daysLabel = LocaleFormatUtils.localizeDigits(
      l10n.auctionCountdownDayCount(parts.days),
      locale,
    );
    return '$daysLabel $time';
  }

  return time;
}

String auctionCountdownLabel(
  AppLocalizations l10n,
  AuctionCountdownParts parts,
) {
  if (parts.isFinished) {
    return l10n.auctionFinishedBadge;
  }
  if (parts.isUpcoming) {
    return l10n.auctionStartsIn;
  }
  return l10n.auctionTimeLeft;
}
