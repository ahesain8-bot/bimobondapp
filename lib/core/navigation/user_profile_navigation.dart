import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Opens another user's profile. Returns the latest follow state when the
/// screen is popped, or `null` if none was provided.
Future<bool?> openUserProfile(
  BuildContext context, {
  required String userId,
  String? username,
  String? fullName,
  String? avatarUrl,
  bool? isFollowing,
}) {
  if (userId.trim().isEmpty) return Future.value(null);

  final authState = context.read<AuthBloc>().state;
  if (authState is AuthSuccess) {
    final myId = authState.user.id;
    final myFirebaseUid = authState.user.firebaseUid;
    if (userId == myId || (myFirebaseUid != null && userId == myFirebaseUid)) {
      context.go('/?tab=profile');
      return Future.value(null);
    }
  }

  return context.pushNamed<bool>(
    'user_profile',
    extra: {
      'userId': userId,
      if (username != null && username.isNotEmpty) 'username': username,
      if (fullName != null && fullName.isNotEmpty) 'fullName': fullName,
      if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatarUrl': avatarUrl,
      if (isFollowing != null) 'isFollowing': isFollowing,
    },
  );
}
