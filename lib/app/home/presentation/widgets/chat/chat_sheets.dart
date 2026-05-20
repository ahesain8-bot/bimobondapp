import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/attachment_grid_menu_item.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ChatSheets {
  ChatSheets._();

  static void showUserInfo({
    required BuildContext context,
    required String username,
    required String imageUrl,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ChatLayoutConstants.moreMenuRadius),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ChatLayoutConstants.userInfoPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SafeNetworkAvatar(
                imageUrl: imageUrl,
                radius: ChatLayoutConstants.userInfoAvatarRadius,
                fallbackText: username,
              ),
              const SizedBox(height: AppSizes.p12),
              Text(
                username,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSizes.p8),
              Text(
                l10n.chatUserBio,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void showReactionPicker({
    required BuildContext context,
    required Map<String, dynamic> msg,
    required void Function(String emoji) onEmojiSelected,
  }) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(ChatLayoutConstants.reactionPickerMargin),
        padding: const EdgeInsets.symmetric(
          vertical: ChatLayoutConstants.reactionPickerVerticalPadding,
          horizontal: ChatLayoutConstants.reactionPickerHorizontalPadding,
        ),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(
            ChatLayoutConstants.reactionPickerRadius,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ChatLayoutConstants.reactionEmojis.map((emoji) {
            return GestureDetector(
              onTap: () {
                msg['reactions'] = [emoji];
                onEmojiSelected(emoji);
                Navigator.pop(context);
              },
              child: Text(
                emoji,
                style: const TextStyle(
                  fontSize: ChatLayoutConstants.reactionEmojiSize,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  static void showEmojiPicker({
    required BuildContext context,
    required TextEditingController messageController,
    required VoidCallback onEmojiInserted,
  }) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: ChatLayoutConstants.emojiSheetHeight,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(ChatLayoutConstants.emojiSheetRadius),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: AppSizes.p12),
            Container(
              width: ChatLayoutConstants.emojiSheetHandleWidth,
              height: ChatLayoutConstants.emojiSheetHandleHeight,
              decoration: BoxDecoration(
                color: theme.dividerColor.withValues(
                  alpha: ChatLayoutConstants.emojiSheetHandleAlpha,
                ),
                borderRadius: BorderRadius.circular(
                  ChatLayoutConstants.emojiSheetHandleRadius,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.p16),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: ChatLayoutConstants.emojiGridCrossCount,
                  mainAxisSpacing: ChatLayoutConstants.emojiGridSpacing,
                  crossAxisSpacing: ChatLayoutConstants.emojiGridSpacing,
                ),
                itemCount: ChatLayoutConstants.emojiGridItemCount,
                itemBuilder: (context, index) {
                  final emojis = ChatLayoutConstants.pickerEmojis;
                  final emoji = emojis[index % emojis.length];
                  return Center(
                    child: GestureDetector(
                      onTap: () {
                        messageController.text += emoji;
                        onEmojiInserted();
                        Navigator.pop(context);
                      },
                      child: Text(
                        emoji,
                        style: const TextStyle(
                          fontSize: ChatLayoutConstants.emojiGridEmojiFontSize,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void showMoreMenu({required BuildContext context}) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    final menuColors = chatTheme.moreMenuIconColors;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(ChatLayoutConstants.userInfoPadding),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(ChatLayoutConstants.moreMenuRadius),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: ChatLayoutConstants.moreMenuCrossCount,
              mainAxisSpacing: ChatLayoutConstants.moreMenuMainSpacing,
              children: [
                AttachmentGridMenuItem(
                  icon: LucideIcons.image,
                  label: l10n.chatMoreGallery,
                  color: menuColors[0],
                ),
                AttachmentGridMenuItem(
                  icon: LucideIcons.camera,
                  label: l10n.chatMoreCamera,
                  color: menuColors[1],
                ),
                AttachmentGridMenuItem(
                  icon: LucideIcons.video,
                  label: l10n.chatMoreVideo,
                  color: menuColors[2],
                ),
                AttachmentGridMenuItem(
                  icon: LucideIcons.mapPin,
                  label: l10n.chatMoreLocation,
                  color: menuColors[3],
                ),
                AttachmentGridMenuItem(
                  icon: LucideIcons.userPlus,
                  label: l10n.chatMoreContact,
                  color: menuColors[4],
                ),
                AttachmentGridMenuItem(
                  icon: LucideIcons.file,
                  label: l10n.chatMoreFile,
                  color: menuColors[5],
                ),
                AttachmentGridMenuItem(
                  icon: LucideIcons.gift,
                  label: l10n.chatMoreGift,
                  color: menuColors[6],
                ),
                AttachmentGridMenuItem(
                  icon: LucideIcons.chartBar,
                  label: l10n.chatMorePoll,
                  color: menuColors[7],
                ),
              ],
            ),
            const SizedBox(height: AppSizes.p20),
          ],
        ),
      ),
    );
  }
}
