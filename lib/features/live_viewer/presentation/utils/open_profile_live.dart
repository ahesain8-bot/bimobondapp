import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/auth/domain/entities/user_entity.dart';
import '../../../../core/constants/live_traffic_source.dart';
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
///
/// [trafficSource] is the documented bucket for the screen the open came from
/// (`lives/live-p0-parity.md` §5). It defaults to `PROFILE` because that is
/// where the LIVE badge lives; a `LIVE_STARTED` notification passes
/// `NOTIFICATION` instead. An unrecognised value is dropped rather than sent,
/// so the host's report is never polluted with an invented bucket.
Future<void> openProfileCurrentLive(
  BuildContext context,
  UserEntity user, {
  String trafficSource = LiveTrafficSource.profile,
}) async {
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
      builder: (_) =>
          _ProfileLiveWatchPage(live: live, trafficSource: trafficSource),
    ),
  );
}

class _ProfileLiveWatchPage extends StatefulWidget {
  const _ProfileLiveWatchPage({
    required this.live,
    required this.trafficSource,
  });

  final LiveEntity live;
  final String trafficSource;

  @override
  State<_ProfileLiveWatchPage> createState() => _ProfileLiveWatchPageState();
}

class _ProfileLiveWatchPageState extends State<_ProfileLiveWatchPage> {
  late final LiveViewerBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = di.sl<LiveViewerBloc>();
    // Entering from a profile badge or a LIVE notification uses the same
    // activation event as the feed, so the ticket and age gates run before
    // join. The room page never joins on its own.
    _bloc.add(
      LiveViewerActivated(
        widget.live,
        trafficSource: LiveTrafficSource.normalise(widget.trafficSource),
      ),
    );
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
