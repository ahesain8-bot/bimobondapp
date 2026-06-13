import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/user_mention_entity.dart';
import 'package:bimobondapp/core/navigation/post_navigation.dart';
import 'package:flutter/material.dart';

/// Opens the post related to a mentions inbox item.
Future<void> openMentionPost(
  BuildContext context,
  UserMentionEntity mention,
) async {
  final postId = mention.postId.trim();
  if (postId.isEmpty) return;

  final highlightCommentId = mention.commentId?.trim();

  final embedded = mention.post;
  if (embedded != null && embedded.id.isNotEmpty && _canOpenEmbedded(embedded)) {
    openPost(
      context,
      embedded,
      openComments: true,
      highlightCommentId:
          highlightCommentId != null && highlightCommentId.isNotEmpty
              ? highlightCommentId
              : null,
    );
    return;
  }

  await openPostById(
    context,
    postId,
    openComments: true,
    highlightCommentId:
        highlightCommentId != null && highlightCommentId.isNotEmpty
            ? highlightCommentId
            : null,
  );
}

bool _canOpenEmbedded(PostEntity post) {
  if (post.videoUrl != null && post.videoUrl!.isNotEmpty) return true;
  if (post.thumbnailUrl != null && post.thumbnailUrl!.isNotEmpty) return true;
  return post.media.isNotEmpty;
}
