import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

enum ActivityHubTab {
  all,
  comments,
  mentions,
  likes,
  followers,
}

extension ActivityHubTabX on ActivityHubTab {
  bool matches(String type) {
    return switch (this) {
      ActivityHubTab.all => true,
      ActivityHubTab.comments => const {
          'POST_COMMENT',
          'COMMENT_REPLY',
        }.contains(type),
      ActivityHubTab.mentions => type == 'MENTION',
      ActivityHubTab.likes => const {
          'POST_LIKE',
          'COMMENT_LIKE',
        }.contains(type),
      ActivityHubTab.followers => const {
          'NEW_FOLLOWER',
          'FOLLOW_REQUEST',
          'FOLLOW_REQUEST_ACCEPTED',
        }.contains(type),
    };
  }

  String label(AppLocalizations l10n) {
    return switch (this) {
      ActivityHubTab.all => l10n.notificationsFilterAll,
      ActivityHubTab.comments => l10n.messagesActivityComments,
      ActivityHubTab.mentions => l10n.messagesActivityMentions,
      ActivityHubTab.likes => l10n.activityTabLikes,
      ActivityHubTab.followers => l10n.messagesActivityFollowers,
    };
  }
}

/// Horizontal filter chips for the Activity hub.
class ActivityFilterTabs extends StatelessWidget {
  const ActivityFilterTabs({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final ActivityHubTab selected;
  final ValueChanged<ActivityHubTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: MessagesLayoutConstants.horizontalPadding,
        ),
        itemCount: ActivityHubTab.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tab = ActivityHubTab.values[index];
          final isSelected = tab == selected;
          return ChoiceChip(
            label: Text(tab.label(l10n)),
            selected: isSelected,
            onSelected: (_) => onSelected(tab),
            showCheckmark: false,
            selectedColor: theme.colorScheme.primary.withValues(alpha: 0.14),
            backgroundColor: chatTheme.inboxSearchFill,
            labelStyle: TextStyle(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 13,
            ),
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          );
        },
      ),
    );
  }
}
