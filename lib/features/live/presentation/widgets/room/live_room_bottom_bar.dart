import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../core/utils/app_assets.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_event.dart';
import 'live_room_guests_sheet.dart';
import 'live_room_options_sheet.dart';
import 'live_room_share_sheet.dart';

/// Host live bottom bar — TikTok LIVE order:
/// [Say something…] [share] [effects] [more] [guests]
class LiveRoomBottomBar extends StatelessWidget {
  const LiveRoomBottomBar({super.key});

  static const double _buttonSize = 42;
  static const double _actionGap = 8;
  static const Color _buttonFill = Color(0xFF202022);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bloc = context.read<LiveRoomBloc>();

    return Padding(
      padding: EdgeInsets.fromLTRB(10, 8, 10, 10 + bottomInset),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          height: _buttonSize,
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => bloc.add(const LiveRoomChatTapped()),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      'اكتب تعليقاً…',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _CircleSvgButton(
                asset: AppAssets.roomBarShare,
                iconWidth: 27,
                iconHeight: 27,
                onTap: () {
                  bloc.add(const LiveRoomShareTapped());
                  LiveRoomShareSheet.show(context);
                },
              ),
              const SizedBox(width: _actionGap),
              _CircleSvgButton(
                asset: AppAssets.roomBarEffects,
                iconWidth: 27,
                iconHeight: 27,
                onTap: () => bloc.add(const LiveRoomEffectsTapped()),
              ),
              const SizedBox(width: _actionGap),
              _CircleSvgButton(
                asset: AppAssets.roomBarMore,
                iconWidth: 23,
                iconHeight: 23,
                onTap: () {
                  bloc.add(const LiveRoomMoreTapped());
                  LiveRoomOptionsSheet.show(context);
                },
              ),
              const SizedBox(width: _actionGap),
              _CircleSvgButton(
                asset: AppAssets.roomBarCollab,
                iconWidth: 32,
                iconHeight: 29,
                onTap: () {
                  bloc.add(const LiveRoomCollabTapped());
                  LiveRoomGuestsSheet.show(context);
                },
              ),
            ],
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
        decoration: const BoxDecoration(
          color: LiveRoomBottomBar._buttonFill,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: SvgPicture.asset(
          asset,
          width: iconWidth,
          height: iconHeight,
        ),
      ),
    );
  }
}
