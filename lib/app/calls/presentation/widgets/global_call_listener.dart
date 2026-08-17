import 'dart:async';

import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/calls/domain/entities/call_entity.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_bloc.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_state.dart';
import 'package:bimobondapp/app/calls/presentation/pages/active_call_screen.dart';
import 'package:bimobondapp/app/calls/presentation/pages/incoming_call_screen.dart';
import 'package:bimobondapp/app/calls/presentation/widgets/floating_call_widget.dart';
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

class _GlobalCallListenerState extends State<GlobalCallListener> {
  Timer? _durationTimer;
  int _secondsElapsed = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _connectSocketIfAuth());
    _startTimer();
  }

  void _startTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
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
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _connectSocketIfAuth() {
    if (!mounted) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) {
      context.read<CallBloc>().socketService.connect(authState.user.id);
    }
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
            final nav = AppRouter.rootNavigatorKey.currentState;
            if (nav == null) return;

            if (state is CallIncomingState) {
              nav.push(
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (routeContext) => BlocProvider.value(
                    value: context.read<CallBloc>(),
                    child: IncomingCallScreen(call: state.call),
                  ),
                ),
              );
            } else if (state is CallActiveState || state is CallOutgoingRingingState) {
              nav.push(
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (routeContext) => BlocProvider.value(
                    value: context.read<CallBloc>(),
                    child: const ActiveCallScreen(),
                  ),
                ),
              );
            } else if (state is CallEndedState) {
              if (nav.canPop()) {
                nav.pop();
              }
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

          // Minimized Floating Call Overlay
          BlocBuilder<CallBloc, CallState>(
            builder: (context, state) {
              if (state is! CallActiveState && state is! CallOutgoingRingingState) {
                return const SizedBox.shrink();
              }

              final CallEntity call;
              bool isMuted = false;
              if (state is CallOutgoingRingingState) {
                call = state.call;
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
                  timerText: _formatDuration(_secondsElapsed),
                  isMuted: isMuted,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
