import 'package:bimobondapp/app/posts/domain/entities/post_view_entity.dart';
import 'package:equatable/equatable.dart';

class PostViewsPageEntity extends Equatable {
  const PostViewsPageEntity({
    required this.views,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<PostViewEntity> views;
  final int page;
  final int lastPage;
  final int total;

  bool get hasReachedMax => page >= lastPage;

  @override
  List<Object?> get props => [views, page, lastPage, total];
}
