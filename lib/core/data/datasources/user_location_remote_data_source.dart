import 'package:bimobondapp/app/promotions/domain/entities/promotion_entities.dart';
import 'package:bimobondapp/core/error/dio_handler.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserLocationPayload {
  const UserLocationPayload({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
    this.city,
    this.region,
    this.country,
    this.source = 'APP_OPEN',
  });

  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final String? city;
  final String? region;
  final String? country;
  final String source;

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
      if (altitude != null) 'altitude': altitude,
      if (city != null && city!.isNotEmpty) 'city': city,
      if (region != null && region!.isNotEmpty) 'region': region,
      if (country != null && country!.isNotEmpty) 'country': country,
      'source': source,
    };
  }
}

class UserLocationRemoteDataSource {
  UserLocationRemoteDataSource({required this.apiClient});

  final ApiClient apiClient;

  Future<void> saveLocation(UserLocationPayload payload) async {
    try {
      await apiClient.dio.put(
        ApiConstants.updateUserLocation,
        data: payload.toJson(),
        options: Options(headers: await _authHeaders()),
      );
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  Future<LocationHistoryPageEntity> getHistory({
    int page = 1,
    int limit = 50,
    DateTime? from,
    DateTime? to,
    String? source,
  }) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.userLocationHistory,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (from != null) 'from': from.toUtc().toIso8601String(),
          if (to != null) 'to': to.toUtc().toIso8601String(),
          if (source != null && source.isNotEmpty) 'source': source,
        },
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        return LocationHistoryPageEntity.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
      throw ServerException(message: 'Failed to load location history');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  Future<LocationMovementsEntity> getMovements({
    DateTime? from,
    DateTime? to,
    int limit = 1000,
    String? source,
  }) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.userLocationMovements,
        queryParameters: {
          'limit': limit,
          if (from != null) 'from': from.toUtc().toIso8601String(),
          if (to != null) 'to': to.toUtc().toIso8601String(),
          if (source != null && source.isNotEmpty) 'source': source,
        },
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        return LocationMovementsEntity.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
      throw ServerException(message: 'Failed to load location movements');
    } catch (error) {
      throw DioHandler.handle(error);
    }
  }

  /// Same Firebase Bearer token pattern as profile/posts endpoints.
  Future<Map<String, dynamic>> _authHeaders() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      final idToken = await firebaseUser.getIdToken();
      return {'Authorization': 'Bearer $idToken'};
    }
    throw ServerException(message: 'User not authenticated');
  }
}
