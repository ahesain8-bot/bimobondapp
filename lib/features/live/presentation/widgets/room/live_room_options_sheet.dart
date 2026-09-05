import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/utils/app_colors.dart';
import '../../../../../core/utils/app_sizes.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/utils/app_text_styles.dart';
import '../../../../../core/widgets/app_form_dialog.dart';
import '../../../domain/repositories/live_session_repository.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_event.dart';
import '../../bloc/live_room/live_room_state.dart';
import 'live_room_battle_opponents_sheet.dart';
import 'live_room_option_tile.dart';
import 'live_room_settings_sheet.dart';

/// Presents the TikTok-style live stream options menu as a modal bottom sheet.
class LiveRoomOptionsSheet {
  const LiveRoomOptionsSheet._();

  static Future<void> show(BuildContext context) async {
    final bloc = context.read<LiveRoomBloc>();
    // A modal route's subtree hangs off the root navigator, not off the live
    // room page, so anything the sheet needs has to be re-provided here. The
    // repository is what the "بدء منافسة" tile reads to open the opponent
    // picker; without it that tile threw ProviderNotFound on every tap and
    // the row simply did nothing.
    final repository = context.read<LiveSessionRepository>();

    final destination = await showModalBottomSheet<LiveRoomMenuDestination>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.optionsScrim,
      builder: (sheetContext) {
        return BlocProvider.value(
          value: bloc,
          child: RepositoryProvider.value(
            value: repository,
            child: const _LiveRoomOptionsSheetBody(),
          ),
        );
      },
    );

    if (destination == LiveRoomMenuDestination.settings && context.mounted) {
      await LiveRoomSettingsSheet.show(context);
    }
    if (destination == LiveRoomMenuDestination.startBattle && context.mounted) {
      await LiveRoomBattleOpponentsSheet.show(context);
    }
  }
}

class _LiveRoomOptionsSheetBody extends StatelessWidget {
  const _LiveRoomOptionsSheetBody();

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.optionsSheetBackground,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppSizes.optionsSheetRadius),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.optionsSheetHorizontal,
                      AppSpacing.md,
                      AppSpacing.optionsSheetHorizontal,
                      AppSpacing.optionsFooterBottom + bottomInset,
                    ),
                    child: BlocBuilder<LiveRoomBloc, LiveRoomState>(
                      buildWhen: (previous, current) {
                        if (previous is! LiveRoomReady ||
                            current is! LiveRoomReady) {
                          return true;
                        }
                        return previous.isMirrorEnabled !=
                                current.isMirrorEnabled ||
                            previous.isMicMuted != current.isMicMuted ||
                            previous.isStabilizationEnabled !=
                                current.isStabilizationEnabled ||
                            previous.isNoiseReductionEnabled !=
                                current.isNoiseReductionEnabled ||
                            previous.isAiContentTagged !=
                                current.isAiContentTagged ||
                            previous.isLivePaused != current.isLivePaused ||
                            previous.showLiveGiftsBadge !=
                                current.showLiveGiftsBadge ||
                            previous.showLiveTitleBadge !=
                                current.showLiveTitleBadge;
                      },
                      builder: (context, state) {
                        final ready =
                            state is LiveRoomReady ? state : null;
                        return _OptionsContent(ready: ready);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionsContent extends StatelessWidget {
  const _OptionsContent({required this.ready});

  final LiveRoomReady? ready;

  void _close(BuildContext context) {
    Navigator.of(context).maybePop();
  }

  void _navigate(
    BuildContext context,
    LiveRoomMenuDestination destination, {
    bool closeSheet = true,
  }) {
    context
        .read<LiveRoomBloc>()
        .add(LiveRoomMenuDestinationRequested(destination));
    if (!closeSheet) return;
    if (destination == LiveRoomMenuDestination.settings ||
        destination == LiveRoomMenuDestination.startBattle) {
      // Hand the destination back to `show`, which reopens from the page's
      // own context once this sheet is really gone. Popping here and pushing
      // in the same frame left the options sheet stacked underneath.
      Navigator.of(context).pop(destination);
      return;
    }
    _close(context);
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<LiveRoomBloc>();
    final isMirror = ready?.isMirrorEnabled ?? false;
    final isMuted = ready?.isMicMuted ?? false;
    final isStabilization = ready?.isStabilizationEnabled ?? true;
    final isNoiseReduction = ready?.isNoiseReductionEnabled ?? false;
    final isAiTagged = ready?.isAiContentTagged ?? false;
    final isPaused = ready?.isLivePaused ?? false;
    final giftsBadge = ready?.showLiveGiftsBadge ?? true;
    final titleBadge = ready?.showLiveTitleBadge ?? true;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LiveRoomOptionsCard(
          children: [
            LiveRoomOptionTile(
              icon: Icons.card_giftcard_outlined,
              title: 'هدايا البث',
              trailing: LiveRoomOptionTrailing.chevron,
              showBadge: giftsBadge,
              onTap: () => _navigate(
                context,
                LiveRoomMenuDestination.liveGifts,
              ),
            ),
            // Direct way into a PK round. Before this the only trigger was
            // accepting a guest's chat request, which then blind-auto-matched
            // a stranger; the host could never simply pick who to face.
            LiveRoomOptionTile(
              icon: Icons.sports_mma_outlined,
              title: 'بدء منافسة',
              subtitle: 'اختر بثاً مباشراً آخر لتتنافس معه.',
              trailing: LiveRoomOptionTrailing.chevron,
              onTap: () => _navigate(
                context,
                LiveRoomMenuDestination.startBattle,
              ),
            ),
            LiveRoomOptionTile(
              icon: Icons.movie_filter_outlined,
              title: 'لحظات البث البارزة',
              trailing: LiveRoomOptionTrailing.chevron,
              onTap: () => _navigate(
                context,
                LiveRoomMenuDestination.liveHighlights,
              ),
            ),
            LiveRoomOptionTile(
              icon: Icons.cameraswitch_outlined,
              title: 'قلب الكاميرا',
              onTap: () {
                bloc.add(const LiveRoomFlipCameraRequested());
                _close(context);
              },
            ),
            LiveRoomOptionTile(
              icon: Icons.flip_outlined,
              title: 'انعكاس الفيديو',
              trailing: LiveRoomOptionTrailing.toggle,
              toggleValue: isMirror,
              onToggle: (_) => bloc.add(const LiveRoomMirrorToggled()),
            ),
            LiveRoomOptionTile(
              icon: Icons.mic_off_outlined,
              title: 'كتم الميكروفون',
              trailing: LiveRoomOptionTrailing.toggle,
              toggleValue: isMuted,
              onToggle: (_) => bloc.add(const LiveRoomMicMuteToggled()),
            ),
            LiveRoomOptionTile(
              icon: Icons.rocket_launch_outlined,
              title: 'زيادة استقرار البث',
              subtitle:
                  'يقيد بعض الميزات لمنع التأخير أو الانقطاع أثناء البث المباشر.',
              learnMoreLabel: 'معرفة المزيد',
              onLearnMore: () => _navigate(
                context,
                LiveRoomMenuDestination.learnMoreStabilization,
                closeSheet: false,
              ),
              trailing: LiveRoomOptionTrailing.toggle,
              toggleValue: isStabilization,
              onToggle: (_) =>
                  bloc.add(const LiveRoomStabilizationToggled()),
            ),
            LiveRoomOptionTile(
              icon: Icons.graphic_eq_outlined,
              title: 'إزالة ضوضاء الخلفية',
              subtitle: 'اجعل المشاهدين يسمعون صوتك بوضوح أكبر.',
              trailing: LiveRoomOptionTrailing.toggle,
              toggleValue: isNoiseReduction,
              onToggle: (_) =>
                  bloc.add(const LiveRoomNoiseReductionToggled()),
            ),
            LiveRoomOptionTile(
              icon: isPaused
                  ? Icons.play_circle_outline
                  : Icons.pause_circle_outline,
              title: isPaused ? 'استئناف LIVE' : 'إيقاف LIVE مؤقتًا',
              onTap: () {
                bloc.add(const LiveRoomPauseLiveTapped());
                _close(context);
              },
            ),
            LiveRoomOptionTile(
              icon: Icons.settings_outlined,
              title: 'الإعدادات',
              trailing: LiveRoomOptionTrailing.chevron,
              onTap: () => _navigate(
                context,
                LiveRoomMenuDestination.settings,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.optionsCardGap),
        LiveRoomOptionsCard(
          children: [
            LiveRoomOptionTile(
              icon: Icons.chat_bubble_outline,
              title: 'تعليق',
              onTap: () => _navigate(
                context,
                LiveRoomMenuDestination.comments,
              ),
            ),
            LiveRoomOptionTile(
              icon: Icons.article_outlined,
              title: 'نبذة عني',
              trailing: LiveRoomOptionTrailing.chevron,
              onTap: () => _navigate(
                context,
                LiveRoomMenuDestination.aboutMe,
              ),
            ),
            LiveRoomOptionTile(
              icon: Icons.edit_outlined,
              title: 'عنوان البث',
              trailing: LiveRoomOptionTrailing.chevron,
              showBadge: titleBadge,
              onTap: () async {
                final roomBloc = context.read<LiveRoomBloc>();
                final currentTitle = ready?.session.title ?? '';
                final controller = TextEditingController(text: currentTitle);
                final result = await showDialog<String>(
                  context: context,
                  builder: (dialogContext) {
                    return AppFormDialog(
                      title: 'عنوان البث',
                      primaryLabel: 'حفظ',
                      onPrimary: () => Navigator.of(dialogContext)
                          .pop(controller.text.trim()),
                      secondaryLabel: 'إلغاء',
                      onSecondary: () => Navigator.of(dialogContext).pop(),
                      children: [
                        AppFormField(
                          controller: controller,
                          hintText: 'أدخل عنوان البث',
                          autofocus: true,
                          maxLength: 120,
                          maxLines: 2,
                          bottomGap: 0,
                        ),
                      ],
                    );
                  },
                );
                controller.dispose();
                if (result == null || result.isEmpty) return;
                roomBloc.add(LiveRoomTitleSubmitted(result));
                if (context.mounted) _close(context);
              },
            ),
            LiveRoomOptionTile(
              icon: Icons.verified_user_outlined,
              title: 'الفعاليات',
              trailing: LiveRoomOptionTrailing.chevron,
              onTap: () => _navigate(
                context,
                LiveRoomMenuDestination.events,
              ),
            ),
            LiveRoomOptionTile(
              icon: Icons.filter_none_outlined,
              title: 'الإفصاح عن المحتوى',
              trailing: LiveRoomOptionTrailing.chevron,
              onTap: () => _navigate(
                context,
                LiveRoomMenuDestination.contentDisclosure,
              ),
            ),
            LiveRoomOptionTile(
              icon: Icons.smart_toy_outlined,
              title: 'محتوى أنشأه الذكاء الاصطناعي',
              subtitle:
                  'أضف هذه العلامة لتخبر المشاهدين أنه تم إنشاء المحتوى أو تعديله باستخدام الذكاء الاصطناعي.',
              learnMoreLabel: 'معرفة المزيد',
              onLearnMore: () => _navigate(
                context,
                LiveRoomMenuDestination.learnMoreAiContent,
                closeSheet: false,
              ),
              trailing: LiveRoomOptionTrailing.toggle,
              toggleValue: isAiTagged,
              onToggle: (_) => bloc.add(const LiveRoomAiContentToggled()),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _HelpFooter(
          onHelp: () => _navigate(
            context,
            LiveRoomMenuDestination.help,
          ),
          onReport: () => _navigate(
            context,
            LiveRoomMenuDestination.reportProblem,
          ),
        ),
      ],
    );
  }
}

class _HelpFooter extends StatelessWidget {
  const _HelpFooter({
    required this.onHelp,
    required this.onReport,
  });

  final VoidCallback onHelp;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          GestureDetector(
            onTap: onHelp,
            child: const Text(
              'هل تحتاج إلى مساعدة؟',
              style: AppTextStyles.optionsMenuFooter,
            ),
          ),
          const Text(' ', style: AppTextStyles.optionsMenuFooter),
          GestureDetector(
            onTap: onReport,
            child: Text(
              'الإبلاغ عن مشكلة',
              style: AppTextStyles.optionsMenuFooter.copyWith(
                decoration: TextDecoration.underline,
                decorationColor: AppColors.optionsSubtitle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
