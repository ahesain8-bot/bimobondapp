import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:flutter/material.dart';

class AuctionBidStatColumn extends StatelessWidget {
  const AuctionBidStatColumn({
    required this.label,
    required this.value,
    required this.alignEnd,
    this.valueColor,
    this.leadingIcon,
    super.key,
  });

  final String label;
  final String value;
  final bool alignEnd;
  final Color? valueColor;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final valueRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leadingIcon != null) ...[
          Icon(
            leadingIcon,
            size: alignEnd ? 14 : 16,
            color: valueColor ?? Theme.of(context).colorScheme.onSurface,
          ),
          const SizedBox(width: AppSizes.p4),
        ],
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            style: TextStyle(
              fontSize: alignEnd ? 15 : 18,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        CustomText(
          label,
          fontSize: 12,
          variant: TextVariant.secondary,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        ),
        const SizedBox(height: AppSizes.p4),
        valueRow,
      ],
    );
  }
}
