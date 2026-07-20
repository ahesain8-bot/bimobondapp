import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_post_by_id_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart'
    as posts_di;
import 'package:bimobondapp/app/posts/presentation/pages/profile_posts_viewer_screen.dart';
import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/presentation/pages/sound_detail_screen.dart';
import 'package:bimobondapp/app/sounds/presentation/utils/sound_audio_preview.dart';
import 'package:bimobondapp/core/navigation/profile_posts_navigation.dart';
import 'package:bimobondapp/core/routes/app_router.dart';
import 'package:bimobondapp/core/services/feed_playback_gate.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:flutter/material.dart';

/// Opens the TikTok-style sound page above modals (e.g. the sound picker sheet).
/// Returns a [SoundEntity] when the user confirms "Use this sound" in [pickMode].
Future<SoundEntity?> openSoundDetail(
  BuildContext context, {
  required String soundId,
  bool pickMode = false,
  SoundEntity? preview,
}) async {
  if (soundId.isEmpty) return null;

  final navigatorContext =
      AppRouter.rootNavigatorKey.currentContext ?? context;

  FeedPlaybackGate.instance.setBlocked(true);
  try {
    return await Navigator.of(navigatorContext, rootNavigator: true)
        .push<SoundEntity>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SoundDetailScreen(
          soundId: soundId,
          pickMode: pickMode,
          previewSound: preview,
        ),
      ),
    );
  } finally {
    FeedPlaybackGate.instance.syncFromRouter();
  }
}

/// Pops a sound detail page opened via [openSoundDetail].
void popSoundDetail(BuildContext context, [SoundEntity? result]) {
  Navigator.of(context, rootNavigator: true).pop(result);
}

/// Opens posts from a sound page in the same vertical viewer as profile,
/// stacked above the sound overlay (not under it via GoRouter).
Future<void> openSoundPostsViewer(
  BuildContext context, {
  required List<SoundPostPreviewEntity> previews,
  required int initialIndex,
}) async {
  if (previews.isEmpty) return;
  final start = initialIndex.clamp(0, previews.length - 1);
  final tappedId = previews[start].id.trim();
  if (tappedId.isEmpty) return;

  await SoundAudioPreview.stop();
  if (!context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  // Load tapped post first, then the rest so the viewer can swipe.
  final getPost = posts_di.sl<GetPostByIdUseCase>();
  final tappedResult = await getPost(tappedId);

  final posts = <PostEntity>[];
  String? loadError;
  tappedResult.fold(
    (failure) => loadError = failure.message,
    (post) {
      if (!post.isStory) posts.add(post);
    },
  );

  if (posts.isNotEmpty) {
    final otherIds = <String>[];
    for (var i = 0; i < previews.length; i++) {
      if (i == start) continue;
      final id = previews[i].id.trim();
      if (id.isNotEmpty) otherIds.add(id);
    }
    // Cap parallel fetches to keep the open snappy.
    final toFetch = otherIds.take(24).toList(growable: false);
    if (toFetch.isNotEmpty) {
      final others = await Future.wait(toFetch.map((id) => getPost(id)));
      for (final result in others) {
        result.fold((_) {}, (post) {
          if (!post.isStory && !posts.any((p) => p.id == post.id)) {
            posts.add(post);
          }
        });
      }
      // Keep original grid order.
      final byId = {for (final p in posts) p.id: p};
      posts
        ..clear()
        ..addAll(
          previews
              .map((e) => byId[e.id.trim()])
              .whereType<PostEntity>(),
        );
    }
  }

  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop(); // loading dialog

  if (posts.isEmpty) {
    PopupDialogs.showErrorDialog(
      context,
      loadError ?? 'Post not found',
    );
    return;
  }

  var index = posts.indexWhere((p) => p.id == tappedId);
  if (index < 0) index = 0;

  final args = ProfilePostsOpenArgs(
    posts: posts,
    initialIndex: index,
    source: ProfilePostsViewerSource.userPosts,
    page: 1,
    hasReachedMax: true,
  );

  // Must use the same navigator as sound detail, otherwise GoRouter pushes
  // land underneath the fullscreen sound route.
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => ProfilePostsViewerScreen(args: args),
    ),
  );
}
