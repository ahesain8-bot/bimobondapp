import 'package:bimobondapp/app/chats/presentation/bloc/chat_bloc.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/chat_event.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/chat_state.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_app_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_input_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_message_list.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_recording_overlay.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_sheets.dart';
import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChatView extends StatefulWidget {
  const ChatView({
    required this.chatId,
    required this.username,
    required this.imageUrl,
    required this.currentUserId,
    super.key,
  });

  final String chatId;
  final String username;
  final String imageUrl;
  final String currentUserId;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isRecording = false;
  Map<String, dynamic>? _replyTo;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: ChatLayoutConstants.scrollAnimationDuration,
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    context.read<ChatBloc>().add(
      ChatMessageSendRequested(
        content: text,
        replyToId: _replyTo?['id']?.toString(),
      ),
    );

    _messageController.clear();
    setState(() => _replyTo = null);
    _scrollToBottom();
  }

  void _showUserInfo() {
    ChatSheets.showUserInfo(
      context: context,
      username: widget.username,
      imageUrl: widget.imageUrl,
    );
  }

  void _showReactionPicker(Map<String, dynamic> msg) {
    final messageId = msg['id']?.toString();
    if (messageId == null) return;

    ChatSheets.showReactionPicker(
      context: context,
      msg: msg,
      onEmojiSelected: (emoji) {
        context.read<ChatBloc>().add(
          ChatMessageReactRequested(messageId: messageId, emoji: emoji),
        );
      },
    );
  }

  void _onTypingChanged(bool isTyping) {
    context.read<ChatBloc>().add(ChatTypingChanged(isTyping: isTyping));
  }

  bool get _isRtl => Directionality.of(context) == TextDirection.rtl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasText = _messageController.text.isNotEmpty;

    return BlocConsumer<ChatBloc, ChatState>(
      listenWhen: (previous, current) {
        if (current is! ChatLoadSuccess) return false;
        if (previous is! ChatLoadSuccess) return true;
        return previous.messages.length != current.messages.length;
      },
      listener: (context, state) {
        if (state is ChatLoadSuccess) {
          _scrollToBottom();
        }
      },
      builder: (context, state) {
        final messages = state is ChatLoadSuccess
            ? state.messages
            : <Map<String, dynamic>>[];
        final isTypingRemote = state is ChatLoadSuccess
            ? state.isTypingRemote
            : false;
        final isLoading = state is ChatLoading;

        String? replyPreviewText;
        if (_replyTo != null) {
          replyPreviewText = _replyTo!['text']?.toString() ?? '';
        }

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: ChatAppBar(
            username: widget.username,
            imageUrl: widget.imageUrl,
            onProfileTap: _showUserInfo,
          ),
          body: Stack(
            children: [
              ChatBackground(
                child: Column(
                  children: [
                    Expanded(
                      child: isLoading && messages.isEmpty
                          ? const ChatMessageListSkeleton()
                          : ChatMessageList(
                              scrollController: _scrollController,
                              messages: messages,
                              isTyping: isTypingRemote,
                              username: widget.username,
                              isRtl: _isRtl,
                              onReactionPicker: _showReactionPicker,
                              onReplyTo: (msg) =>
                                  setState(() => _replyTo = msg),
                            ),
                    ),
                    if (state is ChatFailure)
                      Padding(
                        padding: const EdgeInsets.all(
                          ChatLayoutConstants.errorBannerPadding,
                        ),
                        child: Text(
                          state.message,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ChatInputBar(
                      controller: _messageController,
                      hasText: hasText,
                      replyPreviewText: replyPreviewText,
                      onSend: _sendMessage,
                      onMoreMenu: () =>
                          ChatSheets.showMoreMenu(context: context),
                      onEmojiPicker: () => ChatSheets.showEmojiPicker(
                        context: context,
                        messageController: _messageController,
                        onEmojiInserted: () => setState(() {}),
                      ),
                      onRecordingStart: () =>
                          setState(() => _isRecording = true),
                      onRecordingEnd: () =>
                          setState(() => _isRecording = false),
                      onReplyClose: () => setState(() => _replyTo = null),
                      onTextChanged: (typing) => _onTypingChanged(typing),
                    ),
                  ],
                ),
              ),
              if (_isRecording) const ChatRecordingOverlay(),
            ],
          ),
        );
      },
    );
  }
}

class ChatBackground extends StatelessWidget {
  const ChatBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.scaffoldBackgroundColor,
            chatTheme.backgroundGradientEnd,
          ],
        ),
      ),
      child: child,
    );
  }
}
