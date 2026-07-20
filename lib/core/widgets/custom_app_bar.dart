import 'package:bimobondapp/core/utils/app_bar_utils.dart';
import 'package:bimobondapp/core/utils/system_ui_overlay_utils.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/directional_back_icon.dart';
import 'package:flutter/material.dart';
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
  final bool hideBottomDivider;
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
    this.hideBottomDivider = false,
    this.onBackPressed,
    this.elevation = 0,
  });

  bool get _hasTitle =>
      titleWidget != null || (title != null && title!.isNotEmpty);

  bool get _showBottomDivider =>
      !hideBottomDivider && (showBottomDivider || _hasTitle);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultFgColor =
        theme.textTheme.bodyLarge?.color ?? theme.colorScheme.onSurface;

    final titleContent =
        titleWidget ??
        (title != null
            ? CustomText(title!, fontSize: 18, fontWeight: FontWeight.bold)
            : null);

    final backButton = showBackButton
        ? IconButton(
            icon: const DirectionalBackIcon(size: 20),
            onPressed: onBackPressed ??
                () {
                  if (context.canPop()) {
                    context.pop();
                  }
                },
          )
        : null;

    final resolvedLeading = leading ?? backButton;

    return AppBar(
      automaticallyImplyLeading: false,
      leadingWidth: resolvedLeading != null ? 48 : null,
      leading: resolvedLeading,
      centerTitle: centerTitle,
      title: centerTitle
          ? null
          : titleContent,
      actions: actions,
      flexibleSpace: centerTitle && titleContent != null
          ? SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 56),
                  child: titleContent,
                ),
              ),
            )
          : null,
      backgroundColor: backgroundColor ?? Colors.transparent,
      foregroundColor: defaultFgColor,
      elevation: elevation,
      bottom: _showBottomDivider ? const AppBarBottomDivider() : null,
      systemOverlayStyle: backgroundColor != null
          ? appContentSystemUiOverlayStyle(
              ThemeData.estimateBrightnessForColor(backgroundColor!),
            )
          : appContentSystemUiOverlayStyle(theme.brightness),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        AppBarBottomDivider.toolbarHeightWithDivider(
          kToolbarHeight,
          showDivider: _showBottomDivider,
        ),
      );
}
