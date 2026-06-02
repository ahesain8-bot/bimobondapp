import 'package:bimobondapp/app/social/domain/entities/user_like_entity.dart';
import 'package:equatable/equatable.dart';

class UserLikesPageEntity extends Equatable {
  const UserLikesPageEntity({
    required this.likes,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<UserLikeEntity> likes;
  final int page;
  final int lastPage;
  final int total;

  bool get hasReachedMax => page >= lastPage;

  @override
  List<Object?> get props => [likes, page, lastPage, total];
}
