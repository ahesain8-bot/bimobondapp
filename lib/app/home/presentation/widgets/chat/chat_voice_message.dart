import 'dart:math' as math;

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
    final iconColor = widget.isMe
        ? chatTheme.onSentBubble
        : chatTheme.onReceivedBubble;
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
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.p4),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isLoading)
                        SizedBox(
                          width: ChatLayoutConstants.voicePlayIconSize,
                          height: ChatLayoutConstants.voicePlayIconSize,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: iconColor.withValues(
                              alpha: _canPlay ? 1 : disabledAlpha,
                            ),
                          ),
                        )
                      else
                        Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: iconColor.withValues(
                            alpha: _canPlay ? 1 : disabledAlpha,
                          ),
                          size: ChatLayoutConstants.voicePlayIconSize,
                        ),
                      if (_isPlaying)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: _VoicePlayingPulse(color: iconColor),
                        ),
                    ],
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
                    isPlaying: _isPlaying,
                    isPaused: _isActive && !_isPlaying,
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
                          fontWeight:
                              _isPlaying ? FontWeight.w600 : FontWeight.normal,
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

class _VoicePlayingPulse extends StatefulWidget {
  const _VoicePlayingPulse({required this.color});

  final Color color;

  @override
  State<_VoicePlayingPulse> createState() => _VoicePlayingPulseState();
}

class _VoicePlayingPulseState extends State<_VoicePlayingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 0.75 + _controller.value * 0.35;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: ChatLayoutConstants.voicePlayingPulseSize,
            height: ChatLayoutConstants.voicePlayingPulseSize,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

class ChatVoiceWaveform extends StatefulWidget {
  const ChatVoiceWaveform({
    super.key,
    required this.isMe,
    required this.isPlaying,
    required this.isPaused,
    this.progress,
  });

  final bool isMe;
  final bool isPlaying;
  final bool isPaused;
  final double? progress;

  @override
  State<ChatVoiceWaveform> createState() => _ChatVoiceWaveformState();
}

class _ChatVoiceWaveformState extends State<ChatVoiceWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;
  late final List<double> _baseHeights;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: ChatLayoutConstants.voiceWaveAnimationMs,
      ),
    );
    _baseHeights = List<double>.generate(
      ChatLayoutConstants.voiceWaveBarCount,
      (index) =>
          ChatLayoutConstants.voiceWaveBarMinHeight +
          (index * 3 + 7) % ChatLayoutConstants.voiceWaveBarMaxExtra,
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(ChatVoiceWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.isPlaying) {
      _waveController.repeat(reverse: true);
    } else {
      _waveController
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  Color _barColor(BuildContext context, bool highlighted) {
    final chatTheme = ChatTheme.of(context);
    if (widget.isMe) {
      return chatTheme.onSentBubble.withValues(
        alpha: highlighted
            ? ChatLayoutConstants.voiceWaveSentActiveAlpha
            : ChatLayoutConstants.voiceWaveSentAlpha,
      );
    }
    return chatTheme.onReceivedBubble.withValues(
      alpha: highlighted
          ? ChatLayoutConstants.voiceWaveSentActiveAlpha
          : ChatLayoutConstants.voiceWaveSentAlpha,
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress ?? 0;
    final trackColor = _barColor(context, false).withValues(alpha: 0.35);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: ChatLayoutConstants.voiceWaveBarMinHeight +
              ChatLayoutConstants.voiceWaveBarMaxExtra,
          child: AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              final t = _waveController.value * math.pi * 2;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(
                  ChatLayoutConstants.voiceWaveBarCount,
                  (index) {
                    final barProgress =
                        (index + 1) / ChatLayoutConstants.voiceWaveBarCount;
                    final passed = widget.isPlaying || widget.isPaused
                        ? barProgress <= progress + 0.05
                        : false;

                    final waveBoost = widget.isPlaying
                        ? math.sin(t + index * 0.65) *
                            ChatLayoutConstants.voiceWaveBarMaxExtra *
                            0.35
                        : 0.0;

                    final height = _baseHeights[index] + waveBoost;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 80),
                      width: ChatLayoutConstants.voiceWaveBarWidth,
                      height: height.clamp(
                        ChatLayoutConstants.voiceWaveBarMinHeight,
                        ChatLayoutConstants.voiceWaveBarMinHeight +
                            ChatLayoutConstants.voiceWaveBarMaxExtra,
                      ),
                      decoration: BoxDecoration(
                        color: passed || widget.isPlaying
                            ? _barColor(context, widget.isPlaying || passed)
                            : trackColor,
                        borderRadius: BorderRadius.circular(
                          ChatLayoutConstants.voiceWaveBarRadius,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        if (widget.isPlaying || widget.isPaused) ...[
          const SizedBox(height: AppSizes.p4),
          ClipRRect(
            borderRadius: BorderRadius.circular(
              ChatLayoutConstants.voiceWaveBarRadius,
            ),
            child: LinearProgressIndicator(
              value: widget.isPlaying || widget.isPaused ? progress : null,
              minHeight: ChatLayoutConstants.voiceProgressBarHeight,
              backgroundColor: trackColor,
              color: _barColor(context, true),
            ),
          ),
        ],
      ],
    );
  }
}
