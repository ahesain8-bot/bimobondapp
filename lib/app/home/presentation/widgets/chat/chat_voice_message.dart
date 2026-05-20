import 'dart:math' as math;

import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';

class ChatVoiceMessageWidget extends StatelessWidget {
  const ChatVoiceMessageWidget({
    super.key,
    required this.isMe,
    required this.duration,
  });

  final bool isMe;
  final String duration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    return SizedBox(
      width: ChatLayoutConstants.voiceMessageWidth,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p12),
        child: Row(
          children: [
            Icon(
              Icons.play_arrow_rounded,
              color: isMe
                  ? chatTheme.onSentBubble
                  : theme.colorScheme.primary,
              size: ChatLayoutConstants.voicePlayIconSize,
            ),
            const SizedBox(width: AppSizes.p8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChatVoiceWaveform(isMe: isMe),
                  const SizedBox(height: AppSizes.p4),
                  Text(
                    duration,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isMe
                          ? chatTheme.onSentBubbleMuted
                          : theme.textTheme.bodySmall?.color,
                      fontSize: ChatLayoutConstants.voiceDurationFontSize,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatVoiceWaveform extends StatelessWidget {
  const ChatVoiceWaveform({required this.isMe});

  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(ChatLayoutConstants.voiceWaveBarCount, (index) {
        return Container(
          width: ChatLayoutConstants.voiceWaveBarWidth,
          height:
              ChatLayoutConstants.voiceWaveBarMinHeight +
              math.Random().nextInt(
                ChatLayoutConstants.voiceWaveBarMaxExtra,
              ).toDouble(),
          decoration: BoxDecoration(
            color: isMe
                ? chatTheme.onSentBubble.withValues(
                    alpha: ChatLayoutConstants.voiceWaveSentAlpha,
                  )
                : theme.colorScheme.primary.withValues(
                    alpha: ChatLayoutConstants.voiceWavePrimaryAlpha,
                  ),
            borderRadius: BorderRadius.circular(
              ChatLayoutConstants.voiceWaveBarRadius,
            ),
          ),
        );
      }),
    );
  }
}
