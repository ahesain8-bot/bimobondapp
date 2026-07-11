import 'dart:ui';

import 'package:bimobondapp/app/notifications/domain/entities/notification_entity.dart';
import 'package:bimobondapp/app/notifications/presentation/utils/notification_display_text.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

Future<void> showAdminNotificationDialog(
  BuildContext context, {
  required NotificationEntity notification,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0xFF4A4A4A).withValues(alpha: 0.85),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, _) {
      return _GlassNotificationDialog(notification: notification);
    },
    transitionBuilder: (context, animation, _, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class _GlassNotificationDialog extends StatelessWidget {
  const _GlassNotificationDialog({required this.notification});

  final NotificationEntity notification;

  static const _glassFill = Color(0x33FFFFFF);
  static const _glassBorder = Color(0x8FFFFFFF);
  static const _textColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = NotificationDisplayText.title(l10n, notification);
    final message = NotificationDisplayText.body(l10n, notification);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: _GlassPanel(
                  borderRadius: BorderRadius.circular(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const _GlassDivider(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 160),
                          child: SingleChildScrollView(
                            child: Text(
                              message,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _textColor.withValues(alpha: 0.92),
                                fontSize: 13,
                                height: 1.45,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const _GlassDivider(),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          child: SizedBox(
                            width: double.infinity,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              child: Text(
                                l10n.notificationsOk,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            _GlassPanel(
              borderRadius: BorderRadius.circular(999),
              child: const SizedBox(
                width: 58,
                height: AppSizes.buttonHeightLg,
                child: Icon(
                  LucideIcons.bell,
                  color: _textColor,
                  size: 26,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    required this.borderRadius,
  });

  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _GlassNotificationDialog._glassFill,
            borderRadius: borderRadius,
            border: Border.all(
              color: _GlassNotificationDialog._glassBorder,
              width: 1.2,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.22),
                Colors.white.withValues(alpha: 0.08),
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassDivider extends StatelessWidget {
  const _GlassDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: _GlassNotificationDialog._glassBorder,
    );
  }
}
