import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonWidget extends StatelessWidget {
  final double? height;
  final double? width;
  final double borderRadius;
  final BoxShape shape;

  /// Subtle shimmer on a black feed background (home video loading).
  final bool onBlackBackground;

  const SkeletonWidget({
    super.key,
    this.height,
    this.width,
    this.borderRadius = 8,
    this.shape = BoxShape.rectangle,
    this.onBlackBackground = false,
  });

  const SkeletonWidget.circular({
    super.key,
    required double size,
    this.onBlackBackground = false,
  }) : height = size,
       width = size,
       borderRadius = size / 2,
       shape = BoxShape.circle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final baseColor = onBlackBackground
        ? const Color(0xFF1A1A1A)
        : isDark
        ? Colors.grey[800]!
        : Colors.grey[300]!;
    final highlightColor = onBlackBackground
        ? const Color(0xFF2E2E2E)
        : isDark
        ? Colors.grey[700]!
        : Colors.grey[100]!;
    final fillColor = onBlackBackground
        ? const Color(0xFF141414)
        : Colors.white;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: fillColor,
          shape: shape,
          borderRadius: shape == BoxShape.rectangle
              ? BorderRadius.circular(borderRadius)
              : null,
        ),
      ),
    );
  }
}

class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key});

  static const Color _background = Colors.black;

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: _background,
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            SkeletonWidget(
              height: double.infinity,
              width: double.infinity,
              borderRadius: 0,
              onBlackBackground: true,
            ),
            Positioned(
              left: 16,
              bottom: 110,
              right: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonWidget(
                    height: 20,
                    width: 120,
                    onBlackBackground: true,
                  ),
                  SizedBox(height: 8),
                  SkeletonWidget(
                    height: 14,
                    width: 200,
                    onBlackBackground: true,
                  ),
                  SizedBox(height: 4),
                  SkeletonWidget(
                    height: 14,
                    width: 150,
                    onBlackBackground: true,
                  ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              bottom: 120,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: SkeletonWidget.circular(
                      size: 45,
                      onBlackBackground: true,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: SkeletonWidget.circular(
                      size: 45,
                      onBlackBackground: true,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: SkeletonWidget.circular(
                      size: 45,
                      onBlackBackground: true,
                    ),
                  ),
                  SkeletonWidget.circular(
                    size: 45,
                    onBlackBackground: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          const SkeletonWidget.circular(size: 100),
          const SizedBox(height: 16),
          const SkeletonWidget(height: 20, width: 150),
          const SizedBox(height: 8),
          const SkeletonWidget(height: 14, width: 250),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (index) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: SkeletonWidget(height: 40, width: 60),
              ),
            ),
          ),
          const SizedBox(height: 32),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 1,
              mainAxisSpacing: 1,
              childAspectRatio: 0.75,
            ),
            itemCount: 12,
            itemBuilder: (context, index) =>
                const SkeletonWidget(borderRadius: 0),
          ),
        ],
      ),
    );
  }
}

/// Shimmer placeholder matching an auction list card.
class AuctionCardSkeleton extends StatelessWidget {
  const AuctionCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AspectRatio(
            aspectRatio: 16 / 10,
            child: SkeletonWidget(borderRadius: 0),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.p16,
              AppSizes.p12,
              AppSizes.p16,
              AppSizes.p16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const SkeletonWidget(height: 16, width: 140),
                    const SizedBox(height: AppSizes.p6),
                    SkeletonWidget(
                      height: 12,
                      width: MediaQuery.sizeOf(context).width * 0.35,
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.p12),
                // Match the new segmented stats container block
                const SkeletonWidget(
                  height: 48,
                  borderRadius: AppSizes.radiusMd,
                ),
                const SizedBox(height: AppSizes.p12),
                const SkeletonWidget(
                  height: 46,
                  borderRadius: AppSizes.radiusMd,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


/// Horizontal category chips placeholder for [AuctionsScreen].
class AuctionsCategoryStripSkeleton extends StatelessWidget {
  const AuctionsCategoryStripSkeleton({super.key, this.chipCount = 6});

  final int chipCount;

  static const double _stripHeight = 44;
  static const List<double> _chipWidths = [72, 88, 96, 80, 104, 76];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _stripHeight,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: chipCount,
        separatorBuilder: (_, _) => const SizedBox(width: AppSizes.p8),
        itemBuilder: (context, index) {
          final width = _chipWidths[index % _chipWidths.length];
          return SkeletonWidget(
            height: _stripHeight,
            width: width,
            borderRadius: _stripHeight / 2,
          );
        },
      ),
    );
  }
}

/// Vertical list of [AuctionCardSkeleton] items for category filtering.
class AuctionListSkeleton extends StatelessWidget {
  const AuctionListSkeleton({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < itemCount; i++) ...[
          if (i > 0) const SizedBox(height: AppSizes.p16),
          const AuctionCardSkeleton(),
        ],
      ],
    );
  }
}

class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (context, index) => ListTile(
        leading: const SkeletonWidget.circular(size: 40),
        title: const SkeletonWidget(height: 16, width: 150),
        subtitle: const SkeletonWidget(height: 12, width: 100),
        trailing: const SkeletonWidget(height: 32, width: 80),
      ),
    );
  }
}

/// Inbox chat row placeholders on the messages (الدردشة) tab.
class MessagesChatListSkeleton extends StatelessWidget {
  const MessagesChatListSkeleton({
    super.key,
    this.itemCount = MessagesLayoutConstants.chatListSkeletonItemCount,
  });

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.p12),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.p8),
      itemBuilder: (_, _) => const _MessagesChatTileSkeleton(),
    );
  }
}

class _MessagesChatTileSkeleton extends StatelessWidget {
  const _MessagesChatTileSkeleton();

  @override
  Widget build(BuildContext context) {
    final avatarSize = MessagesLayoutConstants.conversationAvatarRadius * 2;

    return SizedBox(
      height: MessagesLayoutConstants.chatListSkeletonTileHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.p8),
        child: Row(
          children: [
            SkeletonWidget.circular(size: avatarSize),
            const SizedBox(width: AppSizes.p12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: SkeletonWidget(height: 16, width: 120),
                      ),
                      const SizedBox(width: AppSizes.p8),
                      const SkeletonWidget(height: 12, width: 36),
                    ],
                  ),
                  const SizedBox(height: AppSizes.p8),
                  SkeletonWidget(
                    height: 14,
                    width: avatarSize + 80,
                    borderRadius: MessagesLayoutConstants.conversationTileRadius,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Message bubble placeholders on the 1:1 chat screen.
class ChatMessageListSkeleton extends StatelessWidget {
  const ChatMessageListSkeleton({
    super.key,
    this.itemCount = ChatLayoutConstants.chatMessageSkeletonCount,
  });

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        ChatLayoutConstants.messageListHorizontalPadding,
        ChatLayoutConstants.messageListTopPadding,
        ChatLayoutConstants.messageListHorizontalPadding,
        ChatLayoutConstants.messageListBottomPadding,
      ),
      itemCount: itemCount,
      separatorBuilder: (_, index) => SizedBox(
        height: index == 0
            ? ChatLayoutConstants.messageGroupTopSpacing
            : ChatLayoutConstants.messageItemSpacing,
      ),
      itemBuilder: (context, index) {
        final isMe = index.isOdd;
        final width = index.isEven
            ? ChatLayoutConstants.chatMessageSkeletonLongWidth
            : ChatLayoutConstants.chatMessageSkeletonShortWidth;

        return Align(
          alignment: isMe
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: SkeletonWidget(
            height: ChatLayoutConstants.chatMessageSkeletonBubbleHeight,
            width: width,
            borderRadius: ChatLayoutConstants.bubbleRadius,
          ),
        );
      },
    );
  }
}

/// Shimmer placeholders for the live gift sheet catalog grid.
class GiftSheetSkeleton extends StatelessWidget {
  const GiftSheetSkeleton({super.key, this.itemCount = 8});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    const crossCount = 4;
    const horizontalPadding = 20.0;
    const spacing = 16.0;
    const aspectRatio = 0.62;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final itemWidth =
        (screenWidth - horizontalPadding * 2 - spacing * (crossCount - 1)) /
        crossCount;
    final itemHeight = itemWidth / aspectRatio;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        spacing: spacing,
        runSpacing: spacing,
        children: List.generate(
          itemCount,
          (_) => SizedBox(
            width: itemWidth,
            height: itemHeight,
            child: const _GiftCardSkeleton(),
          ),
        ),
      ),
    );
  }
}

/// Balance chip placeholder on the gift sheet header.
class GiftBalanceChipSkeleton extends StatelessWidget {
  const GiftBalanceChipSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _GiftSheetShimmerBox(height: 32, width: 88, borderRadius: 20);
  }
}

/// Send / buy button placeholder on the gift sheet footer.
class GiftSheetFooterSkeleton extends StatelessWidget {
  const GiftSheetFooterSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => _GiftSheetShimmerBox(
            height: 50,
            width: constraints.maxWidth,
            borderRadius: 25,
          ),
        ),
      ),
    );
  }
}

class _GiftCardSkeleton extends StatelessWidget {
  const _GiftCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _GiftSheetShimmerBox(height: 32, width: 32, borderRadius: 8),
          SizedBox(height: 10),
          _GiftSheetShimmerBox(height: 10, width: 52),
          SizedBox(height: 6),
          _GiftSheetShimmerBox(height: 10, width: 36),
        ],
      ),
    );
  }
}

class _GiftSheetShimmerBox extends StatelessWidget {
  const _GiftSheetShimmerBox({
    required this.height,
    required this.width,
    this.borderRadius = 8,
  });

  final double height;
  final double width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: 0.08),
      highlightColor: Colors.white.withValues(alpha: 0.2),
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
