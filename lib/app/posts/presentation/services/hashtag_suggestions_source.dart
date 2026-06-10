import 'package:bimobondapp/app/posts/domain/entities/hashtag_entity.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_hashtags_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart' as posts_di;

/// Loads trending / search hashtag suggestions for inline compose.
class HashtagSuggestionsSource {
  HashtagSuggestionsSource._();

  static Future<List<HashtagEntity>> search(String query) async {
    final trimmed = query.trim();
    final useCase = posts_di.sl<GetHashtagsUseCase>();
    final result = await useCase(
      GetHashtagsParams(
        page: 1,
        limit: 20,
        search: trimmed.isEmpty ? null : trimmed,
        sort: trimmed.isEmpty ? HashtagSort.popular : HashtagSort.name,
      ),
    );

    return result.fold((_) => const [], (page) => page.hashtags);
  }
}
