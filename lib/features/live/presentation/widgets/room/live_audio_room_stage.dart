import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Voice Chat room surface: avatars + speaker state, never a video renderer.
class LiveAudioRoomStage extends StatelessWidget {
  const LiveAudioRoomStage({
    super.key,
    required this.hostName,
    this.hostAvatarUrl,
    this.coverUrl,
    this.speakers = const [],
    this.paused = false,
  });

  final String hostName;
  final String? hostAvatarUrl;
  final String? coverUrl;
  final List<LiveAudioSpeaker> speakers;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF12121A),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (coverUrl != null && coverUrl!.isNotEmpty)
            Opacity(
              opacity: 0.22,
              child: CachedNetworkImage(imageUrl: coverUrl!, fit: BoxFit.cover),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 88, 24, 140),
              child: Column(
                children: [
                  _Seat(
                    name: hostName,
                    avatarUrl: hostAvatarUrl,
                    isHost: true,
                    speaking: !paused,
                  ),
                  const SizedBox(height: 28),
                  if (speakers.isEmpty)
                    Text(
                      'ارفع يدك للحديث',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 18,
                      runSpacing: 18,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final speaker in speakers)
                          _Seat(
                            name: speaker.name,
                            avatarUrl: speaker.avatarUrl,
                            speaking: speaker.speaking,
                            muted: speaker.muted,
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LiveAudioSpeaker {
  const LiveAudioSpeaker({
    required this.name,
    this.avatarUrl,
    this.speaking = false,
    this.muted = false,
  });

  final String name;
  final String? avatarUrl;
  final bool speaking;
  final bool muted;
}

class _Seat extends StatelessWidget {
  const _Seat({
    required this.name,
    this.avatarUrl,
    this.isHost = false,
    this.speaking = false,
    this.muted = false,
  });

  final String name;
  final String? avatarUrl;
  final bool isHost;
  final bool speaking;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final size = isHost ? 96.0 : 72.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: speaking && !muted
                  ? const Color(0xFF2EE6A6)
                  : Colors.white24,
              width: 3,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: avatarUrl != null && avatarUrl!.isNotEmpty
              ? CachedNetworkImage(imageUrl: avatarUrl!, fit: BoxFit.cover)
              : ColoredBox(
                  color: const Color(0xFF2A2A36),
                  child: Center(
                    child: Text(
                      name.isEmpty ? '?' : name.substring(0, 1),
                      style: const TextStyle(color: Colors.white, fontSize: 28),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          isHost ? '$name · مضيف' : name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ],
    );
  }
}
