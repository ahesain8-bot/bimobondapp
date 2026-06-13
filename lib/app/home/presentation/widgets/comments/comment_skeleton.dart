import 'package:bimobondapp/app/home/presentation/widgets/comments/comment_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_surface.dart';
import 'package:flutter/material.dart';

class CommentSkeletonRow extends StatelessWidget {
  const CommentSkeletonRow({this.isReply = false, super.key});

  static const _tone = LiquidGlassSkeletonTone.light;

  final bool isReply;

  @override
  Widget build(BuildContext context) {
    final avatarSize = isReply
        ? CommentLayout.replyAvatarRadius * 2
        : CommentLayout.avatarSize;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LiquidGlassSkeletonBox.circular(size: avatarSize, tone: _tone),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LiquidGlassSkeletonBox(
                height: 14,
                width: isReply ? 110 : 140,
                tone: _tone,
              ),
              const SizedBox(height: 8),
              const LiquidGlassSkeletonBox(
                height: 15,
                width: double.infinity,
                tone: _tone,
              ),
              const SizedBox(height: 4),
              LiquidGlassSkeletonBox(
                height: 15,
                width: isReply ? 160 : 220,
                tone: _tone,
              ),
              const SizedBox(height: 12),
              LiquidGlassSkeletonBox(
                height: 14,
                width: isReply ? 72 : 100,
                tone: _tone,
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
