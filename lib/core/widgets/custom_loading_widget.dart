import 'package:bimobondapp/core/utils/app_assets.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class CustomLoadingWidget extends StatelessWidget {
  final double size;
  final bool isFullScreen;
  final double? progress;
  final String? message;

  const CustomLoadingWidget({
    super.key,
    this.size = 120,
    this.isFullScreen = false,
    this.progress,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    Widget loadingContent = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Lottie.asset(
            AppAssets.loadingAnimation,
            width: size,
            height: size,
            fit: BoxFit.contain,
            repeat: true,
            errorBuilder: (context, error, stackTrace) {
              return SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: progress,
                  color: primaryColor,
                ),
              );
            },
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isFullScreen
                    ? Colors.white
                    : theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (progress != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: size * 1.5,
              child: LinearProgressIndicator(
                value: progress,
                color: primaryColor,
                backgroundColor: theme.colorScheme.secondary.withValues(
                  alpha: 0.2,
                ),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(progress! * 100).toInt()}%',
              style: theme.textTheme.labelSmall?.copyWith(
                color: isFullScreen
                    ? Colors.white70
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );

    if (isFullScreen) {
      return Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: loadingContent,
      );
    }

    return loadingContent;
  }
}
