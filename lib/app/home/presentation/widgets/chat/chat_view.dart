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
import 'package:bimobondapp/core/navigation/user_profile_navigation.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:bimobondapp/app/calls/domain/entities/call_entity.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_bloc.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_event.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_state.dart';
import 'package:bimobondapp/app/calls/presentation/widgets/active_call_banner.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_message_text.dart';
import 'package:bimobondapp/core/utils/comment_translator.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:permission_handler/permission_handler.dart';

class ChatView extends StatefulWidget {
  const ChatView({
    required this.chatId,
    required this.username,
    required this.imageUrl,
    required this.currentUserId,
    this.peerUserId,
    this.isPeerActive = false,
    this.lastSeenAt,
    this.lastSeenText,
    this.openCamera = false,
    this.initialIsPinned = false,
    this.initialIsMuted = false,
    super.key,
  });

  final String chatId;
  final String username;
  final String imageUrl;
  final String currentUserId;
  final String? peerUserId;
  final bool isPeerActive;
  final String? lastSeenAt;
  final String? lastSeenText;
  final bool openCamera;
  final bool initialIsPinned;
  final bool initialIsMuted;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late bool _isMuted;
  late bool _isPinned;
  late bool _isPeerActive;
  String? _lastSeenAt;
  String? _lastSeenText;
  bool _isBlocked = false;
  String? _wallpaperUrl;

  bool _isRecording = false;
  Map<String, dynamic>? _replyTo;
  final ChatVoiceRecorder _voiceRecorder = ChatVoiceRecorder();
  Future<void>? _startRecordingFuture;
  bool _didRequestCamera = false;

  bool _isTypingLocal = false;

  final Map<String, String> _translatedMessageTexts = {};
  final Set<String> _showTranslationMessageIds = {};
  final Set<String> _translatingMessageIds = {};

  void _onInputChanged() {
    final isTyping = _messageController.text.isNotEmpty;
    if (_isTypingLocal != isTyping) {
      _isTypingLocal = isTyping;
      context.read<ChatBloc>().add(ChatTypingChanged(isTyping: isTyping));
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _isMuted = widget.initialIsMuted;
    _isPinned = widget.initialIsPinned;
    _isPeerActive = widget.isPeerActive;
    _lastSeenAt = widget.lastSeenAt;
    _lastSeenText = widget.lastSeenText;
    _messageController.addListener(_onInputChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CallBloc>().socketService.joinChat(widget.chatId);
      context.read<CallBloc>().add(CheckActiveCallEvent(chatId: widget.chatId));
      _checkBlockStatus();
      _fetchChatDetails();
    });
    if (widget.openCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didRequestCamera) return;
        _didRequestCamera = true;
        _pickAndSend(ChatAttachmentPicker.pickFromCamera);
      });
    }
  }

  Future<void> _fetchPeerUserStatus(String peerId) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final dio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': ApiConstants.apiKey,
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      final response = await dio.get(ApiConstants.userById(peerId));
      if (response.statusCode == 200 && response.data is Map) {
        final data = Map<String, dynamic>.from(response.data as Map);
        final isOnline = data['isOnline'] == true ||
            data['is_online'] == true ||
            data['isActive'] == true ||
            data['is_active'] == true;
        final lastSeen = data['lastSeen']?.toString() ??
            data['last_seen']?.toString() ??
            data['lastSeenAt']?.toString() ??
            data['last_seen_at']?.toString();

        if (mounted) {
          setState(() {
            _isPeerActive = isOnline;
            if (lastSeen != null && lastSeen.trim().isNotEmpty) {
              _lastSeenAt = lastSeen;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('ChatView: Error fetching peer user status: $e');
    }
  }

  Future<void> _fetchChatDetails() async {
    if (widget.chatId.isEmpty) return;
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final dio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': ApiConstants.apiKey,
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );

      final response = await dio.get(ApiConstants.chatById(widget.chatId));
      if (response.statusCode == 200 && response.data is Map) {
        final data = Map<String, dynamic>.from(response.data as Map);
        final settingsMap =
            data['settings'] is Map ? data['settings'] as Map : null;

        final isBlockedInChat = data['isBlocked'] == true ||
            data['isBlockedByYou'] == true ||
            data['isBlockedByThem'] == true ||
            data['is_blocked'] == true ||
            data['blocked'] == true ||
            settingsMap?['isBlocked'] == true ||
            settingsMap?['is_blocked'] == true;

        if (isBlockedInChat && mounted) {
          setState(() {
            _isBlocked = true;
          });
        }

        // Extract peerUserId from chat participants if not available
        final participants = data['participants'] is List
            ? data['participants'] as List
            : (data['members'] is List ? data['members'] as List : []);

        String? targetPeerId = widget.peerUserId;
        final myId = FirebaseAuth.instance.currentUser?.uid;
        for (final item in participants) {
          if (item is Map) {
            final id = item['id']?.toString() ?? item['_id']?.toString();
            if (id != null && id != myId) {
              if (targetPeerId == null || targetPeerId.isEmpty) {
                targetPeerId = id;
              }
              final isOnline = item['isOnline'] == true ||
                  item['is_online'] == true ||
                  item['isActive'] == true ||
                  item['is_active'] == true;
              final lastSeen = item['lastSeen']?.toString() ??
                  item['last_seen']?.toString() ??
                  item['lastSeenAt']?.toString() ??
                  item['last_seen_at']?.toString();
              if (mounted) {
                setState(() {
                  _isPeerActive = isOnline;
                  if (lastSeen != null && lastSeen.trim().isNotEmpty) {
                    _lastSeenAt = lastSeen;
                  }
                });
              }
              break;
            }
          }
        }

        if (targetPeerId != null && targetPeerId.isNotEmpty) {
          _fetchPeerUserStatus(targetPeerId);
          try {
            final relRes = await dio.get(
              ApiConstants.userRelationship(targetPeerId),
            );
            if (relRes.statusCode == 200 && relRes.data is Map) {
              final rData = Map<String, dynamic>.from(relRes.data as Map);
              final isBlockedInRel = rData['isBlocked'] == true ||
                  rData['isBlockedByYou'] == true ||
                  rData['isBlockedByThem'] == true;
              if (isBlockedInRel && mounted) {
                setState(() {
                  _isBlocked = true;
                });
              }
            }
          } catch (e) {
            debugPrint('ChatView: Error checking relationship in _fetchChatDetails: $e');
          }
        }

        // Precedence: personalWallpaperUrl -> sharedWallpaperUrl -> wallpaperUrl
        final personalUrl = data['personalWallpaperUrl']?.toString() ??
            data['personalWallpaper']?.toString() ??
            settingsMap?['personalWallpaperUrl']?.toString();

        final sharedUrl = data['sharedWallpaperUrl']?.toString() ??
            data['wallpaperUrl']?.toString() ??
            settingsMap?['wallpaperUrl']?.toString();

        final effectiveWallpaper = (personalUrl != null && personalUrl.trim().isNotEmpty)
            ? personalUrl
            : sharedUrl;

        if (mounted && effectiveWallpaper != null && effectiveWallpaper.trim().isNotEmpty) {
          setState(() {
            _wallpaperUrl = effectiveWallpaper;
          });
        }
      }
    } catch (e) {
      debugPrint('ChatView: Error fetching chat details for wallpaper: $e');
    }
  }

  Future<void> _checkBlockStatus() async {
    String? peerId = widget.peerUserId;
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final dio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': ApiConstants.apiKey,
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );

      if (peerId == null || peerId.isEmpty) {
        try {
          final response = await dio.get(ApiConstants.chatById(widget.chatId));
          if (response.statusCode == 200 && response.data is Map) {
            final data = Map<String, dynamic>.from(response.data as Map);
            final participants = data['participants'] is List
                ? data['participants'] as List
                : (data['members'] is List ? data['members'] as List : []);
            final myId = FirebaseAuth.instance.currentUser?.uid;
            for (final item in participants) {
              if (item is Map) {
                final id = item['id']?.toString() ?? item['_id']?.toString();
                if (id != null && id.isNotEmpty && id != myId) {
                  peerId = id;
                  break;
                }
              }
            }
          }
        } catch (e) {
          debugPrint('ChatView: Error resolving peerId in _checkBlockStatus: $e');
        }
      }

      if (peerId == null || peerId.isEmpty) return;

      // 1. Check My Blocks list
      try {
        final blocksRes = await dio.get(ApiConstants.myBlocks);
        if (blocksRes.statusCode == 200) {
          final List blocksList = blocksRes.data is List
              ? blocksRes.data as List
              : (blocksRes.data is Map && blocksRes.data['data'] is List
                  ? blocksRes.data['data'] as List
                  : []);
          final isBlockedInList = blocksList.any((item) {
            if (item is Map) {
              final id = item['id'] ??
                  item['userId'] ??
                  item['blockedUserId'] ??
                  item['targetUserId'];
              return id?.toString() == peerId;
            }
            return item?.toString() == peerId;
          });
          if (isBlockedInList && mounted) {
            setState(() {
              _isBlocked = true;
            });
            return;
          }
        }
      } catch (e) {
        debugPrint('ChatView: Error checking blocks list: $e');
      }

      // 2. Check relationship endpoint
      try {
        final relRes = await dio.get(
          ApiConstants.userRelationship(peerId),
        );
        if (relRes.statusCode == 200 && relRes.data is Map) {
          final rData = Map<String, dynamic>.from(relRes.data as Map);
          final isBlockedInRel = rData['isBlocked'] == true ||
              rData['isBlockedByYou'] == true ||
              rData['isBlockedByThem'] == true;
          if (isBlockedInRel && mounted) {
            setState(() {
              _isBlocked = true;
            });
            return;
          }
        }
      } catch (e) {
        debugPrint('ChatView: Error checking relationship: $e');
      }

      // 3. Check follow status endpoint
      try {
        final followRes = await dio.get(
          ApiConstants.userFollowStatus(peerId),
        );
        if (followRes.statusCode == 200 && followRes.data is Map) {
          final fData = Map<String, dynamic>.from(followRes.data as Map);
          final isBlockedInFollow = fData['isBlocked'] == true ||
              fData['is_blocked'] == true ||
              fData['blocked'] == true;
          if (isBlockedInFollow && mounted) {
            setState(() {
              _isBlocked = true;
            });
            return;
          }
        }
      } catch (e) {
        debugPrint('ChatView: Error checking follow status: $e');
      }
    } catch (e) {
      debugPrint('ChatView: Error in _checkBlockStatus: $e');
    }
  }

  @override
  void dispose() {
    context.read<CallBloc>().socketService.leaveChat(widget.chatId);
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

    if (_isTypingLocal) {
      _isTypingLocal = false;
      context.read<ChatBloc>().add(const ChatTypingChanged(isTyping: false));
    }

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

    await openUserProfile(
      context,
      userId: id,
      username: widget.username,
      avatarUrl: widget.imageUrl,
    );
  }

  Future<void> _toggleMessageTranslation(Map<String, dynamic> msg) async {
    final messageId = msg['id']?.toString();
    if (messageId == null || messageId.isEmpty) return;

    if (_showTranslationMessageIds.contains(messageId)) {
      setState(() {
        _showTranslationMessageIds.remove(messageId);
      });
      return;
    }

    if (_translatedMessageTexts.containsKey(messageId)) {
      setState(() {
        _showTranslationMessageIds.add(messageId);
      });
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final messageText = chatMessageText(msg, l10n);
    if (messageText.trim().isEmpty) return;

    setState(() {
      _translatingMessageIds.add(messageId);
    });

    final targetLang = Localizations.localeOf(context).languageCode;
    final translated = await CommentTranslator.translate(
      text: messageText,
      targetLang: targetLang,
    );

    if (!mounted) return;

    setState(() {
      _translatingMessageIds.remove(messageId);
      if (translated != null && translated.trim().isNotEmpty) {
        _translatedMessageTexts[messageId] = translated;
        _showTranslationMessageIds.add(messageId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.translationFailed),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _showMessageActions(Map<String, dynamic> msg) {
    if (msg['isDeleted'] == true) return;
    final messageId = msg['id']?.toString();
    final type = msg['type']?.toString() ?? 'text';
    final l10n = AppLocalizations.of(context)!;
    final text = chatMessageText(msg, l10n);
    final canTranslate = type == 'text' && text.trim().isNotEmpty && msg['isDeleted'] != true;
    final isTranslated = messageId != null && _showTranslationMessageIds.contains(messageId);
    final isTranslating = messageId != null && _translatingMessageIds.contains(messageId);

    ChatSheets.showMessageActions(
      context: context,
      onReply: () => setState(() => _replyTo = msg),
      onReact: () => _showReactionPicker(msg),
      onEmojiSelected: (emoji) {
        if (messageId != null) {
          context.read<ChatBloc>().add(
            ChatMessageReactRequested(messageId: messageId, emoji: emoji),
          );
        }
      },
      onTranslate: canTranslate ? () => _toggleMessageTranslation(msg) : null,
      isTranslated: isTranslated,
      isTranslating: isTranslating,
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
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          l10n.chatDeleteMessageTitle,
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        content: Text(
          l10n.chatDeleteMessageMessage,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(
              l10n.chatActionDelete,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
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

  Future<void> _unblockUserInChat() async {
    if (widget.peerUserId == null || widget.peerUserId!.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final dio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': ApiConstants.apiKey,
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );

      try {
        await dio.post(ApiConstants.unblockUser(widget.peerUserId!));
      } catch (_) {
        await dio.delete(ApiConstants.blockUser(widget.peerUserId!));
      }

      if (mounted) {
        setState(() {
          _isBlocked = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.unblock),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('ChatView: Error unblocking user: $e');
    }
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

        final callState = context.watch<CallBloc>().state;
        CallEntity? activeCall;
        if (callState is CallActiveState && callState.call.chatId == widget.chatId) {
          activeCall = callState.call;
        } else if (callState is CallOutgoingRingingState && callState.call.chatId == widget.chatId) {
          activeCall = callState.call;
        }

        final isRemoteTyping =
            state is ChatLoadSuccess && state.isTypingRemote;
        final isAr = l10n.localeName == 'ar';
        final effectiveLastSeenText = isRemoteTyping
            ? (isAr ? 'يكتب الآن...' : 'Typing...')
            : _lastSeenText;

        return Scaffold(
          backgroundColor: chatTheme.chatBackgroundColor,
          appBar: ChatAppBar(
            chatId: widget.chatId,
            username: widget.username,
            imageUrl: widget.imageUrl,
            userId: widget.peerUserId,
            isPeerActive: isRemoteTyping ? true : _isPeerActive,
            lastSeenAt: _lastSeenAt,
            lastSeenText: effectiveLastSeenText,
            isMuted: _isMuted,
            isPinned: _isPinned,
            isBlocked: _isBlocked,
            onMutedChanged: (val) => setState(() => _isMuted = val),
            onPinnedChanged: (val) => setState(() => _isPinned = val),
            onBlockedChanged: (val) => setState(() => _isBlocked = val),
            onWallpaperUrlChanged: (url) => setState(() => _wallpaperUrl = url),
            onProfileTap: _onPeerHeaderTap,
            onAudioCallTap: () {
              final invitees = widget.peerUserId != null && widget.peerUserId!.isNotEmpty
                  ? [widget.peerUserId!]
                  : null;
              context.read<CallBloc>().add(
                    StartCallEvent(
                      chatId: widget.chatId,
                      type: 'AUDIO',
                      inviteeIds: invitees,
                    ),
                  );
            },
            onVideoCallTap: () {
              final invitees = widget.peerUserId != null && widget.peerUserId!.isNotEmpty
                  ? [widget.peerUserId!]
                  : null;
              context.read<CallBloc>().add(
                    StartCallEvent(
                      chatId: widget.chatId,
                      type: 'VIDEO',
                      inviteeIds: invitees,
                    ),
                  );
            },
          ),

          body: Stack(
            children: [
              ChatPatternBackground(
                backgroundColor: chatTheme.chatBackgroundColor,
                wallpaperUrl: _wallpaperUrl,
                child: Column(
                  children: [
                    if (activeCall != null)
                      ActiveCallBanner(call: activeCall),
                    Expanded(
                      child: isLoading && messages.isEmpty
                          ? const ChatMessageListSkeleton()
                          : ChatMessageList(
                              scrollController: _scrollController,
                              messages: messages.map((m) {
                                final mId = m['id']?.toString();
                                if (mId != null) {
                                  final isTrans = _showTranslationMessageIds.contains(mId);
                                  final transText = _translatedMessageTexts[mId];
                                  final isTranslating = _translatingMessageIds.contains(mId);
                                  if (isTrans || transText != null || isTranslating) {
                                    return {
                                      ...m,
                                      if (transText != null) 'translatedText': transText,
                                      'showTranslation': isTrans,
                                      'isTranslating': isTranslating,
                                    };
                                  }
                                }
                                return m;
                              }).toList(),
                              isTyping: isTypingRemote,
                              username: widget.username,
                              peerImageUrl: widget.imageUrl,
                              peerUserId: widget.peerUserId,
                              currentUserName: currentUserName,
                              currentUserImageUrl: currentUserImageUrl,
                              currentUserId: widget.currentUserId,
                              isRtl: _isRtl,
                              onReactionPicker: _showMessageActions,
                              onToggleTranslate: _toggleMessageTranslation,
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
                              onProfileTap: _onPeerHeaderTap,
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
                    if (_isBlocked)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 10,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          top: false,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.chatYouBlockedUser,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: _unblockUserInChat,
                                style: TextButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary
                                      .withValues(alpha: 0.1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 8,
                                  ),
                                ),
                                child: Text(
                                  l10n.unblock,
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ChatInputBar(
                        controller: _messageController,
                        hasText: hasText,
                        replyPreviewText: replyPreviewText,
                        onSend: _sendMessage,
                        onMoreMenu: () => ChatSheets.showMoreMenu(
                          context: context,
                          onGallery: () => _pickAndSend(
                            ChatAttachmentPicker.pickFromGallery,
                          ),
                          onCamera: () => _pickAndSend(
                            ChatAttachmentPicker.pickFromCamera,
                          ),
                          onVideo: () => _pickAndSend(
                            ChatAttachmentPicker.pickVideo,
                          ),
                          onLocation: _sendLocationAttachment,
                          onContact: _sendContactAttachment,
                          onFile: () => _pickAndSend(
                            ChatAttachmentPicker.pickFile,
                          ),
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
