import 'dart:async';

import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_bloc.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_state.dart';
import 'package:bimobondapp/app/calls/presentation/pages/active_call_screen.dart';
import 'package:bimobondapp/app/calls/presentation/pages/incoming_call_screen.dart';
import 'package:bimobondapp/app/calls/presentation/widgets/floating_call_widget.dart';
import 'package:bimobondapp/app/calls/services/callkit_service.dart';
import 'package:bimobondapp/app/calls/services/keyguard_service.dart';
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
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      CallkitService.instance.checkActiveCalls();
      _ensureActiveCallScreenVisibleOnResume();
    } else if (state == AppLifecycleState.paused) {
      if (!mounted) return;
      final callState = context.read<CallBloc>().state;
      final activeSession = context.read<CallBloc>().sessionManager.activeSession;
      if (callState is CallIncomingState &&
          activeSession != null &&
          activeSession.state.isIncomingRinging) {
        CallkitService.instance.showIncomingCall(callState.call.toCallkitData());
      }
    }
  }

  void _ensureActiveCallScreenVisibleOnResume() {
    if (!mounted) return;
    final callState = context.read<CallBloc>().state;
    if (callState is CallActiveState ||
        callState is CallConnectingState ||
        callState is CallOutgoingRingingState) {
      _isActiveCallScreenOpen = false;
      _maximizeCall();
    }
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

    try {
      nav.popUntil((route) =>
          route.isFirst ||
          (route.settings.name != '/incoming-call' &&
           route.settings.name != '/active-call'));
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isActiveCallScreenOpen = true;
        _isIncomingCallScreenOpen = false;
      });
    } else {
      _isActiveCallScreenOpen = true;
      _isIncomingCallScreenOpen = false;
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

            try {
              if (state is CallIncomingState) {
                if (_isActiveCallScreenOpen) {
                  try {
                    nav.popUntil((route) =>
                        route.isFirst ||
                        route.settings.name != '/active-call');
                  } catch (_) {}
                  _isActiveCallScreenOpen = false;
                }
                if (!_isIncomingCallScreenOpen) {
                  if (mounted) {
                    setState(() {
                      _isIncomingCallScreenOpen = true;
                    });
                  } else {
                    _isIncomingCallScreenOpen = true;
                  }
                  nav
                      .push(
                        MaterialPageRoute(
                          settings: const RouteSettings(name: '/incoming-call'),
                          fullscreenDialog: true,
                          builder: (routeContext) => BlocProvider.value(
                            value: context.read<CallBloc>(),
                            child: IncomingCallScreen(
                              call: state.call,
                            ),
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
              } else if (state is CallOutgoingRingingState ||
                  state is CallConnectingState ||
                  state is CallActiveState) {
                if (!_isActiveCallScreenOpen) {
                  try {
                    nav.popUntil((route) =>
                        route.isFirst ||
                        (route.settings.name != '/incoming-call' &&
                         route.settings.name != '/active-call'));
                  } catch (_) {}

                  if (mounted) {
                    setState(() {
                      _isActiveCallScreenOpen = true;
                      _isIncomingCallScreenOpen = false;
                    });
                  } else {
                    _isActiveCallScreenOpen = true;
                    _isIncomingCallScreenOpen = false;
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
              } else if (state is CallEndedState || state is CallInitialState) {
                KeyguardService.instance.setShowWhenLocked(false);
                KeyguardService.instance.requestDismissKeyguard();

                try {
                  nav.popUntil((route) =>
                      route.isFirst ||
                      (route.settings.name != '/incoming-call' &&
                       route.settings.name != '/active-call'));
                } catch (_) {}

                if (mounted) {
                  setState(() {
                    _isIncomingCallScreenOpen = false;
                    _isActiveCallScreenOpen = false;
                  });
                } else {
                  _isIncomingCallScreenOpen = false;
                  _isActiveCallScreenOpen = false;
                }
              }
            } catch (e) {
              debugPrint('[GlobalCallListener] Safe navigation popUntil caught: $e');
            }
          },
        ),
      ],
      child: Stack(
        children: [
          widget.child,
          BlocBuilder<CallBloc, CallState>(
            builder: (context, state) {
              final activeSession =
                  context.read<CallBloc>().sessionManager.activeSession;
              final hasActiveSession = activeSession != null &&
                  (activeSession.state.isConnected ||
                      activeSession.state.isConnecting ||
                      activeSession.state.isOutgoing);

              final isCallRunning = state is CallActiveState ||
                  state is CallConnectingState ||
                  state is CallOutgoingRingingState ||
                  hasActiveSession;

              if (isCallRunning &&
                  !_isActiveCallScreenOpen &&
                  !_isIncomingCallScreenOpen) {
                final call = (state is CallActiveState)
                    ? state.call
                    : (state is CallConnectingState)
                        ? state.call
                        : (state is CallOutgoingRingingState)
                            ? state.call
                            : activeSession?.call;

                if (call != null) {
                  final livekitService = (state is CallActiveState)
                      ? state.livekitService
                      : context.read<CallBloc>().livekitService;

                  final isMuted = (state is CallActiveState)
                      ? state.isMuted
                      : false;

                  return FloatingCallWidget(
                    call: call,
                    livekitService: livekitService,
                    timerText: _formatDuration(_secondsElapsed),
                    isMuted: isMuted,
                    onMaximize: _maximizeCall,
                  );
                }
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}
