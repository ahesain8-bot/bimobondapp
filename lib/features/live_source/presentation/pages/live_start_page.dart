import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../live/data/repositories/camera_repository_impl.dart';
import '../../../live/domain/repositories/camera_repository.dart';
import '../../../live/domain/usecases/dispose_camera.dart';
import '../../../live/domain/usecases/initialize_camera.dart';
import '../../../live/presentation/utils/live_screen_wakelock.dart';
import '../bloc/start_live/live_bloc.dart';
import '../bloc/start_live/live_event.dart';
import 'service_plus_page.dart';
import 'fans_community_page.dart';
import 'start_live_share_page.dart';
import 'start_live_interaction_sheet.dart';
import '../widgets/start_live/camera_preview_layer.dart';
import '../widgets/start_live/beautify_panel.dart';
import '../widgets/start_live/effects_panel.dart';
import '../widgets/start_live/live_container.dart';
import '../widgets/start_live/options_row.dart';
import '../widgets/start_live/settings_panel.dart';
import '../widgets/start_live/status_bar_area.dart';
import '../widgets/start_live/tools_row.dart';
import '../widgets/vignette_layer.dart';

/// The live start screen: full-screen camera feed with live setup UI.
class LiveStartPage extends StatefulWidget {
  const LiveStartPage({super.key});

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _cameraRepository = CameraRepositoryImpl();
    _liveBloc = LiveBloc(
      initializeCamera: InitializeCamera(_cameraRepository),
      disposeCamera: DisposeCamera(_cameraRepository),
    );
    _preRequestPermissions();
    _liveBloc.add(const LiveInitializeRequested());
    LiveScreenWakelock.enable();
  }

  /// Request CAMERA + MICROPHONE together up-front so starting the live later
  /// never triggers a second permission dialog (the camera plugin only asks
  /// for CAMERA; LiveKit asks for RECORD_AUDIO when it creates the mic track).
  Future<void> _preRequestPermissions() async {
    try {
      await [Permission.camera, Permission.microphone].request();
    } catch (_) {
      // Camera init below surfaces any hard failure; ignore request errors.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _liveBloc.add(const LiveAppPaused());
    } else if (state == AppLifecycleState.resumed) {
      LiveScreenWakelock.enable();
      _liveBloc.add(const LiveAppResumed());
    }
  }

  @override
  void dispose() {
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

  void _toggleSettingsPanel() {
    setState(() {
      _isSettingsPanelVisible = !_isSettingsPanelVisible;
      _isBeautifyPanelVisible = false;
      _isEffectsPanelVisible = false;
    });
  }

  void _closeToMainPage() {
    Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _liveBloc,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const CameraPreviewLayer(),
            const VignetteLayer(),
            StatusBarArea(onClose: _closeToMainPage),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ToolsRow(
                    onBeautifyTap: _toggleBeautifyPanel,
                    onEffectsTap: _toggleEffectsPanel,
                    onSettingsTap: _toggleSettingsPanel,
                    onServiceTap: _openServicePlusPage,
                    onFansTap: _openFansCommunityPage,
                    onShareTap: _openStartLiveSharePage,
                    onInteractionTap: _openStartLiveInteractionSheet,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  LiveContainer(titleController: _titleController),
                  const SizedBox(height: AppSpacing.sectionGap),
                  const OptionsRow(),
                  const SizedBox(height: AppSpacing.sectionGap),
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
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
