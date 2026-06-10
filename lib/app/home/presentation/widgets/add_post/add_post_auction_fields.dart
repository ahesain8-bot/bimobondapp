import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AddPostAuctionDateParts {
  const AddPostAuctionDateParts({
    required this.dateLine,
    required this.timeLine,
  });

  final String dateLine;
  final String timeLine;
}

AddPostAuctionDateParts parseAddPostAuctionDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = months[local.month - 1];
  final h = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return AddPostAuctionDateParts(
    dateLine: '$month ${local.day}, ${local.year}',
    timeLine: '$h:$min',
  );
}

class AddPostAuctionFields extends StatelessWidget {
  const AddPostAuctionFields({
    required this.itemNameController,
    required this.startingPriceController,
    required this.targetPriceController,
    required this.startDate,
    required this.endDate,
    required this.onPickStartDate,
    required this.onPickEndDate,
    super.key,
  });

  final TextEditingController itemNameController;
  final TextEditingController startingPriceController;
  final TextEditingController targetPriceController;
  final DateTime startDate;
  final DateTime endDate;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndDate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final fieldFill = isDark
        ? const Color(0xFF2A2A2D)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : colorScheme.outlineVariant.withValues(alpha: 0.65);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: borderColor),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 10),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AuctionFormHeader(
            title: l10n.addPostAsAuction,
            subtitle: l10n.auctionItemNameHint,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.p16,
              AppSizes.p4,
              AppSizes.p16,
              AppSizes.p16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AuctionTextField(
                  controller: itemNameController,
                  label: l10n.auctionItemName,
                  hint: l10n.auctionItemNameHint,
                  icon: LucideIcons.package,
                  fillColor: fieldFill,
                ),
                const SizedBox(height: AppSizes.p20),
                CustomText(
                  l10n.auctionsFiltersPriceRange,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  variant: TextVariant.secondary,
                ),
                const SizedBox(height: AppSizes.p10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _AuctionTextField(
                        controller: startingPriceController,
                        label: l10n.auctionsFiltersMinPrice,
                        hint: '0',
                        icon: LucideIcons.dollarSign,
                        fillColor: fieldFill,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.,]'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSizes.p12),
                    Expanded(
                      child: _AuctionTextField(
                        controller: targetPriceController,
                        label: l10n.auctionsFiltersMaxPrice,
                        hint: '0',
                        icon: LucideIcons.target,
                        fillColor: fieldFill,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.,]'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.p20),
                Row(
                  children: [
                    Expanded(
                      child: _AuctionDateCard(
                        label: l10n.auctionStartDate,
                        parts: parseAddPostAuctionDateTime(startDate),
                        icon: LucideIcons.play,
                        accent: colorScheme.primary,
                        fillColor: fieldFill,
                        onTap: onPickStartDate,
                      ),
                    ),
                    const SizedBox(width: AppSizes.p12),
                    Expanded(
                      child: _AuctionDateCard(
                        label: l10n.auctionEndDate,
                        parts: parseAddPostAuctionDateTime(endDate),
                        icon: LucideIcons.flag,
                        accent: colorScheme.secondary,
                        fillColor: fieldFill,
                        onTap: onPickEndDate,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuctionFormHeader extends StatelessWidget {
  const _AuctionFormHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.p16,
        AppSizes.p16,
        AppSizes.p16,
        AppSizes.p12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            colorScheme.primary.withValues(alpha: 0.14),
            colorScheme.secondary.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.secondary],
              ),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              LucideIcons.gavel,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSizes.p12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(
                  title,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                const SizedBox(height: AppSizes.p4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuctionTextField extends StatelessWidget {
  const _AuctionTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.fillColor,
    this.keyboardType,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color fillColor;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomText(
          label,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          variant: TextVariant.secondary,
        ),
        const SizedBox(height: AppSizes.p6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: fillColor,
            prefixIcon: Icon(
              icon,
              size: 18,
              color: colorScheme.primary,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSizes.p12,
              vertical: AppSizes.p12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: BorderSide(
                color: colorScheme.primary.withValues(alpha: 0.65),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AuctionDateCard extends StatelessWidget {
  const _AuctionDateCard({
    required this.label,
    required this.parts,
    required this.icon,
    required this.accent,
    required this.fillColor,
    required this.onTap,
  });

  final String label;
  final AddPostAuctionDateParts parts;
  final IconData icon;
  final Color accent;
  final Color fillColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: fillColor,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSizes.p12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(
              color: accent.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppSizes.p8),
                    ),
                    child: Icon(icon, size: 14, color: accent),
                  ),
                  const SizedBox(width: AppSizes.p8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? LucideIcons.chevronLeft
                        : LucideIcons.chevronRight,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.p10),
              CustomText(
                parts.dateLine,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              const SizedBox(height: AppSizes.p4),
              CustomText(
                parts.timeLine,
                fontSize: 12,
                variant: TextVariant.secondary,
                fontWeight: FontWeight.w500,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
