import 'package:bimobondapp/app/stories/domain/entities/story_entities.dart';
import 'package:bimobondapp/core/error/dio_handler.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class StoriesRemoteDataSource {
  Future<StoryEntity> createStory(CreateStoryInput input);
  Future<List<StoryRingEntity>> getRings();
  Future<StoryListPageEntity> getMyStories({
    int page = 1,
    int limit = 20,
    String? status,
    String? privacyStatus,
    bool? activeOnly,
  });
  Future<StoryListPageEntity> getUserStories(
    String userId, {
    int page = 1,
    int limit = 20,
    String? status,
    String? privacyStatus,
    bool? activeOnly,
  });
  Future<StoryEntity> getStoryById(String storyId);
  Future<StoryEntity> updateStory(
    String storyId,
    Map<String, dynamic> body,
  );
  Future<void> deleteStory(String storyId);
  Future<StoryViewRecordResult> recordView(
    String storyId, {
    int? watchedDuration,
  });
  Future<StoryViewersPageEntity> getViewers(
    String storyId, {
    int page = 1,
    int limit = 20,
  });
}

class StoriesRemoteDataSourceImpl implements StoriesRemoteDataSource {
  StoriesRemoteDataSourceImpl({required this.apiClient});

  final ApiClient apiClient;

  Future<Map<String, dynamic>> _authHeaders({bool required = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final idToken = await user.getIdToken();
      return {'Authorization': 'Bearer $idToken'};
    }
    if (required) {
      throw ServerException(message: 'User not authenticated');
    }
    return {};
  }

  String? _extractErrorMessage(dynamic data) {
    if (data is Map) {
      final message = data['message'];
      if (message is List && message.isNotEmpty) {
        return message.map((e) => e.toString()).join(', ');
      }
      return message?.toString() ?? data['error']?.toString();
    }
    return null;
  }

  Map<String, dynamic> _asMap(dynamic body) {
    if (body is Map<String, dynamic>) return body;
    if (body is Map) return Map<String, dynamic>.from(body);
    throw ServerException(message: 'Unexpected response shape');
  }

  Map<String, dynamic> _listQuery({
    required int page,
    required int limit,
    String? status,
    String? privacyStatus,
    bool? activeOnly,
  }) =>
      {
        'page': page,
        'limit': limit,
        if (status != null && status.isNotEmpty) 'status': status,
        if (privacyStatus != null && privacyStatus.isNotEmpty)
          'privacyStatus': privacyStatus,
        if (activeOnly != null) 'activeOnly': activeOnly ? 'true' : 'false',
      };

  @override
  Future<StoryEntity> createStory(CreateStoryInput input) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.stories,
        data: input.toJson(),
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return StoryEntity.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Failed to create story',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<List<StoryRingEntity>> getRings() async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.storiesRings,
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        final map = _asMap(response.data);
        final raw = map['data'] ?? map['rings'] ?? response.data;
        if (raw is! List) return const [];
        return raw
            .whereType<Map>()
            .map((e) => StoryRingEntity.fromJson(Map<String, dynamic>.from(e)))
            .where((r) => r.user.id.isNotEmpty && r.stories.isNotEmpty)
            .toList();
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Failed to load story rings',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<StoryListPageEntity> getMyStories({
    int page = 1,
    int limit = 20,
    String? status,
    String? privacyStatus,
    bool? activeOnly,
  }) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.storiesMe,
        queryParameters: _listQuery(
          page: page,
          limit: limit,
          status: status,
          privacyStatus: privacyStatus,
          activeOnly: activeOnly,
        ),
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        return StoryListPageEntity.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Failed to load stories',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<StoryListPageEntity> getUserStories(
    String userId, {
    int page = 1,
    int limit = 20,
    String? status,
    String? privacyStatus,
    bool? activeOnly,
  }) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.storiesByUser(userId),
        queryParameters: _listQuery(
          page: page,
          limit: limit,
          status: status,
          privacyStatus: privacyStatus,
          activeOnly: activeOnly,
        ),
        options: Options(headers: await _authHeaders(required: false)),
      );
      if (response.statusCode == 200) {
        return StoryListPageEntity.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to load user stories',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<StoryEntity> getStoryById(String storyId) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.storyById(storyId),
        options: Options(headers: await _authHeaders(required: false)),
      );
      if (response.statusCode == 200) {
        return StoryEntity.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Story not found',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<StoryEntity> updateStory(
    String storyId,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await apiClient.dio.patch(
        ApiConstants.storyById(storyId),
        data: body,
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        return StoryEntity.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Failed to update story',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<void> deleteStory(String storyId) async {
    try {
      final response = await apiClient.dio.delete(
        ApiConstants.storyById(storyId),
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200 || response.statusCode == 204) return;
      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Failed to delete story',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<StoryViewRecordResult> recordView(
    String storyId, {
    int? watchedDuration,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.storyView(storyId),
        data: {
          if (watchedDuration != null) 'watchedDuration': watchedDuration,
        },
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return StoryViewRecordResult.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Failed to record view',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<StoryViewersPageEntity> getViewers(
    String storyId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.storyViewers(storyId),
        queryParameters: {'page': page, 'limit': limit},
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        return StoryViewersPageEntity.fromJson(_asMap(response.data));
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Failed to load viewers',
      );
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }
}
