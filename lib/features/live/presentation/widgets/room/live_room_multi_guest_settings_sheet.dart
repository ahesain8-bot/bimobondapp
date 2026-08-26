import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/utils/app_colors.dart';
import '../../../domain/entities/live_session.dart';
import '../../../domain/repositories/live_session_repository.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_event.dart';
import '../../bloc/live_room/live_room_state.dart';
import 'live_room_host_sheet_chrome.dart';

/// Multi-guest stage settings (`PATCH /lives/:id/settings`).
///
/// `layout` is the backend's stage presentation hint. The API accepts exactly
/// `GRID` and `PANEL`, so the picker offers those two and nothing else.
class LiveRoomMultiGuestSettingsSheet {
  const LiveRoomMultiGuestSettingsSheet._();

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
          child: _MultiGuestSettingsBody(session: state.session),
        ),
      ),
    );
  }
}

class _MultiGuestSettingsBody extends StatefulWidget {
  const _MultiGuestSettingsBody({required this.session});

  final LiveSession session;

  @override
  State<_MultiGuestSettingsBody> createState() =>
      _MultiGuestSettingsBodyState();
}

class _MultiGuestSettingsBodyState extends State<_MultiGuestSettingsBody>
    with LiveRoomHostSheetMixin {
  late bool _guestsEnabled;
  late String _guestRequestMode;
  late int _maxGuests;
  late String _layout;
  late bool _allowGuestCamera;
  late bool _moderatorsCanManageGuests;
  var _saving = false;

  @override
  LiveSessionRepository get repository => context.read<LiveSessionRepository>();

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    _guestsEnabled = s.guestsEnabled ?? true;
    _guestRequestMode = s.guestRequestMode ?? 'EVERYONE';
    _maxGuests = (s.maxGuests ?? 8).clamp(1, 8);
    _layout = _normalizeLayout(s.layout);
    _allowGuestCamera = s.allowGuestCamera ?? true;
    _moderatorsCanManageGuests = s.moderatorsCanManageGuests ?? true;
  }

  /// Anything the server has not sent (or a value this build does not render)
  /// falls back to the schema default rather than leaving the picker blank.
  static String _normalizeLayout(String? raw) {
    final value = raw?.trim().toUpperCase();
    return value == 'PANEL' ? 'PANEL' : 'GRID';
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final updated = await repository.updateSettings(
        liveId: widget.session.id,
        guestsEnabled: _guestsEnabled,
        guestRequestMode: _guestRequestMode,
        maxGuests: _maxGuests,
        layout: _layout,
        allowGuestCamera: _allowGuestCamera,
        moderatorsCanManageGuests: _moderatorsCanManageGuests,
      );
      if (!mounted) return;
      context.read<LiveRoomBloc>().add(LiveRoomSettingsApplied(updated));
      snack('تم حفظ الإعدادات');
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      snack(errorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LiveRoomHostSheetChrome(
      title: 'إعدادات وضع تعدد الضيوف',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          const _SectionLabel('التخطيط'),
          const SizedBox(height: 12),
          _LayoutPicker(
            value: _layout,
            enabled: !_saving,
            onChanged: (v) => setState(() => _layout = v),
          ),
          const SizedBox(height: 4),
          const Divider(height: 28, color: Colors.white12),
          _ToggleRow(
            title: 'تفعيل الضيوف',
            subtitle: 'السماح للمشاهدين بالانضمام إلى المسرح.',
            value: _guestsEnabled,
            onChanged: _saving
                ? null
                : (v) => setState(() => _guestsEnabled = v),
          ),
          const SizedBox(height: 14),
          const _SectionLabel('من يمكنه إرسال طلب الانضمام'),
          const SizedBox(height: 10),
          _RequestModePicker(
            value: _guestRequestMode,
            enabled: !_saving,
            onChanged: (v) => setState(() => _guestRequestMode = v),
          ),
          const SizedBox(height: 18),
          _SectionLabel('الحد الأقصى للضيوف: $_maxGuests'),
          const _RowSubtitle('لا يحتل المضيف مقعدًا من هذه المقاعد.'),
          Slider(
            value: _maxGuests.toDouble(),
            min: 1,
            max: 8,
            divisions: 7,
            label: '$_maxGuests',
            activeColor: AppColors.optionsToggleActive,
            onChanged: _saving
                ? null
                : (v) => setState(() => _maxGuests = v.round()),
          ),
          const SizedBox(height: 4),
          _ToggleRow(
            title: 'السماح بكاميرا الضيف',
            subtitle: 'السماح للضيوف بتشغيل الكاميرا على المسرح.',
            value: _allowGuestCamera,
            onChanged: _saving
                ? null
                : (v) => setState(() => _allowGuestCamera = v),
          ),
          const SizedBox(height: 14),
          _ToggleRow(
            title: 'المشرفون يديرون الضيوف',
            subtitle: 'السماح للمشرفين بدعوة الضيوف وإدارتهم.',
            value: _moderatorsCanManageGuests,
            onChanged: _saving
                ? null
                : (v) => setState(() => _moderatorsCanManageGuests = v),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _RowSubtitle extends StatelessWidget {
  const _RowSubtitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.optionsSubtitle,
          fontSize: 12,
          height: 1.35,
        ),
      ),
    );
  }
}

/// Title · description · switch, matching the reference's settings rows.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              _RowSubtitle(subtitle),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.optionsToggleActive,
        ),
      ],
    );
  }
}

class _RequestModePicker extends StatelessWidget {
  const _RequestModePicker({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  static const _modes = <String, String>{
    'EVERYONE': 'الجميع',
    'FOLLOWERS': 'المتابعون',
    'OFF': 'إيقاف',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in _modes.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: value == entry.key,
            onSelected: enabled ? (_) => onChanged(entry.key) : null,
            showCheckmark: false,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            selectedColor: AppColors.optionsToggleActive,
            side: BorderSide(
              color: value == entry.key
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.16),
            ),
            labelStyle: TextStyle(
              color: value == entry.key ? Colors.black : Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

/// Horizontal strip of stage-layout previews, as in the reference chrome.
///
/// Scrolls rather than shrinking so the cards keep their aspect ratio on
/// narrow phones and at large text scales.
class _LayoutPicker extends StatelessWidget {
  const _LayoutPicker({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LayoutOptionCard(
            label: 'شبكة',
            selected: value == 'GRID',
            enabled: enabled,
            onTap: () => onChanged('GRID'),
            preview: const _GridPreview(),
          ),
          const SizedBox(width: 12),
          _LayoutOptionCard(
            label: 'لوحة',
            selected: value == 'PANEL',
            enabled: enabled,
            onTap: () => onChanged('PANEL'),
            preview: const _PanelPreview(),
          ),
        ],
      ),
    );
  }
}

class _LayoutOptionCard extends StatelessWidget {
  const _LayoutOptionCard({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.preview,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final Widget preview;

  static const double _width = 78;
  static const double _height = 104;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      child: Column(
        children: [
          GestureDetector(
            onTap: enabled ? onTap : null,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              height: _height,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.18),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Opacity(opacity: enabled ? 1 : 0.5, child: preview),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white60,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

/// Equal-sized seats, three per row — the `GRID` stage hint.
class _GridPreview extends StatelessWidget {
  const _GridPreview();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Expanded(child: _PreviewRow(count: 3)),
        SizedBox(height: 4),
        Expanded(child: _PreviewRow(count: 3)),
        SizedBox(height: 4),
        Expanded(child: _PreviewRow(count: 3)),
      ],
    );
  }
}

/// One lead seat beside a strip of smaller ones — the `PANEL` stage hint.
class _PanelPreview extends StatelessWidget {
  const _PanelPreview();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(flex: 2, child: _PreviewBlock()),
        SizedBox(width: 4),
        Expanded(
          child: Column(
            children: [
              Expanded(child: _PreviewBlock()),
              SizedBox(height: 4),
              Expanded(child: _PreviewBlock()),
              SizedBox(height: 4),
              Expanded(child: _PreviewBlock()),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          const Expanded(child: _PreviewBlock()),
        ],
      ],
    );
  }
}

class _PreviewBlock extends StatelessWidget {
  const _PreviewBlock();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(3),
      ),
      child: const SizedBox.expand(),
    );
  }
}
