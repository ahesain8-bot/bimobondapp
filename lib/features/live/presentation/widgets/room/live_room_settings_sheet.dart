import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/utils/app_colors.dart';
import '../../../domain/repositories/live_session_repository.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_state.dart';
import 'live_room_host_sheet_chrome.dart';
import 'live_room_multi_guest_settings_sheet.dart';
import 'live_room_chat_rules_sheet.dart';

/// Host stream settings. Guest policy lives one level deeper, in
/// [LiveRoomMultiGuestSettingsSheet], so a single screen owns
/// `PATCH /lives/:id/settings`.
class LiveRoomSettingsSheet {
  const LiveRoomSettingsSheet._();

  static Future<void> show(BuildContext context) {
    final bloc = context.read<LiveRoomBloc>();
    final repo = context.read<LiveSessionRepository>();
    final state = bloc.state;
    if (state is! LiveRoomReady) return Future.value();

    return LiveRoomHostSheetChrome.show(
      context: context,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: RepositoryProvider.value(
          value: repo,
          child: const _LiveRoomSettingsSheetBody(),
        ),
      ),
    );
  }
}

class _LiveRoomSettingsSheetBody extends StatelessWidget {
  const _LiveRoomSettingsSheetBody();

  @override
  Widget build(BuildContext context) {
    return LiveRoomHostSheetChrome(
      title: 'إعدادات البث',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _SettingsNavRow(
            icon: Icons.groups_outlined,
            title: 'إعدادات وضع تعدد الضيوف',
            subtitle: 'التخطيط وأذونات الانضمام إلى المسرح.',
            onTap: () => LiveRoomMultiGuestSettingsSheet.show(context),
          ),
          _SettingsNavRow(
            icon: Icons.chat_bubble_outline,
            title: 'Comment settings',
            subtitle: 'Control who can comment, slow mode and blocked keywords.',
            onTap: () => LiveRoomChatRulesSheet.show(context),
          ),
        ],
      ),
    );
  }
}

class _SettingsNavRow extends StatelessWidget {
  const _SettingsNavRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Chevron points toward the row's end in either direction.
    final chevron = Directionality.of(context) == TextDirection.rtl
        ? Icons.chevron_left
        : Icons.chevron_right;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.optionsSubtitle,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(chevron, color: Colors.white54, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
