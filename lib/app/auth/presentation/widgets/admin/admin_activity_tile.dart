import 'package:bimobondapp/app/auth/domain/entities/user_activity_entity.dart';
import 'package:bimobondapp/core/constants/settings_layout_constants.dart';
import 'package:bimobondapp/core/utils/admin_activity_labels.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/activity_feed_card.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AdminActivityTile extends StatelessWidget {
  const AdminActivityTile({
    required this.activity,
    required this.l10n,
    required this.onTap,
    super.key,
  });

  final UserActivityEntity activity;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  bool get _isTappable {
    if (activityPostId(activity) != null) return true;
    if (activity.type.toUpperCase() == 'SEND_GIFT' &&
        activityReceiverId(activity) != null) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, accent) = AdminActivityTypeStyle.forType(activity.type);
    final typeLabel = adminActivityTypeLabel(activity.type, l10n);
    final content = adminActivityContent(activity, l10n);
    final timeLabel = adminActivityTimeLabel(activity, l10n);
    final thumbnailUrl = activityThumbnailUrl(activity);

    return ActivityFeedCard(
      badgeColor: accent,
      badgeIcon: icon,
      showTypeBadge: false,
      onTap: _isTappable ? onTap : null,
      avatar: _AdminActivityTypeAvatar(color: accent, icon: icon),
      trailing: _AdminActivityTrailing(
        isTappable: _isTappable,
        thumbnailUrl: thumbnailUrl,
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  typeLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (timeLabel.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  timeLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.7,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          if (content.primary.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              content.primary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.35,
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.75,
                ),
              ),
            ),
          ],
          if (content.quote != null && content.quote!.isNotEmpty)
            ActivityFeedQuoteBox(text: content.quote!),
        ],
      ),
    );
  }
}

class _AdminActivityTypeAvatar extends StatelessWidget {
  const _AdminActivityTypeAvatar({
    required this.color,
    required this.icon,
  });

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: AppSizes.buttonHeightSm,
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
            color: color.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, size: 22, color: Colors.white),
    );
  }
}

class _AdminActivityTrailing extends StatelessWidget {
  const _AdminActivityTrailing({
    required this.isTappable,
    this.thumbnailUrl,
  });

  final bool isTappable;
  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SafeNetworkImage(
          imageUrl: thumbnailUrl!,
          width: 52,
          height: AppSizes.buttonHeightMd,
          fit: BoxFit.cover,
          errorIcon: Icons.image_outlined,
        ),
      );
    }

    if (!isTappable) return const SizedBox.shrink();

    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isRtl ? LucideIcons.chevronLeft : LucideIcons.chevronRight,
        size: SettingsLayoutConstants.chevronSize,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
      ),
    );
  }
}

class AdminActivityEmptyState extends StatelessWidget {
  const AdminActivityEmptyState({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.all(AppSizes.p32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.08),
              border: Border.all(color: accent.withValues(alpha: 0.12)),
            ),
            child: Icon(
              LucideIcons.activity,
              size: 32,
              color: accent.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: AppSizes.p16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminActivitySkeletonTile extends StatelessWidget {
  const AdminActivitySkeletonTile({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: AppSizes.p10),
      child: SkeletonWidget(height: 88, borderRadius: 18),
    );
  }
}
