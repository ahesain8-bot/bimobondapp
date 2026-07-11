import 'package:bimobondapp/app/camera_studio/data/models/camera_studio_catalog_model.dart';
import 'package:bimobondapp/core/error/dio_handler.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:dio/dio.dart';

abstract class CameraStudioRemoteDataSource {
  Future<CameraStudioCatalogModel> getCatalog();
  Future<Map<String, dynamic>> getEffectPlacementSchema();
}

class CameraStudioRemoteDataSourceImpl implements CameraStudioRemoteDataSource {
  CameraStudioRemoteDataSourceImpl({required this.apiClient});

  final ApiClient apiClient;

  String? _extractErrorMessage(dynamic data) {
    if (data is Map) {
      return data['message']?.toString() ?? data['error']?.toString();
    }
    return null;
  }

  @override
  Future<CameraStudioCatalogModel> getCatalog() async {
    try {
      final response = await apiClient.dio.get(ApiConstants.cameraStudioCatalog);
      if (response.statusCode == 200) {
        final body = response.data;
        if (body is Map<String, dynamic>) {
          return CameraStudioCatalogModel.fromJson(body);
        }
        if (body is Map) {
          return CameraStudioCatalogModel.fromJson(
            Map<String, dynamic>.from(body),
          );
        }
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ??
            'Failed to load camera studio catalog',
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<Map<String, dynamic>> getEffectPlacementSchema() async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.cameraStudioEffectPlacementSchema,
      );
      if (response.statusCode == 200) {
        final body = response.data;
        if (body is Map<String, dynamic>) return body;
        if (body is Map) return Map<String, dynamic>.from(body);
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ??
            'Failed to load effect placement schema',
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }
}
