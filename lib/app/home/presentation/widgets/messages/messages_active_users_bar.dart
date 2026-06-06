import 'package:bimobondapp/app/home/presentation/utils/story_grouping.dart';
import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class MessagesActiveUsersBar extends StatelessWidget {
  const MessagesActiveUsersBar({
    required this.storyGroups,
    this.myStoryGroup,
    this.onAddStory,
    this.onOpenStoryGroup,
    this.isStoryGroupViewed,
    super.key,
  });

  final List<StoryUserGroup> storyGroups;
  final StoryUserGroup? myStoryGroup;
  final VoidCallback? onAddStory;
  final void Function(StoryUserGroup group)? onOpenStoryGroup;

  /// When false, the ring uses the primary gradient (unseen stories).
  final bool Function(StoryUserGroup group)? isStoryGroupViewed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final hasMyStories = (myStoryGroup?.stories.isNotEmpty ?? false);

    return SizedBox(
      height: MessagesLayoutConstants.activeUsersBarHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: MessagesLayoutConstants.horizontalPadding,
        ),
        itemCount: 1 + storyGroups.length,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _StoryAddItem(
              label: l10n.messagesYourStory,
              hasStories: hasMyStories,
              avatarUrl: myStoryGroup?.avatarUrl,
              displayName: myStoryGroup?.displayName,
              onViewStories: hasMyStories && myStoryGroup != null
                  ? () => onOpenStoryGroup?.call(myStoryGroup!)
                  : null,
              onAddStory: onAddStory,
            );
          }

          final group = storyGroups[index - 1];
          final viewed = isStoryGroupViewed?.call(group) ?? false;
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: GestureDetector(
              onTap: () => onOpenStoryGroup?.call(group),
              child: Column(
                children: [
                  _StoryRingAvatar(
                    imageUrl: group.avatarUrl,
                    fallbackText: group.displayName,
                    theme: theme,
                    isViewed: viewed,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    group.displayName.split(' ').first,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _StoryRingAvatar extends StatelessWidget {
  const _StoryRingAvatar({
    required this.imageUrl,
    required this.fallbackText,
    required this.theme,
    this.isViewed = false,
  });

  final String? imageUrl;
  final String fallbackText;
  final ThemeData theme;
  final bool isViewed;

  @override
  Widget build(BuildContext context) {
    final ringPadding = MessagesLayoutConstants.activeRingWidth;
    final grayRing = theme.colorScheme.onSurface.withValues(alpha: 0.28);

    return Container(
      padding: EdgeInsets.all(ringPadding),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isViewed
            ? null
            : LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.3),
                ],
              ),
        border: isViewed
            ? Border.all(color: grayRing, width: 2)
            : null,
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          shape: BoxShape.circle,
        ),
        child: SafeNetworkAvatar(
          imageUrl: imageUrl,
          radius: MessagesLayoutConstants.activeAvatarRadius,
          fallbackText: fallbackText,
        ),
      ),
    );
  }
}

class _StoryAddItem extends StatelessWidget {
  const _StoryAddItem({
    required this.label,
    required this.hasStories,
    this.avatarUrl,
    this.displayName,
    this.onViewStories,
    this.onAddStory,
  });

  final String label;
  final bool hasStories;
  final String? avatarUrl;
  final String? displayName;
  final VoidCallback? onViewStories;
  final VoidCallback? onAddStory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ringSize = MessagesLayoutConstants.activeStorySize;

    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 16),
      child: Column(
        children: [
          SizedBox(
            width: ringSize + 4,
            height: ringSize + 4,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  onTap: hasStories ? onViewStories : onAddStory,
                  child: hasStories
                      ? _StoryRingAvatar(
                          imageUrl: avatarUrl,
                          fallbackText: displayName ?? label,
                          theme: theme,
                          isViewed: false,
                        )
                      : Container(
                          width: ringSize,
                          height: ringSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.dividerColor.withValues(alpha: 0.1),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.add,
                              color: theme.colorScheme.primary,
                              size: 30,
                            ),
                          ),
                        ),
                ),
                if (hasStories && onAddStory != null)
                  PositionedDirectional(
                    end: -2,
                    bottom: -2,
                    child: GestureDetector(
                      onTap: onAddStory,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: MessagesLayoutConstants.activeStorySize + 8,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.7,
                ),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
