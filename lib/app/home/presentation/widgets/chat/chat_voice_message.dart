import 'package:bimobondapp/app/home/presentation/utils/chat_voice_duration_formatter.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_voice_playback.dart';
import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
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

    final isSent = widget.isMe;
    final textColor = isSent ? chatTheme.onSentBubbleMuted : chatTheme.onReceivedBubbleMuted;

    return SizedBox(
      width: 210,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary.withValues(
                            alpha: _canPlay ? 1.0 : disabledAlpha,
                          ),
                          theme.colorScheme.secondary.withValues(
                            alpha: _canPlay ? 1.0 : disabledAlpha,
                          ),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ChatVoiceWaveform(
                      isMe: widget.isMe,
                      progress: _progress,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _timeLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: textColor,
                            fontSize: 10.5,
                            fontWeight: _isPlaying
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        if (_isPlaying)
                          Text(
                            '/ ${widget.duration}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: textColor.withValues(alpha: 0.7),
                              fontSize: 10.5,
                            ),
                          ),
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

  static const List<double> _waveformHeights = [
    10, 16, 22, 14, 26, 30, 18, 14, 24, 28,
    20, 14, 26, 18, 14, 22, 16, 10, 14, 8,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentProgress = progress ?? 0.0;

    final activeColor = isMe
        ? theme.colorScheme.primary
        : theme.colorScheme.secondary;
    final trackColor = isMe
        ? theme.colorScheme.primary.withValues(alpha: 0.25)
        : theme.colorScheme.onSurface.withValues(alpha: 0.18);

    final barCount = _waveformHeights.length;

    return SizedBox(
      height: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(
          barCount,
          (index) {
            final barProgress = (index + 1) / barCount;
            final isHighlighted = barProgress <= currentProgress;
            final height = _waveformHeights[index];

            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 2.5,
              height: height,
              decoration: BoxDecoration(
                color: isHighlighted ? activeColor : trackColor,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          },
        ),
      ),
    );
  }
}
