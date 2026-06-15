import 'dart:ui';

import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/gift_comment_l10n.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/live_comment_bubble.dart';

class LivePostCommentsArea extends StatelessWidget {
  const LivePostCommentsArea({
    required this.isRtl,
    required this.comments,
    required this.scrollController,
  });

  final bool isRtl;
  final List<CommentEntity> comments;
  final ScrollController scrollController;

  String _displayName(CommentEntity comment) {
    return comment.user.fullName?.trim().isNotEmpty == true
        ? comment.user.fullName!.trim()
        : (comment.user.username ?? 'User');
  }

  String _commentBody(AppLocalizations l10n, CommentEntity comment) {
    if (comment.isGift) {
      return localizedGiftCommentText(l10n, comment);
    }
    return comment.content;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SizedBox(
      height: LiveDetailsLayoutConstants.chatAreaHeight,
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [0.0, 0.1, 0.9, 1.0],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: ListView.builder(
          controller: scrollController,
          reverse: true,
          physics: const BouncingScrollPhysics(),
          padding: LiveDetailsLayoutConstants.screenHorizontalPadding,
          itemCount: comments.length,
          itemBuilder: (context, index) {
            final comment = comments[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.p8),
              child: Align(
                alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
                child: LiveCommentBubble(
                  isRtl: isRtl,
                  displayName: _displayName(comment),
                  avatarUrl: comment.user.avatarUrl,
                  body: _commentBody(l10n, comment),
                  isGift: comment.isGift,
                  theme: theme,
                  onProfileTap: comment.user.id.isNotEmpty
                      ? () => openUserStoryOrProfile(
                            context,
                            userId: comment.user.id,
                            username: comment.user.username,
                            fullName: comment.user.fullName,
                            avatarUrl: comment.user.avatarUrl,
                          )
                      : null,
                  userId: comment.user.id,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
