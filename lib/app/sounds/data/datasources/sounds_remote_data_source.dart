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

  Future<SoundsPageEntity> getSounds({
    int page = 1,
    int limit = 20,
    String? search,
    SoundSort sort = SoundSort.trending,
    String? creatorId,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'limit': limit,
        'sort': sort.apiValue,
        if (search != null && search.isNotEmpty) 'search': search,
        if (creatorId != null && creatorId.isNotEmpty) 'creatorId': creatorId,
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

  Future<SoundsPageEntity> getMySounds({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.soundsMine,
        queryParameters: {'page': page, 'limit': limit},
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
        final data = response.data;
        if (data is Map) {
          return SoundDetailEntity.fromJson(Map<String, dynamic>.from(data));
        }
      }
      throw ServerException(message: 'Failed to load sound');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  Future<SoundEntity> uploadSound({
    required File audio,
    required int duration,
    String? name,
  }) async {
    try {
      final fileName = audio.path.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(audio.path, filename: fileName),
        'duration': duration,
        if (name != null && name.isNotEmpty) 'name': name,
      });

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
}
