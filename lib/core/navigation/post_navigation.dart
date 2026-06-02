import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_post_by_id_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart' as posts_di;
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void openPost(BuildContext context, PostEntity post) {
  if (post.isAuctionable) {
    context.pushNamed('live_details', extra: {'post': post});
    return;
  }
  context.pushNamed('post_detail', extra: post);
}

/// Loads a full post by id, then navigates to post detail.
Future<void> openPostById(BuildContext context, String postId) async {
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
    (post) => openPost(context, post),
  );
}
