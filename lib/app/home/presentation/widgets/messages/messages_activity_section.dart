import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

enum MessagesActivityType {
  followers,
  activities,
  comments,
  mentions,
  notifications,
}

class MessagesActivitySection extends StatelessWidget {
  const MessagesActivitySection({
    required this.onActivityTap,
    this.hasUnreadNotifications = false,
    super.key,
  });

  final ValueChanged<MessagesActivityType> onActivityTap;
  final bool hasUnreadNotifications;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final activities = [
      (
        type: MessagesActivityType.followers,
        title: l10n.messagesActivityFollowers,
        icon: Icons.person_add_rounded,
        color: MessagesLayoutConstants.activityFollowersColor,
      ),
      (
        type: MessagesActivityType.activities,
        title: l10n.messagesActivityActivities,
        icon: Icons.favorite_rounded,
        color: MessagesLayoutConstants.activityLikesColor,
      ),
      (
        type: MessagesActivityType.comments,
        title: l10n.messagesActivityComments,
        icon: Icons.chat_bubble_rounded,
        color: MessagesLayoutConstants.activityCommentsColor,
      ),
      (
        type: MessagesActivityType.mentions,
        title: l10n.messagesActivityMentions,
        icon: Icons.alternate_email_rounded,
        color: MessagesLayoutConstants.activityMentionsColor,
      ),
      (
        type: MessagesActivityType.notifications,
        title: l10n.messagesActivityNotifications,
        icon: Icons.notifications_rounded,
        color: MessagesLayoutConstants.activityNotificationsColor,
      ),
    ];

    return SizedBox(
      height: MessagesLayoutConstants.activitySectionHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: MessagesLayoutConstants.horizontalPadding,
          vertical: 16,
        ),
        itemCount: activities.length,
        itemBuilder: (context, index) {
          final activity = activities[index];
          return InkWell(
            onTap: () => onActivityTap(activity.type),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                end: MessagesLayoutConstants.activityItemSpacing,
              ),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: MessagesLayoutConstants.activityIconSize,
                        height: MessagesLayoutConstants.activityIconSize,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              activity.color.withValues(alpha: 0.15),
                              activity.color.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                            MessagesLayoutConstants.activityIconRadius,
                          ),
                        ),
                        child: Icon(
                          activity.icon,
                          color: activity.color,
                          size: 26,
                        ),
                      ),
                      if (activity.type == MessagesActivityType.notifications &&
                          hasUnreadNotifications)
                        PositionedDirectional(
                          end: 2,
                          top: 2,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: MessagesLayoutConstants.activityBadgeColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.scaffoldBackgroundColor,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    activity.title,
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color?.withValues(
                        alpha: 0.8,
                      ),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
