import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/utils/post_story_filter.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';

String formatStoryTimeAgo(PostEntity post, AppLocalizations l10n) {
  if (!isStoryStillActive(post)) return l10n.storyExpired;

  final diff = DateTime.now().difference(post.createdAt.toLocal());
  if (diff.inMinutes < 1) return l10n.justNow;
  if (diff.inMinutes < 60) return l10n.storyTimeMinutesAgo(diff.inMinutes);
  return l10n.storyTimeHoursAgo(diff.inHours);
}
