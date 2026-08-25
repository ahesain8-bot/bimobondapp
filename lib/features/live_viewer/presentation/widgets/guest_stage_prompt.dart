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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        padding: const EdgeInsets.fromLTRB(8, 7, 10, 7),
        decoration: BoxDecoration(
          color: const Color(0xEB141418),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
          boxShadow: const [
            BoxShadow(color: Color(0x55000000), blurRadius: 14),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF35E07A),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            const Text(
              'أنت ضيف مباشر',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            _StageAction(
              key: const ValueKey('guest_compete_button'),
              icon: Icons.bolt_rounded,
              label: 'تنافس',
              color: const Color(0xFF25F4EE),
              foreground: Colors.black,
              busy: busy,
              onPressed: () => bloc.add(const LiveViewerCompetitionRequested()),
            ),
            const SizedBox(width: 7),
            _StageAction(
              key: const ValueKey('guest_leave_stage_button'),
              icon: Icons.call_end_rounded,
              label: 'خروج',
              color: const Color(0xFFFE2C55),
              foreground: Colors.white,
              busy: busy,
              onPressed: () => bloc.add(const LiveViewerLeftStage()),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageAction extends StatelessWidget {
  const _StageAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.foreground,
    required this.busy,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color foreground;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: FilledButton.icon(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.45),
          foregroundColor: foreground,
          disabledForegroundColor: foreground.withValues(alpha: 0.6),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: busy
            ? const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(strokeWidth: 1.7),
              )
            : Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
        ),
      ),
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
