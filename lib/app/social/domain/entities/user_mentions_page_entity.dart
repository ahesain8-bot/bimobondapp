import 'package:bimobondapp/app/social/domain/entities/user_mention_entity.dart';
import 'package:equatable/equatable.dart';

class UserMentionsPageEntity extends Equatable {
  const UserMentionsPageEntity({
    required this.mentions,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<UserMentionEntity> mentions;
  final int page;
  final int lastPage;
  final int total;

  bool get hasReachedMax => page >= lastPage;

  @override
  List<Object?> get props => [mentions, page, lastPage, total];
}
