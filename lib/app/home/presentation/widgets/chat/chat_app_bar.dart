import 'package:bimobondapp/app/home/presentation/widgets/home_feed/home_tab_app_bar.dart';
import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({
    required this.username,
    required this.imageUrl,
    required this.onProfileTap,
    super.key,
  });

  final String username;
  final String imageUrl;
  final VoidCallback onProfileTap;

  @override
  Size get preferredSize =>
      const Size.fromHeight(ChatLayoutConstants.appBarHeight);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);

    return HomeTabAppBar(
      title: username,
      centerTitle: false,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: theme.iconTheme.color,
          size: ChatLayoutConstants.appBarLeadingIconSize,
        ),
        onPressed: () => context.pop(),
      ),
      titleWidget: InkWell(
        onTap: onProfileTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SafeNetworkAvatar(
              imageUrl: imageUrl,
              radius: ChatLayoutConstants.headerAvatarRadius,
              fallbackText: username,
            ),
            const SizedBox(width: AppSizes.p12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    username,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: ChatLayoutConstants.headerTitleFontSize,
                      fontWeight: FontWeight.w900,
                      letterSpacing:
                          ChatLayoutConstants.headerTitleLetterSpacing,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    l10n.chatActiveNow,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: chatTheme.activeStatus,
                      fontSize: ChatLayoutConstants.headerStatusFontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            LucideIcons.video,
            color: theme.colorScheme.primary,
            size: ChatLayoutConstants.appBarActionIconSize,
          ),
          onPressed: () {},
        ),
        IconButton(
          icon: Icon(
            LucideIcons.info,
            color: theme.colorScheme.primary,
            size: ChatLayoutConstants.appBarActionIconSize,
          ),
          tooltip: l10n.settingsChatWallpaper,
          onPressed: () => context.pushNamed('chat_wallpaper_settings'),
        ),
      ],
    );
  }
}
