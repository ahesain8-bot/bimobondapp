import 'package:flutter/material.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/services/live_video_quality_preference.dart';
import '../../../../../core/utils/app_colors.dart';
import '../../../../../core/utils/app_sizes.dart';
import '../../../../../core/utils/app_text_styles.dart';
import '../../../domain/entities/live_capture_profile.dart';
import 'live_room_option_tile.dart';

/// Video-quality picker opened from the LIVE settings sheet.
///
/// Only tiers the pipeline can really publish are listed. Picking one sets the
/// ceiling for both the local preview and the LiveKit ladder — a handset that
/// cannot hold it still steps down on its own, so the badge never promises a
/// resolution the sensor refused.
class LiveVideoQualitySheet extends StatefulWidget {
  const LiveVideoQualitySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.optionsScrim,
      builder: (_) => const LiveVideoQualitySheet(),
    );
  }

  @override
  State<LiveVideoQualitySheet> createState() => _LiveVideoQualitySheetState();
}

class _LiveVideoQualitySheetState extends State<LiveVideoQualitySheet> {
  final LiveVideoQualityPreference _preference =
      LiveVideoQualityPreference.instance;

  void _select(LiveCaptureProfile profile) {
    _preference.select(profile);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: AppColors.optionsSheetBackground,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSizes.optionsSheetRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetHeader(),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.optionsSheetHorizontal,
                  AppSpacing.xs,
                  AppSpacing.optionsSheetHorizontal,
                  AppSpacing.optionsFooterBottom + bottomInset,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LiveRoomOptionsCard(
                      children: [
                        for (final profile in _preference.options)
                          _QualityTile(
                            profile: profile,
                            selected: _preference.profile == profile,
                            onTap: () => _select(profile),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.smd,
                      ),
                      child: Text(
                        'يتم اختيار أعلى جودة يدعمها جهازك فعليًا. إذا لم تتحمّل '
                        'الشبكة أو الكاميرا الجودة المحددة، يخفضها التطبيق '
                        'تلقائيًا أثناء البث.',
                        style: AppTextStyles.optionsMenuSubtitle,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.optionsSheetHorizontal,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'جودة الفيديو',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.optionsForeground,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.close,
              size: 20,
              color: AppColors.optionsSubtitle,
            ),
          ),
        ],
      ),
    );
  }
}

/// One selectable tier row (label · dimensions · check).
class _QualityTile extends StatelessWidget {
  const _QualityTile({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  final LiveCaptureProfile profile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.optionsCardHorizontal,
            vertical: AppSpacing.optionsRowVertical,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          profile.label,
                          style: AppTextStyles.optionsMenuTitle,
                        ),
                        if (profile == LiveCaptureProfile.preferred) ...[
                          const SizedBox(width: AppSpacing.sm),
                          const _RecommendedBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${profile.dimensions}  •  ${profile.maxFps} إطار/ث',
                      style: AppTextStyles.optionsMenuSubtitle,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: AppSizes.optionsIcon,
                color: selected
                    ? AppColors.optionsToggleActive
                    : AppColors.optionsSubtitle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendedBadge extends StatelessWidget {
  const _RecommendedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.optionsToggleActive,
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Text(
        'مُوصى به',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
