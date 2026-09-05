import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../core/utils/app_assets.dart';
import '../../../../../core/utils/app_colors.dart';
import '../../../../../core/utils/app_sizes.dart';
import '../../../../../core/utils/app_text_styles.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_event.dart';
import '../../bloc/live_room/live_room_state.dart';
import 'live_room_gallery_sheet.dart';
import 'live_room_guests_sheet.dart';
import 'live_room_elapsed_timer.dart';
import 'live_room_pill.dart';
import 'live_room_ranking_sheet.dart';

/// Second header row — TikTok creator chips under the top bar:
/// ranking · gallery · timer …… invite
class LiveRoomInfoRow extends StatelessWidget {
  const LiveRoomInfoRow({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveRoomBloc, LiveRoomState>(
      buildWhen: (previous, current) {
        if (current is! LiveRoomReady) return false;
        if (previous is! LiveRoomReady) return true;
        final a = previous.session;
        final b = current.session;
        return a.hourlyRankingLabel != b.hourlyRankingLabel ||
            a.hourlyRank != b.hourlyRank ||
            a.galleryCurrent != b.galleryCurrent ||
            a.galleryTotal != b.galleryTotal ||
            a.guestInviteCount != b.guestInviteCount ||
            a.title != b.title;
      },
      builder: (context, state) {
        if (state is! LiveRoomReady) {
          return const SizedBox.shrink();
        }

        final session = state.session;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _RankingChip(
                  label: session.hourlyRankingLabel,
                  onTap: () {
                    context.read<LiveRoomBloc>().add(
                      const LiveRoomRankingTapped(),
                    );
                    LiveRoomRankingSheet.show(context);
                  },
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => LiveRoomGallerySheet.show(context),
                  child: LiveRoomPill(
                    height: AppSizes.roomChipHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    color: AppColors.overlayPillSoft,
                    child: Text(
                      '${session.galleryCurrent}/${session.galleryTotal}',
                      style: AppTextStyles.roomChip,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const LiveRoomElapsedTimer(),
                const Spacer(),
                _InviteChip(
                  count: session.guestInviteCount,
                  onTap: () {
                    context.read<LiveRoomBloc>().add(
                      const LiveRoomInviteTapped(),
                    );
                    LiveRoomGuestsSheet.show(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RankingChip extends StatelessWidget {
  const _RankingChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LiveRoomPill(
        height: AppSizes.roomChipHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        color: AppColors.overlayPillSoft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(AppAssets.roomFlame, width: 13, height: 15),
            const SizedBox(width: 4),
            Text(label, style: AppTextStyles.roomChip),
          ],
        ),
      ),
    );
  }
}

class _InviteChip extends StatelessWidget {
  const _InviteChip({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: AppSizes.roomChipHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2EBD59), Color(0xFF159447)],
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(AppAssets.roomPersonAdd, width: 16, height: 14),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: AppTextStyles.roomChip.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
