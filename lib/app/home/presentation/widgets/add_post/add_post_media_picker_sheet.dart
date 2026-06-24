import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/attachment_grid_menu_item.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AddPostMediaPickerSheet {
  AddPostMediaPickerSheet._();

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onOpenCamera,
    required VoidCallback onOpenGallery,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final menuColors = ChatTheme.of(context).moreMenuIconColors;

    return GlassBottomSheet.showContent<void>(
      context,
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: ChatLayoutConstants.moreMenuCrossCount,
        mainAxisSpacing: ChatLayoutConstants.moreMenuMainSpacing,
        padding: const EdgeInsets.fromLTRB(
          AppSizes.p16,
          0,
          AppSizes.p16,
          AppSizes.p16,
        ),
        children: [
          AttachmentGridMenuItem(
            icon: LucideIcons.clapperboard,
            label: l10n.openCameraStudio,
            color: menuColors[0],
            glassStyle: true,
            onTap: () {
              Navigator.pop(context);
              onOpenCamera();
            },
          ),
          AttachmentGridMenuItem(
            icon: LucideIcons.images,
            label: l10n.uploadFromLibrary,
            color: menuColors[2],
            glassStyle: true,
            onTap: () {
              Navigator.pop(context);
              onOpenGallery();
            },
          ),
        ],
      ),
    );
  }
}
