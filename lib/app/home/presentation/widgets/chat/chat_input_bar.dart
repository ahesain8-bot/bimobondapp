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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    final primary = theme.colorScheme.primary;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
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
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                // Left action button: Trash can (if locked) OR Mic/Send button (if holding/idle)
                (widget.isRecording && _isLocked)
                    ? GestureDetector(
                        onTap: () {
                          widget.onRecordingCancel?.call();
                        },
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
                      )
                    : Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          if (widget.isRecording && !_isLocked)
                            Positioned(
                              bottom: 64 +
                                  math.max(-40.0, math.min(0.0, _dragY)),
                              child: Opacity(
                                opacity:
                                    (1.0 + (_dragY / 60.0)).clamp(0.2, 1.0),
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
                                        color: Colors.black
                                            .withValues(alpha: 0.15),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        LucideIcons.chevronUp,
                                        color: primary,
                                        size: 16,
                                      ),
                                      const SizedBox(height: 4),
                                      Icon(
                                        LucideIcons.lock,
                                        color: primary,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          GestureDetector(
                            key: const ValueKey('mic_gesture_detector'),
                            onTap: widget.hasText
                                ? widget.onSend
                                : () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          isArabic
                                              ? "اضغط مطولاً لتسجيل رسالة صوتية"
                                              : "Hold to record a voice message",
                                        ),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                            onLongPressStart: widget.hasText
                                ? null
                                : (_) {
                                    widget.onRecordingStart();
                                  },
                            onLongPressMoveUpdate: widget.hasText
                                ? null
                                : (details) {
                                    final dy = details.localOffsetFromOrigin.dy;
                                    final dx = details.localOffsetFromOrigin.dx;
                                    setState(() {
                                      _dragX = dx;
                                      _dragY = dy;
                                    });

                                    if (dy < -60 && !_isLocked) {
                                      setState(() {
                                        _isLocked = true;
                                      });
                                    }

                                    if (dx.abs() > 80 && !_isLocked) {
                                      widget.onRecordingCancel?.call();
                                    }
                                  },
                            onLongPressEnd: widget.hasText
                                ? null
                                : (details) {
                                    if (!_isLocked) {
                                      widget.onRecordingEnd();
                                    }
                                  },
                            onLongPressCancel: widget.hasText
                                ? null
                                : () {
                                    if (!_isLocked) {
                                      widget.onRecordingCancel?.call();
                                    }
                                  },
                            child: Container(
                              width: ChatLayoutConstants.inputActionSize,
                              height: ChatLayoutConstants.inputActionSize,
                              decoration: BoxDecoration(
                                color: primary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                widget.hasText
                                    ? LucideIcons.send
                                    : LucideIcons.mic,
                                color: theme.colorScheme.onPrimary,
                                size: widget.hasText
                                    ? ChatLayoutConstants.inputSendIconSize
                                    : ChatLayoutConstants.inputMicIconSize,
                              ),
                            ),
                          ),
                        ],
                      ),
                const SizedBox(width: AppSizes.p8),
                // Middle widget: Capsule containing either the TextField or the recording info
                Expanded(
                  child: Container(
                    height: widget.isRecording ? ChatLayoutConstants.inputFieldHeight : null,
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
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Transform.translate(
                                    offset: Offset(math.max(0.0, _dragX), 0.0),
                                    child: Opacity(
                                      opacity: (1.0 - (_dragX / 80.0))
                                          .clamp(0.0, 1.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            isArabic
                                                ? "اسحب للإلغاء"
                                                : "Slide to cancel",
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                              color: theme.hintColor,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            LucideIcons.chevronRight,
                                            color: theme.hintColor,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 16),
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
                                      setState(() {
                                        _isPaused = false;
                                      });
                                    } else {
                                      widget.onRecordingPause();
                                      setState(() {
                                        _isPaused = true;
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(width: 8),
                              ],
                            ],
                          )
                        : Row(
                            children: [
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(
                                  LucideIcons.smile,
                                  color: primary,
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
                              Expanded(
                                child: TextField(
                                  controller: widget.controller,
                                  onSubmitted: (_) => widget.onSend(),
                                  onChanged: (value) => widget.onTextChanged
                                      ?.call(value.isNotEmpty),
                                  textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                                  textAlign: TextAlign.start,
                                  minLines: 1,
                                  maxLines: 3,
                                  maxLength: 100,
                                  keyboardType: TextInputType.multiline,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontSize: ChatLayoutConstants
                                        .inputFieldFontSize,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: l10n.chatAddComment,
                                    hintTextDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                                    counterText: "",
                                    hintStyle: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                      color: theme.hintColor.withValues(
                                        alpha:
                                            ChatLayoutConstants.inputHintAlpha,
                                      ),
                                      fontSize: ChatLayoutConstants
                                          .inputHintFontSize,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                          ),
                  ),
                ),
                // Right action button: Send (if locked recording) OR Plus (if not recording) OR Hidden (if holding)
                if (widget.isRecording && _isLocked) ...[
                  const SizedBox(width: AppSizes.p8),
                  GestureDetector(
                    onTap: () {
                      widget.onRecordingEnd();
                    },
                    child: Container(
                      width: ChatLayoutConstants.inputActionSize,
                      height: ChatLayoutConstants.inputActionSize,
                      decoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.send,
                        color: theme.colorScheme.onPrimary,
                        size: ChatLayoutConstants.inputSendIconSize,
                      ),
                    ),
                  ),
                ] else if (!widget.isRecording) ...[
                  const SizedBox(width: AppSizes.p8),
                  _ChatInputActionButton(
                    color: primary,
                    onTap: widget.onMoreMenu,
                    icon: LucideIcons.plus,
                    iconSize: 24,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatInputActionButton extends StatelessWidget {
  const _ChatInputActionButton({
    required this.color,
    required this.icon,
    required this.iconSize,
    this.onTap,
  });

  final Color color;
  final IconData icon;
  final double iconSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: ChatLayoutConstants.inputActionSize,
        height: ChatLayoutConstants.inputActionSize,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: theme.colorScheme.onPrimary,
          size: iconSize,
        ),
      ),
    );
  }
}
