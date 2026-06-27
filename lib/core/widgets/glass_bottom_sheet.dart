import 'dart:ui';

import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/directional_chevron_icon.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Central API for modal bottom sheets with the app-wide glass style.
class GlassBottomSheet {
  GlassBottomSheet._();

  static const double _radius = 24;

  static Future<T?> open<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool isScrollControlled = false,
    Color? barrierColor,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.55),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(_radius)),
      ),
      builder: builder,
    );
  }

  static Future<T?> showActions<T>(
    BuildContext context, {
    String? title,
    required List<Widget> children,
    bool scrollable = false,
  }) {
    return open<T>(
      context,
      builder: (_) => GlassBottomSheetShell(
        title: title,
        scrollable: scrollable,
        children: children,
      ),
    );
  }

  static Future<void> showConfirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required String cancelLabel,
    required VoidCallback onConfirm,
    bool destructive = false,
  }) {
    return showActions<void>(
      context,
      title: title,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ),
        GlassBottomSheetListTile(
          label: cancelLabel,
          onTap: () => Navigator.pop(context),
        ),
        GlassBottomSheetListTile(
          label: confirmLabel,
          destructive: destructive,
          onTap: () {
            Navigator.pop(context);
            onConfirm();
          },
        ),
      ],
    );
  }

  static Future<T?> showContent<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    bool isScrollControlled = false,
    bool scrollable = false,
    bool showHandle = true,
    bool expand = false,
    EdgeInsetsGeometry? padding,
    bool adaptTheme = false,
  }) {
    return open<T>(
      context,
      isScrollControlled: isScrollControlled,
      builder: (ctx) {
        Widget body = GlassBottomSheetShell(
          title: title,
          scrollable: scrollable,
          showHandle: showHandle,
          expand: expand,
          child: padding == null ? child : Padding(padding: padding, child: child),
        );
        if (isScrollControlled) {
          body = Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: body,
          );
        }
        if (adaptTheme) {
          body = GlassBottomSheetTheme.wrap(ctx, body);
        }
        return body;
      },
    );
  }

  static Future<T?> showDraggable<T>(
    BuildContext context, {
    required Widget Function(BuildContext context, ScrollController controller)
    builder,
    double initialChildSize = 0.72,
    double minChildSize = 0.45,
    double maxChildSize = 0.92,
    bool adaptTheme = false,
    String? title,
    bool showHandle = true,
  }) {
    return open<T>(
      context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        expand: false,
        builder: (context, scrollController) {
          Widget body = GlassBottomSheetShell(
            expand: true,
            showHandle: showHandle,
            title: title,
            child: builder(context, scrollController),
          );
          if (adaptTheme) {
            body = GlassBottomSheetTheme.wrap(context, body);
          }
          return body;
        },
      ),
    );
  }
}

/// Frosted shell for bottom sheet content.
class GlassBottomSheetShell extends StatelessWidget {
  const GlassBottomSheetShell({
    this.children,
    this.child,
    this.title,
    this.scrollable = false,
    this.showHandle = true,
    this.expand = false,
    super.key,
  }) : assert(children != null || child != null);

  final String? title;
  final List<Widget>? children;
  final Widget? child;
  final bool scrollable;
  final bool showHandle;
  final bool expand;

  static Future<T?> show<T>(
    BuildContext context, {
    String? title,
    required List<Widget> children,
    bool scrollable = false,
  }) {
    return GlassBottomSheet.showActions<T>(
      context,
      title: title,
      children: children,
      scrollable: scrollable,
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.62;

    final Widget content;
    if (expand) {
      content = Expanded(child: child!);
    } else if (scrollable && children != null) {
      content = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ListView(shrinkWrap: true, children: children!),
      );
    } else if (scrollable) {
      content = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(child: child),
      );
    } else if (children != null) {
      content = Column(mainAxisSize: MainAxisSize.min, children: children!);
    } else {
      content = child!;
    }

    return GlassBottomSheetFrame(
      expand: expand,
      showHandle: showHandle,
      title: title,
      child: content,
    );
  }
}

/// Glass chrome only — use when the child manages its own layout.
class GlassBottomSheetFrame extends StatelessWidget {
  const GlassBottomSheetFrame({
    required this.child,
    this.title,
    this.showHandle = true,
    this.expand = false,
    super.key,
  });

  final Widget child;
  final String? title;
  final bool showHandle;
  final bool expand;

  static Widget handle({double width = 40, double height = 4}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  static BoxDecoration decoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.14),
          Colors.black.withValues(alpha: 0.9),
        ],
      ),
      border: Border(
        top: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: decoration(),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (showHandle) ...[
                  const SizedBox(height: 12),
                  handle(),
                ],
                if (title != null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        title!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else if (showHandle)
                  const SizedBox(height: 16),
                child,
                if (!expand) const SizedBox(height: AppSizes.p8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Theme overlay so existing list/form widgets read well on glass sheets.
class GlassBottomSheetTheme {
  GlassBottomSheetTheme._();

  static ThemeData adapt(ThemeData base) {
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      cardColor: Colors.white.withValues(alpha: 0.08),
      dividerColor: Colors.white.withValues(alpha: 0.15),
      iconTheme: base.iconTheme.copyWith(color: Colors.white),
      colorScheme: base.colorScheme.copyWith(
        surface: Colors.transparent,
        onSurface: Colors.white,
        onSurfaceVariant: Colors.white.withValues(alpha: 0.65),
        primary: Colors.white,
        outline: Colors.white.withValues(alpha: 0.2),
        outlineVariant: Colors.white.withValues(alpha: 0.2),
        surfaceContainerHighest: Colors.white.withValues(alpha: 0.1),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      listTileTheme: base.listTileTheme.copyWith(
        iconColor: Colors.white,
        textColor: Colors.white,
      ),
      tabBarTheme: base.tabBarTheme.copyWith(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.55),
        indicatorColor: Colors.white,
        dividerColor: Colors.white.withValues(alpha: 0.15),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
        fillColor: Colors.white.withValues(alpha: 0.1),
      ),
    );
  }

  static Widget wrap(BuildContext context, Widget child) {
    return Theme(
      data: adapt(Theme.of(context)),
      child: child,
    );
  }
}

class GlassBottomSheetActionTile extends StatelessWidget {
  const GlassBottomSheetActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.isSelected = false,
    this.showChevron = true,
    super.key,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isSelected;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    Widget? trailing;
    if (isSelected) {
      trailing = Icon(
        LucideIcons.check,
        color: Colors.white.withValues(alpha: 0.95),
        size: 20,
      );
    } else if (showChevron) {
      trailing = DirectionalChevronIcon(
        size: 20,
        color: Colors.white.withValues(alpha: 0.82),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withValues(alpha: 0.08),
        highlightColor: Colors.white.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: isSelected ? 0.18 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: isSelected ? 0.28 : 0.16,
                    ),
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class GlassBottomSheetListTile extends StatelessWidget {
  const GlassBottomSheetListTile({
    required this.label,
    required this.onTap,
    this.isSelected = false,
    this.icon,
    this.destructive = false,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final bool isSelected;
  final IconData? icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    if (icon != null) {
      return GlassBottomSheetActionTile(
        icon: icon!,
        label: label,
        isSelected: isSelected,
        showChevron: false,
        onTap: onTap,
      );
    }

    final color = destructive ? const Color(0xFFFF6B6B) : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isSelected)
                Icon(LucideIcons.check, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

IconData privacyIconForStatus(String status) {
  switch (status) {
    case 'FRIENDS':
      return LucideIcons.users;
    case 'PRIVATE':
      return LucideIcons.lock;
    default:
      return LucideIcons.globe;
  }
}
