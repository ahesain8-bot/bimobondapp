import 'package:bimobondapp/core/error/error_message_resolver.dart';
import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_surface.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class PopupDialogs {
  static void showSuccessDialog(
    BuildContext context,
    String message, {
    String? title,
  }) {
    final l10n = AppLocalizations.of(context);
    _showTopNotification(
      context,
      title: title ?? l10n?.notificationSuccessTitle ?? 'Success',
      message: message,
    );
  }

  static void showErrorDialog(
    BuildContext context,
    String message, {
    String? title,
  }) {
    final l10n = AppLocalizations.of(context);
    _showTopNotification(
      context,
      title: title ?? l10n?.notificationErrorTitle ?? 'Error',
      message: message,
      isError: true,
    );
  }

  static void showErrorFrom(
    BuildContext context,
    Object error, {
    String? title,
  }) {
    showErrorDialog(
      context,
      ErrorMessageResolver.resolve(error),
      title: title,
    );
  }

  static void _showTopNotification(
    BuildContext context, {
    required String title,
    required String message,
    bool isError = false,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _AnimatedTopNotification(
        title: title,
        message: message,
        isError: isError,
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    overlay.insert(overlayEntry);
  }

  static void showLoadingDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: CustomLoadingWidget(isFullScreen: true, message: message),
      ),
    );
  }

  static void hideLoadingDialog(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  static Future<void> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required String cancelLabel,
    required VoidCallback onConfirm,
    bool destructive = false,
  }) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        content: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onConfirm();
            },
            child: Text(
              confirmLabel,
              style: destructive
                  ? TextStyle(color: theme.colorScheme.error)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationGlassStyle {
  const _NotificationGlassStyle._({
    required this.glassFill,
    required this.glassBorder,
    required this.titleColor,
    required this.messageColor,
    required this.closeColor,
    required this.accentColor,
  });

  factory _NotificationGlassStyle.of(BuildContext context, bool isError) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isError ? AppTheme.errorAccent : AppTheme.successAccent;

    return _NotificationGlassStyle._(
      glassFill: isDark ? const Color(0x40FFFFFF) : const Color(0xF0FFFFFF),
      glassBorder: isDark ? const Color(0x4DFFFFFF) : const Color(0x33000000),
      titleColor: isDark ? Colors.white : const Color(0xDE000000),
      messageColor: isDark
          ? Colors.white.withValues(alpha: 0.72)
          : const Color(0x99000000),
      closeColor: isDark
          ? Colors.white.withValues(alpha: 0.55)
          : Colors.black.withValues(alpha: 0.45),
      accentColor: accentColor,
    );
  }

  final Color glassFill;
  final Color glassBorder;
  final Color titleColor;
  final Color messageColor;
  final Color closeColor;
  final Color accentColor;
}

class _AnimatedTopNotification extends StatefulWidget {
  const _AnimatedTopNotification({
    required this.title,
    required this.message,
    required this.onDismiss,
    this.isError = false,
  });

  final String title;
  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  @override
  State<_AnimatedTopNotification> createState() =>
      _AnimatedTopNotificationState();
}

class _AnimatedTopNotificationState extends State<_AnimatedTopNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 280),
      vsync: this,
    );

    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(curve);

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(curve);

    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_isDismissing) _dismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_isDismissing) return;
    _isDismissing = true;
    await _controller.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final style = _NotificationGlassStyle.of(context, widget.isError);

    return Positioned(
      top: topPadding + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: LiquidGlassSurface(
                borderRadius: BorderRadius.circular(16),
                blurSigma: 24,
                backgroundColor: style.glassFill,
                borderColor: style.glassBorder,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LiquidGlassSurface(
                        borderRadius: BorderRadius.circular(12),
                        blurSigma: 12,
                        backgroundColor: style.accentColor.withValues(
                          alpha: 0.16,
                        ),
                        borderColor: style.accentColor.withValues(alpha: 0.35),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(
                            widget.isError
                                ? LucideIcons.circleX
                                : LucideIcons.circleCheck,
                            color: style.accentColor,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(
                                color: style.titleColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.message,
                              style: TextStyle(
                                color: style.messageColor,
                                fontSize: 14,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _dismiss,
                        child: Icon(
                          LucideIcons.x,
                          color: style.closeColor,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
