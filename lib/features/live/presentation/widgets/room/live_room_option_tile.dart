import 'package:flutter/material.dart';

import '../../../../../core/utils/app_colors.dart';
import '../../../../../core/utils/app_sizes.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/utils/app_text_styles.dart';

/// Trailing control kinds for a live-room options row.
enum LiveRoomOptionTrailing {
  none,
  chevron,
  toggle,
}

/// Single reusable options-menu row (icon · title · trailing).
///
/// Layout follows the RTL TikTok Live pattern: icon at the start (right),
/// trailing control at the end (left).
class LiveRoomOptionTile extends StatelessWidget {
  const LiveRoomOptionTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.learnMoreLabel,
    this.onLearnMore,
    this.trailing = LiveRoomOptionTrailing.none,
    this.toggleValue = false,
    this.showBadge = false,
    this.onTap,
    this.onToggle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? learnMoreLabel;
  final VoidCallback? onLearnMore;
  final LiveRoomOptionTrailing trailing;
  final bool toggleValue;
  final bool showBadge;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: trailing == LiveRoomOptionTrailing.toggle
            ? () => onToggle?.call(!toggleValue)
            : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.optionsCardHorizontal,
            vertical: AppSpacing.optionsRowVertical,
          ),
          child: Row(
            crossAxisAlignment: hasSubtitle
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: AppSizes.optionsIcon,
                color: AppColors.optionsForeground,
              ),
              const SizedBox(width: AppSpacing.optionsIconTextGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.optionsMenuTitle),
                    if (hasSubtitle) ...[
                      const SizedBox(height: 2),
                      _SubtitleBlock(
                        subtitle: subtitle!,
                        learnMoreLabel: learnMoreLabel,
                        onLearnMore: onLearnMore,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _TrailingSlot(
                trailing: trailing,
                toggleValue: toggleValue,
                showBadge: showBadge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubtitleBlock extends StatelessWidget {
  const _SubtitleBlock({
    required this.subtitle,
    this.learnMoreLabel,
    this.onLearnMore,
  });

  final String subtitle;
  final String? learnMoreLabel;
  final VoidCallback? onLearnMore;

  @override
  Widget build(BuildContext context) {
    if (learnMoreLabel == null || onLearnMore == null) {
      return Text(subtitle, style: AppTextStyles.optionsMenuSubtitle);
    }

    return Text.rich(
      TextSpan(
        style: AppTextStyles.optionsMenuSubtitle,
        children: [
          TextSpan(text: subtitle),
          const TextSpan(text: ' '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: onLearnMore,
              child: Text(
                learnMoreLabel!,
                style: AppTextStyles.optionsMenuSubtitle.copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.optionsSubtitle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrailingSlot extends StatelessWidget {
  const _TrailingSlot({
    required this.trailing,
    required this.toggleValue,
    required this.showBadge,
  });

  final LiveRoomOptionTrailing trailing;
  final bool toggleValue;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showBadge) ...[
          Container(
            width: AppSizes.optionsBadge,
            height: AppSizes.optionsBadge,
            decoration: const BoxDecoration(
              color: AppColors.optionsBadge,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        switch (trailing) {
          LiveRoomOptionTrailing.none => const SizedBox.shrink(),
          LiveRoomOptionTrailing.chevron => const Icon(
              Icons.chevron_left,
              size: 22,
              color: AppColors.optionsSubtitle,
            ),
          // Visual-only: row InkWell owns the toggle tap to avoid double-firing.
          LiveRoomOptionTrailing.toggle => IgnorePointer(
              child: _OptionsToggle(value: toggleValue),
            ),
        },
      ],
    );
  }
}

class _OptionsToggle extends StatelessWidget {
  const _OptionsToggle({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: AppSizes.optionsToggleWidth,
      height: AppSizes.optionsToggleHeight,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: value
            ? AppColors.optionsToggleActive
            : AppColors.optionsToggleInactive,
        borderRadius: BorderRadius.circular(AppSizes.optionsToggleHeight),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: value
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Container(
          width: AppSizes.optionsToggleHeight - 4,
          height: AppSizes.optionsToggleHeight - 4,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// White rounded card grouping a list of option tiles.
class LiveRoomOptionsCard extends StatelessWidget {
  const LiveRoomOptionsCard({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.optionsCard,
        borderRadius: BorderRadius.circular(AppSizes.optionsCardRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}
