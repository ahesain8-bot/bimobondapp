class SearchHistoryCategory {
  SearchHistoryCategory._();

  static const String all = 'ALL';
  static const String posts = 'POSTS';
  static const String auctions = 'AUCTIONS';
  static const String users = 'USERS';
  static const String sounds = 'SOUNDS';
  static const String hashtags = 'HASHTAGS';
  static const String lives = 'LIVES';
  static const String chats = 'CHATS';
}

class SearchHistoryEntity {
  const SearchHistoryEntity({
    required this.id,
    required this.query,
    required this.category,
    required this.createdAt,
  });

  final String id;
  final String query;
  final String category;
  final String createdAt;
}

class SearchHistoryPageEntity {
  const SearchHistoryPageEntity({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  final List<SearchHistoryEntity> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;
}

class ClearSearchHistoryResult {
  const ClearSearchHistoryResult({
    required this.success,
    required this.deletedCount,
    this.category,
  });

  final bool success;
  final int deletedCount;
  final String? category;
}
