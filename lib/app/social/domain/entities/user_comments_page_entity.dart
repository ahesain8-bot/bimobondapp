import 'package:bimobondapp/app/social/domain/entities/user_comment_entity.dart';
import 'package:equatable/equatable.dart';

class UserCommentsPageEntity extends Equatable {
  const UserCommentsPageEntity({
    required this.comments,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<UserCommentEntity> comments;
  final int page;
  final int lastPage;
  final int total;

  bool get hasReachedMax => page >= lastPage;

  @override
  List<Object?> get props => [comments, page, lastPage, total];
}
