import 'package:equatable/equatable.dart';

class SearchTrendEntity extends Equatable {
  const SearchTrendEntity({
    required this.query,
    this.id,
    this.rank,
    this.score,
    this.category,
  });

  final String query;
  final String? id;
  final int? rank;
  final int? score;
  final String? category;

  @override
  List<Object?> get props => [id, query, rank, score, category];
}
