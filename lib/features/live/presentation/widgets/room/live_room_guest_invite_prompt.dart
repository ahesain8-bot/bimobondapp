import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_event.dart';
import '../../bloc/live_room/live_room_state.dart';

/// Standing prompt for an invite onto someone else's stage.
///
/// The invite arrives on the personal `user_*` socket room, so it can land at
/// any moment. It is answered here rather than announced in a SnackBar: the
/// accept has to still be reachable a few seconds after it appeared.
class LiveRoomGuestInvitePrompt extends StatelessWidget {
  const LiveRoomGuestInvitePrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveRoomBloc, LiveRoomState>(
      buildWhen: (previous, current) =>
          current is! LiveRoomReady ||
          previous is! LiveRoomReady ||
          previous.pendingGuestInvite != current.pendingGuestInvite,
      builder: (context, state) {
        if (state is! LiveRoomReady) return const SizedBox.shrink();
        final invite = state.pendingGuestInvite;
        if (invite == null) return const SizedBox.shrink();

        final bloc = context.read<LiveRoomBloc>();
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Material(
            color: const Color(0xF21A1A1C),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_add_alt_1,
                    size: 18,
                    color: Color(0xFF20D5EC),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      invite.isCoHost
                          ? 'دعاك ${invite.hostName} للانضمام كمضيف مشارك'
                          : 'دعاك ${invite.hostName} للانضمام إلى المسرح',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => bloc.add(
                      const LiveRoomGuestInviteAnswered(accepted: false),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white60,
                    ),
                    child: const Text('رفض'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: () => bloc.add(
                      const LiveRoomGuestInviteAnswered(accepted: true),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF20D5EC),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('انضمام'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
