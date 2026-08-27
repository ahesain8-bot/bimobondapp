import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/models/live_competition_request.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_event.dart';
import '../../bloc/live_room/live_room_state.dart';
import 'live_room_battle_opponents_sheet.dart';

/// Persistent host decision for a guest's competition request.
///
/// A normal chat line is not actionable and disappears as the feed moves.
/// This card stays immediately above the room controls until the host answers.
class LiveRoomCompetitionRequestPrompt extends StatelessWidget {
  const LiveRoomCompetitionRequestPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveRoomBloc, LiveRoomState>(
      buildWhen: (previous, current) =>
          current is! LiveRoomReady ||
          previous is! LiveRoomReady ||
          previous.pendingCompetitionRequest !=
              current.pendingCompetitionRequest ||
          previous.isCompetitionActionBusy != current.isCompetitionActionBusy,
      builder: (context, state) {
        if (state is! LiveRoomReady) return const SizedBox.shrink();
        final request = state.pendingCompetitionRequest;
        if (request == null || state.isBattleActive) {
          return const SizedBox.shrink();
        }
        final bloc = context.read<LiveRoomBloc>();
        return LiveRoomCompetitionRequestCard(
          request: request,
          busy: state.isCompetitionActionBusy,
          onRejected: () => bloc.add(
            LiveRoomCompetitionRequestAnswered(
              commentId: request.commentId,
              accepted: false,
            ),
          ),
          // Accepting retires the request, then opens the opponent picker: a
          // PK is live-vs-live, so the host still has to choose which
          // broadcast to go up against (or tap quick-match inside the sheet).
          onAccepted: () {
            bloc.add(
              LiveRoomCompetitionRequestAnswered(
                commentId: request.commentId,
                accepted: true,
              ),
            );
            LiveRoomBattleOpponentsSheet.show(context);
          },
        );
      },
    );
  }
}

/// Public pure card so its small-screen layout and taps can be widget-tested
/// without constructing the host's camera/network dependencies.
class LiveRoomCompetitionRequestCard extends StatelessWidget {
  const LiveRoomCompetitionRequestCard({
    super.key,
    required this.request,
    required this.busy,
    required this.onRejected,
    required this.onAccepted,
  });

  final LiveCompetitionRequest request;
  final bool busy;
  final VoidCallback onRejected;
  final VoidCallback onAccepted;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        key: const ValueKey('competition_request_card'),
        color: const Color(0xF21A1A22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _Avatar(url: request.avatarUrl),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          request.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'يطلب بدء جولة منافسة مباشرة',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(
                    Icons.sports_martial_arts_rounded,
                    color: Color(0xFFFF2D6F),
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      key: const ValueKey('competition_reject_button'),
                      onPressed: busy ? null : onRejected,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                        minimumSize: const Size(0, 38),
                      ),
                      child: const Text('رفض'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      key: const ValueKey('competition_accept_button'),
                      onPressed: busy ? null : onAccepted,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF2D6F),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 38),
                      ),
                      icon: busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.bolt_rounded, size: 17),
                      label: Text(busy ? 'جاري البدء…' : 'بدء المنافسة'),
                    ),
                  ),
                ],
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
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.14),
        image: url != null && url!.isNotEmpty
            ? DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover)
            : null,
      ),
      child: url != null && url!.isNotEmpty
          ? null
          : const Icon(Icons.person, size: 17, color: Colors.white70),
    );
  }
}
