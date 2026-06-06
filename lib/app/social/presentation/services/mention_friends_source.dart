import 'package:bimobondapp/app/auth/data/datasources/auth_local_data_source.dart';
import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart' as auth_di;
import 'package:bimobondapp/app/social/domain/entities/social_list_query.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/user_suggestion_entity.dart';
import 'package:bimobondapp/app/social/domain/usecases/get_suggestions_usecase.dart';
import 'package:bimobondapp/app/social/domain/usecases/social_user_list_usecases.dart';
import 'package:bimobondapp/app/social/presentation/di/social_injector.dart' as social_di;

/// Cached people list for inline @mention autocomplete (friends, following, suggestions).
class MentionFriendsSource {
  MentionFriendsSource._();

  static List<SocialUserEntity>? _people;
  static Future<List<SocialUserEntity>>? _loading;

  static Future<List<SocialUserEntity>> ensureLoaded() {
    if (_people != null) {
      return Future.value(_people!);
    }
    _loading ??= _fetch();
    return _loading!;
  }

  static Future<List<SocialUserEntity>> _fetch() async {
    final merged = <SocialUserEntity>[];
    final seen = <String>{};

    void addUsers(Iterable<SocialUserEntity> users) {
      for (final user in users) {
        final id = user.id.trim();
        final username = user.username?.trim() ?? '';
        if (id.isEmpty || username.isEmpty || seen.contains(id)) continue;
        seen.add(id);
        merged.add(user);
      }
    }

    void addSuggestions(Iterable<UserSuggestionEntity> suggestions) {
      addUsers(
        suggestions.map(
          (s) => SocialUserEntity(
            id: s.id,
            username: s.username,
            fullName: s.fullName,
            avatarUrl: s.avatarUrl,
            isFollowing: s.isFollowing,
          ),
        ),
      );
    }

    final friendsResult = await social_di.sl<GetMyFriendsUseCase>()(
      const SocialListQuery(page: 1, limit: 200),
    );
    friendsResult.fold((_) => null, (page) => addUsers(page.users));

    if (merged.length < 30) {
      final suggestionsResult =
          await social_di.sl<GetSuggestionsUseCase>()(
        const GetSuggestionsParams(limit: 50),
      );
      suggestionsResult.fold((_) => null, addSuggestions);
    }

    if (merged.isEmpty) {
      final localUser = await auth_di.sl<AuthLocalDataSource>().getUser();
      final userId = localUser?.id.trim() ?? '';
      if (userId.isNotEmpty) {
        final followingResult = await social_di.sl<GetFollowingUseCase>()(
          GetUserListParams(userId, page: 1, limit: 200),
        );
        followingResult.fold((_) => null, (page) => addUsers(page.users));
      }
    }

    _people = merged;
    _loading = null;
    return _people!;
  }

  static List<SocialUserEntity> filter(
    List<SocialUserEntity> friends,
    String query, {
    int limit = 8,
  }) {
    if (friends.isEmpty) return const [];

    if (query.isEmpty) {
      return friends.take(limit).toList(growable: false);
    }

    final lower = query.toLowerCase();
    final matches = <SocialUserEntity>[];
    for (final user in friends) {
      final username = user.username?.toLowerCase() ?? '';
      final display = user.displayName.toLowerCase();
      if (username.startsWith(lower) ||
          username.contains(lower) ||
          display.contains(lower)) {
        matches.add(user);
        if (matches.length >= limit) break;
      }
    }
    return matches;
  }

  /// Case-insensitive username → user id from the cached list.
  static String? userIdForUsernameSync(String username) {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return null;
    final people = _people;
    if (people == null) return null;

    final lower = trimmed.toLowerCase();
    for (final user in people) {
      final un = user.username?.trim();
      if (un != null && un.toLowerCase() == lower) {
        return user.id;
      }
    }
    return null;
  }

  static void clearCache() {
    _people = null;
    _loading = null;
  }
}
