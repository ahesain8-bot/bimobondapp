import 'package:equatable/equatable.dart';

class PostFilterEntity extends Equatable {
  const PostFilterEntity({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory PostFilterEntity.fromJson(Map<String, dynamic> json) {
    return PostFilterEntity(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  @override
  List<Object?> get props => [id, name];
}
