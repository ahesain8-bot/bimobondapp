import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../core/utils/app_assets.dart';
import '../../../../../core/utils/app_text_styles.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_event.dart';
import '../../bloc/live_room/live_room_state.dart';
import '../../../../../core/widgets/safe_network_image.dart';
import 'live_room_people_sheet.dart';
import 'live_room_ranking_sheet.dart';
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
          (previous is! LiveRoomReady ||
              previous.session != current.session ||
              previous.topGifterAvatars != current.topGifterAvatars),
      builder: (context, state) {
        if (state is! LiveRoomReady) {
          return const SizedBox.shrink();
        }

        final session = state.session;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            textDirection: TextDirection.ltr,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Start (right): profile then likes → visual [likes][profile]
              LiveRoomProfilePill(
                host: session.host,
                followerCount: session.host.hostHeartCount,
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => context.read<LiveRoomBloc>().add(
                  const LiveRoomLikeTapped(),
                ),
                child: LiveRoomLikesPill(likeCount: session.likeCount),
              ),
              const Spacer(),
              // The supporter faces TikTok puts beside the viewer count. Tap
              // opens the ranking sheet, which is where the full leaderboard
              // already lives.
              if (state.topGifterAvatars.isNotEmpty) ...[
                GestureDetector(
                  onTap: () => LiveRoomRankingSheet.show(context),
                  child: _SupporterCluster(avatars: state.topGifterAvatars),
                ),
                const SizedBox(width: 6),
              ],
              GestureDetector(
                onTap: () {
                  context.read<LiveRoomBloc>().add(
                    const LiveRoomViewersTapped(),
                  );
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
                onTap: () => context.read<LiveRoomBloc>().add(
                  const LiveRoomEndRequested(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Overlapping top-supporter faces, highest rank on top — the row TikTok
/// draws next to the viewer count.
class _SupporterCluster extends StatelessWidget {
  const _SupporterCluster({required this.avatars});

  final List<String> avatars;

  static const double _size = 24;
  static const double _overlap = 8;

  @override
  Widget build(BuildContext context) {
    final shown = avatars.take(3).toList(growable: false);
    if (shown.isEmpty) return const SizedBox.shrink();
    final width = _size + (shown.length - 1) * (_size - _overlap);

    return SizedBox(
      width: width,
      height: _size,
      child: Stack(
        children: [
          // Painted in reverse so rank 1 ends up on top of the pile.
          for (var i = shown.length - 1; i >= 0; i--)
            Positioned(
              left: i * (_size - _overlap),
              child: Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                    width: 1.2,
                  ),
                ),
                child: ClipOval(
                  child: SafeNetworkImage(
                    imageUrl: shown[i],
                    width: _size,
                    height: _size,
                    blankOnError: true,
                    showLoadingIndicator: false,
                  ),
                ),
              ),
            ),
        ],
      ),
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
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.46),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        alignment: Alignment.center,
        child: SvgPicture.asset(AppAssets.roomPower, width: 18, height: 18),
      ),
    );
  }
}
