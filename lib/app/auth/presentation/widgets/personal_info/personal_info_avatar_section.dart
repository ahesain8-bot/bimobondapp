import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class PersonalInfoAvatarSection extends StatelessWidget {
  const PersonalInfoAvatarSection({
    required this.l10n,
    required this.avatarUrl,
    required this.fallbackName,
    required this.onChangePhotoTap,
    super.key,
  });

  final AppLocalizations l10n;
  final String? avatarUrl;
  final String fallbackName;
  final VoidCallback onChangePhotoTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: onChangePhotoTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                SafeNetworkAvatar(
                  imageUrl: avatarUrl,
                  radius: 48,
                  fallbackText: fallbackName.isNotEmpty ? fallbackName : 'User',
                  backgroundColor: Colors.grey.shade200,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.scaffoldBackgroundColor,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      LucideIcons.camera,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.p12),
          GestureDetector(
            onTap: onChangePhotoTap,
            child: CustomText(
              l10n.changePhoto,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
