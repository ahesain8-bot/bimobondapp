import 'package:bimobondapp/app/posts/data/models/post_model.dart';
import 'package:bimobondapp/app/search/domain/entities/search_result_entity.dart';
import 'package:bimobondapp/app/social/data/models/social_user_model.dart';
import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/core/error/dio_handler.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SearchRemoteDataSource {
  SearchRemoteDataSource({required this.apiClient});

  final ApiClient apiClient;

  Future<Map<String, String>?> _optionalAuthHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
  }

  Future<SearchResultEntity> search({
    required String q,
    required SearchApiTab tab,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final headers = await _optionalAuthHeaders();
      final response = await apiClient.dio.get(
        ApiConstants.search,
        queryParameters: {
          'q': q,
          'tab': tab.apiValue,
          'page': page,
          'limit': limit,
        },
        options: headers == null ? null : Options(headers: headers),
      );
      if (response.statusCode == 200 && response.data is Map) {
        return _parseSearchResponse(
          Map<String, dynamic>.from(response.data as Map),
          fallbackTab: tab,
          fallbackQ: q,
        );
      }
      throw ServerException(message: 'Failed to search');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  SearchResultEntity _parseSearchResponse(
    Map<String, dynamic> json, {
    required SearchApiTab fallbackTab,
    required String fallbackQ,
  }) {
    final tab = _parseTab(json['tab']?.toString()) ?? fallbackTab;
    return SearchResultEntity(
      q: (json['q'] ?? fallbackQ).toString(),
      tab: tab,
      posts: _parsePostsSection(json['posts']),
      users: _parseUsersSection(json['users']),
      sounds: _parseSoundsSection(json['sounds']),
      hashtags: _parseHashtagsSection(json['hashtags']),
      postsMeta: _parseMeta(json['posts']),
      usersMeta: _parseMeta(json['users']),
      soundsMeta: _parseMeta(json['sounds']),
      hashtagsMeta: _parseMeta(json['hashtags']),
    );
  }

  SearchApiTab? _parseTab(String? raw) {
    switch (raw?.toUpperCase()) {
      case 'BEST':
        return SearchApiTab.best;
      case 'POSTS':
        return SearchApiTab.posts;
      case 'USERS':
        return SearchApiTab.users;
      case 'SOUNDS':
        return SearchApiTab.sounds;
      case 'HASHTAGS':
        return SearchApiTab.hashtags;
      default:
        return null;
    }
  }

  SearchPageMeta? _parseMeta(dynamic section) {
    if (section is! Map) return null;
    final meta = section['meta'];
    if (meta is! Map) return null;
    final map = Map<String, dynamic>.from(meta);
    return SearchPageMeta(
      total: _asInt(map['total']),
      page: _asInt(map['page'], fallback: 1),
      limit: _asInt(map['limit'], fallback: 20),
      totalPages: _asInt(map['totalPages'], fallback: 1),
    );
  }

  List<dynamic> _sectionData(dynamic section) {
    if (section is List) return section;
    if (section is Map) {
      final data = section['data'];
      if (data is List) return data;
    }
    return const [];
  }

  List<PostModel> _parsePostsSection(dynamic section) {
    return _sectionData(section)
        .whereType<Map>()
        .map((e) => PostModel.fromJson(Map<String, dynamic>.from(e)))
        .where((p) => p.id.isNotEmpty)
        .toList();
  }

  List<SocialUserModel> _parseUsersSection(dynamic section) {
    return _sectionData(section)
        .whereType<Map>()
        .map((e) => SocialUserModel.fromJson(Map<String, dynamic>.from(e)))
        .where((u) => u.id.isNotEmpty)
        .toList();
  }

  List<SoundEntity> _parseSoundsSection(dynamic section) {
    return _sectionData(section)
        .whereType<Map>()
        .map((e) => SoundEntity.fromJson(Map<String, dynamic>.from(e)))
        .where((s) => s.id.isNotEmpty)
        .toList();
  }

  List<SearchHashtagEntity> _parseHashtagsSection(dynamic section) {
    final results = <SearchHashtagEntity>[];
    for (final item in _sectionData(section)) {
      if (item is String) {
        final name = item.trim();
        if (name.isNotEmpty) {
          results.add(SearchHashtagEntity(name: name));
        }
        continue;
      }
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final name = (map['name'] ?? map['tag'] ?? map['hashtag'] ?? '')
          .toString()
          .trim();
      if (name.isEmpty) continue;
      results.add(
        SearchHashtagEntity(
          name: name.startsWith('#') ? name.substring(1) : name,
          postCount: _asInt(map['postCount'] ?? map['count'] ?? map['posts']),
        ),
      );
    }
    return results;
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}
