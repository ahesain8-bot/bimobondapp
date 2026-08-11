import 'dart:async';

import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shows a full-screen loader while [DeletePostRequestedEvent] runs.
Future<void> deletePostWithLoading(
  BuildContext context, {
  required String postId,
  bool isStory = false,
}) async {
  final bloc = context.read<PostsBloc>();
  // Keep a root navigator handle so we can dismiss loading even if the
  // calling route is popped on DeletePostSuccess.
  final rootNav = Navigator.of(context, rootNavigator: true);
  PopupDialogs.showLoadingDialog(context);

  final done = bloc.stream
      .firstWhere(
        (s) =>
            (s is DeletePostSuccess && s.postId == postId) ||
            (s is DeletePostFailure && s.postId == postId),
      )
      .timeout(const Duration(seconds: 45));

  bloc.add(DeletePostRequestedEvent(postId, isStory: isStory));

  try {
    final state = await done;
    if (state is DeletePostFailure && context.mounted) {
      PopupDialogs.showErrorDialog(context, state.message);
    }
  } on TimeoutException {
    if (context.mounted) {
      PopupDialogs.showErrorDialog(context, 'Delete timed out — try again');
    }
  } finally {
    if (rootNav.canPop()) {
      rootNav.pop();
    }
  }
}
