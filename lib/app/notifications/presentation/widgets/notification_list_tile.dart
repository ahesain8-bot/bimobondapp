import 'package:bimobondapp/app/chats/presentation/utils/chat_message_mapper.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/app/notifications/domain/entities/notification_entity.dart';
import 'package:bimobondapp/app/notifications/presentation/utils/notification_admin_helper.dart';
import 'package:bimobondapp/app/notifications/presentation/utils/notification_display_text.dart';
import 'package:bimobondapp/app/notifications/presentation/utils/notification_type_style.dart';
import 'package:bimobondapp/core/constants/notifications_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/dotted_divider.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class NotificationListTile extends StatelessWidget {
  const NotificationListTile({
    required this.notification,
    required this.onTap,
    this.onAccept,
    this.onDecline,
    this.showDivider = true,
    super.key,
  });

  final NotificationEntity notification;
  final VoidCallback onTap;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final bool showDivider;

  String? _resolveThumbnailUrl() {
    final post = notification.post;
    if (post == null) return null;
    final thumb = post.thumbnailUrl;
    if (thumb != null && thumb.isNotEmpty) return thumb;
    return null;
  }

  bool get _isFollowRequest => notification.type == 'FOLLOW_REQUEST';

  bool get _hasCustomCopy {
    return notification.title?.trim().isNotEmpty == true ||
        notification.body?.trim().isNotEmpty == true;
  }

  String _detailTimestamp(DateTime dateTime, AppLocalizations l10n) {
    return DateFormat('EEEE h:mm a', l10n.localeName).format(dateTime.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isUnread = !notification.isRead;
    final actorName =
        notification.actor?.displayName ?? l10n.notificationSomeone;
    final relativeTime = formatInboxTime(notification.createdAt, l10n);
    final detailTime = _detailTimestamp(notification.createdAt, l10n);
    final actionPhrase = NotificationDisplayText.actionPhrase(l10n, notification);
    final thumbnailUrl = _resolveThumbnailUrl();
    final showContextTag = NotificationDisplayText.hasPostContext(notification);
    final contextLabel = NotificationDisplayText.postContextLabel(notification);
    final resolvedContextLabel =
        contextLabel.isNotEmpty ? contextLabel : l10n.notificationContextPost;
    final (typeIcon, typeColor) =
        NotificationTypeStyle.forType(notification.type);
    final isAdmin =
        NotificationAdminHelper.isAdminNotificationEntity(notification);

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: NotificationsLayoutConstants.cardPadding,
                vertical: NotificationsLayoutConstants.itemVerticalPadding,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  isAdmin
                      ? _NotificationIconAvatar(
                          icon: typeIcon,
                          color: typeColor,
                        )
                      : _AvatarWithStatus(
                          userId: notification.actor?.id,
                          imageUrl: notification.actor?.avatarUrl,
                          name: actorName,
                          username: notification.actor?.username,
                          fullName: notification.actor?.fullName,
                          badgeIcon: typeIcon,
                          badgeColor: typeColor,
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
                                          NotificationDisplayText.title(
                                            l10n,
                                            notification,
                                          ),
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          NotificationDisplayText.body(
                                            l10n,
                                            notification,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            height: 1.35,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.72),
                                          ),
                                        ),
                                      ],
                                    )
                                  : _ActionRichText(
                                      actorName: actorName,
                                      actionPhrase: actionPhrase,
                                      contextTag: showContextTag
                                          ? _ContextTag(
                                              label: resolvedContextLabel,
                                              color: typeColor,
                                              icon: _contextIcon(
                                                notification.type,
                                              ),
                                            )
                                          : null,
                                    ),
                            ),
                            const SizedBox(width: AppSizes.p8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (relativeTime.isNotEmpty)
                                  Text(
                                    relativeTime,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.65),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                if (isUnread) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    width:
                                        NotificationsLayoutConstants.unreadDotSize,
                                    height:
                                        NotificationsLayoutConstants.unreadDotSize,
                                    decoration: const BoxDecoration(
                                      color:
                                          NotificationsLayoutConstants.unreadDotColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        if (!_hasCustomCopy) ...[
                          const SizedBox(height: 4),
                          Text(
                            detailTime,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                        if (_isFollowRequest &&
                            onAccept != null &&
                            onDecline != null) ...[
                          const SizedBox(height: AppSizes.p12),
                          Row(
                            children: [
                              Expanded(
                                child: _ActionButton(
                                  label: l10n.notificationsDecline,
                                  filled: false,
                                  onTap: onDecline!,
                                ),
                              ),
                              const SizedBox(width: AppSizes.p8),
                              Expanded(
                                child: _ActionButton(
                                  label: l10n.notificationsAccept,
                                  filled: true,
                                  onTap: onAccept!,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (thumbnailUrl != null) ...[
                          const SizedBox(height: AppSizes.p12),
                          _MediaPreviewCard(
                            thumbnailUrl: thumbnailUrl,
                            title: resolvedContextLabel,
                            subtitle: _mediaSubtitle(l10n),
                            onTap: onTap,
                          ),
                        ] else if (notification.comment?.content
                                ?.trim()
                                .isNotEmpty ==
                            true) ...[
                          const SizedBox(height: AppSizes.p10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSizes.p10),
                            decoration: BoxDecoration(
                              color: NotificationsLayoutConstants
                                  .mediaCardBackground(theme),
                              borderRadius: BorderRadius.circular(
                                NotificationsLayoutConstants.mediaCardRadius,
                              ),
                            ),
                            child: Text(
                              notification.comment!.content!.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                height: 1.35,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.75),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: NotificationsLayoutConstants.cardPadding,
            ),
            child: DottedDivider(
              color: NotificationsLayoutConstants.dottedDividerColor(theme),
            ),
          ),
      ],
    );
  }

  String _mediaSubtitle(AppLocalizations l10n) {
    final postType = notification.post?.type?.toLowerCase();
    if (postType != null && postType.contains('video')) {
      return l10n.notificationMediaVideo;
    }
    if (postType != null && postType.contains('image')) {
      return l10n.notificationMediaImage;
    }
  return l10n.notificationContextPost;
  }

  IconData _contextIcon(String type) {
    return switch (type) {
      'AUCTION_UPDATE' || 'AUCTION_WON' => LucideIcons.gavel,
      'MENTION' || 'REPOST' => LucideIcons.sparkles,
      _ => LucideIcons.image,
    };
  }
}

class _NotificationIconAvatar extends StatelessWidget {
  const _NotificationIconAvatar({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final size = NotificationsLayoutConstants.avatarRadius * 2;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.95),
            color.withValues(alpha: 0.72),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, size: 20, color: Colors.white),
    );
  }
}

class _AvatarWithStatus extends StatelessWidget {
  const _AvatarWithStatus({
    required this.userId,
    required this.imageUrl,
    required this.name,
    this.username,
    this.fullName,
    required this.badgeIcon,
    required this.badgeColor,
  });

  final String? userId;
  final String? imageUrl;
  final String name;
  final String? username;
  final String? fullName;
  final IconData badgeIcon;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        StoryProfileAvatar(
          userId: userId,
          imageUrl: imageUrl,
          radius: NotificationsLayoutConstants.avatarRadius,
          fallbackText: name,
          username: username,
          fullName: fullName,
        ),
        PositionedDirectional(
          end: -2,
          bottom: -2,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).cardColor,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: badgeColor.withValues(alpha: 0.35),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              badgeIcon,
              size: 10,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionRichText extends StatelessWidget {
  const _ActionRichText({
    required this.actorName,
    required this.actionPhrase,
    this.contextTag,
  });

  final String actorName;
  final String actionPhrase;
  final Widget? contextTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tag = contextTag;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        RichText(
          text: TextSpan(
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
            children: [
              TextSpan(
                text: actorName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(
                text: ' $actionPhrase',
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                ),
              ),
            ],
          ),
        ),
        if (tag != null) tag,
      ],
    );
  }
}

class _ContextTag extends StatelessWidget {
  const _ContextTag({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          NotificationsLayoutConstants.contextTagRadius,
        ),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        color: color.withValues(alpha: 0.06),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: filled ? theme.colorScheme.onSurface : theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          NotificationsLayoutConstants.actionButtonRadius,
        ),
        side: filled
            ? BorderSide.none
            : BorderSide(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: NotificationsLayoutConstants.actionButtonHeight,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: filled
                    ? theme.colorScheme.surface
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaPreviewCard extends StatelessWidget {
  const _MediaPreviewCard({
    required this.thumbnailUrl,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String thumbnailUrl;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVideo = MediaUtils.isVideo(thumbnailUrl);

    return Material(
      color: NotificationsLayoutConstants.mediaCardBackground(theme),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          NotificationsLayoutConstants.mediaCardRadius,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SafeNetworkImage(
                  imageUrl: thumbnailUrl,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorIcon: isVideo ? LucideIcons.video : LucideIcons.image,
                ),
              ),
              const SizedBox(width: AppSizes.p10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.download,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
