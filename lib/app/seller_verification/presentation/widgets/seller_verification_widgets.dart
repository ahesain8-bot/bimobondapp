import 'dart:io';

import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SellerVerificationPassportPicker extends StatelessWidget {
  const SellerVerificationPassportPicker({
    required this.onTap,
    this.file,
    this.uploaded = false,
    this.loading = false,
    super.key,
  });

  final VoidCallback? onTap;
  final File? file;
  final bool uploaded;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final fill = isDark ? theme.cardColor : Colors.grey[100];

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.p12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            border: Border.all(
              color: isDark ? Colors.white24 : Colors.black12,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: file != null
                      ? Image.file(file!, fit: BoxFit.cover)
                      : ColoredBox(
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                          child: Icon(
                            uploaded
                                ? LucideIcons.circleCheck
                                : LucideIcons.camera,
                            color: AppTheme.primaryColor,
                            size: 28,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: AppSizes.p12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText(
                      l10n.sellerVerificationPassportPhoto,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    const SizedBox(height: 4),
                    CustomText(
                      loading
                          ? l10n.sellerVerificationUploading
                          : uploaded
                              ? l10n.sellerVerificationUploaded
                              : l10n.sellerVerificationTapToUpload,
                      fontSize: 13,
                      variant: TextVariant.secondary,
                    ),
                  ],
                ),
              ),
              if (loading)
                const CustomLoadingWidget(size: 28)
              else
                Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SellerVerificationRejectionBanner extends StatelessWidget {
  const SellerVerificationRejectionBanner({
    required this.reason,
    super.key,
  });

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p12),
      decoration: BoxDecoration(
        color: AppTheme.errorColor,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(
          color: AppTheme.errorAccent.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            LucideIcons.circleAlert,
            size: 18,
            color: AppTheme.errorAccent,
          ),
          const SizedBox(width: AppSizes.p10),
          Expanded(
            child: CustomText(
              reason,
              fontSize: 13,
              color: AppTheme.errorAccent,
            ),
          ),
        ],
      ),
    );
  }
}
