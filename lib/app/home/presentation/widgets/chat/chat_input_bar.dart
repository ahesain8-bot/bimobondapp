import 'dart:async';
import 'dart:math' as math;

import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_reply_preview_bar.dart';
import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    required this.controller,
    required this.hasText,
    required this.replyPreviewText,
    required this.onSend,
    required this.onMoreMenu,
    required this.onEmojiPicker,
    required this.onRecordingStart,
    required this.onRecordingEnd,
    this.onRecordingCancel,
    required this.onReplyClose,
    this.onTextChanged,
    required this.isRecording,
    required this.onRecordingPause,
    required this.onRecordingResume,
    super.key,
  });

  final TextEditingController controller;
  final bool hasText;
  final String? replyPreviewText;
  final VoidCallback onSend;
  final VoidCallback onMoreMenu;
  final VoidCallback onEmojiPicker;
  final VoidCallback onRecordingStart;
  final VoidCallback onRecordingEnd;
  final VoidCallback? onRecordingCancel;
  final VoidCallback onReplyClose;
  final ValueChanged<bool>? onTextChanged;
  final bool isRecording;
  final VoidCallback onRecordingPause;
  final VoidCallback onRecordingResume;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  bool _isLocked = false;
  bool _isPaused = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  bool _blinkState = true;
  Timer? _blinkTimer;

  double _dragX = 0;
  double _dragY = 0;

  void _startTimer() {
    _timer?.cancel();
    _elapsed = Duration.zero;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          _elapsed += const Duration(seconds: 1);
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _startBlink() {
    _blinkTimer?.cancel();
    _blinkState = true;
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      setState(() {
        _blinkState = !_blinkState;
      });
    });
  }

  void _stopBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = null;
  }

  @override
  void didUpdateWidget(covariant ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _startTimer();
        _startBlink();
      } else {
        _stopTimer();
        _stopBlink();
        setState(() {
          _isLocked = false;
          _isPaused = false;
          _elapsed = Duration.zero;
          _dragX = 0;
          _dragY = 0;
        });
      }
    }
  }

  @override
  void dispose() {
    _stopTimer();
    _stopBlink();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _onMicMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!widget.isRecording || _isLocked) return;
    final dy = details.localOffsetFromOrigin.dy;
    final dx = details.localOffsetFromOrigin.dx;
    setState(() {
      _dragX = dx;
      _dragY = dy;
    });

    // Slide left to cancel (mic stays on the right).
    if (dx < -80) {
      widget.onRecordingCancel?.call();
      return;
    }

    // Slide up to lock.
    if (dy < -60) {
      setState(() {
        _isLocked = true;
        _dragX = 0;
        _dragY = 0;
      });
    }
  }

  Widget _buildMicOrSendButton({
    required ThemeData theme,
    required ChatTheme chatTheme,
    required Color primary,
  }) {
    final showSend = widget.hasText && !widget.isRecording;
    final showLockedSend = widget.isRecording && _isLocked;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        if (widget.isRecording && !_isLocked)
          Positioned(
            bottom: 64 + math.max(-40.0, math.min(0.0, _dragY)),
            child: Opacity(
              opacity: (1.0 + (_dragY / 60.0)).clamp(0.2, 1.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.chevronUp, color: primary, size: 16),
                    const SizedBox(height: 4),
                    Icon(LucideIcons.lock, color: primary, size: 16),
                  ],
                ),
              ),
            ),
          ),
        GestureDetector(
          key: const ValueKey('chat_mic_send_button'),
          onTap: showSend
              ? widget.onSend
              : (showLockedSend ? widget.onRecordingEnd : null),
          onLongPressStart: showSend || widget.isRecording
              ? null
              : (_) => widget.onRecordingStart(),
          onLongPressMoveUpdate: widget.isRecording && !_isLocked
              ? _onMicMoveUpdate
              : null,
          onLongPressEnd: (_) {
            if (widget.isRecording && !_isLocked) {
              widget.onRecordingEnd();
            }
          },
          onLongPressCancel: () {
            if (widget.isRecording && !_isLocked) {
              widget.onRecordingCancel?.call();
            }
          },
          child: Container(
            width: ChatLayoutConstants.inputActionSize,
            height: ChatLayoutConstants.inputActionSize,
            decoration: BoxDecoration(
              color: (showSend || widget.isRecording)
                  ? primary
                  : chatTheme.sendIdleFill,
              shape: BoxShape.circle,
            ),
            child: Icon(
              showSend || showLockedSend
                  ? LucideIcons.sendHorizonal
                  : LucideIcons.mic,
              color: (showSend || widget.isRecording)
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              size: showSend || showLockedSend
                  ? ChatLayoutConstants.inputSendIconSize
                  : ChatLayoutConstants.inputMicIconSize,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    final primary = theme.colorScheme.primary;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      decoration: const BoxDecoration(color: Colors.transparent),
      padding: EdgeInsets.fromLTRB(
        ChatLayoutConstants.inputBarHorizontalPadding,
        ChatLayoutConstants.inputBarTopPadding,
        ChatLayoutConstants.inputBarHorizontalPadding,
        MediaQuery.paddingOf(context).bottom +
            ChatLayoutConstants.inputBarBottomExtra,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.replyPreviewText != null)
            ChatReplyPreviewBar(
              text: widget.replyPreviewText!,
              onClose: widget.onReplyClose,
            ),
          // Keep LTR so mic stays on the right (WhatsApp / TikTok style).
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                if (!widget.isRecording) ...[
                  GestureDetector(
                    onTap: widget.onMoreMenu,
                    child: Container(
                      width: ChatLayoutConstants.inputActionSize,
                      height: ChatLayoutConstants.inputActionSize,
                      decoration: BoxDecoration(
                        color: chatTheme.sendIdleFill,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.plus,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.p8),
                ] else if (_isLocked) ...[
                  GestureDetector(
                    onTap: () => widget.onRecordingCancel?.call(),
                    child: Container(
                      width: ChatLayoutConstants.inputActionSize,
                      height: ChatLayoutConstants.inputActionSize,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.trash2,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.p8),
                ],
                Expanded(
                  child: Container(
                    height: widget.isRecording
                        ? ChatLayoutConstants.inputFieldHeight
                        : null,
                    constraints: widget.isRecording
                        ? null
                        : const BoxConstraints(
                            minHeight: ChatLayoutConstants.inputFieldHeight,
                          ),
                    decoration: BoxDecoration(
                      color: chatTheme.inputFill,
                      borderRadius: BorderRadius.circular(
                        ChatLayoutConstants.inputFieldRadius,
                      ),
                    ),
                    child: widget.isRecording
                        ? Row(
                            children: [
                              const SizedBox(width: 16),
                              AnimatedOpacity(
                                opacity: _isPaused
                                    ? 0.5
                                    : (_blinkState ? 1.0 : 0.2),
                                duration: const Duration(milliseconds: 300),
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _isPaused ? Colors.grey : Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDuration(_elapsed),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (!_isLocked) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Transform.translate(
                                    // Follow finger while sliding left to cancel.
                                    offset: Offset(math.min(0.0, _dragX), 0.0),
                                    child: Opacity(
                                      opacity: (1.0 + (_dragX / 80.0)).clamp(
                                        0.0,
                                        1.0,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            LucideIcons.chevronLeft,
                                            color: theme.hintColor,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              isArabic
                                                  ? 'اسحب للإلغاء'
                                                  : 'Slide to cancel',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color: theme.hintColor,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ] else ...[
                                const Spacer(),
                                IconButton(
                                  icon: Icon(
                                    _isPaused
                                        ? LucideIcons.mic
                                        : LucideIcons.pause,
                                    color: primary,
                                  ),
                                  onPressed: () {
                                    if (_isPaused) {
                                      widget.onRecordingResume();
                                      setState(() => _isPaused = false);
                                    } else {
                                      widget.onRecordingPause();
                                      setState(() => _isPaused = true);
                                    }
                                  },
                                ),
                                const SizedBox(width: 4),
                              ],
                            ],
                          )
                        : Row(
                            children: [
                              const SizedBox(width: 14),
                              Expanded(
                                child: TextField(
                                  controller: widget.controller,
                                  onSubmitted: (_) => widget.onSend(),
                                  onChanged: (value) => widget.onTextChanged
                                      ?.call(value.isNotEmpty),
                                  textDirection: isArabic
                                      ? TextDirection.rtl
                                      : TextDirection.ltr,
                                  textAlign: TextAlign.start,
                                  minLines: 1,
                                  maxLines: 3,
                                  maxLength: 100,
                                  keyboardType: TextInputType.multiline,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontSize:
                                        ChatLayoutConstants.inputFieldFontSize,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: l10n.chatSendMessageHint,
                                    hintTextDirection: isArabic
                                        ? TextDirection.rtl
                                        : TextDirection.ltr,
                                    counterText: '',
                                    hintStyle: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                          color: chatTheme.inboxSecondaryText,
                                          fontSize: ChatLayoutConstants
                                              .inputHintFontSize,
                                        ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  LucideIcons.smile,
                                  color: chatTheme.inboxSecondaryText,
                                  size: 22,
                                ),
                                onPressed: widget.onEmojiPicker,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 40,
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: AppSizes.p8),
                _buildMicOrSendButton(
                  theme: theme,
                  chatTheme: chatTheme,
                  primary: primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
