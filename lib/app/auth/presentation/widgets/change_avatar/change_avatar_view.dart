import 'dart:io';

import 'package:bimobondapp/app/auth/presentation/widgets/change_avatar/change_avatar_option_tile.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/change_avatar/change_avatar_preview.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ChangeAvatarView extends StatelessWidget {
  const ChangeAvatarView({
    required this.l10n,
    required this.avatarUrl,
    required this.fallbackName,
    required this.selectedFile,
    required this.isUploading,
    required this.onTakePhotoTap,
    required this.onGalleryTap,
    required this.onRemoveTap,
    super.key,
  });

  final AppLocalizations l10n;
  final String? avatarUrl;
  final String fallbackName;
  final File? selectedFile;
  final bool isUploading;
  final VoidCallback onTakePhotoTap;
  final VoidCallback onGalleryTap;
  final VoidCallback onRemoveTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: l10n.changeProfilePhoto),
      body: Column(
        children: [
          const SizedBox(height: AppSizes.p32),
          ChangeAvatarPreview(
            avatarUrl: avatarUrl,
            fallbackName: fallbackName,
            selectedFile: selectedFile,
            isUploading: isUploading,
          ),
          const SizedBox(height: AppSizes.p48),
          ChangeAvatarOptionTile(
            icon: LucideIcons.camera,
            label: l10n.takePhoto,
            onTap: isUploading ? null : onTakePhotoTap,
          ),
          ChangeAvatarOptionTile(
            icon: LucideIcons.image,
            label: l10n.imageFromLibrary,
            onTap: isUploading ? null : onGalleryTap,
          ),
          ChangeAvatarOptionTile(
            icon: LucideIcons.trash2,
            label: l10n.removeCurrentPhoto,
            isDestructive: true,
            onTap: isUploading ? null : onRemoveTap,
          ),
        ],
      ),
    );
  }
}
