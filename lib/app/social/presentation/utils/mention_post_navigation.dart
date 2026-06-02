import 'package:bimobondapp/app/posts/domain/usecases/get_post_by_id_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart' as posts_di;
import 'package:bimobondapp/app/social/domain/entities/user_mention_entity.dart';
import 'package:bimobondapp/core/navigation/post_navigation.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:flutter/material.dart';

Future<void> openMentionPost(
  BuildContext context,
  UserMentionEntity mention,
) async {
  final post = mention.post;
  if (post != null) {
    openPost(context, post);
    return;
  }

  final postId = mention.postId.trim();
  if (postId.isEmpty) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  final result = await posts_di.sl<GetPostByIdUseCase>()(postId);

  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();

  result.fold(
    (failure) => PopupDialogs.showErrorDialog(context, failure.message),
    (loadedPost) => openPost(context, loadedPost),
  );
}
