import 'package:bimobondapp/app/posts/domain/entities/feed_item_entity.dart';
import 'package:equatable/equatable.dart';

/// One page of feed results with cursor pagination metadata.
class FeedPageEntity extends Equatable {
  const FeedPageEntity({
    required this.items,
    this.nextCursor,
    required this.hasReachedMax,
  });

  final List<FeedItemEntity> items;

  /// Opaque cursor for the next request. `null` when finished or legacy page mode.
  final String? nextCursor;

  /// True when there are no more pages (`nextCursor == null` in cursor mode).
  final bool hasReachedMax;

  @override
  List<Object?> get props => [items, nextCursor, hasReachedMax];
}
