import 'package:equatable/equatable.dart';

class UpdatePostParams extends Equatable {
  final String postId;
  final String? description;
  final String? categoryId;
  final String? privacyStatus;

  const UpdatePostParams({
    required this.postId,
    this.description,
    this.categoryId,
    this.privacyStatus,
  });

  @override
  List<Object?> get props => [postId, description, categoryId, privacyStatus];
}
