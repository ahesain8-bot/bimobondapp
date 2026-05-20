import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Whether the logged-in user owns [post].
bool isCurrentUserPostOwner(BuildContext context, PostEntity post) {
  final authState = context.read<AuthBloc>().state;
  if (authState is! AuthSuccess) return false;

  final ownerIds = {
    authState.user.id,
    if (authState.user.firebaseUid != null) authState.user.firebaseUid!,
  };
  final postOwnerIds = {
    post.userId,
    if (post.user != null) post.user!.id,
  };
  return ownerIds.any(postOwnerIds.contains);
}
