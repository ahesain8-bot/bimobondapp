import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post_widget.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/directional_back_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PostDetailScreen extends StatefulWidget {
  final PostEntity post;
  final bool openCommentsOnLoad;
  final String? highlightCommentId;

  const PostDetailScreen({
    super.key,
    required this.post,
    this.openCommentsOnLoad = false,
    this.highlightCommentId,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late PostEntity _post;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  @override
  Widget build(BuildContext context) {
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
        body: VideoPostWidget(
          key: ValueKey('${_post.id}_${_post.description}'),
          post: _post,
          isActive: true,
          // Never the home feed — gate stays blocked under overlays like sound
          // detail, which would leave this screen silent/frozen.
          respectFeedPlaybackGate: false,
          bottomPadding: MediaQuery.of(context).padding.bottom + 16,
          openCommentsOnLoad: widget.openCommentsOnLoad,
          highlightCommentId: widget.highlightCommentId,
        ),
      ),
    );
  }
}
