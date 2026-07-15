import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:equatable/equatable.dart';

enum SearchApiTab {
  best,
  posts,
  users,
  sounds,
  hashtags,
}

extension SearchApiTabX on SearchApiTab {
  String get apiValue {
    switch (this) {
      case SearchApiTab.best:
        return 'BEST';
      case SearchApiTab.posts:
        return 'POSTS';
      case SearchApiTab.users:
        return 'USERS';
      case SearchApiTab.sounds:
        return 'SOUNDS';
      case SearchApiTab.hashtags:
        return 'HASHTAGS';
    }
  }
}

class SearchHashtagEntity extends Equatable {
  const SearchHashtagEntity({
    required this.name,
    this.postCount = 0,
  });

  final String name;
  final int postCount;

  String get displayName => name.startsWith('#') ? name : '#$name';

  @override
  List<Object?> get props => [name, postCount];
}

class SearchPageMeta extends Equatable {
  const SearchPageMeta({
    this.total = 0,
    this.page = 1,
    this.limit = 20,
    this.totalPages = 1,
  });

  final int total;
  final int page;
  final int limit;
  final int totalPages;

  bool get hasMore => page < totalPages;

  @override
  List<Object?> get props => [total, page, limit, totalPages];
}

class SearchResultEntity extends Equatable {
  const SearchResultEntity({
    required this.q,
    required this.tab,
    this.posts = const [],
    this.users = const [],
    this.sounds = const [],
    this.hashtags = const [],
    this.postsMeta,
    this.usersMeta,
    this.soundsMeta,
    this.hashtagsMeta,
  });

  final String q;
  final SearchApiTab tab;
  final List<PostEntity> posts;
  final List<SocialUserEntity> users;
  final List<SoundEntity> sounds;
  final List<SearchHashtagEntity> hashtags;
  final SearchPageMeta? postsMeta;
  final SearchPageMeta? usersMeta;
  final SearchPageMeta? soundsMeta;
  final SearchPageMeta? hashtagsMeta;

  @override
  List<Object?> get props => [
        q,
        tab,
        posts,
        users,
        sounds,
        hashtags,
        postsMeta,
        usersMeta,
        soundsMeta,
        hashtagsMeta,
      ];
}
