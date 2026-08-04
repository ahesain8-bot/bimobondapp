import 'package:equatable/equatable.dart';
import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';

class ProfileVisitorEntity extends Equatable {
  final UserEntity user;
  final String viewedAt;
  final bool isFollowing;
  final bool isFollowedBy;
  final bool isFriend;

  const ProfileVisitorEntity({
    required this.user,
    required this.viewedAt,
    this.isFollowing = false,
    this.isFollowedBy = false,
    this.isFriend = false,
  });

  @override
  List<Object?> get props => [user, viewedAt, isFollowing, isFollowedBy, isFriend];
}
