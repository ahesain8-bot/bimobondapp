import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/core/widgets/directional_back_icon.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({
    required this.username,
    required this.imageUrl,
    required this.onProfileTap,
    this.userId,
    this.isPeerActive = false,
    super.key,
  });

  final String username;
  final String imageUrl;
  final VoidCallback onProfileTap;
  final String? userId;
  final bool isPeerActive;

  @override
  Size get preferredSize => Size.fromHeight(ChatLayoutConstants.appBarHeight);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Material(
      color: theme.scaffoldBackgroundColor,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: ChatLayoutConstants.appBarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.p4),
            child: Row(
              children: [
                IconButton(
                  icon: DirectionalBackIcon(
                    color: onSurface,
                    size: ChatLayoutConstants.appBarLeadingIconSize,
                  ),
                  onPressed: () => context.pop(),
                ),
                Expanded(
                  child: InkWell(
                    onTap: onProfileTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.p4,
                        vertical: AppSizes.p4,
                      ),
                      child: Row(
                        children: [
                          StoryProfileAvatar(
                            userId: userId,
                            imageUrl: imageUrl,
                            radius: ChatLayoutConstants.headerAvatarRadius,
                            fallbackText: username,
                            username: username,
                            fullName: username,
                            onTap: onProfileTap,
                          ),
                          const SizedBox(width: AppSizes.p10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: isRtl
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  username,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontSize:
                                        ChatLayoutConstants.headerTitleFontSize,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: ChatLayoutConstants
                                        .headerTitleLetterSpacing,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  isPeerActive
                                      ? l10n.chatActiveNow
                                      : l10n.chatActiveYesterday,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: isPeerActive
                                        ? chatTheme.activeStatus
                                        : chatTheme.inboxSecondaryText,
                                    fontSize:
                                        ChatLayoutConstants.headerStatusFontSize,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    LucideIcons.flag,
                    color: onSurface,
                    size: ChatLayoutConstants.appBarActionIconSize,
                  ),
                  onPressed: () {},
                ),
                IconButton(
                  icon: Icon(
                    LucideIcons.ellipsis,
                    color: onSurface,
                    size: ChatLayoutConstants.appBarActionIconSize,
                  ),
                  tooltip: l10n.settingsChatWallpaper,
                  onPressed: () =>
                      context.pushNamed('chat_wallpaper_settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
