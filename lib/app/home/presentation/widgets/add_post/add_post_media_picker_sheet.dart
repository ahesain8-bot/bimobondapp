import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/attachment_grid_menu_item.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AddPostMediaPickerSheet {
  AddPostMediaPickerSheet._();

  static Future<void> show(
    BuildContext context, {
    required void Function(ImageSource source, {required bool isVideo}) onPick,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final menuColors = ChatTheme.of(context).moreMenuIconColors;

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(ChatLayoutConstants.userInfoPadding),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(ChatLayoutConstants.moreMenuRadius),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: ChatLayoutConstants.moreMenuCrossCount,
                mainAxisSpacing: ChatLayoutConstants.moreMenuMainSpacing,
                children: [
                  AttachmentGridMenuItem(
                    icon: LucideIcons.camera,
                    label: l10n.takePhoto,
                    color: menuColors[0],
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onPick(ImageSource.camera, isVideo: false);
                    },
                  ),
                  AttachmentGridMenuItem(
                    icon: LucideIcons.video,
                    label: l10n.recordVideo,
                    color: menuColors[1],
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onPick(ImageSource.camera, isVideo: true);
                    },
                  ),
                  AttachmentGridMenuItem(
                    icon: LucideIcons.images,
                    label: l10n.imageFromLibrary,
                    color: menuColors[2],
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onPick(ImageSource.gallery, isVideo: false);
                    },
                  ),
                  AttachmentGridMenuItem(
                    icon: LucideIcons.film,
                    label: l10n.videoFromLibrary,
                    color: menuColors[3],
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onPick(ImageSource.gallery, isVideo: true);
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.p20),
            ],
          ),
        ),
      ),
    );
  }
}
