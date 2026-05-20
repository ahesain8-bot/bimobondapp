import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final Color? backgroundColor;
  final bool showBackButton;
  final bool showBottomDivider;
  final VoidCallback? onBackPressed;
  final double elevation;

  const CustomAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.backgroundColor,
    this.showBackButton = true,
    this.showBottomDivider = false,
    this.onBackPressed,
    this.elevation = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultFgColor = theme.textTheme.bodyLarge?.color ?? theme.colorScheme.onSurface;

    return AppBar(
      title:
          titleWidget ??
          (title != null
              ? CustomText(title!, fontSize: 18, fontWeight: FontWeight.bold)
              : null),
      actions: actions,
      leading:
          leading ??
          (showBackButton && (context.canPop() || Navigator.canPop(context))
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: onBackPressed ?? () => context.pop(),
                )
              : null),
      centerTitle: centerTitle,
      backgroundColor: backgroundColor ?? Colors.transparent,
      foregroundColor: backgroundColor != null ? null : defaultFgColor,
      elevation: elevation,
      bottom: showBottomDivider
          ? PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(
                height: 1,
                color: theme.dividerColor,
              ),
            )
          : null,
      systemOverlayStyle: backgroundColor != null
          ? (ThemeData.estimateBrightnessForColor(backgroundColor!) == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark)
          : (theme.brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
    kToolbarHeight + (showBottomDivider ? 1 : 0),
  );
}
