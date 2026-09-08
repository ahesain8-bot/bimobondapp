import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/auth/domain/entities/user_current_live.dart';
import '../../../../app/auth/domain/entities/user_entity.dart';
import '../../../../app/auth/presentation/bloc/auth_bloc.dart';
import '../../../../app/auth/presentation/bloc/auth_event.dart';
import '../../../../core/models/live_media_mode.dart';
import '../../../live/presentation/pages/live_room_page.dart' as host_live;
import '../../../live/presentation/utils/live_screen_wakelock.dart';
import '../../data/mappers/live_mapper.dart';
import '../../domain/entities/live_entity.dart';
import '../bloc/live_viewer/live_viewer_bloc.dart';
import '../bloc/live_viewer/live_viewer_event.dart';
import '../di/live_viewer_injector.dart' as di;
import '../widgets/live_room_page.dart';

enum ProfileLiveOpenKind { none, viewer, host }

/// Result of mapping a profile LIVE tap onto an existing room path.
class ProfileLiveOpenDecision {
  const ProfileLiveOpenDecision.none()
    : kind = ProfileLiveOpenKind.none,
      liveId = null,
      viewerLive = null,
      title = null,
      mediaMode = null;

  ProfileLiveOpenDecision.viewer({required LiveEntity live})
    : kind = ProfileLiveOpenKind.viewer,
      liveId = live.id,
      viewerLive = live,
      title = live.title,
      mediaMode = live.mediaMode;

  const ProfileLiveOpenDecision.host({
    required this.liveId,
    this.title,
    required this.mediaMode,
  }) : kind = ProfileLiveOpenKind.host,
       viewerLive = null;

  final ProfileLiveOpenKind kind;
  final String? liveId;
  final LiveEntity? viewerLive;
  final String? title;
  final String? mediaMode;

  bool get usesExistingViewerJoin => kind == ProfileLiveOpenKind.viewer;
  bool get usesHostReconnect => kind == ProfileLiveOpenKind.host;
}

@visibleForTesting
ProfileLiveOpenDecision? debugLastProfileLiveOpen;

@visibleForTesting
String? debugLastProfileLiveInconsistency;

@visibleForTesting
bool debugSkipProfileLiveNavigation = false;

void reportProfileLiveInconsistency(UserEntity user) {
  final message =
      'Profile LIVE inconsistency: userId=${user.id} isLive=${user.isLive} '
      'currentLive=${user.currentLive}';
  debugLastProfileLiveInconsistency = message;
  debugPrint(message);
}

/// Chooses viewer join vs host reconnect. Never fabricates a live id.
ProfileLiveOpenDecision resolveProfileLiveOpen({
  required UserEntity profile,
  required bool isOwnProfile,
}) {
  if (!profile.showsProfileLiveBadge) {
    if (profile.hasInconsistentProfileLive) {
      reportProfileLiveInconsistency(profile);
    }
    return const ProfileLiveOpenDecision.none();
  }

  final parsed = profile.profileCurrentLive;
  if (parsed == null) {
    reportProfileLiveInconsistency(profile);
    return const ProfileLiveOpenDecision.none();
  }

  if (isOwnProfile) {
    return ProfileLiveOpenDecision.host(
      liveId: parsed.id,
      title: parsed.title,
      mediaMode: parsed.mediaMode,
    );
  }

  final live = LiveMapper.fromProfileCurrentLive(
    isLive: profile.isLive,
    currentLive: profile.currentLive,
    hostId: profile.id,
    hostName: profile.fullName ?? profile.username,
    hostAvatar: profile.avatarUrl,
  );
  if (live == null || live.id.isEmpty) {
    reportProfileLiveInconsistency(profile);
    return const ProfileLiveOpenDecision.none();
  }
  return ProfileLiveOpenDecision.viewer(live: live);
}

/// Opens the user's current LIVE from a profile indicator.
///
/// Other users reuse the feed viewer [LiveRoomPage] + [LiveViewerBloc] join
/// path. The logged-in host reconnects via host [host_live.LiveRoomPage]
/// `existingLiveId` (`POST /lives/:id/start`) and never joins as a viewer.
Future<void> openProfileCurrentLive(
  BuildContext context,
  UserEntity user, {
  bool isOwnProfile = false,
  VoidCallback? onReturned,
}) async {
  final decision = resolveProfileLiveOpen(
    profile: user,
    isOwnProfile: isOwnProfile,
  );
  debugLastProfileLiveOpen = decision;

  if (!decision.usesExistingViewerJoin && !decision.usesHostReconnect) {
    return;
  }

  if (!debugSkipProfileLiveNavigation) {
    if (decision.kind == ProfileLiveOpenKind.host) {
      final liveId = decision.liveId;
      if (liveId == null || liveId.isEmpty) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => host_live.LiveRoomPage(
            existingLiveId: liveId,
            title: decision.title,
            mediaMode: decision.mediaMode ?? LiveMediaMode.video,
          ),
        ),
      );
    } else {
      final live = decision.viewerLive;
      if (live == null || live.id.isEmpty) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _ProfileLiveWatchPage(live: live),
        ),
      );
    }
  }

  if (!context.mounted) return;
  onReturned?.call();
  if (isOwnProfile) {
    try {
      context.read<AuthBloc>().add(const FetchProfileEvent());
    } catch (_) {}
  }
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
