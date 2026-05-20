import 'dart:math' as math;

import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ChatRecordingOverlay extends StatelessWidget {
  const ChatRecordingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);

    return Container(
      color: chatTheme.recordingScrim,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(
                ChatLayoutConstants.recordingMicPadding,
              ),
              decoration: BoxDecoration(
                color: theme.cardColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: chatTheme.bubbleShadow.withValues(alpha: 0.26),
                    blurRadius: ChatLayoutConstants.recordingShadowBlur,
                  ),
                ],
              ),
              child: Icon(
                LucideIcons.mic,
                color: theme.colorScheme.primary,
                size: ChatLayoutConstants.recordingMicSize,
              ),
            ),
            const SizedBox(height: AppSizes.p24),
            Text(
              l10n.chatRecording,
              style: theme.textTheme.titleMedium?.copyWith(
                color: chatTheme.recordingForeground,
                fontSize: ChatLayoutConstants.recordingTitleFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSizes.p8),
            Text(
              l10n.chatSlideUpToCancel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: chatTheme.recordingForegroundMuted,
                fontSize: ChatLayoutConstants.recordingSubtitleFontSize,
              ),
            ),
            const SizedBox(height: 40),
            const ChatRecordingWaveform(),
          ],
        ),
      ),
    );
  }
}

class ChatRecordingWaveform extends StatelessWidget {
  const ChatRecordingWaveform({super.key});

  @override
  Widget build(BuildContext context) {
    final chatTheme = ChatTheme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(ChatLayoutConstants.recordingWaveBarCount, (
        index,
      ) {
        return Container(
          width: ChatLayoutConstants.recordingWaveBarWidth,
          height:
              ChatLayoutConstants.recordingWaveBarMinHeight +
              math.Random().nextInt(
                ChatLayoutConstants.recordingWaveBarMaxExtra,
              ).toDouble(),
          margin: const EdgeInsets.symmetric(
            horizontal: ChatLayoutConstants.recordingWaveBarSpacing,
          ),
          decoration: BoxDecoration(
            color: chatTheme.waveformOnOverlay,
            borderRadius: BorderRadius.circular(
              ChatLayoutConstants.recordingWaveBarRadius,
            ),
          ),
        );
      }),
    );
  }
}
