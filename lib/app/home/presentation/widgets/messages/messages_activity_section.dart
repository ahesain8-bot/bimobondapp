import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class MessagesActivitySection extends StatelessWidget {
  const MessagesActivitySection({required this.onActivityTap, super.key});

  final VoidCallback onActivityTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final activities = [
      (
        title: l10n.messagesActivityFollowers,
        icon: Icons.person_add_rounded,
        color: MessagesLayoutConstants.activityFollowersColor,
        badge: '2',
      ),
      (
        title: l10n.messagesActivityActivities,
        icon: Icons.favorite_rounded,
        color: MessagesLayoutConstants.activityLikesColor,
        badge: '12',
      ),
      (
        title: l10n.messagesActivityComments,
        icon: Icons.chat_bubble_rounded,
        color: MessagesLayoutConstants.activityCommentsColor,
        badge: null,
      ),
      (
        title: l10n.messagesActivityMentions,
        icon: Icons.alternate_email_rounded,
        color: MessagesLayoutConstants.activityMentionsColor,
        badge: '1',
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
            onTap: onActivityTap,
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
                      if (activity.badge != null)
                        PositionedDirectional(
                          top: -4,
                          end: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: MessagesLayoutConstants.activityBadgeColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.scaffoldBackgroundColor,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              activity.badge!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                              textAlign: TextAlign.center,
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
