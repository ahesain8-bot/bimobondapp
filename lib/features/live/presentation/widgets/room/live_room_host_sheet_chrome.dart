import 'package:flutter/material.dart';

import '../../../../../core/utils/app_colors.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/network/api_exceptions.dart';
import '../../../domain/repositories/live_session_repository.dart';

/// Shared dark-over-video sheet chrome for live-room host tools.
class LiveRoomHostSheetChrome extends StatelessWidget {
  const LiveRoomHostSheetChrome({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;

  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.optionsScrim,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Material(
            color: const Color(0xFF1A1A1C),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        ...?actions,
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.close, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white12),
                  Flexible(child: child),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

mixin LiveRoomHostSheetMixin<T extends StatefulWidget> on State<T> {
  LiveSessionRepository get repository;

  void snack(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, textAlign: TextAlign.center),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String errorMessage(Object error) {
    if (error is ApiException) return error.message;
    return error.toString();
  }
}

class LiveRoomSheetStatus extends StatelessWidget {
  const LiveRoomSheetStatus.loading({super.key})
      : message = null,
        icon = null,
        isError = false;

  const LiveRoomSheetStatus.empty({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
  }) : isError = false;

  const LiveRoomSheetStatus.error({
    super.key,
    required this.message,
    this.icon = Icons.error_outline,
  }) : isError = true;

  final String? message;
  final IconData? icon;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    if (message == null && icon == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 40,
              color: isError ? Colors.redAccent : Colors.white54,
            ),
            const SizedBox(height: 12),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isError ? Colors.redAccent.shade100 : Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
