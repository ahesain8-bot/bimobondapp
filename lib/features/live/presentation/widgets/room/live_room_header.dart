import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../core/utils/app_assets.dart';
import '../../../../../core/utils/app_text_styles.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_event.dart';
import '../../bloc/live_room/live_room_state.dart';
import 'live_room_people_sheet.dart';
import 'live_room_pill.dart';
import 'live_room_profile_pill.dart';

/// Top overlay matching the reference: profile+likes on start, power+viewers on end.
class LiveRoomHeader extends StatelessWidget {
  const LiveRoomHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveRoomBloc, LiveRoomState>(
      buildWhen: (previous, current) =>
          current is LiveRoomReady &&
          (previous is! LiveRoomReady || previous.session != current.session),
      builder: (context, state) {
        if (state is! LiveRoomReady) {
          return const SizedBox.shrink();
        }

        final session = state.session;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Start (right): profile then likes → visual [likes][profile]
              LiveRoomProfilePill(
                host: session.host,
                followerCount: session.host.hostHeartCount,
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => context
                    .read<LiveRoomBloc>()
                    .add(const LiveRoomLikeTapped()),
                child: LiveRoomLikesPill(likeCount: session.likeCount),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  context
                      .read<LiveRoomBloc>()
                      .add(const LiveRoomViewersTapped());
                  LiveRoomPeopleSheet.show(context);
                },
                child: LiveRoomPill(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        AppAssets.roomPerson,
                        width: 14,
                        height: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        session.viewerCount.toString().padLeft(2, '0'),
                        style: AppTextStyles.roomCounter.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _PowerButton(
                onTap: () => context
                    .read<LiveRoomBloc>()
                    .add(const LiveRoomEndRequested()),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PowerButton extends StatelessWidget {
  const _PowerButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: SvgPicture.asset(
          AppAssets.roomPower,
          width: 18,
          height: 18,
        ),
      ),
    );
  }
}
