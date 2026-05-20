import 'package:bimobondapp/app/categories/data/models/category_model.dart';
import 'package:bimobondapp/core/error/dio_handler.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:dio/dio.dart';

abstract class CategoriesRemoteDataSource {
  Future<List<CategoryModel>> getCategories();
}

class CategoriesRemoteDataSourceImpl implements CategoriesRemoteDataSource {
  CategoriesRemoteDataSourceImpl({required this.apiClient});

  final ApiClient apiClient;

  List<dynamic> _extractList(dynamic body) {
    if (body is List) return body;
    if (body is Map) {
      final data = body['data'];
      if (data is List) return data;
      for (final key in ['items', 'categories']) {
        final nested = body[key];
        if (nested is List) return nested;
      }
    }
    return const [];
  }

  String? _extractErrorMessage(dynamic data) {
    if (data is Map) {
      return data['message']?.toString() ?? data['error']?.toString();
    }
    return null;
  }

  @override
  Future<List<CategoryModel>> getCategories() async {
    try {
      final response = await apiClient.dio.get(ApiConstants.categories);
      if (response.statusCode == 200) {
        return _extractList(response.data)
            .whereType<Map>()
            .map(
              (json) => CategoryModel.fromJson(Map<String, dynamic>.from(json)),
            )
            .where((category) => category.id.isNotEmpty && category.isActive)
            .toList();
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to load categories',
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }
}
