import 'package:flutter/material.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/services/live_beauty_preference.dart';
import '../../../../../core/utils/app_colors.dart';
import '../../../../../core/utils/app_sizes.dart';
import '../../../../../core/utils/app_text_styles.dart';
import '../../../data/services/live_beauty_bridge.dart';
import '../../../domain/entities/live_beauty_preset.dart';
import 'live_room_option_tile.dart';

/// Beauty picker opened from the LIVE settings sheet.
///
/// Unlike the effects tray, what is chosen here reaches viewers: the look is a
/// shader on the published track rather than a widget over the host's preview.
class LiveBeautySheet extends StatefulWidget {
  const LiveBeautySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.optionsScrim,
      builder: (_) => const LiveBeautySheet(),
    );
  }

  @override
  State<LiveBeautySheet> createState() => _LiveBeautySheetState();
}

class _LiveBeautySheetState extends State<LiveBeautySheet> {
  final LiveBeautyPreference _preference = LiveBeautyPreference.instance;

  void _select(LiveBeautyPreset preset) {
    _preference.select(preset);
    setState(() {});
  }

  void _setIntensity(double value) {
    _preference.setIntensity(value);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final active = _preference.preset.isActive;

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
                        for (final preset in _preference.options)
                          _BeautyTile(
                            preset: preset,
                            selected: _preference.preset.id == preset.id,
                            onTap: () => _select(preset),
                          ),
                      ],
                    ),
                    if (active) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _IntensitySlider(
                        value: _preference.intensity,
                        onChanged: _setIntensity,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.smd,
                      ),
                      child: Text(
                        LiveBeautyBridge.isSupported
                            ? 'التجميل يُطبَّق على البث نفسه، فيظهر للمشاهدين '
                                  'كما تراه أنت.'
                            : 'التجميل أثناء البث غير متاح على هذا الجهاز.',
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
              'تجميل',
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

/// One selectable look (name · what it does · check).
class _BeautyTile extends StatelessWidget {
  const _BeautyTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final LiveBeautyPreset preset;
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
                          preset.nameAr,
                          style: AppTextStyles.optionsMenuTitle,
                        ),
                        if (preset.id == LiveBeautyPreset.natural.id) ...[
                          const SizedBox(width: AppSpacing.sm),
                          const _DefaultBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _describe(preset),
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

  static String _describe(LiveBeautyPreset preset) {
    if (!preset.isActive) return 'الكاميرا كما هي';
    final parts = <String>[
      if (preset.smooth > 0.4)
        'نعومة عالية'
      else if (preset.smooth > 0.01)
        'نعومة خفيفة',
      if (preset.brighten > 0.3) 'إضاءة',
      if (preset.tone > 0.3) 'لون دافئ',
      if (preset.sharpen > 0.4) 'وضوح',
      if (preset.eyes > 0.2) 'عيون',
    ];
    return parts.join('  •  ');
  }
}

class _IntensitySlider extends StatelessWidget {
  const _IntensitySlider({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return LiveRoomOptionsCard(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.optionsCardHorizontal,
            AppSpacing.optionsRowVertical,
            AppSpacing.optionsCardHorizontal,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              Text('الشدة', style: AppTextStyles.optionsMenuTitle),
              const Spacer(),
              Text(
                '${(value * 100).round()}%',
                style: AppTextStyles.optionsMenuSubtitle,
              ),
            ],
          ),
        ),
        Slider(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.optionsToggleActive,
          inactiveColor: AppColors.optionsSubtitle,
        ),
      ],
    );
  }
}

class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.optionsToggleActive,
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Text(
        'افتراضي',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
