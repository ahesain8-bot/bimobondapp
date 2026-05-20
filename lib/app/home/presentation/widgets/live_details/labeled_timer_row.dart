import 'dart:ui';

import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';
import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/time_unit_box.dart';

class LabeledTimerRow extends StatelessWidget {
  const LabeledTimerRow({
    required this.hours,
    required this.minutes,
    required this.seconds,
    required this.isFinished,
    required this.hourLabel,
    required this.minuteLabel,
    required this.secondLabel,
    required this.locale,
    required this.digitSize,
    required this.labelSize,
  });

  final int hours;
  final int minutes;
  final int seconds;
  final bool isFinished;
  final String hourLabel;
  final String minuteLabel;
  final String secondLabel;
  final Locale locale;
  final double digitSize;
  final double labelSize;

  @override
  Widget build(BuildContext context) {
    final dash = LocaleFormatUtils.localizeDigits('--', locale);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TimeUnitBox(
          display: isFinished
              ? dash
              : LocaleFormatUtils.twoDigitTimeUnit(hours, locale),
          label: hourLabel,
          digitSize: digitSize,
          labelSize: labelSize,
        ),
        const SizedBox(width: AppSizes.p4),
        TimeUnitBox(
          display: isFinished
              ? dash
              : LocaleFormatUtils.twoDigitTimeUnit(minutes, locale),
          label: minuteLabel,
          digitSize: digitSize,
          labelSize: labelSize,
        ),
        const SizedBox(width: AppSizes.p4),
        TimeUnitBox(
          display: isFinished
              ? dash
              : LocaleFormatUtils.twoDigitTimeUnit(seconds, locale),
          label: secondLabel,
          digitSize: digitSize,
          labelSize: labelSize,
        ),
      ],
    );
  }
}
