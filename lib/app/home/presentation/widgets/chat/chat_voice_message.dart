import 'package:bimobondapp/app/home/presentation/utils/chat_voice_duration_formatter.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_voice_playback.dart';
import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class ChatVoiceMessageWidget extends StatefulWidget {
  const ChatVoiceMessageWidget({
    super.key,
    required this.messageId,
    required this.isMe,
    required this.duration,
    this.audioUrl,
  });

  final String messageId;
  final bool isMe;
  final String duration;
  final String? audioUrl;

  @override
  State<ChatVoiceMessageWidget> createState() => _ChatVoiceMessageWidgetState();
}

class _ChatVoiceMessageWidgetState extends State<ChatVoiceMessageWidget> {
  final ChatVoicePlayback _playback = ChatVoicePlayback.instance;
  bool _isLoading = false;

  bool get _canPlay =>
      widget.audioUrl != null && widget.audioUrl!.trim().isNotEmpty;

  bool get _isPlaying => _playback.isPlaying(widget.messageId);

  bool get _isActive => _playback.isActive(widget.messageId);

  double? get _progress => _playback.playbackProgress(widget.messageId);

  String get _timeLabel {
    if (_isActive) {
      final position = _playback.playbackPosition(widget.messageId);
      if (position != null) {
        return formatVoiceDurationLabel(position.inSeconds);
      }
    }
    return widget.duration;
  }

  @override
  void initState() {
    super.initState();
    _playback.addListener(_onPlaybackChanged);
  }

  @override
  void dispose() {
    _playback.removeListener(_onPlaybackChanged);
    super.dispose();
  }

  void _onPlaybackChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _onPlayTap() async {
    if (!_canPlay || _isLoading) return;

    setState(() => _isLoading = true);
    try {
      await _playback.toggle(widget.messageId, widget.audioUrl!.trim());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.chatVoicePlaybackFailed),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    final disabledAlpha = ChatLayoutConstants.voicePlayDisabledAlpha;

    return SizedBox(
      width: ChatLayoutConstants.voiceMessageWidth,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p12),
        // Keep play on the leading side before waveform (even in RTL chat).
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _canPlay ? _onPlayTap : null,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (widget.isMe
                              ? theme.colorScheme.primary
                              : Colors.white)
                          .withValues(
                        alpha: _canPlay ? 1.0 : disabledAlpha,
                      ),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: widget.isMe
                                  ? Colors.white
                                  : theme.colorScheme.primary,
                            ),
                          )
                        : Icon(
                            _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: widget.isMe
                                ? Colors.white
                                : theme.colorScheme.primary,
                            size: 24,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.p8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ChatVoiceWaveform(
                      isMe: widget.isMe,
                      progress: _progress,
                    ),
                    const SizedBox(height: AppSizes.p6),
                    Row(
                      children: [
                        Text(
                          _timeLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: widget.isMe
                                ? chatTheme.onSentBubbleMuted
                                : chatTheme.onReceivedBubbleMuted,
                            fontSize: ChatLayoutConstants.voiceDurationFontSize,
                            fontWeight: _isPlaying
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        if (_isPlaying) ...[
                          const SizedBox(width: AppSizes.p4),
                          Text(
                            '/ ${widget.duration}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: widget.isMe
                                  ? chatTheme.onSentBubbleMuted.withValues(
                                      alpha: 0.7,
                                    )
                                  : theme.hintColor,
                              fontSize: ChatLayoutConstants.voiceDurationFontSize,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatVoiceWaveform extends StatelessWidget {
  const ChatVoiceWaveform({
    super.key,
    required this.isMe,
    this.progress,
  });

  final bool isMe;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentProgress = progress ?? 0.0;

    final activeColor = isMe
        ? theme.colorScheme.primary
        : Colors.white;
    final trackColor = isMe
        ? theme.colorScheme.primary.withValues(alpha: 0.25)
        : Colors.white.withValues(alpha: 0.4);

    final baseHeights = List<double>.generate(
      ChatLayoutConstants.voiceWaveBarCount,
      (index) =>
          ChatLayoutConstants.voiceWaveBarMinHeight +
          (index * 3 + 7) % ChatLayoutConstants.voiceWaveBarMaxExtra,
    );

    return SizedBox(
      height: ChatLayoutConstants.voiceWaveBarMinHeight +
          ChatLayoutConstants.voiceWaveBarMaxExtra,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(
          ChatLayoutConstants.voiceWaveBarCount,
          (index) {
            final barProgress =
                (index + 1) / ChatLayoutConstants.voiceWaveBarCount;
            final isHighlighted = barProgress <= currentProgress;
            final height = baseHeights[index];

            return Container(
              width: ChatLayoutConstants.voiceWaveBarWidth,
              height: height,
              decoration: BoxDecoration(
                color: isHighlighted ? activeColor : trackColor,
                borderRadius: BorderRadius.circular(
                  ChatLayoutConstants.voiceWaveBarRadius,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
