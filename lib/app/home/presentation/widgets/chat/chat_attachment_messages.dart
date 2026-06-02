import 'package:bimobondapp/app/home/presentation/utils/chat_attachment_payload.dart';
import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_video_player.dart';
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
    final color = isMe ? chatTheme.onSentBubble : theme.colorScheme.primary;

    return InkWell(
      onTap: _openMaps,
      borderRadius: BorderRadius.circular(ChatLayoutConstants.bubbleRadius),
      child: SizedBox(
        width: ChatLayoutConstants.locationMessageWidth,
        child: Row(
          children: [
            Icon(LucideIcons.mapPin, color: color, size: 28),
            const SizedBox(width: AppSizes.p10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.chatMessageLocation,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSizes.p4),
                  Text(
                    payload.displayLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isMe
                          ? chatTheme.onSentBubbleMuted
                          : theme.textTheme.bodySmall?.color,
                    ),
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

class ChatFileMessageWidget extends StatelessWidget {
  const ChatFileMessageWidget({
    required this.fileName,
    required this.fileUrl,
    required this.isMe,
    super.key,
  });

  final String fileName;
  final String? fileUrl;
  final bool isMe;

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
    final color = isMe ? chatTheme.onSentBubble : theme.colorScheme.primary;
    final canOpen = fileUrl != null && fileUrl!.trim().isNotEmpty;

    return InkWell(
      onTap: canOpen ? _openFile : null,
      borderRadius: BorderRadius.circular(ChatLayoutConstants.bubbleRadius),
      child: SizedBox(
        width: ChatLayoutConstants.fileMessageWidth,
        child: Row(
          children: [
            Icon(LucideIcons.file, color: color, size: 28),
            const SizedBox(width: AppSizes.p10),
            Expanded(
              child: Text(
                fileName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
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

  Future<void> _call() async {
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
    final color = isMe ? chatTheme.onSentBubble : theme.colorScheme.primary;

    return InkWell(
      onTap: _call,
      borderRadius: BorderRadius.circular(ChatLayoutConstants.bubbleRadius),
      child: SizedBox(
        width: ChatLayoutConstants.contactMessageWidth,
        child: Row(
          children: [
            Icon(LucideIcons.user, color: color, size: 28),
            const SizedBox(width: AppSizes.p10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payload.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSizes.p4),
                  Text(
                    payload.phone,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isMe
                          ? chatTheme.onSentBubbleMuted
                          : theme.textTheme.bodySmall?.color,
                    ),
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

class ChatVideoMessageWidget extends StatelessWidget {
  const ChatVideoMessageWidget({
    required this.videoUrl,
    super.key,
  });

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
