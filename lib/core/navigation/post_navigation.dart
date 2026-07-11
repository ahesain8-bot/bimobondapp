import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_post_by_id_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart' as posts_di;
import 'package:bimobondapp/core/navigation/feed_navigation.dart';
import 'package:bimobondapp/core/utils/post_story_filter.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Route extra for [post_detail] (supports opening the comments sheet).
class PostOpenArgs {
  const PostOpenArgs({
    required this.post,
    this.openComments = false,
    this.highlightCommentId,
  });

  final PostEntity post;
  final bool openComments;
  final String? highlightCommentId;
}

PostOpenArgs? postOpenArgsFromExtra(Object? extra) {
  if (extra is PostOpenArgs) return extra;
  if (extra is PostEntity) return PostOpenArgs(post: extra);
  return null;
}

/// Opens [stories_viewer] for stories, otherwise [openPost].
void openStoryOrPost(
  BuildContext context,
  PostEntity post, {
  bool openComments = false,
  String? highlightCommentId,
}) {
  if (post.isStory) {
    openStoryViewer(context, post);
    return;
  }
  openPost(
    context,
    post,
    openComments: openComments,
    highlightCommentId: highlightCommentId,
  );
}

void openStoryViewer(BuildContext context, PostEntity post) {
  if (!post.isStory) {
    openPost(context, post);
    return;
  }

  final List<PostEntity> stories;
  if (isStoryStillActive(post)) {
    stories = onlyStoryPosts([post]);
  } else {
    stories = [post];
  }

  if (stories.isEmpty) {
    final l10n = AppLocalizations.of(context)!;
    PopupDialogs.showErrorDialog(context, l10n.storyExpired);
    return;
  }

  context.pushFromFeed(
    'stories_viewer',
    extra: {
      'stories': stories,
      'initialIndex': 0,
    },
  );
}

void openPost(
  BuildContext context,
  PostEntity post, {
  bool openComments = false,
  String? highlightCommentId,
}) {
  final args = PostOpenArgs(
    post: post,
    openComments: openComments,
    highlightCommentId: highlightCommentId,
  );

  if (post.isAuctionable) {
    context.pushFromFeed('live_details', extra: {'post': post});
    return;
  }
  context.pushFromFeed('post_detail', extra: args);
}

/// Loads a full post by id, then navigates to post detail.
Future<void> openPostById(
  BuildContext context,
  String postId, {
  bool openComments = false,
  String? highlightCommentId,
}) async {
  final id = postId.trim();
  if (id.isEmpty) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  final result = await posts_di.sl<GetPostByIdUseCase>()(id);

  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();

  result.fold(
    (failure) => PopupDialogs.showErrorDialog(context, failure.message),
    (post) => openStoryOrPost(
      context,
      post,
      openComments: openComments,
      highlightCommentId: highlightCommentId,
    ),
  );
}
