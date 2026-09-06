import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/live_studio.dart';
import '../../../domain/repositories/live_session_repository.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_state.dart';
import 'live_room_host_sheet_chrome.dart';

/// Host-only OBS / LIVE Studio sheet (`GET /lives/:id/studio`).
///
/// Missing Ingress leaves URL/key empty — live continues on LiveKit.
class LiveRoomStudioSheet {
  const LiveRoomStudioSheet._();

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
          child: _StudioBody(liveId: state.session.id, initial: state.session.studio),
        ),
      ),
    );
  }
}

class _StudioBody extends StatefulWidget {
  const _StudioBody({required this.liveId, this.initial});

  final String liveId;
  final LiveStudio? initial;

  @override
  State<_StudioBody> createState() => _StudioBodyState();
}

class _StudioBodyState extends State<_StudioBody> {
  LiveStudio? _studio;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _studio = widget.initial;
    _load();
  }

  Future<void> _load() async {
    try {
      final studio = await context.read<LiveSessionRepository>().loadStudio(
        widget.liveId,
      );
      if (!mounted) return;
      setState(() {
        _studio = studio ?? _studio;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final studio = _studio;
    return LiveRoomHostSheetChrome(
      title: 'البث من OBS',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'المنفذ الشائع للـ RTMP هو 1935. مفتاح البث للمضيف فقط.',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (studio == null || !studio.hasRtmpCredentials) ...[
              Text(
                'Ingress غير متوفر حالياً. البث بالكاميرا/المايك يعمل بشكل طبيعي.',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
              if (studio?.recordingStatus != null) ...[
                const SizedBox(height: 12),
                Text(
                  'التسجيل: ${studio!.recordingStatus}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ] else ...[
              _CopyField(label: 'RTMP URL', value: studio.rtmpUrl!),
              const SizedBox(height: 10),
              _CopyField(
                label: 'Stream key',
                value: studio.streamKey!,
                obscure: true,
              ),
              if (studio.recordingStatus != null) ...[
                const SizedBox(height: 12),
                Text(
                  'التسجيل: ${studio.recordingStatus}'
                  '${studio.autoRecord ? ' · تلقائي' : ''}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
              if (studio.canPublishScreen)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'يمكن نشر مشاركة الشاشة من هذا البث.',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CopyField extends StatelessWidget {
  const _CopyField({
    required this.label,
    required this.value,
    this.obscure = false,
  });

  final String label;
  final String value;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: value));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم النسخ')),
                  );
                },
                icon: const Icon(Icons.copy, color: Colors.white),
              ),
              Expanded(
                child: Text(
                  obscure ? '••••••••' : value,
                  textAlign: TextAlign.left,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
