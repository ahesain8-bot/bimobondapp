import 'dart:ui';

import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';
import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AuctionCountdownParts {
  const AuctionCountdownParts({
    required this.days,
    required this.hours,
    required this.minutes,
    required this.seconds,
    this.isUpcoming = false,
    this.isActive = false,
    this.isFinished = false,
  });

  const AuctionCountdownParts.finished()
      : days = 0,
        hours = 0,
        minutes = 0,
        seconds = 0,
        isUpcoming = false,
        isActive = false,
        isFinished = true;

  final int days;
  final int hours;
  final int minutes;
  final int seconds;
  final bool isUpcoming;
  final bool isActive;
  final bool isFinished;
}
