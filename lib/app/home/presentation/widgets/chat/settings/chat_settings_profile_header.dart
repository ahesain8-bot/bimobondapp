import 'package:bimobondapp/app/home/presentation/widgets/chat/settings/chat_settings_quick_action_button.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ChatSettingsProfileHeader extends StatelessWidget {
  final String username;
  final String imageUrl;
  final String? peerUserId;
  final bool isMuted;
  final VoidCallback onProfileTap;
  final VoidCallback onMuteTap;
  final VoidCallback onReportTap;

  const ChatSettingsProfileHeader({
    super.key,
    required this.username,
    required this.imageUrl,
    this.peerUserId,
    required this.isMuted,
    required this.onProfileTap,
    required this.onMuteTap,
    required this.onReportTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final primaryTextColor = theme.colorScheme.onSurface;
    final secondaryTextColor =
        theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Profile Avatar with Status Ring
          StoryProfileAvatar(
            userId: peerUserId,
            imageUrl: imageUrl,
            radius: 44,
            fallbackText: username,
            isOnline: true,
          ),
          const SizedBox(height: 12),

          // User Name & Handle
          Text(
            username,
            style: TextStyle(
              color: primaryTextColor,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '@${username.toLowerCase().replaceAll(' ', '_')}',
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
              ChatSettingsQuickActionButton(
                icon: LucideIcons.user,
                label: l10n.chatSettingsProfile,
                onTap: onProfileTap,
              ),
              ChatSettingsQuickActionButton(
                icon: isMuted ? LucideIcons.bellOff : LucideIcons.bell,
                label: isMuted ? l10n.chatSettingsMuted : l10n.chatSettingsMute,
                isActive: isMuted,
                onTap: onMuteTap,
              ),
              ChatSettingsQuickActionButton(
                icon: LucideIcons.shieldAlert,
                label: l10n.chatSettingsReport,
                onTap: onReportTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
