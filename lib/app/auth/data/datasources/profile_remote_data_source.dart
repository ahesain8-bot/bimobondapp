import 'package:bimobondapp/app/auth/domain/entities/profile_enums.dart';
import 'package:bimobondapp/app/stories/domain/entities/story_entities.dart';
import 'package:bimobondapp/app/stories/domain/entities/highlight_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/data/models/post_model.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

abstract class ProfileRemoteDataSource {
  Future<List<HighlightEntity>> getHighlights(
    String userId, {
    bool isMe = false,
  });
  Future<HighlightEntity> createHighlight(
    String title,
    String? coverUrl,
    int? sortOrder,
  );
  Future<HighlightEntity> getHighlightById(String highlightId);
  Future<HighlightEntity> updateHighlight(
    String highlightId, {
    String? title,
    String? coverUrl,
    int? sortOrder,
  });
  Future<void> deleteHighlight(String highlightId);
  Future<void> addStoryToHighlight(
    String highlightId,
    String storyId, {
    int sortOrder,
  });
  Future<HighlightEntity> addBulkStoriesToHighlight(
    String highlightId,
    List<String> storyIds,
  );
  Future<void> removeStoryFromHighlight(
    String highlightId,
    String storyId,
  );
  Future<List<Map<String, dynamic>>> getPinnedPosts(
    String userId, {
    bool isMe = false,
  });
  Future<void> pinPost(String postId, int sortOrder);
  Future<void> unpinPost(String postId);
  Future<List<PostEntity>> getProfileReposts(String userId);
  Future<List<PostEntity>> getProfileLikedPosts(String userId);
  Future<Map<String, dynamic>> getFollowStatus(String userId);
  Future<void> trackProfileView(String userId);
  Future<List<Map<String, dynamic>>> getCloseFriends();
  Future<void> addCloseFriend(String userId);
  Future<void> removeCloseFriend(String memberId);
  Future<List<ProfileLinkEntity>> getProfileLinks(String userId);
  Future<void> updateProfileLinks(List<Map<String, dynamic>> links);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final Dio dio;

  ProfileRemoteDataSourceImpl({Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConstants.baseUrl,
              headers: {
                'Content-Type': 'application/json',
                'x-api-key': ApiConstants.apiKey,
              },
            ),
          );

  Future<Options> _authOptions() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return Options(
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': ApiConstants.apiKey,
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
  }

  List<dynamic> _extractList(dynamic data, List<String> keys) {
    if (data is List) return data;
    if (data is Map) {
      if (data['data'] is List) return data['data'] as List;
      for (final key in keys) {
        if (data[key] is List) return data[key] as List;
      }
      if (data['data'] is Map) {
        for (final key in keys) {
          if (data['data'][key] is List) return data['data'][key] as List;
        }
      }
      for (final val in data.values) {
        if (val is List) return val;
      }
    }
    return [];
  }

  @override
  Future<List<HighlightEntity>> getHighlights(
    String userId, {
    bool isMe = false,
  }) async {
    final opts = await _authOptions();
    final bool useMe = isMe || userId == 'me';

    final endpoints = useMe
        ? ['/stories/highlights/me', '/users/me/highlights']
        : [
            '/users/$userId/highlights',
            '/stories/highlights/user/$userId',
            '/stories/highlights/$userId',
          ];

    for (final endpoint in endpoints) {
      try {
        final res = await dio.get(endpoint, options: opts);
        final list = _extractList(res.data, ['highlights', 'data', 'items']);
        if (list.isNotEmpty) {
          final items = list
              .whereType<Map>()
              .map(
                (m) => HighlightEntity.fromJson(Map<String, dynamic>.from(m)),
              )
              .toList();
          items.sort((a, b) {
            final aDate = a.createdAt;
            final bDate = b.createdAt;
            if (aDate != null && bDate != null) {
              return bDate.compareTo(aDate);
            }
            return 0;
          });
          return items;
        }
      } catch (e) {
        debugPrint('[ProfileRemoteDS] GET $endpoint failed: $e');
      }
    }
    return [];
  }

  @override
  Future<HighlightEntity> createHighlight(
    String title,
    String? coverUrl,
    int? sortOrder,
  ) async {
    final opts = await _authOptions();
    final res = await dio.post(
      '/stories/highlights',
      data: {
        'title': title,
        if (coverUrl != null) 'coverUrl': coverUrl,
        'sortOrder': sortOrder ?? 0,
      },
      options: opts,
    );
    final map = res.data is Map
        ? Map<String, dynamic>.from(res.data['data'] ?? res.data)
        : <String, dynamic>{};
    return HighlightEntity.fromJson(map);
  }

  @override
  Future<HighlightEntity> getHighlightById(String highlightId) async {
    final opts = await _authOptions();
    final res = await dio.get('/stories/highlights/$highlightId', options: opts);
    final map = res.data is Map
        ? Map<String, dynamic>.from(res.data['data'] ?? res.data)
        : <String, dynamic>{};
    return HighlightEntity.fromJson(map);
  }

  @override
  Future<HighlightEntity> updateHighlight(
    String highlightId, {
    String? title,
    String? coverUrl,
    int? sortOrder,
  }) async {
    final opts = await _authOptions();
    final res = await dio.patch(
      '/stories/highlights/$highlightId',
      data: {
        if (title != null) 'title': title,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (sortOrder != null) 'sortOrder': sortOrder,
      },
      options: opts,
    );
    final map = res.data is Map
        ? Map<String, dynamic>.from(res.data['data'] ?? res.data)
        : <String, dynamic>{};
    return HighlightEntity.fromJson(map);
  }

  @override
  Future<void> deleteHighlight(String highlightId) async {
    final opts = await _authOptions();
    await dio.delete('/stories/highlights/$highlightId', options: opts);
  }

  @override
  Future<void> addStoryToHighlight(
    String highlightId,
    String storyId, {
    int sortOrder = 0,
  }) async {
    final opts = await _authOptions();
    await dio.post(
      '/stories/highlights/$highlightId/stories',
      data: {'storyId': storyId, 'sortOrder': sortOrder},
      options: opts,
    );
  }

  @override
  Future<HighlightEntity> addBulkStoriesToHighlight(
    String highlightId,
    List<String> storyIds,
  ) async {
    final opts = await _authOptions();
    final res = await dio.post(
      '/stories/highlights/$highlightId/stories/bulk',
      data: {'storyIds': storyIds},
      options: opts,
    );
    final data = res.data;
    Map<String, dynamic> map = {};
    if (data is Map) {
      if (data['data'] is Map) {
        map = Map<String, dynamic>.from(data['data']);
      } else if (data['highlight'] is Map) {
        map = Map<String, dynamic>.from(data['highlight']);
      } else {
        map = Map<String, dynamic>.from(data);
      }
    }
    return HighlightEntity.fromJson(map);
  }

  @override
  Future<void> removeStoryFromHighlight(
    String highlightId,
    String storyId,
  ) async {
    final opts = await _authOptions();
    await dio.delete(
      '/stories/highlights/$highlightId/stories/$storyId',
      options: opts,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getPinnedPosts(
    String userId, {
    bool isMe = false,
  }) async {
    final opts = await _authOptions();
    final bool useMe = isMe || userId == 'me';
    final endpoint = useMe
        ? '/users/me/pinned-posts'
        : '/users/$userId/pinned-posts';

    try {
      final res = await dio.get(endpoint, options: opts);
      final list = _extractList(res.data, [
        'pinnedPosts',
        'posts',
        'data',
        'items',
      ]);
      return list
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } catch (e) {
      debugPrint('[ProfileRemoteDS] GET $endpoint failed: $e');
      return [];
    }
  }

  @override
  Future<void> pinPost(String postId, int sortOrder) async {
    final opts = await _authOptions();
    await dio.post(
      '/users/me/pinned-posts',
      data: {'postId': postId, 'sortOrder': sortOrder},
      options: opts,
    );
  }

  @override
  Future<void> unpinPost(String postId) async {
    final opts = await _authOptions();
    await dio.delete('/users/me/pinned-posts/$postId', options: opts);
  }

  @override
  Future<List<PostEntity>> getProfileReposts(String userId) async {
    final opts = await _authOptions();
    final endpoint = userId == 'me'
        ? '/users/me/reposts'
        : '/users/$userId/reposts';
    try {
      final res = await dio.get(endpoint, options: opts);
      final list = _extractList(res.data, [
        'reposts',
        'posts',
        'data',
        'items',
      ]);
      return list
          .whereType<Map>()
          .map(
            (m) =>
                PostModel.fromJson(Map<String, dynamic>.from(m['post'] ?? m)),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<PostEntity>> getProfileLikedPosts(String userId) async {
    final opts = await _authOptions();
    final endpoint = userId == 'me'
        ? '/users/me/liked-posts'
        : '/users/$userId/liked-posts';
    final res = await dio.get(endpoint, options: opts);
    final list = _extractList(res.data, [
      'likedPosts',
      'posts',
      'data',
      'items',
    ]);
    return list
        .whereType<Map>()
        .map(
          (m) => PostModel.fromJson(Map<String, dynamic>.from(m['post'] ?? m)),
        )
        .toList();
  }

  @override
  Future<Map<String, dynamic>> getFollowStatus(String userId) async {
    final opts = await _authOptions();
    try {
      final res = await dio.get('/users/$userId/follow-status', options: opts);
      if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
    } catch (_) {}
    return {'isFollowing': false, 'isFollowedBy': false};
  }

  @override
  Future<void> trackProfileView(String userId) async {
    final opts = await _authOptions();
    try {
      await dio.post(
        '/activity/track',
        data: {
          'events': [
            {
              'type': 'PROFILE_VIEW',
              'targetType': 'USER',
              'targetId': userId,
              'source': 'PROFILE',
            },
          ],
        },
        options: opts,
      );
    } catch (_) {}
  }

  @override
  Future<List<Map<String, dynamic>>> getCloseFriends() async {
    final opts = await _authOptions();
    try {
      final res = await dio.get(ApiConstants.myCloseFriends, options: opts);
      final list = _extractList(res.data, [
        'closeFriends',
        'members',
        'users',
        'data',
        'items',
      ]);
      return list
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } catch (e) {
      debugPrint('[ProfileRemoteDS] GET close-friends failed: $e');
      return [];
    }
  }

  @override
  Future<void> addCloseFriend(String userId) async {
    final opts = await _authOptions();
    await dio.post(
      ApiConstants.myCloseFriends,
      data: {'userId': userId},
      options: opts,
    );
  }

  @override
  Future<void> removeCloseFriend(String memberId) async {
    final opts = await _authOptions();
    await dio.delete(ApiConstants.deleteCloseFriend(memberId), options: opts);
  }

  @override
  Future<List<ProfileLinkEntity>> getProfileLinks(String userId) async {
    final opts = await _authOptions();
    final bool isMe = userId == 'me' || userId.isEmpty;
    final endpoint = isMe
        ? ApiConstants.myProfileLinks
        : ApiConstants.userProfileLinks(userId);
    try {
      final res = await dio.get(endpoint, options: opts);
      final list = _extractList(res.data, [
        'links',
        'profileLinks',
        'data',
        'items',
      ]);
      return list
          .whereType<Map>()
          .map((m) => ProfileLinkEntity.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (e) {
      debugPrint('[ProfileRemoteDS] GET profile-links failed: $e');
      return [];
    }
  }

  @override
  Future<void> updateProfileLinks(List<Map<String, dynamic>> links) async {
    final opts = await _authOptions();
    await dio.put(
      ApiConstants.myProfileLinks,
      data: {'links': links},
      options: opts,
    );
  }
}
