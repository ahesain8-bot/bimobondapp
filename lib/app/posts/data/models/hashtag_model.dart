import 'package:bimobondapp/app/posts/domain/entities/hashtag_entity.dart';

int? _parsePaginationInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

class HashtagModel extends HashtagEntity {
  const HashtagModel({
    required super.id,
    required super.name,
    super.viewCount,
    super.postCount,
  });

  factory HashtagModel.fromJson(Map<String, dynamic> json) {
    return HashtagModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString().toLowerCase() ?? '',
      viewCount: _parsePaginationInt(json['viewCount']) ?? 0,
      postCount: _parsePaginationInt(json['postCount']) ?? 0,
    );
  }
}

class HashtagsPageModel extends HashtagsPageEntity {
  const HashtagsPageModel({
    required super.hashtags,
    required super.page,
    required super.lastPage,
    required super.total,
  });

  factory HashtagsPageModel.fromResponse(
    dynamic body, {
    required int requestedPage,
    required int requestedLimit,
  }) {
    final root = body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    final data = root['data'];
    final raw = data is List ? data : root['data'];
    final hashtags = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => HashtagModel.fromJson(Map<String, dynamic>.from(e)))
            .where((tag) => tag.name.isNotEmpty)
            .toList()
        : const <HashtagModel>[];

    final metaRaw = root['meta'];
    final meta = metaRaw is Map
        ? Map<String, dynamic>.from(metaRaw)
        : root;

    final page = _parsePaginationInt(meta['page']) ?? requestedPage;
    final totalPages = _parsePaginationInt(meta['totalPages']);
    final lastPage = _parsePaginationInt(meta['lastPage']) ??
        totalPages ??
        (hashtags.length < requestedLimit ? page : page + 1);
    final total = _parsePaginationInt(meta['total']) ?? hashtags.length;

    return HashtagsPageModel(
      hashtags: hashtags,
      page: page,
      lastPage: lastPage,
      total: total,
    );
  }
}
