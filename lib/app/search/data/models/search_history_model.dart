import 'package:bimobondapp/app/search/domain/entities/search_history_entity.dart';

class SearchHistoryModel extends SearchHistoryEntity {
  const SearchHistoryModel({
    required super.id,
    required super.query,
    required super.category,
    required super.createdAt,
  });

  factory SearchHistoryModel.fromJson(Map<String, dynamic> json) {
    return SearchHistoryModel(
      id: json['id']?.toString() ?? '',
      query: json['query']?.toString() ?? '',
      category: json['category']?.toString() ?? SearchHistoryCategory.posts,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class SearchHistoryPageModel extends SearchHistoryPageEntity {
  const SearchHistoryPageModel({
    required super.items,
    required super.total,
    required super.page,
    required super.limit,
    required super.totalPages,
  });

  factory SearchHistoryPageModel.fromJson(Map<String, dynamic> json) {
    final raw = json['data'];
    final items = raw is List
        ? raw
              .whereType<Map>()
              .map((e) => SearchHistoryModel.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : <SearchHistoryModel>[];

    final meta = json['meta'];
    final metaMap = meta is Map
        ? Map<String, dynamic>.from(meta)
        : <String, dynamic>{};

    return SearchHistoryPageModel(
      items: items,
      total: _asInt(metaMap['total']) ?? items.length,
      page: _asInt(metaMap['page']) ?? 1,
      limit: _asInt(metaMap['limit']) ?? 10,
      totalPages: _asInt(metaMap['totalPages']) ?? 1,
    );
  }
}

class ClearSearchHistoryResultModel extends ClearSearchHistoryResult {
  const ClearSearchHistoryResultModel({
    required super.success,
    required super.deletedCount,
    super.category,
  });

  factory ClearSearchHistoryResultModel.fromJson(Map<String, dynamic> json) {
    return ClearSearchHistoryResultModel(
      success: json['success'] == true,
      deletedCount: _asInt(json['deletedCount']) ?? 0,
      category: json['category']?.toString(),
    );
  }
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
