import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/auth/domain/entities/user_entity.dart';
import '../../../live/presentation/utils/live_screen_wakelock.dart';
import '../../data/mappers/live_mapper.dart';
import '../../domain/entities/live_entity.dart';
import '../bloc/live_viewer/live_viewer_bloc.dart';
import '../bloc/live_viewer/live_viewer_event.dart';
import '../di/live_viewer_injector.dart' as di;
import '../widgets/live_room_page.dart';

/// Opens the user's current LIVE from a profile indicator using the existing
/// viewer join pipeline. No-ops when `isLive` is false or `currentLive` has
/// no id.
Future<void> openProfileCurrentLive(
  BuildContext context,
  UserEntity user,
) async {
  if (user.isLive != true) return;
  final live = LiveMapper.fromProfileCurrentLive(
    isLive: user.isLive,
    currentLive: user.currentLive,
    hostId: user.id,
    hostName: user.fullName ?? user.username,
    hostAvatar: user.avatarUrl,
  );
  if (live == null || live.id.isEmpty) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _ProfileLiveWatchPage(live: live),
    ),
  );
}

class _ProfileLiveWatchPage extends StatefulWidget {
  const _ProfileLiveWatchPage({required this.live});

  final LiveEntity live;

  @override
  State<_ProfileLiveWatchPage> createState() => _ProfileLiveWatchPageState();
}

class _ProfileLiveWatchPageState extends State<_ProfileLiveWatchPage> {
  late final LiveViewerBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = di.sl<LiveViewerBloc>();
    LiveScreenWakelock.enable();
  }

  @override
  void dispose() {
    _bloc.add(const LiveViewerDeactivated(leavingFeed: true));
    unawaited(_bloc.close());
    LiveScreenWakelock.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: LiveRoomPage(
        live: widget.live,
        isActive: true,
        onClose: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}
