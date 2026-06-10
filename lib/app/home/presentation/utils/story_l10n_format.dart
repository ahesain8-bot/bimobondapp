import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/utils/post_story_filter.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// Relative time with an explicit "ago" suffix (e.g. 5m ago, 2h ago).
String formatTimeAgo(DateTime dateTime, AppLocalizations l10n) {
  final local = dateTime.toLocal();
  final diff = DateTime.now().difference(local);

  if (diff.inSeconds < 5) return l10n.justNow;
  if (diff.inMinutes < 1) return l10n.storyTimeMinutesAgo(1);
  if (diff.inMinutes < 60) return l10n.storyTimeMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.storyTimeHoursAgo(diff.inHours);
  if (diff.inDays < 7) return l10n.storyTimeDaysAgo(diff.inDays);
  return DateFormat.MMMd(l10n.localeName).format(local);
}

String formatStoryTimeAgo(PostEntity post, AppLocalizations l10n) {
  if (!isStoryStillActive(post)) return l10n.storyExpired;
  return formatTimeAgo(post.createdAt, l10n);
}
