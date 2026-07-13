import 'package:bimobondapp/app/search/domain/entities/search_trend_entity.dart';

class SearchTrendModel extends SearchTrendEntity {
  const SearchTrendModel({
    required super.query,
    super.id,
    super.rank,
    super.score,
    super.category,
  });

  factory SearchTrendModel.fromJson(Map<String, dynamic> json) {
    final query = json['query']?.toString() ??
        json['keyword']?.toString() ??
        json['term']?.toString() ??
        json['title']?.toString() ??
        json['name']?.toString() ??
        '';
    return SearchTrendModel(
      query: query,
      id: json['id']?.toString(),
      rank: _asInt(json['rank'] ?? json['position']),
      score: _asInt(json['score'] ?? json['count'] ?? json['searchCount']),
      category: json['category']?.toString(),
    );
  }
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

List<SearchTrendModel> parseSearchTrendsResponse(dynamic body) {
  List<dynamic> raw = const [];
  if (body is List) {
    raw = body;
  } else if (body is Map) {
    final map = Map<String, dynamic>.from(body);
    for (final key in ['data', 'trends', 'items', 'results']) {
      final value = map[key];
      if (value is List) {
        raw = value;
        break;
      }
    }
  }

  return raw
      .whereType<Map>()
      .map((e) => SearchTrendModel.fromJson(Map<String, dynamic>.from(e)))
      .where((t) => t.query.trim().isNotEmpty)
      .toList();
}
