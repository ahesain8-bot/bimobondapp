import 'package:equatable/equatable.dart';

/// Optional delivery metadata, never proof that another entry is promoted.
class LiveFeedPromotion extends Equatable {
  const LiveFeedPromotion({this.id, this.label});

  final String? id;
  final String? label;

  static LiveFeedPromotion? fromJson(Object? value) {
    if (value is! Map) return null;
    return LiveFeedPromotion(
      id: value['id'] is String ? value['id'] as String : null,
      label: value['label'] is String ? value['label'] as String : null,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    if (label != null) 'label': label,
  };

  @override
  List<Object?> get props => [id, label];
}
