import 'dart:async';
import 'dart:typed_data';

import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/core/widgets/video_post_preview_placeholder.dart';
import 'package:flutter/material.dart';

/// Static cover for a video in a profile grid tile.
///
/// Shows the poster image when available; otherwise extracts a single frame
/// from the video. No video playback happens in the grid — videos only play
/// when the post is opened.
class ProfileGridVideoBackground extends StatefulWidget {
  const ProfileGridVideoBackground({
    required this.videoUrl,
    this.posterUrl,
    super.key,
  });

  final String videoUrl;
  final String? posterUrl;

  @override
  State<ProfileGridVideoBackground> createState() =>
      _ProfileGridVideoBackgroundState();
}

class _ProfileGridVideoBackgroundState
    extends State<ProfileGridVideoBackground> {
  bool _posterGenerationStarted = false;
  Uint8List? _generatedPosterBytes;

  String get _resolvedVideoUrl =>
      MediaUtils.resolveAbsoluteUrl(widget.videoUrl);

  String? get _resolvedPosterUrl {
    final raw = widget.posterUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    final resolved = MediaUtils.resolveAbsoluteUrl(raw);
    if (MediaUtils.isVideo(resolved)) return null;
    return isValidNetworkImageUrl(resolved) ? resolved : null;
  }

  @override
  void initState() {
    super.initState();
    _maybeGeneratePoster();
  }

  @override
  void didUpdateWidget(ProfileGridVideoBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.posterUrl != widget.posterUrl) {
      _generatedPosterBytes = null;
      _posterGenerationStarted = false;
      _maybeGeneratePoster();
    }
  }

  void _maybeGeneratePoster() {
    if (_posterGenerationStarted || _resolvedPosterUrl != null) return;
    _posterGenerationStarted = true;
    unawaited(_generatePosterFromVideo());
  }

  Future<void> _generatePosterFromVideo() async {
    final url = _resolvedVideoUrl;
    if (url.isEmpty) return;

    try {
      final bytes = await VideoThumbnailUtils.generateThumbnailBytes(
        url,
        timeMs: 0,
        quality: 70,
        maxHeight: 480,
      );
      if (!mounted || bytes == null) return;
      setState(() => _generatedPosterBytes = bytes);
    } catch (e) {
      debugPrint('Profile grid poster generation failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final posterUrl = _resolvedPosterUrl;

    if (posterUrl != null) {
      return SafeNetworkImage(
        imageUrl: posterUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        blankOnError: true,
      );
    }

    if (_generatedPosterBytes != null) {
      return Image.memory(
        _generatedPosterBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) =>
            const VideoPostPreviewPlaceholder(iconSize: 34),
      );
    }

    return const VideoPostPreviewPlaceholder(iconSize: 34);
  }
}
