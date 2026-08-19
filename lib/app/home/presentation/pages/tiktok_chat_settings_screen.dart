import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:bimobondapp/core/widgets/directional_back_icon.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class TikTokChatSettingsScreen extends StatefulWidget {
  final String chatId;
  final String username;
  final String imageUrl;
  final String? peerUserId;
  final bool initialIsMuted;
  final bool initialIsPinned;

  const TikTokChatSettingsScreen({
    super.key,
    required this.chatId,
    required this.username,
    required this.imageUrl,
    this.peerUserId,
    this.initialIsMuted = false,
    this.initialIsPinned = false,
  });

  @override
  State<TikTokChatSettingsScreen> createState() =>
      _TikTokChatSettingsScreenState();
}

class _TikTokChatSettingsScreenState extends State<TikTokChatSettingsScreen> {
  late bool _isMuted;
  late bool _isPinned;
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    _isMuted = widget.initialIsMuted;
    _isPinned = widget.initialIsPinned;
  }

  Future<void> _updateSettings({bool? isMuted, bool? isPinned}) async {
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
    } catch (e) {
      debugPrint('TikTokChatSettingsScreen: Error updating settings: $e');
    }
  }

  Future<void> _blockUser() async {
    if (widget.peerUserId == null || widget.peerUserId!.isEmpty) return;
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
            content: Text('Blocked @${widget.username}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('TikTokChatSettingsScreen: Error blocking user: $e');
    }
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
      debugPrint('TikTokChatSettingsScreen: Error deleting chat: $e');
    }
  }

  void _showBlockConfirmation() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Block @${widget.username}?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'They will not be able to send you messages, view your profile, or see your activity.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _blockUser();
            },
            child: const Text(
              'Block',
              style: TextStyle(color: Color(0xFFFF453A), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete conversation?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will remove the chat history for you. This action cannot be undone.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _deleteChat();
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFFF453A), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white.withValues(alpha: 0.55) : Colors.black54;
    final dividerColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: DirectionalBackIcon(color: primaryTextColor, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          'Details',
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
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Profile Avatar with Status Ring
                    StoryProfileAvatar(
                      userId: widget.peerUserId,
                      imageUrl: widget.imageUrl,
                      radius: 44,
                      fallbackText: widget.username,
                      isOnline: true,
                    ),
                    const SizedBox(height: 12),

                    // User Name & Handle
                    Text(
                      widget.username,
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${widget.username.toLowerCase().replaceAll(' ', '_')}',
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Horizontal Quick Action Buttons (Profile | Mute | Report)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _QuickActionButton(
                          icon: LucideIcons.user,
                          label: 'Profile',
                          isDark: isDark,
                          onTap: () {
                            if (widget.peerUserId != null && widget.peerUserId!.isNotEmpty) {
                              context.pushNamed(
                                'user_profile',
                                pathParameters: {'id': widget.peerUserId!},
                              );
                            }
                          },
                        ),
                        _QuickActionButton(
                          icon: _isMuted ? LucideIcons.bellOff : LucideIcons.bell,
                          label: _isMuted ? 'Muted' : 'Mute',
                          isActive: _isMuted,
                          isDark: isDark,
                          onTap: () => _updateSettings(isMuted: !_isMuted),
                        ),
                        _QuickActionButton(
                          icon: LucideIcons.shieldAlert,
                          label: 'Report',
                          isDark: isDark,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Report sheet opened'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
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
                    _SwitchTile(
                      icon: LucideIcons.bell,
                      title: 'Mute notifications',
                      value: _isMuted,
                      primaryColor: primaryTextColor,
                      secondaryColor: secondaryTextColor,
                      onChanged: (val) => _updateSettings(isMuted: val),
                    ),
                    Divider(height: 1, indent: 56, color: dividerColor),
                    _SwitchTile(
                      icon: LucideIcons.pin,
                      title: 'Pin to top',
                      value: _isPinned,
                      primaryColor: primaryTextColor,
                      secondaryColor: secondaryTextColor,
                      onChanged: (val) => _updateSettings(isPinned: val),
                    ),
                    Divider(height: 1, indent: 56, color: dividerColor),
                    _NavigationTile(
                      icon: LucideIcons.image,
                      title: 'Chat wallpaper',
                      subtitle: 'Custom theme background',
                      primaryColor: primaryTextColor,
                      secondaryColor: secondaryTextColor,
                      onTap: () {
                        context.pushNamed('chat_wallpaper_settings');
                      },
                    ),
                    Divider(height: 1, indent: 56, color: dividerColor),
                    _NavigationTile(
                      icon: LucideIcons.search,
                      title: 'Search in conversation',
                      primaryColor: primaryTextColor,
                      secondaryColor: secondaryTextColor,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Search in conversation'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
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
                    _NavigationTile(
                      icon: LucideIcons.userX,
                      title: _isBlocked ? 'Blocked' : 'Block @${widget.username}',
                      titleColor: const Color(0xFFFF453A),
                      primaryColor: primaryTextColor,
                      secondaryColor: secondaryTextColor,
                      onTap: _isBlocked ? null : _showBlockConfirmation,
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
                    _NavigationTile(
                      icon: LucideIcons.trash2,
                      title: 'Delete chat history',
                      titleColor: const Color(0xFFFF453A),
                      primaryColor: primaryTextColor,
                      secondaryColor: secondaryTextColor,
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
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    this.isActive = false,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final activeColor = isActive ? const Color(0xFFFE2C55) : (isDark ? Colors.white : Colors.black87);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: activeBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: activeColor, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white.withValues(alpha: 0.7) : Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final Color primaryColor;
  final Color secondaryColor;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: primaryColor, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: primaryColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: const Color(0xFFFE2C55),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _NavigationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Color primaryColor;
  final Color secondaryColor;
  final VoidCallback? onTap;

  const _NavigationTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.titleColor,
    required this.primaryColor,
    required this.secondaryColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTitleColor = titleColor ?? primaryColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: effectiveTitleColor, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: effectiveTitleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: secondaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              color: secondaryColor.withValues(alpha: 0.5),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
