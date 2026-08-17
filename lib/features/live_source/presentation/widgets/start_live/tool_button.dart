import 'package:flutter/material.dart';

import '../../../../../core/utils/app_sizes.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/utils/app_text_styles.dart';

/// A single tool button: image on top, single-line label below.
class ToolButton extends StatelessWidget {
  const ToolButton({
    super.key,
    required this.asset,
    required this.label,
    this.onTap,
  });

  final String asset;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Left-only margin so consecutive tools stay close to each other.
      margin: const EdgeInsets.only(left: AppSpacing.sm, right: AppSpacing.sm),
      child: SizedBox(
        width: AppSizes.toolButtonWidth,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: AppSizes.toolImageAreaHeight,
                child: Image.asset(
                  asset,
                  width: AppSizes.toolImage,
                  height: AppSizes.toolImage,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: AppSpacing.iconLabelGap),
              // Single-line label: FittedBox scales the text down (if needed)
              // so it fits on one line while keeping the button size unchanged.
              SizedBox(
                height: AppSizes.toolLabelHeight,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.toolLabel,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
