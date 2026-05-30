import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:flutter/material.dart';

class ProfileStatItem extends StatelessWidget {
  const ProfileStatItem({
    required this.number,
    required this.label,
    this.onTap,
    super.key,
  });

  final String number;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        CustomText(number, fontSize: 18, fontWeight: FontWeight.bold),
        const SizedBox(height: AppSizes.p4),
        CustomText(label, fontSize: 13, variant: TextVariant.secondary),
      ],
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.p12,
          vertical: AppSizes.p4,
        ),
        child: content,
      ),
    );
  }
}
