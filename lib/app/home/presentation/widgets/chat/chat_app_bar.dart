import 'package:bimobondapp/app/home/presentation/pages/bimo_bond_chat_settings_screen.dart';
import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/core/utils/system_ui_overlay_utils.dart';
import 'package:bimobondapp/core/widgets/directional_back_icon.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({
    required this.chatId,
    required this.username,
    required this.imageUrl,
    required this.onProfileTap,
    this.onAudioCallTap,
    this.onVideoCallTap,
    this.userId,
    this.isPeerActive = false,
    this.lastSeenAt,
    this.lastSeenText,
    this.isMuted = false,
    this.isPinned = false,
    this.isBlocked = false,
    this.onMutedChanged,
    this.onPinnedChanged,
    this.onBlockedChanged,
    this.onWallpaperUrlChanged,
    super.key,
  });

  final String chatId;
  final String username;
  final String imageUrl;
  final VoidCallback onProfileTap;
  final VoidCallback? onAudioCallTap;
  final VoidCallback? onVideoCallTap;
  final String? userId;
  final bool isPeerActive;
  final String? lastSeenAt;
  final String? lastSeenText;
  final bool isMuted;
  final bool isPinned;
  final bool isBlocked;
  final ValueChanged<bool>? onMutedChanged;
  final ValueChanged<bool>? onPinnedChanged;
  final ValueChanged<bool>? onBlockedChanged;
  final ValueChanged<String?>? onWallpaperUrlChanged;

  String _buildStatusText(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName == 'ar';
    if (isPeerActive) {
      return l10n.chatActiveNow;
    }
    if (lastSeenText != null && lastSeenText!.trim().isNotEmpty) {
      return lastSeenText!.trim();
    }
    if (lastSeenAt != null && lastSeenAt!.trim().isNotEmpty) {
      try {
        final dt = DateTime.parse(lastSeenAt!).toLocal();
        final now = DateTime.now();
        final difference = now.difference(dt);

        if (difference.inMinutes < 5) {
          return l10n.chatActiveNow;
        }

        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));
        final date = DateTime(dt.year, dt.month, dt.day);

        final hourStr = dt.hour.toString().padLeft(2, '0');
        final minStr = dt.minute.toString().padLeft(2, '0');
        final timeStr = '$hourStr:$minStr';

        if (date == today) {
          return isAr
              ? 'آخر ظهور اليوم الساعة $timeStr'
              : 'Last seen today at $timeStr';
        } else if (date == yesterday) {
          return isAr
              ? 'آخر ظهور أمس الساعة $timeStr'
              : 'Last seen yesterday at $timeStr';
        } else if (difference.inDays < 30) {
          return isAr
              ? 'آخر ظهور منذ ${difference.inDays} ${difference.inDays == 1 ? 'يوم' : 'أيام'}'
              : 'Last seen ${difference.inDays}d ago';
        } else {
          return isAr
              ? 'آخر ظهور ${dt.day}/${dt.month}/${dt.year}'
              : 'Last seen ${dt.day}/${dt.month}/${dt.year}';
        }
      } catch (_) {}
    }
    return l10n.chatActiveNow;
  }

  @override
  Size get preferredSize => Size.fromHeight(ChatLayoutConstants.appBarHeight);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final overlay = appContentSystemUiOverlayStyle(theme.brightness);

    final statusText = _buildStatusText(context);
    final isOnlineNow = isPeerActive || statusText == l10n.chatActiveNow;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Directionality(
        textDirection: Directionality.of(context),
        child: Material(
          color: theme.scaffoldBackgroundColor,
          elevation: 0,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: ChatLayoutConstants.appBarHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.p4),
                child: Row(
                  children: [
                    IconButton(
                      icon: DirectionalBackIcon(
                        color: onSurface,
                        size: ChatLayoutConstants.appBarLeadingIconSize,
                      ),
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: onProfileTap,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.p4,
                            vertical: AppSizes.p4,
                          ),
                          child: Row(
                            children: [
                              StoryProfileAvatar(
                                userId: userId,
                                imageUrl: imageUrl,
                                radius: ChatLayoutConstants.headerAvatarRadius,
                                fallbackText: username,
                                username: username,
                                fullName: username,
                                isOnline: isOnlineNow,
                                onTap: onProfileTap,
                              ),

                              const SizedBox(width: AppSizes.p10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      username,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontSize: ChatLayoutConstants
                                                .headerTitleFontSize,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: ChatLayoutConstants
                                                .headerTitleLetterSpacing,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.left,
                                    ),
                                    Text(
                                      statusText,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: isOnlineNow
                                                ? chatTheme.activeStatus
                                                : chatTheme.inboxSecondaryText,
                                            fontSize: ChatLayoutConstants
                                                .headerStatusFontSize,
                                            fontWeight: FontWeight.w500,
                                          ),
                                      textAlign: TextAlign.left,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (!isBlocked) ...[
                      IconButton(
                        icon: Icon(
                          LucideIcons.phone,
                          color: onSurface,
                          size: ChatLayoutConstants.appBarActionIconSize,
                        ),
                        onPressed: onAudioCallTap,
                      ),
                      IconButton(
                        icon: Icon(
                          LucideIcons.video,
                          color: onSurface,
                          size: ChatLayoutConstants.appBarActionIconSize,
                        ),
                        onPressed: onVideoCallTap,
                      ),
                    ],

                    IconButton(
                      icon: Icon(
                        LucideIcons.ellipsisVertical,
                        color: onSurface,
                        size: ChatLayoutConstants.appBarActionIconSize,
                      ),
                      tooltip: 'Details',
                      onPressed: () async {
                        final result = await Navigator.of(context)
                            .push<Map<String, dynamic>>(
                              MaterialPageRoute(
                                builder: (_) => BimoBondChatSettingsScreen(
                                  chatId: chatId,
                                  username: username,
                                  imageUrl: imageUrl,
                                  peerUserId: userId,
                                  initialIsMuted: isMuted,
                                  initialIsPinned: isPinned,
                                  initialIsBlocked: isBlocked,
                                ),
                              ),
                            );
                        if (result != null) {
                          final nextMuted = result['isMuted'] == true;
                          final nextPinned = result['isPinned'] == true;
                          final nextBlocked = result['isBlocked'] == true;
                          final nextWallpaper =
                              result['wallpaperUrl'] as String?;
                          onMutedChanged?.call(nextMuted);
                          onPinnedChanged?.call(nextPinned);
                          onBlockedChanged?.call(nextBlocked);
                          onWallpaperUrlChanged?.call(nextWallpaper);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
