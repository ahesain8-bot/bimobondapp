import 'package:bimobondapp/app/posts/data/models/post_view_model.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_views_page_entity.dart';

class PostViewsPageModel extends PostViewsPageEntity {
  const PostViewsPageModel({
    required super.views,
    required super.page,
    required super.lastPage,
    required super.total,
  });

  factory PostViewsPageModel.fromResponse(
    dynamic body,
    List<PostViewModel> views, {
    required int requestedPage,
    required int requestedLimit,
    Map<String, dynamic>? envelope,
  }) {
    final resolvedEnvelope = envelope ?? _envelopeOf(body);
    final metaRaw = resolvedEnvelope['meta'];
    final meta = metaRaw is Map
        ? Map<String, dynamic>.from(metaRaw)
        : resolvedEnvelope;

    final page = _parseInt(meta['page']) ?? requestedPage;
    final lastPage = _parseInt(meta['lastPage']) ??
        (views.length < requestedLimit ? page : page + 1);
    final total = _parseInt(meta['total']) ?? views.length;

    return PostViewsPageModel(
      views: views,
      page: page,
      lastPage: lastPage,
      total: total,
    );
  }

  static Map<String, dynamic> _envelopeOf(dynamic body) {
    if (body is! Map) return {};
    final root = Map<String, dynamic>.from(body);
    final data = root['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return root;
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
