import 'package:bimobondapp/app/auth/domain/entities/user_activity_entity.dart';
import 'package:equatable/equatable.dart';

class UserActivityPageEntity extends Equatable {
  const UserActivityPageEntity({
    required this.activities,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<UserActivityEntity> activities;
  final int page;
  final int lastPage;
  final int total;

  bool get hasReachedMax => page >= lastPage;

  @override
  List<Object?> get props => [activities, page, lastPage, total];
}
