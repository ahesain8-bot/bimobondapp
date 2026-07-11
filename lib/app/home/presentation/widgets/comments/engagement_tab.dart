import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';

/// Wide, padded tab cell for the engagement sheet.
class EngagementTab extends StatelessWidget {
  const EngagementTab({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: AppSizes.buttonHeightSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.p8,
          vertical: AppSizes.p6,
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
