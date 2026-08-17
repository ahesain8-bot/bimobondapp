import 'dart:async';

import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/calls/domain/entities/call_entity.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_bloc.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_event.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_state.dart';
import 'package:bimobondapp/app/calls/presentation/pages/active_call_screen.dart';
import 'package:bimobondapp/app/calls/presentation/pages/incoming_call_screen.dart';
import 'package:bimobondapp/app/calls/presentation/widgets/floating_call_widget.dart';
import 'package:bimobondapp/app/calls/services/callkit_service.dart';
import 'package:bimobondapp/core/routes/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class GlobalCallListener extends StatefulWidget {
  final Widget child;

  const GlobalCallListener({
    super.key,
    required this.child,
  });

  @override
  State<GlobalCallListener> createState() => _GlobalCallListenerState();
}

class _GlobalCallListenerState extends State<GlobalCallListener>
    with WidgetsBindingObserver {
  Timer? _durationTimer;
  int _secondsElapsed = 0;
  bool _isIncomingCallScreenOpen = false;
  bool _isActiveCallScreenOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectSocketIfAuth();
      _initCallkitListeners();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      CallkitService.instance.checkActiveCalls();
      CallkitService.instance.endAllCalls();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (!mounted) return;
      final callState = context.read<CallBloc>().state;
      if (callState is CallIncomingState) {
        CallkitService.instance.showIncomingCall(callState.call.toCallkitData());
      }
    }
  }

  void _initCallkitListeners() {
    CallkitService.instance.initialize(
      onAccept: (extra) {
        final callId = extra['callId']?.toString() ?? extra['id']?.toString();
        if (callId != null && callId.isNotEmpty && mounted) {
          final currentState = context.read<CallBloc>().state;
          if (currentState is CallActiveState && currentState.call.id == callId) {
            return;
          }
          context.read<CallBloc>().add(AcceptCallEvent(callId: callId));
        }
      },
      onDecline: (extra) {
        final callId = extra['callId']?.toString() ?? extra['id']?.toString();
        if (callId != null && callId.isNotEmpty && mounted) {
          context.read<CallBloc>().add(RejectCallEvent(callId: callId));
        }
      },
    );
  }

  void _startTimer() {
    _durationTimer?.cancel();
    _secondsElapsed = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  void _stopTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
    if (mounted) {
      setState(() {
        _secondsElapsed = 0;
      });
    } else {
      _secondsElapsed = 0;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _durationTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _connectSocketIfAuth() {
    if (!mounted) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) {
      context.read<CallBloc>().socketService.connect(authState.user.id);
    }
  }

  void _maximizeCall() {
    if (_isActiveCallScreenOpen) return;
    final nav = AppRouter.rootNavigatorKey.currentState;
    if (nav == null) return;

    if (mounted) {
      setState(() {
        _isActiveCallScreenOpen = true;
      });
    } else {
      _isActiveCallScreenOpen = true;
    }

    nav
        .push(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/active-call'),
            fullscreenDialog: true,
            builder: (routeContext) => BlocProvider.value(
              value: context.read<CallBloc>(),
              child: const ActiveCallScreen(),
            ),
          ),
        )
        .then((_) {
          if (mounted) {
            setState(() {
              _isActiveCallScreenOpen = false;
            });
          } else {
            _isActiveCallScreenOpen = false;
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthSuccess) {
              context.read<CallBloc>().socketService.connect(state.user.id);
              CallkitService.instance.checkActiveCalls();
            } else if (state is AuthInitial) {
              context.read<CallBloc>().socketService.disconnect();
            }
          },
        ),
        BlocListener<CallBloc, CallState>(
          listenWhen: (previous, current) =>
              previous.runtimeType != current.runtimeType,
          listener: (context, state) {
            if (state is CallIncomingState || state is CallOutgoingRingingState) {
              _stopTimer();
            } else if (state is CallActiveState) {
              if (_durationTimer == null) {
                _startTimer();
              }
            } else if (state is CallEndedState || state is CallInitialState) {
              _stopTimer();
            }

            final nav = AppRouter.rootNavigatorKey.currentState;
            if (nav == null) return;

            if (state is CallIncomingState) {
              if (!_isIncomingCallScreenOpen) {
                _isIncomingCallScreenOpen = true;
                nav
                    .push(
                      MaterialPageRoute(
                        settings: const RouteSettings(name: '/incoming-call'),
                        fullscreenDialog: true,
                        builder: (routeContext) => BlocProvider.value(
                          value: context.read<CallBloc>(),
                          child: IncomingCallScreen(call: state.call),
                        ),
                      ),
                    )
                    .then((_) {
                      if (mounted) {
                        setState(() {
                          _isIncomingCallScreenOpen = false;
                        });
                      } else {
                        _isIncomingCallScreenOpen = false;
                      }
                    });
              }
            } else if (state is CallActiveState || state is CallOutgoingRingingState) {
              _maximizeCall();
            } else if (state is CallEndedState) {
              _isIncomingCallScreenOpen = false;
              _isActiveCallScreenOpen = false;
              nav.popUntil(
                (route) =>
                    route.settings.name != '/incoming-call' &&
                    route.settings.name != '/active-call',
              );

              final rootCtx = AppRouter.rootNavigatorKey.currentContext;
              if (rootCtx != null && rootCtx.mounted) {
                ScaffoldMessenger.of(rootCtx).showSnackBar(
                  SnackBar(
                    content: Text(state.reason ?? 'Call ended'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
          },
        ),
      ],
      child: Stack(
        children: [
          widget.child,

          // Minimized Floating Call Overlay (Only when ActiveCallScreen is minimized/closed)
          BlocBuilder<CallBloc, CallState>(
            builder: (context, state) {
              if (_isActiveCallScreenOpen ||
                  (state is! CallActiveState &&
                      state is! CallOutgoingRingingState &&
                      state is! CallReconnectingState)) {
                return const SizedBox.shrink();
              }

              final CallEntity call;
              bool isMuted = false;
              String timerDisplay = _formatDuration(_secondsElapsed);

              if (state is CallOutgoingRingingState) {
                call = state.call;
              } else if (state is CallReconnectingState) {
                call = state.call;
                final isAr = Localizations.localeOf(context).languageCode == 'ar';
                timerDisplay = isAr ? 'جاري إعادة الاتصال...' : 'Reconnecting...';
              } else {
                final activeState = state as CallActiveState;
                call = activeState.call;
                isMuted = activeState.isMuted;
              }

              final livekitService = context.read<CallBloc>().livekitService;

              return Directionality(
                textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
                child: FloatingCallWidget(
                  call: call,
                  livekitService: livekitService,
                  timerText: timerDisplay,
                  isMuted: isMuted,
                  onMaximize: _maximizeCall,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
