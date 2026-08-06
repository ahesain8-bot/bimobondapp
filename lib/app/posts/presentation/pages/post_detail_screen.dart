import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_post_utils.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_posts_viewer_layout.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_progress_notifier.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_scrub_time_overlay.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_search_progress_column.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post_widget.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:bimobondapp/core/constants/traffic_source.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/directional_back_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PostDetailScreen extends StatefulWidget {
  final PostEntity post;
  final bool openCommentsOnLoad;
  final String? highlightCommentId;
  final String trafficSource;

  const PostDetailScreen({
    super.key,
    required this.post,
    this.openCommentsOnLoad = false,
    this.highlightCommentId,
    this.trafficSource = TrafficSource.other,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late PostEntity _post;
  final FeedVideoProgressNotifier _videoProgress = FeedVideoProgressNotifier();

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  @override
  void dispose() {
    _videoProgress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomChrome = MediaQuery.viewPaddingOf(context).bottom;
    final showProgressBar = feedPostHasVideo(_post);
    final showSearchRow = feedPostShowsProfileSearchChrome(_post);
    final progressBottom = FeedVideoPostsViewerLayout.progressColumnBottom(
      bottomChrome,
    );

    return BlocListener<PostsBloc, PostsState>(
      listener: (context, state) {
        if (state is UpdatePostSuccess && state.post.id == _post.id) {
          setState(() => _post = state.post);
        } else if (state is DeletePostSuccess && state.postId == _post.id) {
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: CustomAppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const DirectionalBackIcon(color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: FeedVideoProgressScope(
          notifier: _videoProgress,
          child: Stack(
            fit: StackFit.expand,
            children: [
              VideoPostWidget(
                key: ValueKey('${_post.id}_${_post.description}'),
                post: _post,
                isActive: true,
                // Never the home feed — gate stays blocked under overlays like
                // sound detail, which would leave this screen silent/frozen.
                respectFeedPlaybackGate: false,
                feedMediaFit: BoxFit.cover,
                bottomPadding:
                    FeedVideoPostsViewerLayout.videoContentBottomPadding(
                      bottomChromeStackHeight: bottomChrome,
                      post: _post,
                      showProgressBar: showProgressBar,
                      showSearchRow: showSearchRow,
                    ),
                openCommentsOnLoad: widget.openCommentsOnLoad,
                highlightCommentId: widget.highlightCommentId,
                trafficSource: widget.trafficSource,
              ),
              const Positioned.fill(child: FeedVideoScrubTimeOverlay()),
              if (showProgressBar || showSearchRow)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: progressBottom,
                  child: Material(
                    type: MaterialType.transparency,
                    child: FeedVideoSearchProgressColumn(
                      post: _post,
                      transparentBackground: true,
                      showProgressBar: showProgressBar,
                      showSearchRow: showSearchRow,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
