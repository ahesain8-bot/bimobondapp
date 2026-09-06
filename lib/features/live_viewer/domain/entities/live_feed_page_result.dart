import 'package:equatable/equatable.dart';

import 'live_entity.dart';

/// One page from `GET /lives/feed` (`{ data, meta }`).
class LiveFeedPageResult extends Equatable {
  const LiveFeedPageResult({
    required this.lives,
    required this.page,
    required this.limit,
    this.total,
    this.totalPages,
  });

  final List<LiveEntity> lives;
  final int page;
  final int limit;
  final int? total;
  final int? totalPages;

  /// Prefer server meta; fall back to a full-page heuristic.
  bool get hasMore {
    if (totalPages != null) return page < totalPages!;
    return lives.length >= limit;
  }

  @override
  List<Object?> get props => [lives, page, limit, total, totalPages];
}
