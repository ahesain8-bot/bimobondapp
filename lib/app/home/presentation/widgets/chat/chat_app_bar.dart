import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
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
    super.key,
  });

  final String username;
  final String imageUrl;
  final VoidCallback onProfileTap;
  final String? userId;

  @override
  Size get preferredSize => Size.fromHeight(ChatLayoutConstants.appBarHeight);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    final primary = theme.colorScheme.primary;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(ChatLayoutConstants.appBarBottomRadius),
        bottomRight: Radius.circular(ChatLayoutConstants.appBarBottomRadius),
      ),
      child: Material(
        color: theme.colorScheme.surface,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: ChatLayoutConstants.appBarHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.p4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: theme.iconTheme.color,
                      size: ChatLayoutConstants.appBarLeadingIconSize,
                    ),
                    onPressed: () => context.pop(),
                  ),
                  InkWell(
                    onTap: onProfileTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.p4,
                        vertical: AppSizes.p4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
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
                          const SizedBox(width: AppSizes.p12),
                          Column(
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
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: ChatLayoutConstants
                                      .headerTitleLetterSpacing,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                l10n.chatActiveNow,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: chatTheme.activeStatus,
                                  fontSize:
                                      ChatLayoutConstants.headerStatusFontSize,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      LucideIcons.video,
                      color: primary,
                      size: ChatLayoutConstants.appBarActionIconSize,
                    ),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: Icon(
                      LucideIcons.info,
                      color: primary,
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
      ),
    );
  }
}
