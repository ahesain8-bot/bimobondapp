import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../domain/entities/live_guest.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_event.dart';
import '../../bloc/live_room/live_room_state.dart';

/// Actionable notice that a viewer asked to come on stage.
///
/// The pending count already shows as a chip in the info row, but that is a
/// number the host has to notice and then dig into a sheet to act on. A request
/// is a decision waiting on them, so it is answered right here.
class LiveRoomGuestRequestPrompt extends StatelessWidget {
  const LiveRoomGuestRequestPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveRoomBloc, LiveRoomState>(
      buildWhen: (previous, current) =>
          current is! LiveRoomReady ||
          previous is! LiveRoomReady ||
          previous.requestingGuests.length != current.requestingGuests.length ||
          (previous.requestingGuests.isNotEmpty &&
              current.requestingGuests.isNotEmpty &&
              previous.requestingGuests.first.userId !=
                  current.requestingGuests.first.userId),
      builder: (context, state) {
        if (state is! LiveRoomReady) return const SizedBox.shrink();
        final waiting = state.requestingGuests;
        if (waiting.isEmpty) return const SizedBox.shrink();

        // Answer them one at a time, oldest first: a stack of banners would
        // cover the stream, and the roster refreshes after every decision.
        return _RequestBar(guest: waiting.first, queued: waiting.length - 1);
      },
    );
  }
}

class _RequestBar extends StatelessWidget {
  const _RequestBar({required this.guest, required this.queued});

  final LiveGuest guest;

  /// How many more are waiting behind this one.
  final int queued;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<LiveRoomBloc>();
    final scale = MediaQuery.textScalerOf(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: const Color(0xF21A1A22),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              _Avatar(url: guest.avatarUrl),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      guest.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      queued > 0
                          ? 'يطلب الانضمام إلى المسرح · و$queued بالانتظار'
                          : 'يطلب الانضمام إلى المسرح',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              // Buttons keep their own width as the text scales, so a large
              // font setting shrinks the name rather than pushing them out.
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: scale.scale(160)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => bloc.add(
                        LiveRoomGuestRequestAnswered(
                          userId: guest.userId,
                          accepted: false,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white60,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: const Text('رفض'),
                    ),
                    const SizedBox(width: 4),
                    FilledButton(
                      onPressed: () => bloc.add(
                        LiveRoomGuestRequestAnswered(
                          userId: guest.userId,
                          accepted: true,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF20D5EC),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: const Text('قبول'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.14),
        image: url != null && url!.isNotEmpty
            ? DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover)
            : null,
      ),
      child: url != null && url!.isNotEmpty
          ? null
          : const Icon(Icons.person, size: 16, color: Colors.white70),
    );
  }
}
