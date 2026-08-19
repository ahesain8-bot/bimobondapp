import 'package:flutter/material.dart';

import '../../../../../core/utils/app_colors.dart';
import '../../../../../core/utils/app_sizes.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../live/presentation/widgets/room/live_video_quality_sheet.dart';
import 'live_room_option_tile.dart';

/// Settings sheet using the same surface, cards and rows as the room menu.
class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key, this.onDismiss});

  final VoidCallback? onDismiss;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  bool _stabilization = true;
  bool _mirrorLive = true;
  bool _removeBackgroundNoise = false;
  bool _liveGifts = true;
  bool _guardian = true;
  bool _giftGallery = true;
  bool _liveSongs = true;
  bool _aiContent = false;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onDismiss,
              child: const ColoredBox(color: AppColors.optionsScrim),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Material(
                color: AppColors.optionsSheetBackground,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSizes.optionsSheetRadius),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.optionsSheetHorizontal,
                        AppSpacing.sm,
                        AppSpacing.optionsSheetHorizontal,
                        AppSpacing.xs,
                      ),
                      child: SizedBox(
                        height: 30,
                        child: Center(
                          child: Text(
                            'الإعدادات',
                            style: TextStyle(
                              color: AppColors.optionsForeground,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.optionsSheetHorizontal,
                          AppSpacing.xs,
                          AppSpacing.optionsSheetHorizontal,
                          AppSpacing.optionsFooterBottom + bottomInset,
                        ),
                        child: _SettingsCards(
                          stabilization: _stabilization,
                          mirrorLive: _mirrorLive,
                          removeBackgroundNoise: _removeBackgroundNoise,
                          liveGifts: _liveGifts,
                          guardian: _guardian,
                          giftGallery: _giftGallery,
                          liveSongs: _liveSongs,
                          aiContent: _aiContent,
                          onStabilizationChanged: (value) =>
                              setState(() => _stabilization = value),
                          onMirrorChanged: (value) =>
                              setState(() => _mirrorLive = value),
                          onNoiseChanged: (value) =>
                              setState(() => _removeBackgroundNoise = value),
                          onGiftsChanged: (value) =>
                              setState(() => _liveGifts = value),
                          onGuardianChanged: (value) =>
                              setState(() => _guardian = value),
                          onGalleryChanged: (value) =>
                              setState(() => _giftGallery = value),
                          onSongsChanged: (value) =>
                              setState(() => _liveSongs = value),
                          onAiChanged: (value) =>
                              setState(() => _aiContent = value),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCards extends StatelessWidget {
  const _SettingsCards({
    required this.stabilization,
    required this.mirrorLive,
    required this.removeBackgroundNoise,
    required this.liveGifts,
    required this.guardian,
    required this.giftGallery,
    required this.liveSongs,
    required this.aiContent,
    required this.onStabilizationChanged,
    required this.onMirrorChanged,
    required this.onNoiseChanged,
    required this.onGiftsChanged,
    required this.onGuardianChanged,
    required this.onGalleryChanged,
    required this.onSongsChanged,
    required this.onAiChanged,
  });

  final bool stabilization;
  final bool mirrorLive;
  final bool removeBackgroundNoise;
  final bool liveGifts;
  final bool guardian;
  final bool giftGallery;
  final bool liveSongs;
  final bool aiContent;
  final ValueChanged<bool> onStabilizationChanged;
  final ValueChanged<bool> onMirrorChanged;
  final ValueChanged<bool> onNoiseChanged;
  final ValueChanged<bool> onGiftsChanged;
  final ValueChanged<bool> onGuardianChanged;
  final ValueChanged<bool> onGalleryChanged;
  final ValueChanged<bool> onSongsChanged;
  final ValueChanged<bool> onAiChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LiveRoomOptionsCard(
          children: [
            LiveRoomOptionTile(
              icon: Icons.admin_panel_settings_outlined,
              title: 'المشرفون',
              subtitle: 'المشرفون هم فقط الذين تستطيع إضافتهم كمشرفين.',
              trailing: LiveRoomOptionTrailing.chevron,
            ),
            LiveRoomOptionTile(
              icon: Icons.groups_outlined,
              title: 'المشاهدون الذين وصلتهم',
              subtitle: 'إدارة المشاهدين الذين يمكنهم الوصول إلى بثك.',
              trailing: LiveRoomOptionTrailing.chevron,
            ),
            LiveRoomOptionTile(
              icon: Icons.person_add_alt_1_outlined,
              title: 'إعداد البث لاكتساب عملاء',
              trailing: LiveRoomOptionTrailing.chevron,
            ),
            LiveRoomOptionTile(
              icon: Icons.high_quality_outlined,
              title: 'جودة الفيديو',
              trailing: LiveRoomOptionTrailing.chevron,
              onTap: () => LiveVideoQualitySheet.show(context),
            ),
            LiveRoomOptionTile(
              icon: Icons.rocket_launch_outlined,
              title: 'زيادة استقرار البث',
              subtitle:
                  'يقيد بعض الميزات لمنع التأخير أو الانقطاع أثناء البث المباشر.',
              trailing: LiveRoomOptionTrailing.toggle,
              toggleValue: stabilization,
              onToggle: onStabilizationChanged,
            ),
            LiveRoomOptionTile(
              icon: Icons.flip_outlined,
              title: 'مرآة البث',
              trailing: LiveRoomOptionTrailing.toggle,
              toggleValue: mirrorLive,
              onToggle: onMirrorChanged,
            ),
            LiveRoomOptionTile(
              icon: Icons.graphic_eq_outlined,
              title: 'إزالة ضوضاء الخلفية',
              subtitle: 'اجعل المشاهدين يسمعون صوتك بوضوح أكبر.',
              trailing: LiveRoomOptionTrailing.toggle,
              toggleValue: removeBackgroundNoise,
              onToggle: onNoiseChanged,
            ),
            LiveRoomOptionTile(
              icon: Icons.groups_2_outlined,
              title: 'التحكم في الجمهور',
              subtitle: 'تحكم في الجمهور الذي يمكنه مشاهدة بث LIVE هذا.',
              trailing: LiveRoomOptionTrailing.chevron,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.optionsCardGap),
        LiveRoomOptionsCard(
          children: [
            LiveRoomOptionTile(
              icon: Icons.card_giftcard_outlined,
              title: 'هدايا LIVE',
              subtitle: 'السماح للمشاهدين بإرسال الهدايا أثناء بث LIVE.',
              trailing: LiveRoomOptionTrailing.toggle,
              toggleValue: liveGifts,
              onToggle: onGiftsChanged,
            ),
            LiveRoomOptionTile(
              icon: Icons.shield_outlined,
              title: 'الحارس',
              subtitle:
                  'اسمح للمشاهدين بالتفاعل ليكون أحدهم حارساً واحصل على امتيازات الحارس.',
              trailing: LiveRoomOptionTrailing.toggle,
              toggleValue: guardian,
              onToggle: onGuardianChanged,
            ),
            LiveRoomOptionTile(
              icon: Icons.redeem_outlined,
              title: 'معرض الهدايا',
              subtitle: 'السماح للمشاهدين بإضافة الهدايا في معرض الهدايا لديك.',
              trailing: LiveRoomOptionTrailing.toggle,
              toggleValue: giftGallery,
              onToggle: onGalleryChanged,
            ),
            LiveRoomOptionTile(
              icon: Icons.music_note_outlined,
              title: 'أغاني LIVE',
              subtitle: 'السماح للمشاهدين بإرسال مقاطع موسيقية كهدايا.',
              trailing: LiveRoomOptionTrailing.toggle,
              toggleValue: liveSongs,
              onToggle: onSongsChanged,
            ),
            LiveRoomOptionTile(
              icon: Icons.leaderboard_outlined,
              title: 'الترتيب',
              trailing: LiveRoomOptionTrailing.chevron,
            ),
            LiveRoomOptionTile(
              icon: Icons.chat_bubble_outline,
              title: 'إعدادات التعليقات',
              trailing: LiveRoomOptionTrailing.chevron,
            ),
            LiveRoomOptionTile(
              icon: Icons.video_library_outlined,
              title: 'تسجيلات LIVE',
              subtitle:
                  'تحكم في إعدادات تسجيل البث واللقطات البارزة ومشاركتها.',
              trailing: LiveRoomOptionTrailing.chevron,
            ),
            LiveRoomOptionTile(
              icon: Icons.info_outline,
              title: 'الإفصاح عن المحتوى',
              subtitle: 'الإفصاح عن المحتوى المدعوم في بث LIVE هذا.',
              trailing: LiveRoomOptionTrailing.chevron,
            ),
            LiveRoomOptionTile(
              icon: Icons.smart_toy_outlined,
              title: 'محتوى أنشأه الذكاء الاصطناعي',
              subtitle:
                  'أضف هذه العلامة لتخبر المشاهدين أنه تم إنشاء المحتوى أو تعديله باستخدام الذكاء الاصطناعي.',
              trailing: LiveRoomOptionTrailing.toggle,
              toggleValue: aiContent,
              onToggle: onAiChanged,
            ),
          ],
        ),
      ],
    );
  }
}
