import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../core/utils/app_assets.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_event.dart';
import 'live_room_guests_sheet.dart';
import 'live_room_options_sheet.dart';
import 'live_room_share_sheet.dart';

/// Host LIVE bottom bar — TikTok creator order:
/// `[guests] [beauty] [share] [more]`
class LiveRoomBottomBar extends StatelessWidget {
  const LiveRoomBottomBar({super.key});

  static const double _buttonSize = 36;
  static const double _actionGap = 6;
  static const Color _buttonFill = Color(0x85202024);

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<LiveRoomBloc>();

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            height: 42,
            child: Row(
              children: [
                const Spacer(),
                _CircleSvgButton(
                  asset: AppAssets.roomBarCollab,
                  iconWidth: 28,
                  iconHeight: 25,
                  onTap: () {
                    LiveRoomGuestsSheet.show(context);
                  },
                ),
                const SizedBox(width: _actionGap),
                _CircleSvgButton(
                  asset: AppAssets.roomBarEffects,
                  iconWidth: 25,
                  iconHeight: 25,
                  onTap: () => bloc.add(const LiveRoomEffectsTapped()),
                ),
                const SizedBox(width: _actionGap),
                _CircleSvgButton(
                  asset: AppAssets.roomBarShare,
                  iconWidth: 25,
                  iconHeight: 25,
                  onTap: () {
                    bloc.add(const LiveRoomShareTapped());
                    LiveRoomShareSheet.show(context);
                  },
                ),
                const SizedBox(width: _actionGap),
                _CircleSvgButton(
                  asset: AppAssets.roomBarMore,
                  iconWidth: 22,
                  iconHeight: 22,
                  onTap: () {
                    bloc.add(const LiveRoomMoreTapped());
                    LiveRoomOptionsSheet.show(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleSvgButton extends StatelessWidget {
  const _CircleSvgButton({
    required this.asset,
    required this.iconWidth,
    required this.iconHeight,
    required this.onTap,
  });

  final String asset;
  final double iconWidth;
  final double iconHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: LiveRoomBottomBar._buttonSize,
        height: LiveRoomBottomBar._buttonSize,
        decoration: BoxDecoration(
          color: LiveRoomBottomBar._buttonFill,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: SvgPicture.asset(asset, width: iconWidth, height: iconHeight),
      ),
    );
  }
}
