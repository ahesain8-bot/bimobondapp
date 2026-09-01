import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:bimobondapp/app/ar_camera/ar_camera_bridge.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../live/data/repositories/camera_repository_impl.dart';
import '../../../live/domain/repositories/camera_repository.dart';
import '../../../live/domain/usecases/dispose_camera.dart';
import '../../../live/domain/usecases/initialize_camera.dart';
import '../bloc/start_live/live_bloc.dart';
import '../bloc/start_live/live_event.dart';
import 'service_plus_page.dart';
import 'fans_community_page.dart';
import 'start_live_share_page.dart';
import 'start_live_interaction_sheet.dart';
import '../widgets/start_live/ar_live_camera_preview.dart';
import '../widgets/start_live/bottom_tabs.dart';
import '../widgets/start_live/camera_preview_layer.dart';
import '../widgets/start_live/beautify_panel.dart';
import '../widgets/start_live/effects_panel.dart';
import '../widgets/start_live/live_container.dart';
import '../widgets/start_live/options_row.dart';
import '../widgets/start_live/settings_panel.dart';
import '../widgets/start_live/status_bar_area.dart';
import '../widgets/start_live/tools_row.dart';
import '../widgets/vignette_layer.dart';
import '../utils/ar_live_beauty_defaults.dart';
import '../utils/live_screen_wakelock.dart';

/// The live start screen: classic live setup UI + beauty camera.
///
/// When [reuseHostArCamera] is true (opened from the post camera on Android),
/// this page is transparent and keeps using the host's already-running Kotlin
/// AR PlatformView — remounting a second AndroidView was causing a black screen.
///
/// On Android, FaceWarp's GLSurfaceView paints above Flutter widgets, so the
/// classic chrome (tools / title / LIVE) is shown via a native Dialog instead.
class LiveStartPage extends StatefulWidget {
  const LiveStartPage({
    super.key,
    this.reuseHostArCamera = false,
  });

  /// Host route keeps [ArCameraPreview] mounted underneath this transparent page.
  final bool reuseHostArCamera;

  @override
  State<LiveStartPage> createState() => _LiveStartPageState();
}

class _LiveStartPageState extends State<LiveStartPage>
    with WidgetsBindingObserver {
  final TextEditingController _titleController = TextEditingController();
  bool _isBeautifyPanelVisible = false;
  bool _isEffectsPanelVisible = false;
  bool _isSettingsPanelVisible = false;
  late final CameraRepository _cameraRepository;
  late final LiveBloc _liveBloc;
  bool _openingLive = false;

  bool get _useNativeChrome => ArLiveCameraPreview.isSupported;

  bool get _reuseAr =>
      widget.reuseHostArCamera && ArLiveCameraPreview.isSupported;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _cameraRepository = CameraRepositoryImpl();
    _liveBloc = LiveBloc(
      initializeCamera: InitializeCamera(_cameraRepository),
      disposeCamera: DisposeCamera(_cameraRepository),
      reuseHostArCamera: _reuseAr,
    );
    _preRequestPermissions();
    _liveBloc.add(const LiveInitializeRequested());
    LiveScreenWakelock.enable();

    if (_reuseAr) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ArLiveBeautyDefaults.apply(isFrontCamera: true);
      });
    }

    if (_useNativeChrome) {
      ArCameraBridge.installPlatformCallbacks();
      ArCameraBridge.onLiveStartGoLive = _onNativeGoLive;
      ArCameraBridge.onLiveStartClose = _closeToMainPage;
      ArCameraBridge.onLiveStartBeautify = _onNativeBeautify;
      ArCameraBridge.onLiveStartEffects = _onNativeEffects;
      ArCameraBridge.onLiveStartSettings = _onNativeSettings;
      ArCameraBridge.onLiveStartFlip = () {
        _liveBloc.add(const LiveCameraSwitchRequested());
      };
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _enableNativeChrome();
      });
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _enableNativeChrome();
      });
    }
  }

  Future<void> _enableNativeChrome() async {
    if (!mounted || !_useNativeChrome) return;
    await ArCameraBridge.setLiveStartChrome(visible: true);
  }

  Future<void> _hideNativeChrome() async {
    if (!_useNativeChrome) return;
    await ArCameraBridge.setLiveStartChrome(visible: false);
  }

  Future<void> _onNativeGoLive(String title) async {
    if (_openingLive || !mounted) return;
    _openingLive = true;
    try {
      await _hideNativeChrome();
      if (!mounted) return;
      await openLiveRoomFromStart(
        context,
        title: title.trim(),
        liveBloc: _liveBloc,
      );
      if (mounted && _useNativeChrome) {
        await _enableNativeChrome();
      }
    } finally {
      _openingLive = false;
    }
  }

  Future<void> _prepareForFlutterPanel() async {
    await _hideNativeChrome();
    if (!mounted) return;
    // Letterbox GL away from the bottom so Flutter panels are visible.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final bottomPx = (320 * dpr).round();
    await ArCameraBridge.setPreviewLetterbox(topPx: 0, bottomPx: bottomPx);
  }

  Future<void> _restoreAfterFlutterPanel() async {
    if (!mounted) return;
    await ArCameraBridge.setPreviewLetterbox(topPx: 0, bottomPx: 0);
    if (mounted && _useNativeChrome) {
      await _enableNativeChrome();
    }
  }

  Future<void> _onNativeBeautify() async {
    await _prepareForFlutterPanel();
    if (!mounted) return;
    setState(() {
      _isBeautifyPanelVisible = true;
      _isEffectsPanelVisible = false;
      _isSettingsPanelVisible = false;
    });
  }

  Future<void> _onNativeEffects() async {
    await _prepareForFlutterPanel();
    if (!mounted) return;
    setState(() {
      _isEffectsPanelVisible = true;
      _isBeautifyPanelVisible = false;
      _isSettingsPanelVisible = false;
    });
  }

  Future<void> _onNativeSettings() async {
    await _prepareForFlutterPanel();
    if (!mounted) return;
    setState(() {
      _isSettingsPanelVisible = true;
      _isBeautifyPanelVisible = false;
      _isEffectsPanelVisible = false;
    });
  }

  Future<void> _preRequestPermissions() async {
    try {
      await [Permission.camera, Permission.microphone].request();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_reuseAr) {
      // Host owns the PlatformView lifecycle while we are an overlay.
      return;
    }
    if (state == AppLifecycleState.paused) {
      _liveBloc.add(const LiveAppPaused());
    } else if (state == AppLifecycleState.resumed) {
      LiveScreenWakelock.enable();
      _liveBloc.add(const LiveAppResumed());
      if (_useNativeChrome &&
          !_isBeautifyPanelVisible &&
          !_isEffectsPanelVisible &&
          !_isSettingsPanelVisible) {
        _enableNativeChrome();
      }
    }
  }

  @override
  void dispose() {
    if (_useNativeChrome) {
      ArCameraBridge.onLiveStartGoLive = null;
      ArCameraBridge.onLiveStartClose = null;
      ArCameraBridge.onLiveStartBeautify = null;
      ArCameraBridge.onLiveStartEffects = null;
      ArCameraBridge.onLiveStartSettings = null;
      ArCameraBridge.onLiveStartFlip = null;
      ArCameraBridge.setLiveStartChrome(visible: false);
    }
    WidgetsBinding.instance.removeObserver(this);
    _liveBloc.close();
    _titleController.dispose();
    LiveScreenWakelock.disable();
    super.dispose();
  }

  void _toggleBeautifyPanel() {
    setState(() {
      _isBeautifyPanelVisible = !_isBeautifyPanelVisible;
      _isEffectsPanelVisible = false;
      _isSettingsPanelVisible = false;
    });
  }

  void _toggleEffectsPanel() {
    setState(() {
      _isEffectsPanelVisible = !_isEffectsPanelVisible;
      _isBeautifyPanelVisible = false;
      _isSettingsPanelVisible = false;
    });
  }

  Future<void> _toggleSettingsPanel() async {
    final closing = _isSettingsPanelVisible;
    setState(() {
      _isSettingsPanelVisible = !_isSettingsPanelVisible;
      _isBeautifyPanelVisible = false;
      _isEffectsPanelVisible = false;
    });
    if (_useNativeChrome && closing) {
      await _restoreAfterFlutterPanel();
    }
  }

  Future<void> _dismissFlutterPanels() async {
    if (!_isBeautifyPanelVisible &&
        !_isEffectsPanelVisible &&
        !_isSettingsPanelVisible) {
      return;
    }
    setState(() {
      _isBeautifyPanelVisible = false;
      _isEffectsPanelVisible = false;
      _isSettingsPanelVisible = false;
    });
    if (_useNativeChrome) {
      await _restoreAfterFlutterPanel();
    }
  }

  void _closeToMainPage() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _openServicePlusPage() {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ServicePlusPage()));
  }

  Future<void> _openFansCommunityPage() {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const FansCommunityPage()));
  }

  Future<void> _openStartLiveSharePage() {
    return StartLiveShareSheet.show(context);
  }

  Future<void> _openStartLiveInteractionSheet() {
    return StartLiveInteractionSheet.show(context);
  }

  Future<void> _openMoreSheet() {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.ios_share_rounded, color: Colors.white),
                  title: const Text('Share', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openStartLiveSharePage();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.home_outlined, color: Colors.white),
                  title: const Text(
                    'LIVE Center',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openServicePlusPage();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.assignment_outlined,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Get leads',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openFansCommunityPage();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_camera_back_outlined,
                    color: Colors.white,
                  ),
                  title: const Text('Dual', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openStartLiveInteractionSheet();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // Android beauty GL covers Flutter chrome — native Dialog owns tools/LIVE.
    if (_useNativeChrome) {
      return BlocProvider.value(
        value: _liveBloc,
        child: Scaffold(
          backgroundColor: _reuseAr ? Colors.transparent : Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (!_reuseAr) const Positioned.fill(child: CameraPreviewLayer()),
              if (_isBeautifyPanelVisible ||
                  _isEffectsPanelVisible ||
                  _isSettingsPanelVisible)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _dismissFlutterPanels,
                    child: const ColoredBox(color: Colors.transparent),
                  ),
                ),
              if (_isBeautifyPanelVisible)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: BeautifyPanel(),
                ),
              if (_isEffectsPanelVisible)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: EffectsPanel(),
                ),
              if (_isSettingsPanelVisible)
                Positioned.fill(
                  child: SettingsPanel(onDismiss: _toggleSettingsPanel),
                ),
            ],
          ),
        ),
      );
    }

    return BlocProvider.value(
      value: _liveBloc,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: CameraPreviewLayer()),
            const IgnorePointer(child: VignetteLayer()),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: StatusBarArea(
                onClose: _closeToMainPage,
                titleController: _titleController,
                onChangeCover: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Change cover coming soon')),
                  );
                },
                onAddTopic: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Add topic coming soon')),
                  );
                },
                onAddGoal: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('LIVE goal coming soon')),
                  );
                },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0xE6000000),
                      Color(0x99000000),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ToolsRow(
                      onBeautifyTap: _toggleBeautifyPanel,
                      onEffectsTap: _toggleEffectsPanel,
                      onSettingsTap: _toggleSettingsPanel,
                      onMoreTap: _openMoreSheet,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    LiveContainer(titleController: _titleController),
                    const SizedBox(height: AppSpacing.sm),
                    const OptionsRow(),
                    const BottomTabs(),
                    SizedBox(height: AppSpacing.sm + bottomInset),
                  ],
                ),
              ),
            ),
            if (_isBeautifyPanelVisible)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: BeautifyPanel(),
              ),
            if (_isEffectsPanelVisible)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: EffectsPanel(),
              ),
            if (_isSettingsPanelVisible)
              Positioned.fill(
                child: SettingsPanel(onDismiss: _toggleSettingsPanel),
              ),
          ],
        ),
      ),
    );
  }
}
