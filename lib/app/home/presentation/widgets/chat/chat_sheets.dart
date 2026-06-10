import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/attachment_grid_menu_item.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ChatSheets {
  ChatSheets._();

  static void showUserInfo({
    required BuildContext context,
    required String username,
    required String imageUrl,
    String? userId,
  }) {
    if (userId != null && userId.isNotEmpty) {
      openUserActiveStoriesOrProfile(
        context,
        userId: userId,
        username: username,
        avatarUrl: imageUrl,
      );
      return;
    }

    final l10n = AppLocalizations.of(context)!;

    GlassBottomSheet.showContent<void>(
      context,
      child: Padding(
        padding: const EdgeInsets.all(ChatLayoutConstants.userInfoPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StoryProfileAvatar(
              userId: userId,
              imageUrl: imageUrl,
              radius: ChatLayoutConstants.userInfoAvatarRadius,
              fallbackText: username,
              username: username,
            ),
            const SizedBox(height: AppSizes.p12),
            Text(
              username,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppSizes.p8),
            Text(
              l10n.chatUserBio,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void showMessageActions({
    required BuildContext context,
    required VoidCallback onReply,
    required VoidCallback onReact,
    VoidCallback? onDelete,
  }) {
    final l10n = AppLocalizations.of(context)!;

    GlassBottomSheet.showActions<void>(
      context,
      children: [
        GlassBottomSheetActionTile(
          icon: LucideIcons.reply,
          label: l10n.chatActionReply,
          showChevron: false,
          onTap: () {
            Navigator.pop(context);
            onReply();
          },
        ),
        GlassBottomSheetActionTile(
          icon: LucideIcons.smile,
          label: l10n.chatActionReact,
          showChevron: false,
          onTap: () {
            Navigator.pop(context);
            onReact();
          },
        ),
        if (onDelete != null)
          GlassBottomSheetListTile(
            label: l10n.chatActionDelete,
            destructive: true,
            icon: LucideIcons.trash2,
            onTap: () {
              Navigator.pop(context);
              onDelete();
            },
          ),
      ],
    );
  }

  static void showReactionPicker({
    required BuildContext context,
    required Map<String, dynamic> msg,
    required void Function(String emoji) onEmojiSelected,
  }) {
    GlassBottomSheet.open<void>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(ChatLayoutConstants.reactionPickerMargin),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            ChatLayoutConstants.reactionPickerRadius,
          ),
          child: GlassBottomSheetFrame(
            showHandle: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: ChatLayoutConstants.reactionPickerVerticalPadding,
                horizontal: ChatLayoutConstants.reactionPickerHorizontalPadding,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ChatLayoutConstants.reactionEmojis.map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      onEmojiSelected(emoji);
                      Navigator.pop(ctx);
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
          ),
        ),
      ),
    );
  }

  static void showEmojiPicker({
    required BuildContext context,
    required TextEditingController messageController,
    required VoidCallback onEmojiInserted,
  }) {
    GlassBottomSheet.showContent<void>(
      context,
      isScrollControlled: true,
      child: SizedBox(
        height: ChatLayoutConstants.emojiSheetHeight,
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
    );
  }

  static void showMoreMenu({
    required BuildContext context,
    VoidCallback? onGallery,
    VoidCallback? onCamera,
    VoidCallback? onVideo,
    VoidCallback? onLocation,
    VoidCallback? onContact,
    VoidCallback? onFile,
    VoidCallback? onGift,
    VoidCallback? onPoll,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final menuColors = ChatTheme.of(context).moreMenuIconColors;

    void tap(VoidCallback? action) {
      Navigator.pop(context);
      action?.call();
    }

    GlassBottomSheet.showContent<void>(
      context,
      child: Padding(
        padding: const EdgeInsets.all(ChatLayoutConstants.userInfoPadding),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: ChatLayoutConstants.moreMenuCrossCount,
          mainAxisSpacing: ChatLayoutConstants.moreMenuMainSpacing,
          children: [
            AttachmentGridMenuItem(
              icon: LucideIcons.image,
              label: l10n.chatMoreGallery,
              color: menuColors[0],
              glassStyle: true,
              onTap: () => tap(onGallery),
            ),
            AttachmentGridMenuItem(
              icon: LucideIcons.camera,
              label: l10n.chatMoreCamera,
              color: menuColors[1],
              glassStyle: true,
              onTap: () => tap(onCamera),
            ),
            AttachmentGridMenuItem(
              icon: LucideIcons.video,
              label: l10n.chatMoreVideo,
              color: menuColors[2],
              glassStyle: true,
              onTap: () => tap(onVideo),
            ),
            AttachmentGridMenuItem(
              icon: LucideIcons.mapPin,
              label: l10n.chatMoreLocation,
              color: menuColors[3],
              glassStyle: true,
              onTap: () => tap(onLocation),
            ),
            AttachmentGridMenuItem(
              icon: LucideIcons.userPlus,
              label: l10n.chatMoreContact,
              color: menuColors[4],
              glassStyle: true,
              onTap: () => tap(onContact),
            ),
            AttachmentGridMenuItem(
              icon: LucideIcons.file,
              label: l10n.chatMoreFile,
              color: menuColors[5],
              glassStyle: true,
              onTap: () => tap(onFile),
            ),
            AttachmentGridMenuItem(
              icon: LucideIcons.gift,
              label: l10n.chatMoreGift,
              color: menuColors[6],
              glassStyle: true,
              onTap: () => tap(onGift),
            ),
            AttachmentGridMenuItem(
              icon: LucideIcons.chartBar,
              label: l10n.chatMorePoll,
              color: menuColors[7],
              glassStyle: true,
              onTap: () => tap(onPoll),
            ),
          ],
        ),
      ),
    );
  }
}
