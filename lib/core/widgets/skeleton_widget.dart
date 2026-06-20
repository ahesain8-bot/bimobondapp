import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/core/constants/notifications_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/dotted_divider.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_surface.dart';
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
                  SkeletonWidget.circular(size: 45, onBlackBackground: true),
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
  const AuctionListSkeleton({
    super.key,
    this.itemCount = 5,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSizes.p16),
  });

  final int itemCount;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        children: [
          for (var i = 0; i < itemCount; i++) ...[
            if (i > 0) const SizedBox(height: AppSizes.p16),
            const AuctionCardSkeleton(),
          ],
        ],
      ),
    );
  }
}

/// Vertical list of promoted post card placeholders.
class PromotedPostsListSkeleton extends StatelessWidget {
  const PromotedPostsListSkeleton({
    super.key,
    this.itemCount = 4,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 24),
  });

  final int itemCount;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (_, _) => const PromotedPostCardSkeleton(),
    );
  }
}

/// Shimmer placeholder matching a promoted post list card.
class PromotedPostCardSkeleton extends StatelessWidget {
  const PromotedPostCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.65),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AspectRatio(
              aspectRatio: 16 / 9,
              child: SkeletonWidget(borderRadius: 0),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SkeletonWidget(
                          height: 16,
                          borderRadius: AppSizes.radiusSm,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SkeletonWidget(
                        height: 28,
                        width: 64,
                        borderRadius: 999,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: SkeletonWidget(
                            height: 72,
                            borderRadius: AppSizes.radiusSm,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  const SkeletonWidget(height: 12, width: 120),
                  const SizedBox(height: 8),
                  SkeletonWidget(
                    height: 8,
                    borderRadius: AppSizes.radiusSm,
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

class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 15,
      itemBuilder: (context, index) => ListTile(
        leading: const SkeletonWidget.circular(size: 40),
        title: const SkeletonWidget(height: 16, width: 150),
        subtitle: const SkeletonWidget(height: 12, width: 100),
        trailing: const SkeletonWidget(height: 32, width: 80),
      ),
    );
  }
}

/// Notification-style placeholders for the user comments screen.
class UserCommentsListSkeleton extends StatelessWidget {
  const UserCommentsListSkeleton({super.key, this.itemCount = 15});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount: itemCount,
      separatorBuilder: (context, _) => Divider(
        height: 1,
        color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
      ),
      itemBuilder: (context, _) => const _UserCommentTileSkeleton(),
    );
  }
}

class _UserCommentTileSkeleton extends StatelessWidget {
  const _UserCommentTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p16,
        vertical: AppSizes.p12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonWidget.circular(size: 44),
          const SizedBox(width: AppSizes.p12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: SkeletonWidget(height: 14, width: double.infinity),
                    ),
                    const SizedBox(width: AppSizes.p8),
                    SkeletonWidget(height: 12, width: 36, borderRadius: 6),
                  ],
                ),
                const SizedBox(height: 8),
                const SkeletonWidget(height: 16, width: double.infinity),
                const SizedBox(height: 6),
                SkeletonWidget(
                  height: 16,
                  width: MediaQuery.sizeOf(context).width * 0.55,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Notification-style placeholders for the user likes screen.
class UserLikesListSkeleton extends StatelessWidget {
  const UserLikesListSkeleton({super.key, this.itemCount = 15});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount: itemCount,
      separatorBuilder: (context, _) => Divider(
        height: 1,
        color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
      ),
      itemBuilder: (context, _) => const _UserLikeTileSkeleton(),
    );
  }
}

class _UserLikeTileSkeleton extends StatelessWidget {
  const _UserLikeTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p16,
        vertical: AppSizes.p12,
      ),
      child: Row(
        children: [
          const SkeletonWidget.circular(size: 44),
          const SizedBox(width: AppSizes.p12),
          Expanded(
            child: Row(
              children: [
                const Expanded(
                  child: SkeletonWidget(height: 14, width: double.infinity),
                ),
                const SizedBox(width: AppSizes.p8),
                SkeletonWidget(height: 12, width: 36, borderRadius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Notification-style placeholders for the user mentions screen.
class UserMentionsListSkeleton extends StatelessWidget {
  const UserMentionsListSkeleton({super.key, this.itemCount = 15});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount: itemCount,
      separatorBuilder: (context, _) => Divider(
        height: 1,
        color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
      ),
      itemBuilder: (context, _) => const _UserLikeTileSkeleton(),
    );
  }
}

/// Notification-style placeholders for the my followers screen.
class UserFollowersListSkeleton extends StatelessWidget {
  const UserFollowersListSkeleton({super.key, this.itemCount = 15});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount: itemCount,
      separatorBuilder: (context, _) => Divider(
        height: 1,
        color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
      ),
      itemBuilder: (context, _) => const _UserFollowerTileSkeleton(),
    );
  }
}

class _UserFollowerTileSkeleton extends StatelessWidget {
  const _UserFollowerTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p16,
        vertical: AppSizes.p12,
      ),
      child: Row(
        children: [
          const SkeletonWidget.circular(size: 44),
          const SizedBox(width: AppSizes.p12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonWidget(height: 14, width: double.infinity),
                const SizedBox(height: 6),
                SkeletonWidget(
                  height: 12,
                  width: MediaQuery.sizeOf(context).width * 0.28,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.p8),
          SkeletonWidget(
            height: 32,
            width: 88,
            borderRadius: AppSizes.radiusMd,
          ),
        ],
      ),
    );
  }
}

/// Horizontal card placeholders for recent mentions on the messages tab.
class MessagesMentionsStripSkeleton extends StatelessWidget {
  const MessagesMentionsStripSkeleton({super.key, this.cardCount = 3});

  final int cardCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            MessagesLayoutConstants.sectionHorizontalPadding,
            8,
            MessagesLayoutConstants.sectionHorizontalPadding,
            12,
          ),
          child: SkeletonWidget(
            height: 18,
            width: 160,
            borderRadius: MessagesLayoutConstants.inboxChipRadius,
          ),
        ),
        SizedBox(
          height: MessagesLayoutConstants.mentionsStripHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: cardCount,
            itemBuilder: (context, _) => Container(
              width: MessagesLayoutConstants.mentionCardWidth,
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(
                  MessagesLayoutConstants.mentionCardRadius,
                ),
                border: Border.all(
                  color: theme.dividerColor.withValues(
                    alpha: MessagesLayoutConstants.dividerAlpha,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const SkeletonWidget.circular(size: 42),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonWidget(height: 12, width: 72),
                        SizedBox(height: 6),
                        SkeletonWidget(height: 10, width: 110),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SkeletonWidget(
                    height: MessagesLayoutConstants.mentionPreviewSize,
                    width: MessagesLayoutConstants.mentionPreviewSize,
                    borderRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Vertical list placeholders on the follow suggestions screen.
class FollowSuggestionsListSkeleton extends StatelessWidget {
  const FollowSuggestionsListSkeleton({
    super.key,
    this.itemCount = 15,
    this.scrollable = true,
  });

  final int itemCount;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: scrollable
          ? const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics())
          : const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: itemCount,
      separatorBuilder: (context, _) => Divider(
        height: 1,
        indent: 72,
        color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
      ),
      itemBuilder: (context, _) => const _FollowSuggestionTileSkeleton(),
    );
  }
}

class _FollowSuggestionTileSkeleton extends StatelessWidget {
  const _FollowSuggestionTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p16,
        vertical: AppSizes.p4,
      ),
      leading: const SkeletonWidget.circular(size: 48),
      title: const SkeletonWidget(height: 16, width: 140),
      subtitle: const Padding(
        padding: EdgeInsets.only(top: 6),
        child: SkeletonWidget(height: 12, width: 100),
      ),
      trailing: const SkeletonWidget(height: 34, width: 96, borderRadius: 12),
    );
  }
}

/// Horizontal card placeholders for people-you-may-know on the messages tab.
class MessagesSuggestionsStripSkeleton extends StatelessWidget {
  const MessagesSuggestionsStripSkeleton({super.key, this.cardCount = 4});

  final int cardCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            MessagesLayoutConstants.sectionHorizontalPadding,
            24,
            MessagesLayoutConstants.sectionHorizontalPadding,
            12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonWidget(
                height: 15,
                width: 160,
                borderRadius: MessagesLayoutConstants.inboxChipRadius,
              ),
              SkeletonWidget(
                height: 13,
                width: 52,
                borderRadius: MessagesLayoutConstants.inboxChipRadius,
              ),
            ],
          ),
        ),
        SizedBox(
          height: MessagesLayoutConstants.suggestionsStripHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: cardCount,
            itemBuilder: (context, _) => Container(
              width: MessagesLayoutConstants.suggestionCardWidth,
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              padding: const EdgeInsets.all(AppSizes.p16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(
                  MessagesLayoutConstants.suggestionCardRadius,
                ),
                border: Border.all(
                  color: theme.dividerColor.withValues(
                    alpha: MessagesLayoutConstants.dividerAlpha,
                  ),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SkeletonWidget.circular(
                    size: MessagesLayoutConstants.suggestionAvatarRadius * 2,
                  ),
                  const SizedBox(height: AppSizes.p12),
                  const SkeletonWidget(height: 13, width: 90),
                  const SizedBox(height: AppSizes.p4),
                  const SkeletonWidget(height: 10, width: 72),
                  const SizedBox(height: 14),
                  SkeletonWidget(
                    height:
                        MessagesLayoutConstants.suggestionFollowButtonHeight,
                    width: double.infinity,
                    borderRadius: 12,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
                    borderRadius:
                        MessagesLayoutConstants.conversationTileRadius,
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
    return const LiquidGlassSkeletonBox(height: 32, width: 88, borderRadius: 20);
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
          builder: (context, constraints) => LiquidGlassSkeletonBox(
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
          LiquidGlassSkeletonBox(height: 32, width: 32, borderRadius: 8),
          SizedBox(height: 10),
          LiquidGlassSkeletonBox(height: 10, width: 52),
          SizedBox(height: 6),
          LiquidGlassSkeletonBox(height: 10, width: 36),
        ],
      ),
    );
  }
}

/// A skeleton item mimicking [NotificationListTile]
class NotificationListTileSkeleton extends StatelessWidget {
  const NotificationListTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: NotificationsLayoutConstants.cardPadding,
        vertical: NotificationsLayoutConstants.itemVerticalPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Circular Avatar Shimmer
          const SkeletonWidget.circular(
            size: NotificationsLayoutConstants.avatarRadius * 2,
          ),
          const SizedBox(width: AppSizes.p12),
          // Content Shimmer Columns
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main notification text lines
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // First line representing user name + action phrase
                          const SkeletonWidget(
                            height: 14,
                            width: double.infinity,
                          ),
                          const SizedBox(height: 6),
                          // Second line representing action phrase continuation / detail context
                          SkeletonWidget(
                            height: 14,
                            width: MediaQuery.sizeOf(context).width * 0.45,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSizes.p8),
                    // Relative Time Shimmer
                    const SkeletonWidget(
                      height: 12,
                      width: 36,
                      borderRadius: 6,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Detailed Date Timestamp Shimmer
                const SkeletonWidget(
                  height: 12,
                  width: 80,
                  borderRadius: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A vertical list of [NotificationListTileSkeleton] items separated by [DottedDivider] widgets.
class NotificationsListSkeleton extends StatelessWidget {
  const NotificationsListSkeleton({
    super.key,
    this.itemCount = 15,
    this.physics,
  });

  final int itemCount;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.separated(
      physics: physics ??
          const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
      padding: const EdgeInsets.symmetric(vertical: AppSizes.p8),
      itemCount: itemCount,
      separatorBuilder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: NotificationsLayoutConstants.cardPadding,
        ),
        child: DottedDivider(
          color: NotificationsLayoutConstants.dottedDividerColor(theme),
        ),
      ),
      itemBuilder: (context, _) => const NotificationListTileSkeleton(),
    );
  }
}

