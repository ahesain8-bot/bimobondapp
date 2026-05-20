import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';

class ProfileHeaderWidget extends StatelessWidget {
  final String? avatarUrl;
  final String? username;
  final String? fullName;
  final VoidCallback? onEditPressed;

  const ProfileHeaderWidget({
    super.key,
    this.avatarUrl,
    this.username,
    this.fullName,
    this.onEditPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Center(
          child: Stack(
            children: [
              SafeNetworkAvatar(
                imageUrl: avatarUrl,
                radius: 50,
                fallbackText: username ?? fullName,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(AppSizes.p4),
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.plus,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        // const SizedBox(height: AppSizes.p12),
        // Full Name with Edit Button
        if (fullName != null && fullName!.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomText(fullName!, fontSize: 20, fontWeight: FontWeight.bold),
              const SizedBox(width: AppSizes.p8),
              TextButton(
                onPressed: onEditPressed,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: theme.primaryColor,
                ),
                child: CustomText(
                  l10n.edit,
                  color: theme.primaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        // const SizedBox(height: AppSizes.p4),
        // Username
        CustomText(
          '@${username ?? 'username'}',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          variant: TextVariant.secondary,
        ),
      ],
    );
  }
}
