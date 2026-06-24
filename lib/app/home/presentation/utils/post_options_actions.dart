import 'dart:io';

import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/home/presentation/utils/chat_shared_post_cache.dart';
import 'package:bimobondapp/app/home/presentation/utils/story_flow.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_event.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

class PostOptionsActions {
  PostOptionsActions(this.context, this.post);

  final BuildContext context;
  final PostEntity post;

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  bool _ensureLoggedIn() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) return true;

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

  Future<void> report() async {
    if (!_ensureLoggedIn()) return;

    await PopupDialogs.showConfirmDialog(
      context,
      title: l10n.postReportTitle,
      message: l10n.postReportMessage,
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.postOptionReport,
      destructive: true,
      onConfirm: () {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.postReportSubmitted)),
        );
      },
    );
  }

  void notInterested() {
    if (!_ensureLoggedIn()) return;
    context.read<PostsBloc>().add(HidePostFromFeedEvent(post.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.postNotInterestedApplied)),
    );
  }

  Future<void> download() async {
    if (!_ensureLoggedIn()) return;

    final url = _primaryMediaUrl();
    if (url == null) {
      PopupDialogs.showErrorDialog(context, l10n.postDownloadFailed);
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.postDownloadStarted)),
    );

    try {
      final directory = await getApplicationDocumentsDirectory();
      final downloads = Directory('${directory.path}/downloads');
      if (!await downloads.exists()) {
        await downloads.create(recursive: true);
      }

      final uri = Uri.parse(url);
      final fileName = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : 'post_${post.id}';
      final target = File('${downloads.path}/$fileName');

      await Dio().download(url, target.path);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.postDownloadSaved)),
      );
    } catch (_) {
      if (!context.mounted) return;
      PopupDialogs.showErrorDialog(context, l10n.postDownloadFailed);
    }
  }

  Future<void> addToStory() async {
    if (!_ensureLoggedIn()) return;
    ChatSharedPostCache.put(post);
    await StoryFlow.start(context);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.postAddToStoryHint)),
    );
  }

  Future<void> shareAsGif() async {
    final videoUrl = MediaUtils.resolveVideoUrl(post);
    if (videoUrl == null) {
      PopupDialogs.showErrorDialog(context, l10n.postShareAsGifUnavailable);
      return;
    }

    if (!_ensureLoggedIn()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.settingsComingSoon)),
    );
  }

  Future<void> createGroup() async {
    if (!_ensureLoggedIn()) return;
    ChatSharedPostCache.put(post);
    context.pushNamed('all_chats');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.postCreateGroupHint)),
    );
  }

  String? _primaryMediaUrl() {
    final video = MediaUtils.resolveVideoUrl(post);
    if (video != null && video.isNotEmpty) return video;

    final thumb = post.thumbnailUrl;
    if (thumb != null && thumb.isNotEmpty) {
      return MediaUtils.resolveAbsoluteUrl(thumb);
    }

    for (final item in post.media) {
      if (item.url.isEmpty) continue;
      final url = MediaUtils.resolveAbsoluteUrl(item.url);
      if (url.isNotEmpty) return url;
    }
    return null;
  }
}
