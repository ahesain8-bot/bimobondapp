import 'package:equatable/equatable.dart';

class SocialListQuery extends Equatable {
  const SocialListQuery({
    this.userId,
    this.page = 1,
    this.limit = 20,
  });

  final String? userId;
  final int page;
  final int limit;

  Map<String, dynamic> toQueryParams() => {
        'page': page,
        'limit': limit,
      };

  @override
  List<Object?> get props => [userId, page, limit];
}
