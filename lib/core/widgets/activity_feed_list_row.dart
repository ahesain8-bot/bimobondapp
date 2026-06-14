import 'package:bimobondapp/app/chats/presentation/utils/chat_message_mapper.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/core/constants/notifications_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/dotted_divider.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Flat activity row matching the notifications list (avatar, action line, dotted divider).
class ActivityFeedListRow extends StatelessWidget {
  const ActivityFeedListRow({
    required this.actorName,
    required this.actionPhrase,
    required this.onTap,
    this.userId,
    this.imageUrl,
    this.username,
    this.fullName,
    this.isFollowing,
    this.onAvatarTap,
    this.createdAt,
    this.detailSubtitle,
    this.extraPhrase,
    this.quoteText,
    this.contextTagLabel,
    this.contextTagColor,
    this.contextTagIcon,
    this.mediaThumbnailUrl,
    this.mediaTitle,
    this.mediaSubtitle,
    this.trailing,
    this.showDivider = true,
    this.showUsernameUnderName = false,
    this.compactPadding = false,
    this.badgeIcon,
    this.badgeColor,
    super.key,
  });

  final String actorName;
  final String actionPhrase;
  final VoidCallback onTap;
  final String? userId;
  final String? imageUrl;
  final String? username;
  final String? fullName;
  final bool? isFollowing;
  final VoidCallback? onAvatarTap;
  final DateTime? createdAt;
  final String? detailSubtitle;
  final String? extraPhrase;
  final String? quoteText;
  final String? contextTagLabel;
  final Color? contextTagColor;
  final IconData? contextTagIcon;
  final String? mediaThumbnailUrl;
  final String? mediaTitle;
  final String? mediaSubtitle;
  final Widget? trailing;
  final bool showDivider;
  final bool showUsernameUnderName;
  final bool compactPadding;
  final IconData? badgeIcon;
  final Color? badgeColor;

  String _detailTimestamp(DateTime dateTime, AppLocalizations l10n) {
    return DateFormat('EEEE h:mm a', l10n.localeName).format(dateTime.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final relativeTime = formatInboxTime(createdAt, l10n);
    final detailLine = detailSubtitle ??
        (createdAt != null ? _detailTimestamp(createdAt!, l10n) : null);
    final showContextTag =
        contextTagLabel != null && contextTagLabel!.trim().isNotEmpty;
    final tagColor = contextTagColor ?? theme.colorScheme.primary;

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: NotificationsLayoutConstants.cardPadding,
                vertical: compactPadding
                    ? AppSizes.p8
                    : NotificationsLayoutConstants.itemVerticalPadding,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ActivityFeedAvatarWithStatus(
                    userId: userId,
                    imageUrl: imageUrl,
                    name: actorName,
                    username: username,
                    fullName: fullName,
                    isFollowing: isFollowing,
                    onTap: onAvatarTap,
                    badgeIcon: badgeIcon,
                    badgeColor: badgeColor,
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
                              child: showUsernameUnderName
                                  ? ActivityFeedNameHeader(
                                      displayName: actorName,
                                      username: username,
                                      actionPhrase: actionPhrase,
                                    )
                                  : ActivityFeedActionLine(
                                      actorName: actorName,
                                      actionPhrase: actionPhrase,
                                      extraPhrase: extraPhrase,
                                      contextTag: showContextTag
                                          ? ActivityFeedContextTag(
                                              label: contextTagLabel!.trim(),
                                              color: tagColor,
                                              icon: contextTagIcon ??
                                                  LucideIcons.image,
                                            )
                                          : null,
                                    ),
                            ),
                            if (trailing != null) ...[
                              const SizedBox(width: AppSizes.p8),
                              trailing!,
                            ] else if (relativeTime.isNotEmpty) ...[
                              const SizedBox(width: AppSizes.p8),
                              Text(
                                relativeTime,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.65),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (!showUsernameUnderName &&
                            detailLine != null &&
                            detailLine.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            detailLine,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                        if (quoteText != null && quoteText!.trim().isNotEmpty) ...[
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
                              quoteText!.trim(),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                height: 1.35,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.75),
                              ),
                            ),
                          ),
                        ],
                        if (mediaThumbnailUrl != null &&
                            mediaThumbnailUrl!.isNotEmpty) ...[
                          const SizedBox(height: AppSizes.p12),
                          ActivityFeedMediaPreviewCard(
                            thumbnailUrl: mediaThumbnailUrl!,
                            title: mediaTitle ?? '',
                            subtitle: mediaSubtitle ?? '',
                            onTap: onTap,
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
}

class ActivityFeedAvatarWithStatus extends StatelessWidget {
  const ActivityFeedAvatarWithStatus({
    required this.name,
    this.userId,
    this.imageUrl,
    this.username,
    this.fullName,
    this.isFollowing,
    this.onTap,
    this.badgeIcon,
    this.badgeColor,
    super.key,
  });

  final String name;
  final String? userId;
  final String? imageUrl;
  final String? username;
  final String? fullName;
  final bool? isFollowing;
  final VoidCallback? onTap;
  final IconData? badgeIcon;
  final Color? badgeColor;

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
          isFollowing: isFollowing,
          onTap: onTap,
        ),
        if (badgeIcon != null && badgeColor != null)
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
                    color: badgeColor!.withValues(alpha: 0.35),
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
          )
        else
          PositionedDirectional(
            end: 0,
            bottom: 0,
            child: Container(
              width: NotificationsLayoutConstants.statusDotSize,
              height: NotificationsLayoutConstants.statusDotSize,
              decoration: BoxDecoration(
                color: NotificationsLayoutConstants.unreadDotColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).cardColor,
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class ActivityFeedNameHeader extends StatelessWidget {
  const ActivityFeedNameHeader({
    required this.displayName,
    this.username,
    this.actionPhrase,
    super.key,
  });

  final String displayName;
  final String? username;
  final String? actionPhrase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final handle = username?.trim();
    final action = actionPhrase?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
            children: [
              TextSpan(
                text: displayName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (action != null && action.isNotEmpty)
                TextSpan(
                  text: ' $action',
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                  ),
                ),
            ],
          ),
        ),
        if (handle != null && handle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            '@$handle',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
              height: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}

class ActivityFeedActionLine extends StatelessWidget {
  const ActivityFeedActionLine({
    required this.actorName,
    required this.actionPhrase,
    this.extraPhrase,
    this.contextTag,
    super.key,
  });

  final String actorName;
  final String actionPhrase;
  final String? extraPhrase;
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
              if (extraPhrase != null && extraPhrase!.isNotEmpty)
                TextSpan(
                  text: ' · $extraPhrase',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
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

class ActivityFeedContextTag extends StatelessWidget {
  const ActivityFeedContextTag({
    required this.label,
    required this.color,
    required this.icon,
    super.key,
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

class ActivityFeedMediaPreviewCard extends StatelessWidget {
  const ActivityFeedMediaPreviewCard({
    required this.thumbnailUrl,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final String thumbnailUrl;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  errorIcon: MediaUtils.isVideo(thumbnailUrl)
                      ? LucideIcons.video
                      : LucideIcons.image,
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
                    if (subtitle.isNotEmpty)
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
