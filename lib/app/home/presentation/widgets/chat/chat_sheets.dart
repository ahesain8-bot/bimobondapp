import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/tag_text_editing.dart';
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
    String? fullName,
  }) {
    if (userId != null && userId.isNotEmpty) {
      openUserActiveStoriesOrProfile(
        context,
        userId: userId,
        username: username,
        fullName: fullName,
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
              fullName: fullName,
            ),
            const SizedBox(height: AppSizes.p12),
            Text(
              fullName ?? username,
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
              style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
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
    required void Function(String emoji) onEmojiSelected,
    VoidCallback? onTranslate,
    bool isTranslated = false,
    bool isTranslating = false,
    VoidCallback? onDelete,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final onSurface = theme.colorScheme.onSurface;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                // Top Quick Reaction Emoji Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: ChatLayoutConstants.reactionEmojis.map((emoji) {
                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(sheetCtx);
                              onEmojiSelected(emoji);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 26),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  color: theme.dividerColor.withValues(alpha: 0.5),
                ),

                // Action List Tiles
                ListTile(
                  leading: Icon(
                    LucideIcons.reply,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    l10n.chatActionReply,
                    style: TextStyle(
                      color: onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    onReply();
                  },
                ),
                ListTile(
                  leading: Icon(
                    LucideIcons.smile,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    l10n.chatActionReact,
                    style: TextStyle(
                      color: onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    onReact();
                  },
                ),
                if (onTranslate != null)
                  ListTile(
                    leading: isTranslating
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : Icon(
                            LucideIcons.languages,
                            color: theme.colorScheme.primary,
                          ),
                    title: Text(
                      isTranslating
                          ? (l10n.localeName.startsWith('ar')
                              ? 'جاري الترجمة...'
                              : 'Translating...')
                          : isTranslated
                              ? (l10n.localeName.startsWith('ar')
                                  ? 'عرض النص الأصلي'
                                  : 'Show original')
                              : (l10n.localeName.startsWith('ar')
                                  ? 'ترجمة الرسالة'
                                  : 'Translate message'),
                      style: TextStyle(
                        color: onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    onTap: isTranslating
                        ? null
                        : () {
                            Navigator.pop(sheetCtx);
                            onTranslate();
                          },
                  ),
                if (onDelete != null) ...[
                  Divider(
                    height: 1,
                    color: theme.dividerColor.withValues(alpha: 0.5),
                  ),
                  ListTile(
                    leading: const Icon(LucideIcons.trash2, color: Colors.red),
                    title: Text(
                      l10n.chatActionDelete,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      onDelete();
                    },
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
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
      elevation: 0,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 10,
            ),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: ChatLayoutConstants.pickerEmojis.map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      onEmojiSelected(emoji);
                      Navigator.pop(ctx);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 28),
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
                  TagTextEditing.insertText(messageController, emoji);
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
          ],
        ),
      ),
    );
  }
}
