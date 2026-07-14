import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/chat_bloc.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/chat_event.dart';
import 'package:bimobondapp/app/chats/presentation/bloc/chat_state.dart';
import 'package:bimobondapp/app/home/presentation/utils/chat_attachment_payload.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_app_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_input_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_message_list.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_pattern_background.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_voice_playback.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_voice_recorder.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_attachment_picker.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_sheets.dart';
import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

class ChatView extends StatefulWidget {
  const ChatView({
    required this.chatId,
    required this.username,
    required this.imageUrl,
    required this.currentUserId,
    this.peerUserId,
    this.openCamera = false,
    super.key,
  });

  final String chatId;
  final String username;
  final String imageUrl;
  final String currentUserId;
  final String? peerUserId;
  final bool openCamera;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isRecording = false;
  Map<String, dynamic>? _replyTo;
  final ChatVoiceRecorder _voiceRecorder = ChatVoiceRecorder();
  Future<void>? _startRecordingFuture;
  bool _didRequestCamera = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() => setState(() {}));
    if (widget.openCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didRequestCamera) return;
        _didRequestCamera = true;
        _pickAndSend(ChatAttachmentPicker.pickFromCamera);
      });
    }
  }

  @override
  void dispose() {
    ChatVoicePlayback.instance.stop();
    _voiceRecorder.dispose();
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

  Future<void> _onPeerHeaderTap() async {
    final id = widget.peerUserId?.trim() ?? '';
    if (id.isEmpty) {
      ChatSheets.showUserInfo(
        context: context,
        username: widget.username,
        imageUrl: widget.imageUrl,
        userId: widget.peerUserId,
        fullName: widget.username,
      );
      return;
    }

    await openUserActiveStoriesOrProfile(
      context,
      userId: id,
      username: widget.username,
      fullName: widget.username,
      avatarUrl: widget.imageUrl,
    );
  }

  void _showMessageActions(Map<String, dynamic> msg) {
    if (msg['isDeleted'] == true) return;

    ChatSheets.showMessageActions(
      context: context,
      onReply: () => setState(() => _replyTo = msg),
      onReact: () => _showReactionPicker(msg),
      onDelete: msg['isMe'] == true ? () => _confirmDeleteMessage(msg) : null,
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

  Future<void> _confirmDeleteMessage(Map<String, dynamic> msg) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final messageId = msg['id']?.toString();
    if (messageId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.chatDeleteMessageTitle),
        content: Text(l10n.chatDeleteMessageMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              l10n.chatActionDelete,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    context.read<ChatBloc>().add(
      ChatMessageDeleteRequested(messageId: messageId),
    );
  }

  void _onTypingChanged(bool isTyping) {
    context.read<ChatBloc>().add(ChatTypingChanged(isTyping: isTyping));
  }

  Future<void> _onRecordingStart() async {
    _startRecordingFuture = _startRecordingProcess();
    await _startRecordingFuture;
  }

  Future<void> _startRecordingProcess() async {
    final result = await _voiceRecorder.start();
    if (!mounted) return;

    if (result == true) {
      setState(() => _isRecording = true);
      return;
    }

    if (result == ChatVoiceRecorderStartFailure.permissionPermanentlyDenied) {
      await _showMicrophonePermissionDialog();
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final message = result == ChatVoiceRecorderStartFailure.pluginUnavailable
        ? l10n.chatRecordingPluginUnavailable
        : l10n.chatRecordingPermissionDenied;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: result == ChatVoiceRecorderStartFailure.permissionDenied
            ? SnackBarAction(
                label: l10n.chatRecordingAllowMicrophone,
                onPressed: _onRecordingStart,
              )
            : null,
      ),
    );
  }

  Future<void> _showMicrophonePermissionDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.chatRecordingPermissionTitle),
        content: Text(l10n.chatRecordingPermissionSettingsMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              openAppSettings();
            },
            child: Text(
              l10n.chatRecordingOpenSettings,
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onRecordingEnd() async {
    if (_startRecordingFuture != null) {
      await _startRecordingFuture;
      _startRecordingFuture = null;
    }

    if (!_isRecording) return;

    final result = await _voiceRecorder.stop();
    if (!mounted) return;

    setState(() => _isRecording = false);

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.chatVoiceTooShort),
        ),
      );
      return;
    }

    final durationSeconds = result.duration.inSeconds.clamp(1, 3600);
    context.read<ChatBloc>().add(
      ChatVoiceMessageSendRequested(
        filePath: result.file.path,
        durationSeconds: durationSeconds,
        replyToId: _replyTo?['id']?.toString(),
      ),
    );

    setState(() => _replyTo = null);
    _scrollToBottom();
  }

  Future<void> _onRecordingCancel() async {
    if (_startRecordingFuture != null) {
      await _startRecordingFuture;
      _startRecordingFuture = null;
    }

    await _voiceRecorder.cancel();
    if (mounted) {
      setState(() => _isRecording = false);
    }
  }

  Future<void> _sendAttachment(
    Future<ChatAttachmentDraft?> Function() pick,
  ) async {
    final draft = await pick();
    if (!mounted || draft == null) return;

    context.read<ChatBloc>().add(
      ChatAttachmentSendRequested(
        messageType: draft.type,
        content: draft.content,
        localFilePath: draft.filePath,
        replyToId: _replyTo?['id']?.toString(),
        payload: draft.payload,
        mimeType: draft.mimeType,
        sizeBytes: draft.sizeBytes,
      ),
    );
    setState(() => _replyTo = null);
    _scrollToBottom();
  }

  void _showAttachmentFailed() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.chatAttachmentSendFailed),
      ),
    );
  }

  Future<void> _pickAndSend(
    Future<ChatAttachmentDraft?> Function() pick,
  ) async {
    try {
      await _sendAttachment(pick);
    } catch (_) {
      _showAttachmentFailed();
    }
  }

  Future<void> _sendLocationAttachment() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final bloc = context.read<ChatBloc>();
    final replyToId = _replyTo?['id']?.toString();

    final draft = await ChatAttachmentPicker.pickCurrentLocation();
    if (!mounted) return;

    if (draft == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.chatLocationPermissionDenied)),
      );
      return;
    }

    bloc.add(
      ChatAttachmentSendRequested(
        messageType: draft.type,
        content: draft.content,
        payload: draft.payload,
        replyToId: replyToId,
      ),
    );
    setState(() => _replyTo = null);
    _scrollToBottom();
  }

  Future<void> _sendContactAttachment() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final bloc = context.read<ChatBloc>();
    final replyToId = _replyTo?['id']?.toString();

    final draft = await ChatAttachmentPicker.pickContact();
    if (!mounted) return;

    if (draft == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.chatContactsPermissionDenied)),
      );
      return;
    }

    bloc.add(
      ChatAttachmentSendRequested(
        messageType: draft.type,
        content: draft.content,
        payload: draft.payload,
        replyToId: replyToId,
      ),
    );
    setState(() => _replyTo = null);
    _scrollToBottom();
  }

  bool get _isRtl => Directionality.of(context) == TextDirection.rtl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
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

        final l10n = AppLocalizations.of(context)!;
        String? replyPreviewText;
        if (_replyTo != null) {
          if (_replyTo!['type'] == 'voice') {
            final duration = _replyTo!['duration']?.toString();
            replyPreviewText = duration != null && duration.isNotEmpty
                ? '${l10n.messagesInboxLastVoice} · $duration'
                : l10n.messagesInboxLastVoice;
          } else {
            replyPreviewText = _replyTo!['text']?.toString() ?? '';
          }
        }

        final authState = context.watch<AuthBloc>().state;
        final currentUser = authState is AuthSuccess ? authState.user : null;
        final currentUserName = currentUser?.fullName?.trim().isNotEmpty == true
            ? currentUser!.fullName!.trim()
            : (currentUser?.username?.trim().isNotEmpty == true
                  ? currentUser!.username!.trim()
                  : 'User');
        final currentUserImageUrl = currentUser?.avatarUrl?.trim() ?? '';

        return Scaffold(
          backgroundColor: chatTheme.chatBackgroundColor,
          appBar: ChatAppBar(
            username: widget.username,
            imageUrl: widget.imageUrl,
            userId: widget.peerUserId,
            onProfileTap: _onPeerHeaderTap,
          ),
          body: Stack(
            children: [
              ChatPatternBackground(
                backgroundColor: chatTheme.chatBackgroundColor,
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
                              peerImageUrl: widget.imageUrl,
                              peerUserId: widget.peerUserId,
                              currentUserName: currentUserName,
                              currentUserImageUrl: currentUserImageUrl,
                              currentUserId: widget.currentUserId,
                              isRtl: _isRtl,
                              onReactionPicker: _showMessageActions,
                              onReplyTo: (msg) =>
                                  setState(() => _replyTo = msg),
                              onPollVote: (messageId, optionIndex) {
                                context.read<ChatBloc>().add(
                                  ChatPollVoteRequested(
                                    messageId: messageId,
                                    optionIndex: optionIndex,
                                  ),
                                );
                              },
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
                      onMoreMenu: () => ChatSheets.showMoreMenu(
                        context: context,
                        onGallery: () =>
                            _pickAndSend(ChatAttachmentPicker.pickFromGallery),
                        onCamera: () =>
                            _pickAndSend(ChatAttachmentPicker.pickFromCamera),
                        onVideo: () =>
                            _pickAndSend(ChatAttachmentPicker.pickVideo),
                        onLocation: _sendLocationAttachment,
                        onContact: _sendContactAttachment,
                        onFile: () =>
                            _pickAndSend(ChatAttachmentPicker.pickFile),
                      ),
                      onEmojiPicker: () => ChatSheets.showEmojiPicker(
                        context: context,
                        messageController: _messageController,
                        onEmojiInserted: () => setState(() {}),
                      ),
                      onRecordingStart: _onRecordingStart,
                      onRecordingEnd: _onRecordingEnd,
                      onRecordingCancel: _onRecordingCancel,
                      onReplyClose: () => setState(() => _replyTo = null),
                      onTextChanged: (typing) => _onTypingChanged(typing),
                      isRecording: _isRecording,
                      onRecordingPause: () => _voiceRecorder.pause(),
                      onRecordingResume: () => _voiceRecorder.resume(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
