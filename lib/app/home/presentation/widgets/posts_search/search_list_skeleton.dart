import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:flutter/material.dart';

/// Skeleton rows matching search history / trend tiles.
class SearchListSkeleton extends StatelessWidget {
  const SearchListSkeleton({
    this.itemCount = 5,
    this.showHeader = false,
    this.headerWidth = 120,
    super.key,
  });

  final int itemCount;
  final bool showHeader;
  final double headerWidth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.p16,
              AppSizes.p16,
              AppSizes.p16,
              AppSizes.p8,
            ),
            child: SkeletonWidget(
              height: 18,
              width: headerWidth,
              borderRadius: 6,
            ),
          ),
        for (var i = 0; i < itemCount; i++)
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSizes.p16,
              vertical: 12,
            ),
            child: Row(
              children: [
                SkeletonWidget.circular(size: 20),
                SizedBox(width: 14),
                Expanded(
                  child: SkeletonWidget(height: 14, borderRadius: 6),
                ),
                SizedBox(width: 14),
                SkeletonWidget(height: 14, width: 14, borderRadius: 4),
              ],
            ),
          ),
      ],
    );
  }
}
