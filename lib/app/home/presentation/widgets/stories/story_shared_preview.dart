import 'package:bimobondapp/app/home/presentation/utils/chat_shared_post_cache.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/post_cover_card.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_post_by_id_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart' as posts_di;
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/core/navigation/post_navigation.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Story/post thumbnail — same cover as profile grid [PostCoverCard].
class StorySharedPreview extends StatelessWidget {
  const StorySharedPreview({
    this.post,
    this.sharedStoryUi,
    this.compact = false,
    super.key,
  });

  final PostEntity? post;
  final Map<String, dynamic>? sharedStoryUi;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 56.0 : double.infinity;
    final cover = post != null
        ? PostCoverCard(post: post!)
        : PostCoverCard.fromSharedStoryUi(
            sharedStoryUi: sharedStoryUi ?? const {},
          );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(
        ProfileLayoutConstants.gridItemRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        child: AspectRatio(
          aspectRatio: ProfileLayoutConstants.gridAspectRatio,
          child: cover,
        ),
      ),
    );
  }
}

/// Story/post attachment on a chat message — loads post by [sharedPostId].
class ChatStoryReplyPreview extends StatefulWidget {
  const ChatStoryReplyPreview({
    required this.sharedPostId,
    this.sharedStory,
    required this.isMe,
    super.key,
  });

  final String sharedPostId;
  final Map<String, dynamic>? sharedStory;
  final bool isMe;

  @override
  State<ChatStoryReplyPreview> createState() => _ChatStoryReplyPreviewState();
}

class _ChatStoryReplyPreviewState extends State<ChatStoryReplyPreview> {
  PostEntity? _post;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  @override
  void didUpdateWidget(ChatStoryReplyPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sharedPostId != widget.sharedPostId) {
      _loadPost();
    }
  }

  Future<void> _loadPost() async {
    final id = widget.sharedPostId.trim();
    if (id.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    final cached = ChatSharedPostCache.get(id);
    if (cached != null) {
      setState(() {
        _post = cached;
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    final result = await posts_di.sl<GetPostByIdUseCase>()(id);
    if (!mounted) return;

    result.fold(
      (_) => setState(() => _loading = false),
      (post) {
        ChatSharedPostCache.put(post);
        setState(() {
          _post = post;
          _loading = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isStory = _post?.isStory == true ||
        widget.sharedStory?['isStory'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.p6),
      padding: const EdgeInsets.all(AppSizes.p6),
      decoration: BoxDecoration(
        color: widget.isMe
            ? Colors.white.withValues(alpha: 0.12)
            : theme.dividerColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(
          ProfileLayoutConstants.gridItemRadius,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loading)
            const SizedBox(
              width: 56,
              child: AspectRatio(
                aspectRatio: ProfileLayoutConstants.gridAspectRatio,
                child: SkeletonWidget(borderRadius: AppSizes.radiusSm),
              ),
            )
          else
            GestureDetector(
              onTap: _post != null ? () => openStoryOrPost(context, _post!) : null,
              child: StorySharedPreview(
                post: _post,
                sharedStoryUi: _post == null ? widget.sharedStory : null,
                compact: true,
              ),
            ),
          const SizedBox(width: AppSizes.p10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.p4),
              child: Text(
                isStory ? l10n.storyMessageOnStory : l10n.storyMessageOnPost,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: widget.isMe
                      ? Colors.white.withValues(alpha: 0.9)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.75),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
