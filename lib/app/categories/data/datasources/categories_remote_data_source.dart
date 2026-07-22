import 'package:bimobondapp/app/categories/data/models/category_model.dart';
import 'package:bimobondapp/core/error/dio_handler.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:dio/dio.dart';

class CategoriesQuery {
  const CategoriesQuery({
    this.search,
    this.parentId,
    this.flat,
    this.isMain,
  });

  final String? search;
  final String? parentId;
  final bool? flat;
  final bool? isMain;

  Map<String, dynamic> toQueryParameters() => {
        if (search != null && search!.trim().isNotEmpty)
          'search': search!.trim(),
        if (parentId != null && parentId!.isNotEmpty) 'parentId': parentId,
        if (flat != null) 'flat': flat,
        if (isMain != null) 'isMain': isMain,
      };
}

abstract class CategoriesRemoteDataSource {
  Future<List<CategoryModel>> getCategories([CategoriesQuery query = const CategoriesQuery()]);

  Future<CategoryModel> getCategoryById(String id);
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

  Map<String, dynamic> _asMap(dynamic body) {
    if (body is Map<String, dynamic>) return body;
    if (body is Map) return Map<String, dynamic>.from(body);
    throw ServerException(message: 'Unexpected category response shape');
  }

  String? _extractErrorMessage(dynamic data) {
    if (data is Map) {
      return data['message']?.toString() ?? data['error']?.toString();
    }
    return null;
  }

  List<CategoryModel> _parseList(dynamic body) {
    final list = _extractList(body)
        .whereType<Map>()
        .map((json) => CategoryModel.fromJson(Map<String, dynamic>.from(json)))
        .where((category) => category.id.isNotEmpty && category.isActive)
        .toList();
    list.sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      if (byOrder != 0) return byOrder;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  @override
  Future<List<CategoryModel>> getCategories([
    CategoriesQuery query = const CategoriesQuery(),
  ]) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.categories,
        queryParameters: query.toQueryParameters().isEmpty
            ? null
            : query.toQueryParameters(),
      );
      if (response.statusCode == 200) {
        return _parseList(response.data);
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to load categories',
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<CategoryModel> getCategoryById(String id) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.categoryById(id));
      if (response.statusCode == 200) {
        final model = CategoryModel.fromJson(_asMap(response.data));
        if (model.id.isEmpty) {
          throw ServerException(message: 'Category not found');
        }
        return model;
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Category not found',
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }
}
