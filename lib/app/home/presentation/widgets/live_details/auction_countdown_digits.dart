import 'dart:ui';

import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';
import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/auction_countdown_parts.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/labeled_timer_row.dart';

class AuctionCountdownDigits extends StatelessWidget {
  const AuctionCountdownDigits({
    required this.parts,
    this.compact = false,
  });

  final AuctionCountdownParts parts;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final digitSize = compact ? 12.0 : 18.0;
    final daySize = compact ? 13.0 : 20.0;

    final l10n = AppLocalizations.of(context)!;
    final timerRow = LabeledTimerRow(
      hours: parts.hours,
      minutes: parts.minutes,
      seconds: parts.seconds,
      isFinished: parts.isFinished,
      hourLabel: l10n.auctionTimerHour,
      minuteLabel: l10n.auctionTimerMinute,
      secondLabel: l10n.auctionTimerSecond,
      locale: locale,
      digitSize: digitSize,
      labelSize: compact ? 8.0 : 9.0,
    );

    if (parts.days > 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            LocaleFormatUtils.localizeDigits(
              l10n.auctionCountdownDayCount(parts.days),
              locale,
            ),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: daySize,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppSizes.p8),
          timerRow,
        ],
      );
    }

    return timerRow;
  }
}
