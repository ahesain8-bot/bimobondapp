import 'package:equatable/equatable.dart';

enum HashtagSort { name, popular, posts }

extension HashtagSortQuery on HashtagSort {
  String get apiValue {
    switch (this) {
      case HashtagSort.name:
        return 'NAME';
      case HashtagSort.popular:
        return 'POPULAR';
      case HashtagSort.posts:
        return 'POSTS';
    }
  }
}

class HashtagEntity extends Equatable {
  const HashtagEntity({
    required this.id,
    required this.name,
    this.viewCount = 0,
    this.postCount = 0,
  });

  final String id;
  final String name;
  final int viewCount;
  final int postCount;

  @override
  List<Object?> get props => [id, name, viewCount, postCount];
}

class HashtagsPageEntity extends Equatable {
  const HashtagsPageEntity({
    required this.hashtags,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<HashtagEntity> hashtags;
  final int page;
  final int lastPage;
  final int total;

  bool get hasReachedMax => page >= lastPage;

  @override
  List<Object?> get props => [hashtags, page, lastPage, total];
}
