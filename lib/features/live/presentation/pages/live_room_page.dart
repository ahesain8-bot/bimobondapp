import 'package:camera/camera.dart';
import 'package:bimobondapp/app/auctions/data/datasources/auction_socket_service.dart';
import 'package:bimobondapp/app/auctions/presentation/di/auctions_injector.dart'
    as auctions_di;
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/network/live_api_client.dart';
import '../../data/datasources/lives_media_datasource.dart';
import '../../data/datasources/lives_remote_datasource.dart';
import '../../data/datasources/lives_socket_datasource.dart';
import '../../data/repositories/camera_repository_impl.dart';
import '../../data/repositories/live_session_repository_impl.dart';
import '../../domain/effects/live_effects_catalog.dart';
import '../../domain/repositories/camera_repository.dart';
import '../../domain/repositories/live_session_repository.dart';
import '../../domain/usecases/dispose_camera.dart';
import '../../domain/usecases/end_live_session.dart';
import '../../domain/usecases/initialize_camera.dart';
import '../../domain/usecases/like_live_session.dart';
import '../../domain/usecases/send_live_comment.dart';
import '../../domain/usecases/start_live_session.dart';
import '../../domain/usecases/update_live_title.dart';
import '../bloc/live_room/live_room_bloc.dart';
import '../bloc/live_room/live_room_event.dart';
import '../bloc/live_room/live_room_state.dart';
import '../effects/live_face_tracker.dart';
import '../effects/live_face_tracker_scope.dart';
import '../widgets/room/live_room_bottom_bar.dart';
import '../widgets/room/live_room_camera_layer.dart';
import '../widgets/room/live_room_chat_composer.dart';
import '../widgets/room/live_room_chat_feed.dart';
import '../widgets/room/live_room_competition_request_prompt.dart';
import '../widgets/room/live_room_guest_invite_prompt.dart';
import '../widgets/room/live_room_guest_request_prompt.dart';
import '../widgets/room/live_room_stage.dart';
import '../widgets/room/live_room_effects_panel.dart';
import '../widgets/room/live_room_header.dart';
import '../widgets/room/live_room_info_row.dart';
import '../widgets/room/live_starting_indicator.dart';
import '../widgets/vignette_layer.dart';
import '../utils/live_screen_wakelock.dart';
import '../../../live_viewer/presentation/widgets/floating_hearts.dart';
import '../../../live_viewer/presentation/widgets/floating_gifts.dart';

/// Host live-room screen: full-screen camera with TikTok-style Arabic overlays.
class LiveRoomPage extends StatefulWidget {
  const LiveRoomPage({super.key, this.title, this.initialCamera});

  /// Optional title entered on the start screen.
  final String? title;

  /// The camera that was ALREADY running on the start screen.
  /// Handed over so the room reuses the same lens (no reopen, no flicker).
  final CameraController? initialCamera;

  @override
  State<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _LiveRoomPageState extends State<LiveRoomPage>
    with WidgetsBindingObserver {
  LiveRoomBloc? _bloc;
  LiveSessionRepository? _sessionRepository;
  late final CameraRepository _cameraRepository;
  late final LiveFaceTracker _faceTracker;
  late final DateTime _startIndicatorDeadline;
  var _depsReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraRepository = CameraRepositoryImpl();
    _faceTracker = LiveFaceTracker();
    _startIndicatorDeadline = DateTime.now().add(const Duration(seconds: 7));
    _preRequestPermissions();
    LiveScreenWakelock.enable();
  }

  Future<void> _preRequestPermissions() async {
    try {
      await [Permission.camera, Permission.microphone].request();
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_depsReady) return;
    _depsReady = true;

    final apiClient = LiveApiClient();
    apiClient.idTokenProvider = () async {
      final user = fb.FirebaseAuth.instance.currentUser;
      return user?.getIdToken();
    };
    final remote = LivesRemoteDataSource(apiClient: apiClient);
    final socket = LivesSocketDataSource(
      idTokenProvider: () async => apiClient.idTokenProvider?.call(),
    );
    final media = LivesMediaDataSource();
    _sessionRepository = LiveSessionRepositoryImpl(
      remote: remote,
      socket: socket,
      media: media,
    );

    _bloc =
        LiveRoomBloc(
          startLiveSession: StartLiveSession(_sessionRepository!),
          endLiveSession: EndLiveSession(_sessionRepository!),
          initializeCamera: InitializeCamera(_cameraRepository),
          disposeCamera: DisposeCamera(_cameraRepository),
          sendLiveComment: SendLiveComment(_sessionRepository!),
          likeLiveSession: LikeLiveSession(_sessionRepository!),
          updateLiveTitle: UpdateLiveTitle(_sessionRepository!),
          sessionRepository: _sessionRepository!,
          giftSocketService: auctions_di.sl<AuctionSocketService>(),
        )..add(
          LiveRoomStarted(
            title: widget.title,
            initialCamera: widget.initialCamera,
          ),
        );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bloc = _bloc;
    if (bloc == null) return;
    if (state == AppLifecycleState.inactive) {
      bloc.add(const LiveRoomAppPaused());
    } else if (state == AppLifecycleState.resumed) {
      LiveScreenWakelock.enable();
      bloc.add(const LiveRoomAppResumed());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _faceTracker.dispose();
    _bloc?.close();
    LiveScreenWakelock.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = _bloc;
    if (bloc == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return BlocProvider.value(
      value: bloc,
      child: RepositoryProvider<LiveSessionRepository>.value(
        value: _sessionRepository!,
        child: LiveFaceTrackerScope(
          tracker: _faceTracker,
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              final state = bloc.state;
              if (state is LiveRoomReady && !state.isEnding) {
                bloc.add(const LiveRoomEndRequested());
                return;
              }
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
            child: MultiBlocListener(
              listeners: [
                BlocListener<LiveRoomBloc, LiveRoomState>(
                  listenWhen: (previous, current) => current is LiveRoomEnded,
                  listener: (context, state) {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  },
                ),
                BlocListener<LiveRoomBloc, LiveRoomState>(
                  listenWhen: (previous, current) {
                    if (current is LiveRoomReady &&
                        current.actionMessage != null &&
                        (previous is! LiveRoomReady ||
                            previous.actionMessage != current.actionMessage)) {
                      return true;
                    }
                    return false;
                  },
                  listener: (context, state) {
                    if (state is! LiveRoomReady) return;
                    final message = state.actionMessage;
                    if (message == null || message.isEmpty) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(content: Text(message)));
                    context.read<LiveRoomBloc>().add(
                      const LiveRoomClearActionMessage(),
                    );
                  },
                ),
                BlocListener<LiveRoomBloc, LiveRoomState>(
                  listenWhen: (previous, current) {
                    if (current is! LiveRoomReady) return true;
                    if (previous is! LiveRoomReady) return true;
                    return previous.controller != current.controller ||
                        previous.selectedEffectId != current.selectedEffectId ||
                        previous.isCameraInitialized !=
                            current.isCameraInitialized ||
                        previous.isMediaConnected != current.isMediaConnected;
                  },
                  listener: (context, state) async {
                    if (state is! LiveRoomReady) {
                      await _faceTracker.bindController(null);
                      await _faceTracker.setEnabled(false);
                      return;
                    }
                    // Face effects need Flutter CameraController image stream.
                    // While LiveKit owns the camera, tracking is unavailable.
                    if (!state.isCameraInitialized ||
                        state.controller == null) {
                      await _faceTracker.bindController(null);
                      await _faceTracker.setEnabled(false);
                      return;
                    }
                    await _faceTracker.bindController(state.controller);
                    final effect = LiveEffectsCatalog.byId(
                      state.selectedEffectId,
                    );
                    await _faceTracker.setEnabled(effect.needsFaceTracking);
                  },
                ),
              ],
              child: Scaffold(
                backgroundColor: Colors.black,
                body: _LiveRoomBody(
                  startIndicatorDeadline: _startIndicatorDeadline,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveRoomBody extends StatelessWidget {
  const _LiveRoomBody({required this.startIndicatorDeadline});

  final DateTime startIndicatorDeadline;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveRoomBloc, LiveRoomState>(
      buildWhen: (previous, current) =>
          current is LiveRoomLoading ||
          current is LiveRoomOpening ||
          current is LiveRoomFailure ||
          current is LiveRoomReady ||
          current is LiveRoomEnded,
      builder: (context, state) {
        if (state is LiveRoomLoading || state is LiveRoomInitial) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        if (state is LiveRoomFailure) {
          return SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    if (state.isRecovering) ...[
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 16),
                      const Text(
                        'جاري المعالجة…',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ] else ...[
                      if (state.isActiveLiveConflict) ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => context.read<LiveRoomBloc>().add(
                              const LiveRoomRecoverEndAndRestart(),
                            ),
                            child: const Text(
                              'إنهاء البث السابق والبدء من جديد',
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => context.read<LiveRoomBloc>().add(
                              const LiveRoomRecoverResumeActive(),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                            ),
                            child: const Text('استئناف البث الحالي'),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text(
                          'رجوع',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }

        // Opening: local preview as soon as the camera is ready (API still in flight).
        if (state is LiveRoomOpening) {
          return Stack(
            fit: StackFit.expand,
            children: [
              const LiveRoomCameraLayer(),
              const VignetteLayer(),
              LiveStartingIndicator(
                deadline: startIndicatorDeadline,
                isPublished: false,
              ),
            ],
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            // The stage *is* the video area: alone it renders the full-bleed
            // camera, and as soon as someone else is publishing it becomes the
            // shared split box under the header.
            LiveRoomStage(
              // Header + info row, measured off the same tokens they are built
              // from, so the stage sits under them on every screen instead of
              // trusting one hard-coded offset.
              topInset:
                  MediaQuery.paddingOf(context).top + AppSpacing.roomStageTop,
            ),
            const VignetteLayer(),
            LiveStartingIndicator(
              deadline: startIndicatorDeadline,
              isPublished: state is LiveRoomReady && state.isMediaConnected,
            ),
            const IgnorePointer(
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: 168,
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x99000000),
                          Color(0x3D000000),
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.52, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const IgnorePointer(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: 330,
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Color(0xCC000000),
                          Color(0x66000000),
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.52, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SafeArea(
              bottom: false,
              child: Column(
                children: [
                  SizedBox(height: AppSpacing.xxs),
                  LiveRoomHeader(),
                  SizedBox(height: AppSpacing.xs),
                  LiveRoomInfoRow(),
                  // Everything between the header and the bars lives in one
                  // flexible slot pinned to its bottom. Previously the feed was
                  // a rigid child after a Spacer, so the moment the keyboard or
                  // the effects panel claimed the space the column overflowed
                  // and the feed was the part that got clipped.
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(height: AppSpacing.xs),
                        Flexible(
                          child: Padding(
                            padding: EdgeInsetsDirectional.only(
                              start: AppSpacing.xl,
                              end: AppSpacing.roomHorizontal,
                              bottom: AppSpacing.xs,
                            ),
                            child: LiveRoomChatFeed(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  LiveRoomCompetitionRequestPrompt(),
                  LiveRoomGuestRequestPrompt(),
                  LiveRoomGuestInvitePrompt(),
                  LiveRoomChatComposer(),
                  LiveRoomBottomBar(),
                  LiveRoomEffectsPanel(),
                ],
              ),
            ),
            Positioned.fill(
              child: BlocBuilder<LiveRoomBloc, LiveRoomState>(
                buildWhen: (previous, current) =>
                    current is LiveRoomReady &&
                    (previous is! LiveRoomReady ||
                        previous.latestGiftCombo != current.latestGiftCombo),
                builder: (context, state) {
                  if (state is! LiveRoomReady) {
                    return const SizedBox.shrink();
                  }
                  final bloc = context.read<LiveRoomBloc>();
                  return FloatingGiftsLayer(
                    recentGifts: const [],
                    latestCombo: state.latestGiftCombo,
                    onComboConsumed: (payload) {
                      if (bloc.isClosed) return;
                      bloc.add(LiveRoomGiftComboConsumed(payload));
                    },
                  );
                },
              ),
            ),
            BlocBuilder<LiveRoomBloc, LiveRoomState>(
              buildWhen: (previous, current) =>
                  current is LiveRoomReady &&
                  (previous is! LiveRoomReady ||
                      previous.floatingHeartBurst !=
                          current.floatingHeartBurst),
              builder: (context, overlayState) {
                if (overlayState is! LiveRoomReady) {
                  return const SizedBox.shrink();
                }
                return FloatingHeartsOverlay(
                  burst: overlayState.floatingHeartBurst,
                  onConsumed: () => context.read<LiveRoomBloc>().add(
                    const LiveRoomHeartBurstConsumed(),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
