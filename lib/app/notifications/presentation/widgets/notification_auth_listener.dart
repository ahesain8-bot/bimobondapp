import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/notifications/presentation/di/notifications_injector.dart'
    as notifications_di;
import 'package:bimobondapp/app/notifications/presentation/services/notification_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NotificationAuthListener extends StatefulWidget {
  const NotificationAuthListener({required this.child, super.key});

  final Widget child;

  @override
  State<NotificationAuthListener> createState() =>
      _NotificationAuthListenerState();
}

class _NotificationAuthListenerState extends State<NotificationAuthListener> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFromCurrentAuth());
  }

  void _syncFromCurrentAuth() {
    if (!mounted) return;
    final state = context.read<AuthBloc>().state;
    final coordinator = notifications_di.sl<NotificationCoordinator>();
    if (state is AuthSuccess) {
      coordinator.onLoggedIn(state.user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          current is AuthSuccess || current is AuthInitial,
      listener: (context, state) {
        final coordinator = notifications_di.sl<NotificationCoordinator>();
        if (state is AuthSuccess) {
          coordinator.onLoggedIn(state.user.id);
        } else if (state is AuthInitial) {
          coordinator.onLoggedOut();
        }
      },
      child: widget.child,
    );
  }
}
