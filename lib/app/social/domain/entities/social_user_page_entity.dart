import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:equatable/equatable.dart';

class SocialUserPageEntity extends Equatable {
  const SocialUserPageEntity({
    required this.users,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<SocialUserEntity> users;
  final int page;
  final int lastPage;
  final int total;

  bool get hasReachedMax => page >= lastPage;

  @override
  List<Object?> get props => [users, page, lastPage, total];
}
