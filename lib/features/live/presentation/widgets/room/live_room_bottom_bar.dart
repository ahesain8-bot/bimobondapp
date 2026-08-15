import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../core/utils/app_assets.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_event.dart';
import 'live_room_guests_sheet.dart';
import 'live_room_options_sheet.dart';
import 'live_room_people_sheet.dart';
import 'live_room_share_sheet.dart';

/// Bottom action bar rebuilt from the current vector reference.
class LiveRoomBottomBar extends StatelessWidget {
  const LiveRoomBottomBar({super.key});

  static const double _buttonSize = 42;
  static const double _leftInset = 8;
  static const double _rightInset = 12;
  static const double _chatShareGap = 14;
  static const double _shareEffectsGap = 14;
  static const double _effectsMoreGap = 9;
  static const double _rightGroupGap = 14;
  static const Color _buttonFill = Color(0xFF202022);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bloc = context.read<LiveRoomBloc>();

    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: EdgeInsets.fromLTRB(
        _leftInset,
        8,
        _rightInset,
        10 + bottomInset,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            _CircleSvgButton(
              asset: AppAssets.roomBarChat,
              iconWidth: 28,
              iconHeight: 28,
              onTap: () => bloc.add(const LiveRoomChatTapped()),
            ),
            const SizedBox(width: _chatShareGap),
            _CircleSvgButton(
              asset: AppAssets.roomBarShare,
              iconWidth: 27,
              iconHeight: 27,
              onTap: () {
                bloc.add(const LiveRoomShareTapped());
                LiveRoomShareSheet.show(context);
              },
            ),
            const SizedBox(width: _shareEffectsGap),
            _CircleSvgButton(
              asset: AppAssets.roomBarEffects,
              iconWidth: 27,
              iconHeight: 27,
              onTap: () => bloc.add(const LiveRoomEffectsTapped()),
            ),
            const SizedBox(width: _effectsMoreGap),
            _CircleSvgButton(
              asset: AppAssets.roomBarMore,
              iconWidth: 23,
              iconHeight: 23,
              onTap: () {
                bloc.add(const LiveRoomMoreTapped());
                LiveRoomOptionsSheet.show(context);
              },
            ),
            const Spacer(),
            _CircleSvgButton(
              asset: AppAssets.roomBarCollab,
              iconWidth: 32,
              iconHeight: 29,
              onTap: () {
                bloc.add(const LiveRoomCollabTapped());
                LiveRoomGuestsSheet.show(context);
              },
            ),
            const SizedBox(width: _rightGroupGap),
            _CircleSvgButton(
              asset: AppAssets.roomBarPeople,
              iconWidth: 31,
              iconHeight: 28,
              onTap: () {
                bloc.add(const LiveRoomViewersTapped());
                LiveRoomPeopleSheet.show(context);
              },
            ),
          ],
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
