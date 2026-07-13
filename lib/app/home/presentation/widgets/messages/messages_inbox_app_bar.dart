import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// TikTok-style inbox top bar: compose (+), Inbox title, search.
class MessagesInboxAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const MessagesInboxAppBar({
    required this.onComposeTap,
    required this.onSearchTap,
    this.onTitleTap,
    super.key,
  });

  final VoidCallback onComposeTap;
  final VoidCallback onSearchTap;
  final VoidCallback? onTitleTap;

  @override
  Size get preferredSize =>
      const Size.fromHeight(MessagesLayoutConstants.appBarHeight);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: MessagesLayoutConstants.appBarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: l10n.messagesNewConversation,
                  onPressed: onComposeTap,
                  icon: Icon(LucideIcons.plus, color: onSurface, size: 26),
                ),
                Expanded(
                  child: Center(
                    child: InkWell(
                      onTap: onTitleTap,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.messagesInboxTitle,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize:
                                    MessagesLayoutConstants.inboxTitleFontSize,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              LucideIcons.chevronDown,
                              size: 18,
                              color: onSurface.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppTheme.successAccent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.scaffoldBackgroundColor,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.messagesSearchHint,
                  onPressed: onSearchTap,
                  icon: Icon(
                    LucideIcons.search,
                    color: chatTheme.inboxSecondaryText,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
