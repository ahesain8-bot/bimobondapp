import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:bimobondapp/features/live_viewer/presentation/utils/open_profile_live.dart';
import 'package:flutter/material.dart';

/// LIVE indicator on a profile avatar. Visible even when the profile is
/// private/locked. Tapping the badge opens [user.currentLive] when navigation
/// supports it.
class ProfileLiveNowBadge extends StatelessWidget {
  const ProfileLiveNowBadge({
    required this.user,
    required this.child,
    super.key,
  });

  final UserEntity? user;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final profile = user;
    if (profile == null || profile.isLive != true) return child;

    return GestureDetector(
      onTap: () => openProfileCurrentLive(context, profile),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFE2C55), width: 2.5),
            ),
            child: child,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFE2C55),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'LIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
