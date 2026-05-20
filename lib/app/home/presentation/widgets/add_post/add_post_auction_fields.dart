import 'package:bimobondapp/core/constants/add_post_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

String formatAddPostAuctionDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final h = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $h:$min';
}

class AddPostAuctionDateRow extends StatelessWidget {
  const AddPostAuctionDateRow({
    required this.label,
    required this.value,
    required this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.p8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.p8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    label,
                    fontSize: 12,
                    variant: TextVariant.secondary,
                  ),
                  const SizedBox(height: AppSizes.p4),
                  CustomText(value, fontSize: 14, fontWeight: FontWeight.w600),
                ],
              ),
            ),
            Icon(
              LucideIcons.calendar,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: AddPostLayoutConstants.auctionSectionBackgroundAlpha,
        ),
        borderRadius: BorderRadius.circular(AppSizes.p12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(
            alpha: AddPostLayoutConstants.auctionSectionBorderAlpha,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: itemNameController,
            decoration: InputDecoration(
              labelText: l10n.auctionItemName,
              hintText: l10n.auctionItemNameHint,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSizes.p12),
          TextField(
            controller: startingPriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.auctionStartingPrice,
              border: const OutlineInputBorder(),
              isDense: true,
              prefixText: '\$ ',
            ),
          ),
          const SizedBox(height: AppSizes.p12),
          TextField(
            controller: targetPriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.auctionTargetPriceLabel,
              border: const OutlineInputBorder(),
              isDense: true,
              prefixText: '\$ ',
            ),
          ),
          const SizedBox(height: AppSizes.p12),
          AddPostAuctionDateRow(
            label: l10n.auctionStartDate,
            value: formatAddPostAuctionDateTime(startDate),
            onTap: onPickStartDate,
          ),
          const SizedBox(height: AppSizes.p8),
          AddPostAuctionDateRow(
            label: l10n.auctionEndDate,
            value: formatAddPostAuctionDateTime(endDate),
            onTap: onPickEndDate,
          ),
        ],
      ),
    );
  }
}
