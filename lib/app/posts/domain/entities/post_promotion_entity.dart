import 'package:equatable/equatable.dart';

class PostPromotionEntity extends Equatable {
  const PostPromotionEntity({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;

  factory PostPromotionEntity.fromJson(Map<String, dynamic> json) {
    return PostPromotionEntity(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Promoted',
    );
  }

  @override
  List<Object?> get props => [id, label];
}
