import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/utils/app_sizes.dart';
import '../../../../../core/utils/live_feed_fade.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/utils/app_text_styles.dart';
import '../../../../../core/widgets/gifter_level_badge.dart';
import '../../../domain/entities/live_chat_message.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_event.dart';
import '../../bloc/live_room/live_room_state.dart';

/// Activity feed anchored to the bottom start edge, the way TikTok anchors it
/// — which in Arabic means the right edge, with the avatar on the right, as in
/// the reference screenshots.
class LiveRoomChatFeed extends StatelessWidget {
  const LiveRoomChatFeed({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveRoomBloc, LiveRoomState>(
      buildWhen: (previous, current) =>
          current is LiveRoomReady &&
          (previous is! LiveRoomReady ||
              previous.session.messages != current.session.messages),
      builder: (context, state) {
        if (state is! LiveRoomReady) {
          return const SizedBox.shrink();
        }

        final messages = state.session.messages;
        LiveChatMessage? pinned;
        for (final message in messages) {
          if (message.isPinned) {
            pinned = message;
            break;
          }
        }
        final size = MediaQuery.sizeOf(context);
        final maxWidth = size.width * AppSizes.roomChatMaxWidthFactor;
        return LayoutBuilder(
          builder: (context, constraints) {
            // Honour whatever slot the room actually gave us. The screen
            // fraction is only a cap now: hard-coding it overflowed the column
            // whenever the keyboard or the effects panel took the space away.
            final cap = size.height * AppSizes.roomChatMaxHeightFactor;
            final listMaxHeight = constraints.hasBoundedHeight
                ? math.min(constraints.maxHeight, cap)
                : cap;

            return Align(
              alignment: AlignmentDirectional.bottomStart,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (pinned != null) ...[
                      _PinnedCommentBar(message: pinned),
                      const SizedBox(height: AppSpacing.roomChatGap),
                    ],
                    // Laid out bottom-up so the newest line sits just above
                    // the composer, and scrollable so the backlog above it is
                    // reachable rather than clipped away for good.
                    Flexible(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: listMaxHeight),
                        child: ShaderMask(
                          shaderCallback: (rect) => liveFeedFadeShader(
                            rect,
                            scrollableHeight: listMaxHeight,
                          ),
                          blendMode: BlendMode.dstIn,
                          child: ListView.separated(
                            reverse: true,
                            shrinkWrap: true,
                            physics: const ClampingScrollPhysics(),
                            padding: EdgeInsets.zero,
                            itemCount: messages.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.roomChatGap),
                            itemBuilder: (context, index) {
                              final message =
                                  messages[messages.length - 1 - index];
                              return _ChatMessageTile(message: message);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ChatMessageTile extends StatelessWidget {
  const _ChatMessageTile({required this.message});

  final LiveChatMessage message;

  Future<void> _showModeration(BuildContext context) async {
    final action = await showModalBottomSheet<LiveRoomModerationAction>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1C),
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    message.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                    color: Colors.white70,
                  ),
                  title: Text(
                    message.isPinned ? 'إلغاء تثبيت التعليق' : 'تثبيت التعليق',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    message.isPinned
                        ? LiveRoomModerationAction.unpin
                        : LiveRoomModerationAction.pin,
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Colors.white70,
                  ),
                  title: const Text(
                    'حذف التعليق',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    LiveRoomModerationAction.deleteComment,
                  ),
                ),
                if (message.userId != null && message.userId!.isNotEmpty) ...[
                  ListTile(
                    leading: const Icon(
                      Icons.volume_off_outlined,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      'كتم دردشة المشاهد',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () => Navigator.pop(
                      sheetContext,
                      LiveRoomModerationAction.muteChat,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.volume_up_outlined,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      'إلغاء كتم الدردشة',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () => Navigator.pop(
                      sheetContext,
                      LiveRoomModerationAction.unmuteChat,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.block, color: Colors.redAccent),
                    title: const Text(
                      'حظر المشاهد من البث',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    onTap: () => Navigator.pop(
                      sheetContext,
                      LiveRoomModerationAction.banViewer,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (action == null || !context.mounted) return;
    context.read<LiveRoomBloc>().add(
      LiveRoomModerationRequested(
        action: action,
        commentId: message.id,
        userId: message.userId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A viewer comment stacks a dim handle over the bright line they wrote,
    // behind their picture. Joins and gifts stay one line with the round badge.
    final isComment =
        message.body != null &&
        message.username != null &&
        message.username!.isNotEmpty;

    return GestureDetector(
      onLongPress: () => _showModeration(context),
      child: Container(
        // No surface and no border, during a battle too. TikTok carries its
        // comments on the shadow baked into the text styles; the opaque pill
        // this used to draw over PK is the thing that read as "not TikTok".
        padding: const EdgeInsetsDirectional.fromSTEB(5, 4, 9, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.isJoinEvent) ...[
              const _JoinBadge(),
              const SizedBox(width: AppSpacing.xs),
            ] else if (isComment) ...[
              _CommenterAvatar(url: message.avatarUrl),
              const SizedBox(width: AppSpacing.xs),
            ] else if ((message.gifterLevel ?? 0) > 0) ...[
              GifterLevelBadge(level: message.gifterLevel!, compact: true),
              const SizedBox(width: AppSpacing.xs),
            ] else if (message.showBadge) ...[
              const _SystemBadge(),
              const SizedBox(width: AppSpacing.xs),
            ],
            Expanded(
              child: isComment
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if ((message.gifterLevel ?? 0) > 0) ...[
                              GifterLevelBadge(
                                level: message.gifterLevel!,
                                compact: true,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Flexible(
                              child: Text(
                                message.isPinned
                                    ? '📌 ${message.username}'
                                    : message.username!,
                                style: AppTextStyles.roomChatAuthor,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Text(message.body!, style: AppTextStyles.roomChatBody),
                      ],
                    )
                  : _MessageText(message: message),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round picture beside a comment. Falls back to a neutral disc when the
/// server sends no avatar, so the run keeps its left edge either way.
class _CommenterAvatar extends StatelessWidget {
  const _CommenterAvatar({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.roomChatAvatar,
      height: AppSizes.roomChatAvatar,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        image: url != null && url!.isNotEmpty
            ? DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover)
            : null,
      ),
      child: url != null && url!.isNotEmpty
          ? null
          : const Icon(Icons.person, size: 13, color: Colors.white70),
    );
  }
}

/// Renders a viewer comment as a dimmed name followed by what they said, and
/// anything else (joins, gifts) as the single sentence the producer built.
class _MessageText extends StatelessWidget {
  const _MessageText({
    required this.message,
    this.maxLines,
    this.showPinMarker = true,
  });

  final LiveChatMessage message;
  final int? maxLines;

  /// The pinned bar draws its own pin icon, so it suppresses the inline one.
  final bool showPinMarker;

  @override
  Widget build(BuildContext context) {
    final name = message.username;
    final body = message.body;
    final pin = message.isPinned && showPinMarker ? '📌 ' : '';

    if (name == null || name.isEmpty || body == null) {
      return Text(
        '$pin${message.text}',
        style: AppTextStyles.roomChat,
        textAlign: TextAlign.start,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
      );
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$pin$name  ', style: AppTextStyles.roomChatAuthor),
          TextSpan(text: body, style: AppTextStyles.roomChat),
        ],
      ),
      textAlign: TextAlign.start,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}

/// Arrival marker: the wave TikTok puts in front of a "joined" line.
class _JoinBadge extends StatelessWidget {
  const _JoinBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.roomChatBadge,
      height: AppSizes.roomChatBadge,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: const Text('👋', style: TextStyle(fontSize: 9)),
    );
  }
}

class _SystemBadge extends StatelessWidget {
  const _SystemBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.roomChatBadge,
      height: AppSizes.roomChatBadge,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: const Icon(Icons.music_note, size: 10, color: Colors.white),
    );
  }
}

class _PinnedCommentBar extends StatelessWidget {
  const _PinnedCommentBar({required this.message});

  final LiveChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          const Icon(Icons.push_pin, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          if ((message.gifterLevel ?? 0) > 0) ...[
            GifterLevelBadge(level: message.gifterLevel!, compact: true),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: _MessageText(
              message: message,
              maxLines: 2,
              showPinMarker: false,
            ),
          ),
        ],
      ),
    );
  }
}
