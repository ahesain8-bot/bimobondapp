import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../core/utils/app_assets.dart';
import '../../../../live_viewer/presentation/widgets/comment_input_bar.dart';
import '../../bloc/live_interactive/live_interactive_bloc.dart';
import '../../bloc/live_interactive/live_interactive_state.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_event.dart';
import '../../bloc/live_room/live_room_state.dart';
import 'live_interactive_tools.dart';
import 'live_room_guests_sheet.dart';
import 'live_room_options_sheet.dart';
import 'live_room_share_sheet.dart';

/// Host LIVE bottom bar — TikTok creator order:
/// `[comment] [interactions] [guests] [beauty] [share] [more]`
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
                const Expanded(child: _CommentSlot()),
                const SizedBox(width: 10),
                const _InteractionsButton(),
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

/// The host's half of the shared composer: the collapsed pill, swapped for the
/// viewer's [CommentInputBar] while the room state says the composer is open.
///
/// The bar keeps the visibility in [LiveRoomBloc] rather than local state
/// because the options menu can open the composer too.
class _CommentSlot extends StatelessWidget {
  const _CommentSlot();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveRoomBloc, LiveRoomState>(
      buildWhen: (previous, current) {
        if (previous is! LiveRoomReady || current is! LiveRoomReady) {
          return true;
        }
        return previous.isChatComposerVisible !=
                current.isChatComposerVisible ||
            previous.isSendingChat != current.isSendingChat;
      },
      builder: (context, state) {
        final bloc = context.read<LiveRoomBloc>();
        if (state is! LiveRoomReady || !state.isChatComposerVisible) {
          return CommentPromptPill(
            onTap: () => bloc.add(const LiveRoomChatTapped()),
          );
        }
        return Align(
          alignment: Alignment.bottomCenter,
          child: CommentInputBar(
            // Matches the viewer, so the pill and the field it opens into
            // read the same on both sides of the stream.
            hintText: 'Comment',
            isSending: state.isSendingChat,
            onSend: (text) => bloc.add(LiveRoomChatMessageSubmitted(text)),
            onDismiss: () => bloc.add(const LiveRoomChatComposerClosed()),
          ),
        );
      },
    );
  }
}

/// Entry point to everything the host can start mid-stream. Hidden until the
/// session has an id, since none of the actions can be dispatched before then.
class _InteractionsButton extends StatelessWidget {
  const _InteractionsButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveInteractiveBloc, LiveInteractiveState>(
      buildWhen: (previous, current) =>
          previous.hasLiveId != current.hasLiveId,
      builder: (context, state) {
        if (!state.hasLiveId) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(right: LiveRoomBottomBar._actionGap),
          child: _CircleButton(
            semanticsLabel: LiveInteractiveTools.label,
            onTap: () => LiveInteractiveTools.showHostSheet(context),
            child: const Icon(
              LiveInteractiveTools.icon,
              color: Colors.white,
              size: 20,
            ),
          ),
        );
      },
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
    return _CircleButton(
      onTap: onTap,
      child: SvgPicture.asset(asset, width: iconWidth, height: iconHeight),
    );
  }
}

/// The scrimmed disc every host bar control sits in.
class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.onTap,
    required this.child,
    this.semanticsLabel,
  });

  final VoidCallback onTap;
  final Widget child;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: GestureDetector(
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
          child: child,
        ),
      ),
    );
  }
}
