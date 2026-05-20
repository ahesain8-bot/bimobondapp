import 'dart:ui';

import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';

/// Shared blurred app bar for home tabs (auctions, messages) and chat.
class HomeTabAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeTabAppBar({
    required this.title,
    this.leading,
    this.actions = const [],
    this.centerTitle = true,
    this.titleWidget,
    super.key,
  });

  final String title;
  final Widget? leading;
  final List<Widget> actions;
  final bool centerTitle;
  final Widget? titleWidget;

  @override
  Size get preferredSize =>
      const Size.fromHeight(MessagesLayoutConstants.appBarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final titleContent = titleWidget ??
        Text(
          title,
          style: TextStyle(
            color: theme.textTheme.bodyLarge?.color,
            fontWeight: FontWeight.w900,
            fontSize: MessagesLayoutConstants.inboxTitleFontSize,
            letterSpacing: -0.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: MessagesLayoutConstants.appBarBlurSigma,
          sigmaY: MessagesLayoutConstants.appBarBlurSigma,
        ),
        child: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor.withValues(
            alpha: MessagesLayoutConstants.appBarBackgroundAlpha,
          ),
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: MessagesLayoutConstants.appBarHeight,
          titleSpacing: 0,
          automaticallyImplyLeading: false,
          leading: leading,
          leadingWidth: leading != null ? 56 : null,
          centerTitle: centerTitle,
          title: centerTitle ? Center(child: titleContent) : titleContent,
          actions: [
            ...actions,
            const SizedBox(width: AppSizes.p4),
          ],
        ),
      ),
    );
  }
}

class HomeTabGlassIconButton extends StatelessWidget {
  const HomeTabGlassIconButton({
    required this.icon,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.p8),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(
            alpha: MessagesLayoutConstants.glassButtonAlpha,
          ),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: Icon(icon, color: theme.colorScheme.primary, size: 22),
          onPressed: onTap,
        ),
      ),
    );
  }
}
