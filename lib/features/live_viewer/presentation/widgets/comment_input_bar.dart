import 'package:flutter/material.dart';

import 'tiktok_live_tokens.dart';

class CommentInputBar extends StatefulWidget {
  final ValueChanged<String> onSend;
  final VoidCallback? onEmojiTap;
  final bool enabled;
  final bool isSending;
  final String hintText;

  const CommentInputBar({
    super.key,
    required this.onSend,
    this.onEmojiTap,
    this.enabled = true,
    this.isSending = false,
    this.hintText = 'Write...',
  });

  @override
  State<CommentInputBar> createState() => _CommentInputBarState();
}

class _CommentInputBarState extends State<CommentInputBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;

  static const _quickEmojis = ['😍', '🔥', '😂', '❤️', '👏', '✨'];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.enabled || widget.isSending) return;
    widget.onSend(text);
    _controller.clear();
  }

  void _insertEmoji(String emoji) {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final next = text.replaceRange(start, end, emoji);
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showQuickEmojis = _focusNode.hasFocus;
    return SizedBox(
      height: TikTokLiveTokens.inputH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: _buildInputField()),
          if (showQuickEmojis)
            Positioned(
              left: 0,
              right: 0,
              bottom: TikTokLiveTokens.inputH + 6,
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: _quickEmojis.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  return GestureDetector(
                    onTap: () => _insertEmoji(_quickEmojis[i]),
                    child: Container(
                      width: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: TikTokLiveTokens.frost(0.36),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _quickEmojis[i],
                        style: const TextStyle(fontSize: 17),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputField() {
    return Container(
      height: TikTokLiveTokens.inputH,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 5, 0),
      decoration: BoxDecoration(
        // Same scrim as the collapsed pill it replaces, so opening the
        // composer does not flash a different surface.
        color: TikTokLiveTokens.frost(0.36),
        borderRadius: BorderRadius.circular(TikTokLiveTokens.inputR),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: widget.enabled && !widget.isSending,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.2,
              ),
              cursorColor: TikTokLiveTokens.liveRed,
              cursorWidth: 1.5,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
              onTap: () => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: widget.isSending
                    ? 'Sending...'
                    : widget.enabled
                    ? widget.hintText
                    : 'Chat muted',
                hintStyle: TikTokLiveTokens.inputHint,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 140),
            child: widget.isSending
                ? const SizedBox(
                    key: ValueKey('loading'),
                    width: 28,
                    height: 28,
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                  )
                : GestureDetector(
                    key: const ValueKey('send'),
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => _submit(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _hasText && widget.enabled
                            ? TikTokLiveTokens.liveRed
                            : Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        color: _hasText && widget.enabled
                            ? Colors.white
                            : Colors.white54,
                        size: 16,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
