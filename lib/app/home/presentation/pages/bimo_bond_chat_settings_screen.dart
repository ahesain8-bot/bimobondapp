import 'package:bimobondapp/app/home/presentation/pages/chat_wallpaper_settings_screen.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/settings/chat_settings_navigation_tile.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/settings/chat_settings_profile_header.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/settings/chat_settings_switch_tile.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:bimobondapp/core/widgets/directional_back_icon.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:bimobondapp/core/navigation/user_profile_navigation.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class BimoBondChatSettingsScreen extends StatefulWidget {
  final String chatId;
  final String username;
  final String imageUrl;
  final String? peerUserId;
  final bool initialIsMuted;
  final bool initialIsPinned;
  final bool initialIsBlocked;

  const BimoBondChatSettingsScreen({
    super.key,
    required this.chatId,
    required this.username,
    required this.imageUrl,
    this.peerUserId,
    this.initialIsMuted = false,
    this.initialIsPinned = false,
    this.initialIsBlocked = false,
  });

  @override
  State<BimoBondChatSettingsScreen> createState() =>
      _BimoBondChatSettingsScreenState();
}

class _BimoBondChatSettingsScreenState
    extends State<BimoBondChatSettingsScreen> {
  late bool _isMuted;
  late bool _isPinned;
  late bool _isBlocked;
  String? _wallpaperUrl;

  @override
  void initState() {
    super.initState();
    _isMuted = widget.initialIsMuted;
    _isPinned = widget.initialIsPinned;
    _isBlocked = widget.initialIsBlocked;
    _fetchChatDetails();
  }

  Future<void> _fetchChatDetails() async {
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
        final backendPinned = data['isPinned'] == true ||
            data['is_pinned'] == true ||
            data['pinned'] == true ||
            settingsMap?['isPinned'] == true ||
            settingsMap?['is_pinned'] == true;
        final backendMuted = data['isMuted'] == true ||
            data['is_muted'] == true ||
            data['muted'] == true ||
            settingsMap?['isMuted'] == true ||
            settingsMap?['is_muted'] == true;
        final backendBlocked = data['isBlocked'] == true ||
            data['isBlockedByYou'] == true ||
            data['isBlockedByThem'] == true ||
            data['is_blocked'] == true ||
            data['blocked'] == true ||
            settingsMap?['isBlocked'] == true ||
            settingsMap?['is_blocked'] == true;

        final backendWallpaper = data['personalWallpaperUrl']?.toString() ??
            data['wallpaperUrl']?.toString() ??
            data['sharedWallpaperUrl']?.toString() ??
            settingsMap?['wallpaperUrl']?.toString();

        if (mounted) {
          setState(() {
            _isPinned = widget.initialIsPinned || backendPinned;
            _isMuted = widget.initialIsMuted || backendMuted;
            _isBlocked = widget.initialIsBlocked || backendBlocked;
            _wallpaperUrl = backendWallpaper ?? _wallpaperUrl;
          });
        }
      }

      if (widget.peerUserId != null && widget.peerUserId!.isNotEmpty) {
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
                return id?.toString() == widget.peerUserId;
              }
              return item?.toString() == widget.peerUserId;
            });
            if (isBlockedInList && mounted) {
              setState(() {
                _isBlocked = true;
              });
            }
          }
        } catch (e) {
          debugPrint('Error checking blocks list: $e');
        }

        try {
          final relRes = await dio.get(
            ApiConstants.userRelationship(widget.peerUserId!),
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
          debugPrint('Error checking user relationship: $e');
        }

        try {
          final followRes = await dio.get(
            ApiConstants.userFollowStatus(widget.peerUserId!),
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
            }
          }
        } catch (e) {
          debugPrint('Error checking follow status: $e');
        }
      }
    } catch (e) {
      debugPrint('BimoBondChatSettingsScreen: Error fetching chat details: $e');
    }
  }

  Future<void> _updateSettings({bool? isMuted, bool? isPinned}) async {
    final prevMuted = _isMuted;
    final prevPinned = _isPinned;
    final nextMuted = isMuted ?? _isMuted;
    final nextPinned = isPinned ?? _isPinned;

    setState(() {
      _isMuted = nextMuted;
      _isPinned = nextPinned;
    });

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

      await dio.patch(
        ApiConstants.chatSettings(widget.chatId),
        data: {
          'isMuted': nextMuted,
          'isPinned': nextPinned,
        },
      );

      if (mounted) {
        final feedbackText = isMuted != null
            ? (nextMuted ? 'Notifications muted' : 'Notifications unmuted')
            : (nextPinned ? 'Chat pinned to top' : 'Chat unpinned');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(feedbackText),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('BimoBondChatSettingsScreen: Error updating settings: $e');
      if (mounted) {
        setState(() {
          _isMuted = prevMuted;
          _isPinned = prevPinned;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update settings: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _blockUser() async {
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

      await dio.post(ApiConstants.blockUser(widget.peerUserId!));
      if (mounted) {
        setState(() {
          _isBlocked = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.chatSettingsBlocked),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('BimoBondChatSettingsScreen: Error blocking user: $e');
    }
  }

  Future<void> _unblockUser() async {
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
      debugPrint('BimoBondChatSettingsScreen: Error unblocking user: $e');
    }
  }

  void _showUnblockConfirmation() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '${l10n.unblock} @${widget.username}',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to unblock @${widget.username}?',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              l10n.cancel,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _unblockUser();
            },
            child: Text(
              l10n.unblock,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteChat() async {
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

      await dio.delete(ApiConstants.chatById(widget.chatId));
      if (mounted) {
        Navigator.of(context).pop(); // Close settings screen
        Navigator.of(context).pop(); // Close chat thread back to inbox
      }
    } catch (e) {
      debugPrint('BimoBondChatSettingsScreen: Error deleting chat: $e');
    }
  }

  void _showBlockConfirmation() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.chatSettingsBlockTitle(widget.username),
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          l10n.chatSettingsBlockMessage,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              l10n.cancel,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _blockUser();
            },
            child: Text(
              l10n.chatSettingsBlock(widget.username).split(' ').first,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.chatSettingsDeleteTitle,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          l10n.chatSettingsDeleteMessage,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              l10n.cancel,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _deleteChat();
            },
            child: Text(
              l10n.deleteAction,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.chatSettingsReportTitle(widget.username),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(LucideIcons.shieldAlert, color: Colors.orange),
                title: Text(
                  l10n.chatSettingsReportSpam,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _submitReport(l10n.chatSettingsReportSpam);
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.messageSquareX, color: Colors.red),
                title: Text(
                  l10n.chatSettingsReportHarassment,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _submitReport(l10n.chatSettingsReportHarassment);
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.alertTriangle, color: Colors.amber),
                title: Text(
                  l10n.chatSettingsReportInappropriate,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _submitReport(l10n.chatSettingsReportInappropriate);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submitReport(String reason) {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.chatSettingsReportSubmitted(reason)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final backgroundColor = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;
    final primaryTextColor = theme.colorScheme.onSurface;
    final dividerColor = theme.dividerColor;
    final dangerColor = theme.colorScheme.error;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop({
          'isMuted': _isMuted,
          'isPinned': _isPinned,
          'isBlocked': _isBlocked,
          'wallpaperUrl': _wallpaperUrl,
        });
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: DirectionalBackIcon(color: primaryTextColor, size: 22),
            onPressed: () => Navigator.of(context).pop({
              'isMuted': _isMuted,
              'isPinned': _isPinned,
              'isBlocked': _isBlocked,
              'wallpaperUrl': _wallpaperUrl,
            }),
          ),
        centerTitle: true,
        title: Text(
          l10n.chatSettingsTitle,
          style: TextStyle(
            color: primaryTextColor,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 12),

            // Top Profile Card & Quick Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ChatSettingsProfileHeader(
                username: widget.username,
                imageUrl: widget.imageUrl,
                peerUserId: widget.peerUserId,
                isMuted: _isMuted,
                onProfileTap: () {
                  if (widget.peerUserId != null &&
                      widget.peerUserId!.trim().isNotEmpty) {
                    openUserProfile(
                      context,
                      userId: widget.peerUserId!.trim(),
                      username: widget.username,
                      avatarUrl: widget.imageUrl,
                    );
                  }
                },
                onMuteTap: () => _updateSettings(isMuted: !_isMuted),
                onReportTap: _showReportDialog,
              ),
            ),
            const SizedBox(height: 16),

            // Grouped Section 1: Notifications & Personalization
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    ChatSettingsSwitchTile(
                      icon: LucideIcons.bell,
                      title: l10n.chatSettingsMuteNotifications,
                      value: _isMuted,
                      onChanged: (val) => _updateSettings(isMuted: val),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: dividerColor,
                    ),
                    ChatSettingsSwitchTile(
                      icon: LucideIcons.pin,
                      title: l10n.chatSettingsPinToTop,
                      value: _isPinned,
                      onChanged: (val) => _updateSettings(isPinned: val),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: dividerColor,
                    ),
                    ChatSettingsNavigationTile(
                      icon: LucideIcons.image,
                      title: l10n.chatWallpaperTitle,
                      subtitle: l10n.chatSettingsWallpaperSubtitle,
                      onTap: () async {
                        final res = await Navigator.of(context).push<dynamic>(
                          MaterialPageRoute(
                            builder: (_) => ChatWallpaperSettingsScreen(
                              chatId: widget.chatId,
                              currentWallpaperUrl: _wallpaperUrl,
                            ),
                          ),
                        );
                        if (res is String && mounted) {
                          setState(() {
                            _wallpaperUrl = res;
                          });
                        } else if (res == null && mounted) {
                          setState(() {
                            _wallpaperUrl = null;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Grouped Section 2: Privacy & Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    ChatSettingsNavigationTile(
                      icon: _isBlocked
                          ? LucideIcons.userCheck
                          : LucideIcons.userX,
                      title: _isBlocked
                          ? l10n.unblock
                          : l10n.chatSettingsBlock(widget.username),
                      titleColor:
                          _isBlocked ? theme.colorScheme.primary : dangerColor,
                      onTap: _isBlocked
                          ? _showUnblockConfirmation
                          : _showBlockConfirmation,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Grouped Section 3: Danger Zone / Clear History
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    ChatSettingsNavigationTile(
                      icon: LucideIcons.trash2,
                      title: l10n.chatSettingsDeleteHistory,
                      titleColor: dangerColor,
                      onTap: _showDeleteConfirmation,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    ),
  );
}
}
