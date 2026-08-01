import 'package:bimobondapp/app/posts/domain/entities/post_location_entity.dart';
import 'package:bimobondapp/core/utils/app_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

/// TikTok Local feed location pill: dark capsule + green pin (no badge).
class PostLocationChip extends StatelessWidget {
  const PostLocationChip({required this.location, super.key});

  final PostLocationEntity location;

  static const Color _pinColor = Color(0xFF25D366);

  Future<void> _openMaps() async {
    final label = Uri.encodeComponent(location.feedDisplayLabel);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1'
      '&query=${location.latitude},${location.longitude}($label)',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!location.hasDisplayLabel) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _openMaps,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.fromLTRB(3, 4, 9, 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                AppAssets.locationPinIcon,
                width: 14,
                height: 14,
                colorFilter: const ColorFilter.mode(
                  _pinColor,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  location.feedDisplayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
