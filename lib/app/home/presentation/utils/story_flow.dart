import 'dart:io';

import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/add_post_media_picker_sheet.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

/// Opens media picker and navigates to [add_post] with [isStory] true.
class StoryFlow {
  StoryFlow._();

  static final ImagePicker _picker = ImagePicker();

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

    await AddPostMediaPickerSheet.show(
      context,
      onPick: (source, {required bool isVideo}) =>
          _pickAndOpenAddStory(context, source, isVideo: isVideo),
    );
  }

  static Future<void> _pickAndOpenAddStory(
    BuildContext context,
    ImageSource source, {
    required bool isVideo,
  }) async {
    try {
      if (isVideo) {
        final file = await _picker.pickVideo(source: source);
        if (file == null || !context.mounted) return;
        context.pushNamed(
          'add_post',
          extra: {
            'files': [File(file.path)],
            'type': 'VIDEO',
            'isStory': true,
          },
        );
        return;
      }

      if (source == ImageSource.gallery) {
        final file = await _picker.pickImage(source: source);
        if (file == null || !context.mounted) return;
        context.pushNamed(
          'add_post',
          extra: {
            'files': [File(file.path)],
            'type': 'IMAGE',
            'isStory': true,
          },
        );
        return;
      }

      final file = await _picker.pickImage(source: source);
      if (file == null || !context.mounted) return;
      context.pushNamed(
        'add_post',
        extra: {
          'files': [File(file.path)],
          'type': 'IMAGE',
          'isStory': true,
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      PopupDialogs.showErrorDialog(
        context,
        AppLocalizations.of(context)!.storyPickMediaError(e.toString()),
      );
    }
  }
}
