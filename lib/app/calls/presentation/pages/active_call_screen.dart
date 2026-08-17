import 'dart:async';

import 'package:bimobondapp/app/calls/domain/entities/call_entity.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_bloc.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_event.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_state.dart';
import 'package:bimobondapp/app/calls/presentation/screens/video_call_screen.dart';
import 'package:bimobondapp/app/calls/presentation/screens/voice_call_screen.dart';
import 'package:bimobondapp/app/calls/presentation/widgets/call_status.dart';
import 'package:bimobondapp/app/calls/presentation/widgets/group_invite_dialog.dart';
import 'package:bimobondapp/core/utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ActiveCallScreen extends StatefulWidget {
  const ActiveCallScreen({super.key});

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  Timer? _durationTimer;
  int _secondsElapsed = 0;
  bool _isForceVoiceMode = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _durationTimer?.cancel();
    _secondsElapsed = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final callState = context.read<CallBloc>().state;
      if (callState is CallActiveState) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final minutesStr = m.toString().padLeft(2, '0');
    final secondsStr = s.toString().padLeft(2, '0');
    return '$minutesStr:$secondsStr';
  }

  void _onMinimize() {
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _onMinimize();
        }
      },
      child: BlocConsumer<CallBloc, CallState>(
        listener: (context, state) {
          if (state is CallEndedState) {
            if (context.mounted && Navigator.of(context).canPop()) {
              context.pop();
            }
          }
        },
      builder: (context, state) {
        if (state is! CallActiveState && state is! CallOutgoingRingingState) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F172A),
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final CallEntity call;
        bool isOutgoingRinging = false;
        bool isMuted = false;
        bool isCameraOff = false;
        bool isSpeakerOn = false;

        if (state is CallOutgoingRingingState) {
          call = state.call;
          isOutgoingRinging = true;
          isSpeakerOn = call.isVideo;
        } else {
          final activeState = state as CallActiveState;
          call = activeState.call;
          isMuted = activeState.isMuted;
          isCameraOff = activeState.isCameraOff;
          isSpeakerOn = activeState.isSpeakerPhoneOn;
        }

        final livekitService = context.read<CallBloc>().livekitService;

        // Status calculation
        CallUiStatusState statusState;
        if (isOutgoingRinging) {
          statusState = CallUiStatusState.ringing;
        } else if (!livekitService.isConnected) {
          statusState = CallUiStatusState.connecting;
        } else if (isCameraOff) {
          statusState = CallUiStatusState.cameraDisabled;
        } else if (isMuted) {
          statusState = CallUiStatusState.microphoneMuted;
        } else {
          statusState = CallUiStatusState.connected;
        }

        final isVideoMode = call.isVideo && !_isForceVoiceMode;
        final timerText = _formatDuration(_secondsElapsed);

        if (isVideoMode) {
          return VideoCallScreen(
            call: call,
            livekitService: livekitService,
            timerText: timerText,
            isMuted: isMuted,
            isCameraOff: isCameraOff,
            isSpeakerOn: isSpeakerOn,
            statusState: statusState,
            onToggleMute: () {
              context.read<CallBloc>().add(const ToggleMuteEvent());
            },
            onToggleCamera: () {
              context.read<CallBloc>().add(const ToggleCameraEvent());
            },
            onSwitchCamera: () {
              context.read<CallBloc>().add(const SwitchCameraEvent());
            },
            onToggleSpeaker: () {
              context.read<CallBloc>().add(const ToggleSpeakerEvent());
            },
            onAddParticipant: () {
              showDialog(
                context: context,
                builder: (_) => GroupInviteDialog(callId: call.id),
              );
            },
            onSwitchToVoice: () {
              setState(() {
                _isForceVoiceMode = true;
              });
            },
            onEndCall: () {
              if (call.chat?.isGroup == true) {
                context.read<CallBloc>().add(LeaveCallEvent(callId: call.id));
              } else {
                context.read<CallBloc>().add(EndCallEvent(callId: call.id));
              }
            },
            onMinimize: _onMinimize,
          );
        } else {
          return VoiceCallScreen(
            call: call,
            timerText: timerText,
            isOutgoingRinging: isOutgoingRinging,
            isMuted: isMuted,
            isSpeakerOn: isSpeakerOn,
            statusState: statusState,
            onToggleMute: () {
              context.read<CallBloc>().add(const ToggleMuteEvent());
            },
            onToggleSpeaker: () {
              context.read<CallBloc>().add(const ToggleSpeakerEvent());
            },
            onAddParticipant: () {
              showDialog(
                context: context,
                builder: (_) => GroupInviteDialog(callId: call.id),
              );
            },
            onSwitchToVideo: () {
              if (_isForceVoiceMode) {
                setState(() {
                  _isForceVoiceMode = false;
                });
              }
              if (isCameraOff) {
                context.read<CallBloc>().add(const ToggleCameraEvent());
              }
            },
            onEndCall: () {
              if (call.chat?.isGroup == true) {
                context.read<CallBloc>().add(LeaveCallEvent(callId: call.id));
              } else {
                context.read<CallBloc>().add(EndCallEvent(callId: call.id));
              }
            },
            onMinimize: _onMinimize,
          );
        }
      },
    ),
    );
  }
}
