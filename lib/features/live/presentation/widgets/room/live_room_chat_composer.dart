import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/utils/app_colors.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_event.dart';
import '../../bloc/live_room/live_room_state.dart';

/// Bottom chat composer shown when the host taps chat.
class LiveRoomChatComposer extends StatefulWidget {
  const LiveRoomChatComposer({super.key});

  @override
  State<LiveRoomChatComposer> createState() => _LiveRoomChatComposerState();
}

class _LiveRoomChatComposerState extends State<LiveRoomChatComposer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
        if (state is! LiveRoomReady || !state.isChatComposerVisible) {
          return const SizedBox.shrink();
        }

        return Material(
          color: Colors.black.withValues(alpha: 0.72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context
                      .read<LiveRoomBloc>()
                      .add(const LiveRoomChatComposerClosed()),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !state.isSendingChat,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'اكتب تعليقاً…',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                      filled: true,
                      fillColor: AppColors.overlayPill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _submit(context),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed:
                      state.isSendingChat ? null : () => _submit(context),
                  icon: state.isSendingChat
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _submit(BuildContext context) {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    context.read<LiveRoomBloc>().add(LiveRoomChatMessageSubmitted(text));
    _controller.clear();
  }
}
