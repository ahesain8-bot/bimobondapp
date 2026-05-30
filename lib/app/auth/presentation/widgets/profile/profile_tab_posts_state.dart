import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';

class ProfileTabPostsState {
  static const int pageSize = ProfileLayoutConstants.postsPageSize;

  final List<PostEntity> posts = [];
  int page = 1;
  bool hasReachedMax = false;
  bool isLoadingMore = false;
  bool isInitialLoading = true;
  bool isRefreshing = false;
  int? pendingLoadKey;
}
