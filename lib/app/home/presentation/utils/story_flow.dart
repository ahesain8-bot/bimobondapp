import 'dart:io';

import 'package:bimobondapp/app/ar_camera/ios_ar_camera_screen.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/core/services/feed_playback_gate.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Opens the TikTok-style in-app camera for story creation (capture only).
class StoryFlow {
  StoryFlow._();

  static bool _ensureLoggedIn(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) return true;

    final l10n = AppLocalizations.of(context)!;
    PopupDialogs.showConfirmDialog(
      context,
      title: l10n.loginRequired,
      message: l10n.loginRequiredMessage,
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.login,
      onConfirm: () => context.pushNamed('login'),
    );
    return false;
  }

  static Future<void> start(BuildContext context) async {
    if (!_ensureLoggedIn(context)) return;
    FeedPlaybackGate.instance.setBlocked(true);

    if (Platform.isIOS) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const IosArCameraScreen(isStory: true),
        ),
      );
      return;
    }
    context.pushNamed(
      'add_post_camera',
      extra: const {'isStory': true},
    );
  }
}
