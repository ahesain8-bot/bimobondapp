import 'package:bimobondapp/app/home/presentation/widgets/comments/comment_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class _CommentSkeletonBox extends StatelessWidget {
  const _CommentSkeletonBox({
    this.height,
    this.width,
    this.borderRadius = 8,
  }) : shape = BoxShape.rectangle;

  const _CommentSkeletonBox.circular({required double size})
    : height = size,
      width = size,
      borderRadius = size / 2,
      shape = BoxShape.circle;

  final double? height;
  final double? width;
  final double borderRadius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06);
    final highlight =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: base,
          shape: shape,
          borderRadius: shape == BoxShape.circle
              ? null
              : BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class CommentSkeletonRow extends StatelessWidget {
  const CommentSkeletonRow({this.isReply = false, super.key});

  final bool isReply;

  @override
  Widget build(BuildContext context) {
    final avatarSize = isReply
        ? CommentLayout.replyAvatarRadius * 2
        : CommentLayout.avatarSize;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentSkeletonBox.circular(size: avatarSize),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CommentSkeletonBox(
                height: 13,
                width: isReply ? 90 : 110,
                borderRadius: 4,
              ),
              const SizedBox(height: 8),
              const _CommentSkeletonBox(
                height: 14,
                width: double.infinity,
                borderRadius: 4,
              ),
              const SizedBox(height: 4),
              _CommentSkeletonBox(
                height: 14,
                width: isReply ? 140 : 200,
                borderRadius: 4,
              ),
              const SizedBox(height: 10),
              _CommentSkeletonBox(
                height: 12,
                width: isReply ? 64 : 88,
                borderRadius: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CommentRepliesSkeleton extends StatelessWidget {
  const CommentRepliesSkeleton({this.itemCount = 2, super.key});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: CommentLayout.threadIndent,
      ),
      child: Column(
        children: List.generate(
          itemCount,
          (index) => Padding(
            padding: EdgeInsets.only(
              top: index == 0 ? AppSizes.p12 : AppSizes.p16,
            ),
            child: const CommentSkeletonRow(isReply: true),
          ),
        ),
      ),
    );
  }
}
