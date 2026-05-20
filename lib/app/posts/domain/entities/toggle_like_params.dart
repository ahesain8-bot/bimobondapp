import 'package:equatable/equatable.dart';

class ToggleLikeParams extends Equatable {
  final String id;
  final bool liked;

  const ToggleLikeParams({required this.id, required this.liked});

  @override
  List<Object?> get props => [id, liked];
}
