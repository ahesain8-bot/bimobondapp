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

/// TikTok **creator** LIVE top chrome (LTR):
/// `[avatar · name · ♥ · likes chip]  ……  [supporters] [viewers] [X]`
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
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: LiveRoomProfilePill(
                    host: session.host,
                    followerCount: session.host.hostHeartCount,
                    likeCount: session.likeCount,
                  ),
                ),
                const SizedBox(width: 8),
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
                          '${session.viewerCount}',
                          style: AppTextStyles.roomCounter.copyWith(
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                _CloseButton(
                  onTap: () => context.read<LiveRoomBloc>().add(
                    const LiveRoomEndRequested(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Overlapping top-supporter faces — TikTok row beside the viewer count.
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

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: const SizedBox(
        width: 34,
        height: 34,
        child: Center(
          child: Icon(
            Icons.close_rounded,
            color: Colors.white,
            size: 24,
            shadows: [
              Shadow(
                color: Color(0x8C000000),
                blurRadius: 5,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
