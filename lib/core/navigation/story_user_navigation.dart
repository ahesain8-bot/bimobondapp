import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart' as auth_di;
import 'package:bimobondapp/app/home/presentation/utils/active_stories_registry.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/stories/domain/usecases/stories_usecases.dart';
import 'package:bimobondapp/app/stories/presentation/di/stories_injector.dart'
    as stories_di;
import 'package:bimobondapp/core/data/viewed_stories_store.dart';
import 'package:bimobondapp/core/navigation/feed_navigation.dart';
import 'package:bimobondapp/core/navigation/user_profile_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// True when the user has active stories the viewer has not finished yet.
bool userHasUnseenActiveStories(String userId) {
  final id = userId.trim();
  if (id.isEmpty) return false;

  final registry = auth_di.sl<ActiveStoriesRegistry>();
  final stories = registry.activeStoriesFor(id);
  if (stories.isEmpty) return false;

  final group = registry.groupFor(id);
  if (group == null) return true;

  return !auth_di.sl<ViewedStoriesStore>().isGroupFullyViewed(group.stories);
}

/// Opens active stories when present; otherwise the user's profile.
Future<bool?> openUserActiveStoriesOrProfile(
  BuildContext context, {
  required String userId,
  String? username,
  String? fullName,
  String? avatarUrl,
  bool? isFollowing,
}) async {
  if (userId.trim().isEmpty) return null;

  final authState = context.read<AuthBloc>().state;
  if (authState is AuthSuccess) {
    final myId = authState.user.id;
    final myFirebaseUid = authState.user.firebaseUid;
    if (userId == myId || (myFirebaseUid != null && userId == myFirebaseUid)) {
      context.go('/?tab=profile');
      return null;
    }
  }

  final stories = await _resolveActiveStories(userId);
  if (stories.isNotEmpty) {
    await context.pushFromFeed(
      'stories_viewer',
      extra: {
        'stories': stories,
        'initialIndex': 0,
      },
    );
    return null;
  }

  return openUserProfile(
    context,
    userId: userId,
    username: username,
    fullName: fullName,
    avatarUrl: avatarUrl,
    isFollowing: isFollowing,
  );
}

/// Opens unseen active stories; otherwise the user's profile.
Future<bool?> openUserStoryOrProfile(
  BuildContext context, {
  required String userId,
  String? username,
  String? fullName,
  String? avatarUrl,
  bool? isFollowing,
}) async {
  if (userId.trim().isEmpty) return null;

  final authState = context.read<AuthBloc>().state;
  if (authState is AuthSuccess) {
    final myId = authState.user.id;
    final myFirebaseUid = authState.user.firebaseUid;
    if (userId == myId || (myFirebaseUid != null && userId == myFirebaseUid)) {
      context.go('/?tab=profile');
      return null;
    }
  }

  final stories = await _resolveActiveStories(userId);
  if (stories.isNotEmpty &&
      !auth_di.sl<ViewedStoriesStore>().isGroupFullyViewed(stories)) {
    await context.pushFromFeed(
      'stories_viewer',
      extra: {
        'stories': stories,
        'initialIndex': 0,
      },
    );
    return null;
  }

  return openUserProfile(
    context,
    userId: userId,
    username: username,
    fullName: fullName,
    avatarUrl: avatarUrl,
    isFollowing: isFollowing,
  );
}

/// Opens the user's active stories (including already-seen) from profile.
Future<void> openUserActiveStories(BuildContext context, String userId) async {
  final id = userId.trim();
  if (id.isEmpty) return;

  final stories = await _resolveActiveStories(id);
  if (stories.isEmpty) return;

  await context.pushFromFeed(
    'stories_viewer',
    extra: {
      'stories': stories,
      'initialIndex': 0,
    },
  );
}

Future<List<PostEntity>> _resolveActiveStories(String userId) async {
  final registry = auth_di.sl<ActiveStoriesRegistry>();
  final cached = registry.activeStoriesFor(userId);
  if (cached.isNotEmpty) return cached;

  final result = await stories_di.sl<GetUserStoriesUseCase>()(
    GetUserStoriesParams(userId: userId, activeOnly: true, limit: 50),
  );
  return result.fold(
    (_) => const [],
    (page) => page.stories
        .where((s) => s.isActive)
        .map((s) => s.toPostEntity())
        .toList(),
  );
}
