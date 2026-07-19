import 'package:bimobondapp/app/home/presentation/utils/chat_attachment_payload.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/custom_video_player.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatLocationMessageWidget extends StatelessWidget {
  const ChatLocationMessageWidget({
    required this.payload,
    required this.isMe,
    super.key,
  });

  final ChatLocationPayload payload;
  final bool isMe;

  Future<void> _openMaps() async {
    final uri = Uri.parse(payload.mapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    final onColor = isMe ? chatTheme.onSentBubble : chatTheme.onReceivedBubble;
    final muted = isMe
        ? chatTheme.onSentBubbleMuted
        : chatTheme.onReceivedBubbleMuted;
    final accent = theme.colorScheme.primary;

    return InkWell(
      onTap: _openMaps,
      borderRadius: BorderRadius.circular(ChatLayoutConstants.bubbleRadius),
      child: SizedBox(
        width: ChatLayoutConstants.locationMessageWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 88,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: isMe ? 0.35 : 0.18),
                    accent.withValues(alpha: isMe ? 0.12 : 0.06),
                  ],
                ),
              ),
              child: Icon(
                LucideIcons.mapPin,
                color: isMe ? onColor : accent,
                size: 36,
              ),
            ),
            const SizedBox(height: AppSizes.p10),
            Text(
              AppLocalizations.of(context)!.chatMessageLocation,
              style: theme.textTheme.labelSmall?.copyWith(
                color: muted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              payload.displayLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: onColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (payload.address != null &&
                payload.address!.trim().isNotEmpty &&
                payload.address!.trim() != payload.displayLabel) ...[
              const SizedBox(height: 2),
              Text(
                payload.address!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ChatFileMessageWidget extends StatelessWidget {
  const ChatFileMessageWidget({
    required this.fileName,
    required this.fileUrl,
    required this.isMe,
    this.sizeLabel,
    super.key,
  });

  final String fileName;
  final String? fileUrl;
  final bool isMe;
  final String? sizeLabel;

  Future<void> _openFile() async {
    final url = fileUrl?.trim();
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    final color = isMe ? chatTheme.onSentBubble : chatTheme.onReceivedBubble;
    final muted = isMe
        ? chatTheme.onSentBubbleMuted
        : chatTheme.onReceivedBubbleMuted;
    final canOpen = fileUrl != null && fileUrl!.trim().isNotEmpty;
    final size = sizeLabel?.trim();

    return InkWell(
      onTap: canOpen ? _openFile : null,
      borderRadius: BorderRadius.circular(ChatLayoutConstants.bubbleRadius),
      child: SizedBox(
        width: ChatLayoutConstants.fileMessageWidth,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (isMe ? Colors.white : theme.colorScheme.primary)
                    .withValues(alpha: isMe ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(LucideIcons.fileText, color: color, size: 22),
            ),
            const SizedBox(width: AppSizes.p10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (size != null && size.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      size,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ],
              ),
            ),
            Icon(LucideIcons.download, color: muted, size: 18),
          ],
        ),
      ),
    );
  }
}

class ChatContactMessageWidget extends StatelessWidget {
  const ChatContactMessageWidget({
    required this.payload,
    required this.isMe,
    super.key,
  });

  final ChatContactPayload payload;
  final bool isMe;

  Future<void> _onTap(BuildContext context) async {
    if (payload.isAppUser) {
      openUserActiveStoriesOrProfile(
        context,
        userId: payload.userId!,
        username: payload.name,
        fullName: payload.name,
        avatarUrl: payload.avatarUrl,
      );
      return;
    }
    if (!payload.hasPhone) return;
    final digits = payload.phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri(scheme: 'tel', path: digits);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    final color = isMe ? chatTheme.onSentBubble : chatTheme.onReceivedBubble;
    final muted = isMe
        ? chatTheme.onSentBubbleMuted
        : chatTheme.onReceivedBubbleMuted;
    final subtitle = payload.hasPhone ? payload.phone : (payload.email ?? '');

    return InkWell(
      onTap: () => _onTap(context),
      borderRadius: BorderRadius.circular(ChatLayoutConstants.bubbleRadius),
      child: SizedBox(
        width: ChatLayoutConstants.contactMessageWidth,
        child: Row(
          children: [
            if (payload.isAppUser)
              StoryProfileAvatar(
                userId: payload.userId,
                imageUrl: payload.avatarUrl,
                fallbackText: payload.name,
                radius: 22,
                username: payload.name,
                fullName: payload.name,
              )
            else
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    (isMe ? Colors.white : theme.colorScheme.primary)
                        .withValues(alpha: 0.2),
                child: Icon(LucideIcons.user, color: color, size: 22),
              ),
            const SizedBox(width: AppSizes.p10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.chatMessageContact,
                    style: theme.textTheme.labelSmall?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    payload.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatGiftMessageWidget extends StatelessWidget {
  const ChatGiftMessageWidget({
    required this.isMe,
    this.giftName,
    this.thumbnailUrl,
    this.quantity = 1,
    super.key,
  });

  final bool isMe;
  final String? giftName;
  final String? thumbnailUrl;
  final int quantity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    final color = isMe ? chatTheme.onSentBubble : chatTheme.onReceivedBubble;
    final muted = isMe
        ? chatTheme.onSentBubbleMuted
        : chatTheme.onReceivedBubbleMuted;
    final imageUrl = thumbnailUrl != null && thumbnailUrl!.trim().isNotEmpty
        ? MediaUtils.resolveAbsoluteUrl(thumbnailUrl!.trim())
        : null;
    final name = (giftName?.trim().isNotEmpty == true)
        ? giftName!.trim()
        : AppLocalizations.of(context)!.chatMoreGift;
    final isWebp =
        imageUrl != null &&
        imageUrl.toLowerCase().split('?').first.endsWith('.webp');

    return SizedBox(
      width: ChatLayoutConstants.giftMessageWidth,
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isWebp ? Colors.black : null,
              gradient: isWebp
                  ? null
                  : RadialGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.35),
                        theme.colorScheme.primary.withValues(alpha: 0.05),
                      ],
                    ),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl != null && imageUrl.isNotEmpty
                ? ColoredBox(
                    color: isWebp ? Colors.black : Colors.transparent,
                    child: SafeNetworkImage(
                      imageUrl: imageUrl,
                      width: 88,
                      height: 88,
                      fit: BoxFit.contain,
                    ),
                  )
                : Icon(
                    LucideIcons.gift,
                    size: 40,
                    color: isMe ? color : theme.colorScheme.primary,
                  ),
          ),
          const SizedBox(height: AppSizes.p8),
          Text(
            quantity > 1 ? '$name ×$quantity' : name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            AppLocalizations.of(context)!.chatGiftSentLabel,
            style: theme.textTheme.labelSmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

class ChatPollMessageWidget extends StatelessWidget {
  const ChatPollMessageWidget({
    required this.messageId,
    required this.poll,
    required this.isMe,
    required this.currentUserId,
    this.onVote,
    super.key,
  });

  final String messageId;
  final Map<String, dynamic> poll;
  final bool isMe;
  final String? currentUserId;
  final void Function(String messageId, int optionIndex)? onVote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    final onColor = isMe ? chatTheme.onSentBubble : chatTheme.onReceivedBubble;
    final muted = isMe
        ? chatTheme.onSentBubbleMuted
        : chatTheme.onReceivedBubbleMuted;
    final l10n = AppLocalizations.of(context)!;

    final question = poll['question']?.toString() ?? '';
    final options = (poll['options'] is List)
        ? (poll['options'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final counts = (poll['counts'] is List)
        ? (poll['counts'] as List)
              .map((e) => e is num ? e.toInt() : int.tryParse('$e') ?? 0)
              .toList()
        : List<int>.filled(options.length, 0);
    final totalVotes = poll['totalVotes'] is num
        ? (poll['totalVotes'] as num).toInt()
        : counts.fold<int>(0, (a, b) => a + b);
    final hasEnded = poll['hasEnded'] == true;
    final votes = poll['votes'];
    int? myVote;
    final uid = currentUserId?.trim() ?? '';
    if (uid.isNotEmpty && votes is List) {
      for (final v in votes) {
        if (v is! Map) continue;
        if ((v['userId'] ?? v['user_id'])?.toString() == uid) {
          final idx = v['optionIndex'] ?? v['option_index'];
          myVote = idx is num ? idx.toInt() : int.tryParse('$idx');
          break;
        }
      }
    }

    final canVote = !hasEnded && onVote != null && messageId.isNotEmpty;

    return SizedBox(
      width: ChatLayoutConstants.pollMessageWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: theme.textTheme.titleSmall?.copyWith(
              color: onColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSizes.p10),
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSizes.p8),
            _PollOptionRow(
              label: options[i],
              percent: totalVotes <= 0 || i >= counts.length
                  ? 0
                  : counts[i] / totalVotes,
              count: i < counts.length ? counts[i] : 0,
              selected: myVote == i,
              ended: hasEnded,
              isMe: isMe,
              onTap: canVote ? () => onVote!(messageId, i) : null,
            ),
          ],
          const SizedBox(height: AppSizes.p10),
          Text(
            hasEnded ? l10n.chatPollEnded : l10n.chatPollVotesCount(totalVotes),
            style: theme.textTheme.labelSmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

class _PollOptionRow extends StatelessWidget {
  const _PollOptionRow({
    required this.label,
    required this.percent,
    required this.count,
    required this.selected,
    required this.ended,
    required this.isMe,
    this.onTap,
  });

  final String label;
  final double percent;
  final int count;
  final bool selected;
  final bool ended;
  final bool isMe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    final onColor = isMe ? chatTheme.onSentBubble : chatTheme.onReceivedBubble;
    final track = (isMe ? Colors.white : theme.colorScheme.onSurface)
        .withValues(alpha: isMe ? 0.16 : 0.08);
    final fill = selected
        ? theme.colorScheme.primary.withValues(alpha: isMe ? 0.55 : 0.35)
        : (isMe ? Colors.white : theme.colorScheme.primary).withValues(
            alpha: isMe ? 0.28 : 0.16,
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: track,
            border: selected
                ? Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.9),
                    width: 1.5,
                  )
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              FractionallySizedBox(
                widthFactor: percent.clamp(0.0, 1.0),
                child: Container(color: fill),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: onColor,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${(percent * 100).round()}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: onColor.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatVideoMessageWidget extends StatelessWidget {
  const ChatVideoMessageWidget({required this.videoUrl, super.key});

  final String videoUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(ChatLayoutConstants.bubbleRadius),
      child: SizedBox(
        width: ChatLayoutConstants.chatVideoMessageWidth,
        height: ChatLayoutConstants.chatVideoMessageHeight,
        child: CustomVideoPlayer(url: videoUrl, isActive: false),
      ),
    );
  }
}
