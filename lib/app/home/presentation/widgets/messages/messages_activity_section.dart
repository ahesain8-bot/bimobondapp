import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

enum MessagesActivityType {
  followers,
  activities,
  comments,
  mentions,
}

class MessagesActivitySection extends StatelessWidget {
  const MessagesActivitySection({
    required this.onActivityTap,
    super.key,
  });

  final ValueChanged<MessagesActivityType> onActivityTap;

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
