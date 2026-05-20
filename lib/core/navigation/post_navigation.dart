import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void openPost(BuildContext context, PostEntity post) {
  if (post.isAuctionable) {
    context.pushNamed('live_details', extra: {'post': post});
    return;
  }
  context.pushNamed('post_detail', extra: post);
}
