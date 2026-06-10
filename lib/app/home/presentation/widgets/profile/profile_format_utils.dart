String formatProfileCount(int count) {
  if (count >= 1000000) {
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
  if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}K';
  }
  return count.toString();
}

/// API [apiPostCount] often includes stories; the profile grid shows non-story
/// posts only. Once all pages are loaded, use the grid length so the stat matches.
int resolveProfilePostsCount({
  required int? apiPostCount,
  required int loadedPostsCount,
  required bool hasLoadedAllPosts,
}) {
  if (hasLoadedAllPosts) return loadedPostsCount;
  return apiPostCount ?? loadedPostsCount;
}
