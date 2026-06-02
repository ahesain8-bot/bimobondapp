import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:equatable/equatable.dart';

class UserCommentPostEntity extends Equatable {
  const UserCommentPostEntity({
    required this.id,
    this.description,
    this.user,
  });

  final String id;
  final String? description;
  final SocialUserEntity? user;

  @override
  List<Object?> get props => [id, description, user];
}
