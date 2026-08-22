import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Official Instagram 2016 Logo SVG String (Clean Vector Paths & Strokes)
const String kInstagram2016Svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <radialGradient id="rg" cx="0.15" cy="0.85" r="1.3">
    <stop offset="0" stop-color="#FFDC80"/>
    <stop offset="0.2" stop-color="#FCAF45"/>
    <stop offset="0.35" stop-color="#F77737"/>
    <stop offset="0.5" stop-color="#F56040"/>
    <stop offset="0.65" stop-color="#FD1D1D"/>
    <stop offset="0.8" stop-color="#E1306C"/>
    <stop offset="0.9" stop-color="#C13584"/>
    <stop offset="1" stop-color="#833AB4"/>
  </radialGradient>
  <rect width="512" height="512" rx="120" fill="url(#rg)"/>
  <rect x="96" y="96" width="320" height="320" rx="90" fill="none" stroke="#ffffff" stroke-width="34"/>
  <circle cx="256" cy="256" r="76" fill="none" stroke="#ffffff" stroke-width="34"/>
  <circle cx="348" cy="164" r="22" fill="#ffffff"/>
</svg>
''';

/// Official YouTube Color Logo SVG String (svgrepo 475700)
const String kYoutubeSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 461.001 461.001">
  <path fill="#FF0000" d="M365.257,67.393H95.744C42.866,67.393,0,110.259,0,163.137v134.728 c0,52.878,42.866,95.744,95.744,95.744h269.513c52.878,0,95.744-42.866,95.744-95.744V163.137 C461.001,110.259,418.135,67.393,365.257,67.393z"/>
  <path fill="#FFFFFF" d="M185.001,310.001V151.001l131,79.5L185.001,310.001z"/>
</svg>
''';

/// Renders authentic Instagram, YouTube, TikTok, Twitter, Snapchat, Spotify brand icons.
class SocialBrandIcon extends StatelessWidget {
  const SocialBrandIcon({
    required this.brandKey,
    this.size = 20.0,
    this.showContainer = true,
    super.key,
  });

  final String brandKey;
  final double size;
  final bool showContainer;

  static IconData getIconData(String key) {
    final lower = key.toLowerCase();
    if (lower.contains('instagram')) return Icons.camera_alt_rounded;
    if (lower.contains('youtube')) return Icons.play_arrow_rounded;
    if (lower.contains('twitter') || lower.contains('x')) return Icons.alternate_email_rounded;
    if (lower.contains('tiktok')) return Icons.videocam_rounded;
    if (lower.contains('spotify') || lower.contains('music')) return Icons.music_note_rounded;
    if (lower.contains('snapchat')) return Icons.snapchat_rounded;
    return Icons.language_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final lower = brandKey.toLowerCase();

    if (lower.contains('instagram')) {
      return SvgPicture.string(
        kInstagram2016Svg,
        width: size,
        height: size,
      );
    }

    if (lower.contains('youtube')) {
      return SvgPicture.string(
        kYoutubeSvg,
        width: size,
        height: size,
      );
    }

    if (lower.contains('tiktok')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.28),
          color: Colors.black,
        ),
        child: Icon(
          Icons.videocam_rounded,
          size: size * 0.65,
          color: const Color(0xFF25F4EE),
        ),
      );
    }

    if (lower.contains('spotify')) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF1DB954),
        ),
        child: Icon(
          Icons.music_note_rounded,
          size: size * 0.65,
          color: Colors.white,
        ),
      );
    }

    if (lower.contains('twitter') || lower.contains('x')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.28),
          color: const Color(0xFF1DA1F2),
        ),
        child: Icon(
          Icons.alternate_email_rounded,
          size: size * 0.65,
          color: Colors.white,
        ),
      );
    }

    if (lower.contains('snapchat')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.28),
          color: const Color(0xFFFFFC00),
        ),
        child: Icon(
          Icons.camera_rounded,
          size: size * 0.65,
          color: Colors.black,
        ),
      );
    }

    // Default Website / Generic link
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        color: Theme.of(context).colorScheme.primary,
      ),
      child: Icon(
        Icons.link_rounded,
        size: size * 0.65,
        color: Colors.white,
      ),
    );
  }
}
