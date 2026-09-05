import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/entities/live_session_entity.dart';

/// Full-screen polished overlays for every live connection state.
class LiveStateOverlay extends StatelessWidget {
  final LiveConnectionState state;
  final String? message;
  final int reconnectAttempt;
  final VoidCallback? onRetry;
  final VoidCallback? onLeave;

  const LiveStateOverlay({
    super.key,
    required this.state,
    this.message,
    this.reconnectAttempt = 0,
    this.onRetry,
    this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final visible = !(state == LiveConnectionState.connected ||
        state == LiveConnectionState.idle ||
        state == LiveConnectionState.reconnecting);
    debugPrint('[LiveRoom] overlay state=${state.name} visible=$visible');
    if (!visible) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: _buildForState(context),
      ),
    );
  }

  Widget _buildForState(BuildContext context) {
    switch (state) {
      case LiveConnectionState.loading:
        return _Scrim(
          key: const ValueKey('loading'),
          child: _StatusBody(
            icon: Icons.live_tv,
            title: 'Loading live',
            subtitle: 'Fetching room details…',
            showSpinner: true,
          ),
        );
      case LiveConnectionState.connecting:
        return _Scrim(
          key: const ValueKey('connecting'),
          child: _StatusBody(
            icon: Icons.wifi_tethering,
            title: 'Connecting',
            subtitle: 'Joining LiveKit & realtime…',
            showSpinner: true,
          ),
        );
      case LiveConnectionState.reconnecting:
        // The player keeps the last rendered frame while LiveKit/Socket.IO
        // recover in the background. Do not expose transient disconnect UI.
        return const SizedBox.shrink();
      case LiveConnectionState.networkLost:
        return _Scrim(
          key: const ValueKey('network-lost'),
          child: _StatusBody(
            icon: Icons.wifi_off_rounded,
            title: 'Network lost',
            subtitle: message ?? 'The live video connection was lost',
            iconColor: AppColors.error,
            primaryLabel: 'Retry',
            onPrimary: onRetry,
            secondaryLabel: 'Leave',
            onSecondary: onLeave,
          ),
        );
      case LiveConnectionState.liveEnded:
        return _Scrim(
          key: const ValueKey('ended'),
          blur: true,
          child: _StatusBody(
            icon: Icons.videocam_off_rounded,
            title: 'Live ended',
            subtitle: message ?? 'The host ended this live',
            primaryLabel: 'Back to LIVE',
            onPrimary: onLeave,
          ),
        );
      case LiveConnectionState.banned:
        return _Scrim(
          key: const ValueKey('banned'),
          child: _StatusBody(
            icon: Icons.block,
            title: 'Banned',
            subtitle: message ?? 'You cannot watch this live',
            iconColor: AppColors.error,
            primaryLabel: 'Leave',
            onPrimary: onLeave,
          ),
        );
      case LiveConnectionState.error:
        return _Scrim(
          key: const ValueKey('error'),
          child: _StatusBody(
            icon: Icons.error_outline,
            title: 'Something went wrong',
            subtitle: message ?? 'Please try again',
            iconColor: AppColors.error,
            primaryLabel: 'Retry',
            onPrimary: onRetry,
            secondaryLabel: 'Leave',
            onSecondary: onLeave,
          ),
        );
      case LiveConnectionState.empty:
        return _Scrim(
          key: const ValueKey('empty'),
          child: _StatusBody(
            icon: Icons.search_off_rounded,
            title: 'Live not found',
            subtitle: 'This room may have ended or been removed',
            primaryLabel: 'Back',
            onPrimary: onLeave,
          ),
        );
      case LiveConnectionState.connected:
      case LiveConnectionState.idle:
        return const SizedBox.shrink();
    }
  }
}

class _Scrim extends StatelessWidget {
  final Widget child;
  final bool blur;

  const _Scrim({super.key, required this.child, this.blur = false});

  @override
  Widget build(BuildContext context) {
    debugPrint('[LiveRoom] greyScrim=true blur=$blur');
    return Container(
      color: Colors.black.withValues(alpha: blur ? 0.72 : 0.55),
      alignment: Alignment.center,
      child: child
          .animate()
          .fadeIn(duration: 250.ms)
          .scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1)),
    );
  }
}

class _StatusBody extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;
  final bool showSpinner;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _StatusBody({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.showSpinner = false,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, color: iconColor ?? Colors.white, size: 34),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: AppTextStyles.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (showSpinner) ...[
            const SizedBox(height: 22),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          ],
          if (primaryLabel != null) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onPrimary,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                minimumSize: const Size(180, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text(primaryLabel!),
            ),
          ],
          if (secondaryLabel != null) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: onSecondary,
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              child: Text(secondaryLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
