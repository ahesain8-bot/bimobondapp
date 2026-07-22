import 'dart:io';

import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/core/error/dio_handler.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SoundsRemoteDataSource {
  SoundsRemoteDataSource({required this.apiClient});

  final ApiClient apiClient;

  Future<Map<String, dynamic>> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw ServerException(message: 'User not authenticated');
    }
    final idToken = await user.getIdToken();
    return {'Authorization': 'Bearer $idToken'};
  }

  List<SoundEntity> _parseSoundList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => SoundEntity.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  SoundDetailEntity _parseDetail(dynamic data) {
    if (data is Map) {
      return SoundDetailEntity.fromJson(Map<String, dynamic>.from(data));
    }
    throw ServerException(message: 'Invalid sound response');
  }

  Future<SoundsPageEntity> getSounds({
    int page = 1,
    int limit = 20,
    String? search,
    SoundSort sort = SoundSort.trending,
    String? creatorId,
    String? groupId,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'limit': limit,
        'sort': sort.apiValue,
        if (search != null && search.isNotEmpty) 'search': search,
        if (creatorId != null && creatorId.isNotEmpty) 'creatorId': creatorId,
        if (groupId != null && groupId.isNotEmpty) 'groupId': groupId,
      };
      final response = await apiClient.dio.get(
        ApiConstants.sounds,
        queryParameters: query,
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          return SoundsPageEntity.fromJson(Map<String, dynamic>.from(data));
        }
      }
      throw ServerException(message: 'Failed to load sounds');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  Future<List<SoundEntity>> getTrending({int limit = 30}) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.soundsTrending,
        queryParameters: {'limit': limit},
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return _parseSoundList(data);
        }
        if (data is Map) {
          final nested = data['data'];
          if (nested is List) return _parseSoundList(nested);
        }
      }
      throw ServerException(message: 'Failed to load trending sounds');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  Future<List<SoundGroupEntity>> getGroups() async {
    try {
      final response = await apiClient.dio.get(ApiConstants.soundsGroups);
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return data
              .whereType<Map>()
              .map(
                (e) => SoundGroupEntity.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList();
        }
        if (data is Map) {
          final nested = data['data'];
          if (nested is List) {
            return nested
                .whereType<Map>()
                .map(
                  (e) =>
                      SoundGroupEntity.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList();
          }
        }
      }
      throw ServerException(message: 'Failed to load sound groups');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  Future<SoundGroupEntity> getGroupById(String id) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.soundGroupById(id));
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          return SoundGroupEntity.fromJson(Map<String, dynamic>.from(data));
        }
      }
      throw ServerException(message: 'Failed to load sound group');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  Future<SoundsPageEntity> getMySounds({
    int page = 1,
    int limit = 20,
    String? search,
    SoundSort sort = SoundSort.recent,
  }) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.soundsMine,
        queryParameters: {
          'page': page,
          'limit': limit,
          'sort': sort.apiValue,
          if (search != null && search.isNotEmpty) 'search': search,
        },
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          return SoundsPageEntity.fromJson(Map<String, dynamic>.from(data));
        }
        if (data is List) {
          return SoundsPageEntity(
            sounds: _parseSoundList(data),
            page: page,
            totalPages: 1,
            total: data.length,
          );
        }
      }
      throw ServerException(message: 'Failed to load your sounds');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  Future<SoundDetailEntity> getSoundById(String id) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.soundById(id));
      if (response.statusCode == 200) {
        return _parseDetail(response.data);
      }
      throw ServerException(message: 'Failed to load sound');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  Future<SoundsSegmentsPageEntity> getSoundSegments({
    required String soundId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.soundSegments(soundId),
        queryParameters: {'page': page, 'limit': limit},
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          return SoundsSegmentsPageEntity.fromJson(
            Map<String, dynamic>.from(data),
          );
        }
        if (data is List) {
          return SoundsSegmentsPageEntity(
            segments: data
                .whereType<Map>()
                .map(
                  (e) => SoundSegmentEntity.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList(),
            page: page,
            totalPages: 1,
            total: data.length,
          );
        }
      }
      throw ServerException(message: 'Failed to load sound segments');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  Future<SoundSegmentEntity> createSoundSegment({
    required String soundId,
    required int startMs,
    required int endMs,
    String? label,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.soundSegments(soundId),
        data: {
          'startMs': startMs,
          'endMs': endMs,
          if (label != null && label.isNotEmpty) 'label': label,
        },
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map) {
          return SoundSegmentEntity.fromJson(Map<String, dynamic>.from(data));
        }
      }
      throw ServerException(message: 'Failed to create sound segment');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  Future<SoundSegmentDetailEntity> getSegmentById(String segmentId) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.soundSegmentById(segmentId),
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          return SoundSegmentDetailEntity.fromJson(
            Map<String, dynamic>.from(data),
          );
        }
      }
      throw ServerException(message: 'Failed to load sound segment');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  Future<SoundEntity> uploadSound({
    required File audio,
    required int duration,
    String? name,
    File? cover,
  }) async {
    try {
      final fileName = audio.path.split(Platform.pathSeparator).last;
      final formMap = <String, dynamic>{
        'audio': await MultipartFile.fromFile(audio.path, filename: fileName),
        'duration': duration,
        if (name != null && name.isNotEmpty) 'name': name,
      };
      if (cover != null) {
        final coverName = cover.path.split(Platform.pathSeparator).last;
        formMap['coverUrl'] = await MultipartFile.fromFile(
          cover.path,
          filename: coverName,
        );
      }
      final formData = FormData.fromMap(formMap);

      final response = await apiClient.dio.post(
        ApiConstants.soundsUpload,
        data: formData,
        options: Options(
          headers: {
            ...await _authHeaders(),
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map) {
          return SoundEntity.fromJson(Map<String, dynamic>.from(data));
        }
      }
      throw ServerException(message: 'Failed to upload sound');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  Future<SoundDetailEntity> createSoundFromUrl({
    required String audioUrl,
    required int duration,
    String? name,
    String? coverUrl,
    List<double>? waveformPeaks,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.sounds,
        data: {
          'audioUrl': audioUrl,
          'duration': duration,
          if (name != null && name.isNotEmpty) 'name': name,
          if (coverUrl != null && coverUrl.isNotEmpty) 'coverUrl': coverUrl,
          if (waveformPeaks != null) 'waveformPeaks': waveformPeaks,
        },
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return _parseDetail(response.data);
      }
      throw ServerException(message: 'Failed to create sound');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  Future<SoundDetailEntity> createFromOriginal({
    required String originalSoundId,
    required String audioUrl,
    required int duration,
    String? name,
    String? coverUrl,
    List<double>? waveformPeaks,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.soundsFromOriginal,
        data: {
          'originalSoundId': originalSoundId,
          'audioUrl': audioUrl,
          'duration': duration,
          if (name != null && name.isNotEmpty) 'name': name,
          if (coverUrl != null && coverUrl.isNotEmpty) 'coverUrl': coverUrl,
          if (waveformPeaks != null) 'waveformPeaks': waveformPeaks,
        },
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return _parseDetail(response.data);
      }
      throw ServerException(message: 'Failed to create remix sound');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }
}
