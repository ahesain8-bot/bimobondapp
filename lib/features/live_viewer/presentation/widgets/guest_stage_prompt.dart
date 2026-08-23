import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/live_viewer/live_viewer_bloc.dart';
import '../bloc/live_viewer/live_viewer_event.dart';
import '../bloc/live_viewer/live_viewer_state.dart';

/// Standing prompt for an invite onto the host's stage, plus the control to
/// step back off it once you are up there.
///
/// Both live in one widget because they occupy the same slot and are mutually
/// exclusive: you are either being asked, or already on.
class GuestStagePrompt extends StatelessWidget {
  const GuestStagePrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveViewerBloc, LiveViewerState>(
      buildWhen: (prev, curr) =>
          prev.pendingGuestInvite != curr.pendingGuestInvite ||
          prev.isOnStage != curr.isOnStage ||
          prev.isGuestActionBusy != curr.isGuestActionBusy,
      builder: (context, state) {
        final invite = state.pendingGuestInvite;
        if (invite != null) {
          return _InviteBar(
            hostName: invite.hostName,
            isCoHost: invite.isCoHost,
            busy: state.isGuestActionBusy,
          );
        }
        if (state.isOnStage) {
          return _OnStageBar(busy: state.isGuestActionBusy);
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _InviteBar extends StatelessWidget {
  const _InviteBar({
    required this.hostName,
    required this.isCoHost,
    required this.busy,
  });

  final String hostName;
  final bool isCoHost;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<LiveViewerBloc>();
    return _Bar(
      icon: Icons.person_add_alt_1,
      iconColor: const Color(0xFF20D5EC),
      label: isCoHost
          ? 'دعاك $hostName للانضمام كمضيف مشارك'
          : 'دعاك $hostName للانضمام إلى المسرح',
      actions: [
        TextButton(
          onPressed: busy
              ? null
              : () => bloc.add(
                  const LiveViewerGuestInviteAnswered(accepted: false),
                ),
          style: TextButton.styleFrom(foregroundColor: Colors.white60),
          child: const Text('رفض'),
        ),
        const SizedBox(width: 4),
        FilledButton(
          onPressed: busy
              ? null
              : () => bloc.add(
                  const LiveViewerGuestInviteAnswered(accepted: true),
                ),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF20D5EC),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: busy ? const _Spinner() : const Text('انضمام'),
        ),
      ],
    );
  }
}

class _OnStageBar extends StatelessWidget {
  const _OnStageBar({required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<LiveViewerBloc>();
    return _Bar(
      icon: Icons.videocam,
      iconColor: const Color(0xFF35E07A),
      label: 'أنت على المسرح الآن',
      actions: [
        FilledButton(
          onPressed: busy ? null : () => bloc.add(const LiveViewerLeftStage()),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFF2D55),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: busy ? const _Spinner() : const Text('مغادرة المسرح'),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.actions,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: const Color(0xF21A1A22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
