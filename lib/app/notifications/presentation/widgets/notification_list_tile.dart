import 'package:bimobondapp/app/chats/presentation/utils/chat_message_mapper.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/app/notifications/domain/entities/notification_entity.dart';
import 'package:bimobondapp/app/notifications/presentation/utils/notification_display_text.dart';
import 'package:bimobondapp/app/notifications/presentation/utils/notification_type_style.dart';
import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/activity_feed_card.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class NotificationListTile extends StatelessWidget {
  const NotificationListTile({
    required this.notification,
    required this.onTap,
    super.key,
  });

  final NotificationEntity notification;
  final VoidCallback onTap;

  String? _resolveThumbnailUrl() {
    final post = notification.post;
    if (post == null) return null;

    final thumb = post.thumbnailUrl;
    if (thumb != null && MediaUtils.isImage(thumb)) return thumb;
    return thumb;
  }

  bool get _hasCustomCopy {
    return notification.title?.trim().isNotEmpty == true ||
        notification.body?.trim().isNotEmpty == true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cardColor = activityFeedCardColor(theme);
    final isUnread = !notification.isRead;
    final (typeIcon, typeColor) =
        NotificationTypeStyle.forType(notification.type);
    final time = formatInboxTime(notification.createdAt, l10n);
    final actorName =
        notification.actor?.displayName ?? l10n.notificationSomeone;
    final body = NotificationDisplayText.body(l10n, notification);
    final title = NotificationDisplayText.title(l10n, notification);
    final thumbnailUrl = _resolveThumbnailUrl();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.p10),
      child: Material(
        color: isUnread
            ? theme.colorScheme.primary.withValues(alpha: 0.04)
            : cardColor,
        elevation: isUnread ? 0 : 0,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isUnread
                    ? theme.colorScheme.primary.withValues(alpha: 0.12)
                    : theme.dividerColor.withValues(alpha: 0.08),
              ),
              boxShadow: isUnread
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isUnread)
                    Container(
                      width: 3,
                      color: theme.colorScheme.primary,
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              StoryProfileAvatar(
                                userId: notification.actor?.id,
                                imageUrl: notification.actor?.avatarUrl,
                                radius: 24,
                                fallbackText: actorName,
                                username: notification.actor?.username,
                                fullName: notification.actor?.fullName,
                              ),
                              PositionedDirectional(
                                end: -2,
                                bottom: -2,
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: typeColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: cardColor,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: typeColor.withValues(alpha: 0.35),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    typeIcon,
                                    size: 11,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: AppSizes.p12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _hasCustomCopy
                                          ? Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  title,
                                                  style: theme
                                                      .textTheme.titleSmall
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: -0.2,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  body,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: theme.textTheme.bodyMedium
                                                      ?.copyWith(
                                                    height: 1.35,
                                                    color: theme
                                                        .textTheme.bodyMedium?.color
                                                        ?.withValues(alpha: 0.75),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : RichText(
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              text: TextSpan(
                                                style: theme.textTheme.bodyMedium
                                                    ?.copyWith(height: 1.35),
                                                children: [
                                                  TextSpan(
                                                    text: actorName,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: ' ${_actionSuffix(l10n, body, actorName)}',
                                                    style: TextStyle(
                                                      color: theme.textTheme
                                                          .bodyMedium?.color
                                                          ?.withValues(alpha: 0.75),
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                    ),
                                    if (time.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        time,
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.7),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (notification.comment?.content?.trim().isNotEmpty ==
                                    true) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      notification.comment!.content!.trim(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        height: 1.3,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (thumbnailUrl != null &&
                              thumbnailUrl.isNotEmpty) ...[
                            const SizedBox(width: AppSizes.p10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SafeNetworkImage(
                                imageUrl: thumbnailUrl,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                                errorIcon: Icons.image_outlined,
                              ),
                            ),
                          ] else if (isUnread) ...[
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: MessagesLayoutConstants.activityBadgeColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _actionSuffix(
    AppLocalizations l10n,
    String body,
    String actorName,
  ) {
    if (body.startsWith(actorName)) {
      return body.substring(actorName.length).trimLeft();
    }
    return body;
  }
}
