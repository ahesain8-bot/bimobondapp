import 'package:bimobondapp/app/auth/domain/entities/profile_enums.dart';
import 'package:flutter/material.dart';

/// Renders TikTok/Instagram verification badge next to username / display name.
class ProfileVerificationBadge extends StatelessWidget {
  const ProfileVerificationBadge({
    required this.badge,
    this.isVerified = false,
    this.size = 16.0,
    super.key,
  });

  final VerificationBadge badge;
  final bool isVerified;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (badge == VerificationBadge.none && !isVerified) {
      return const SizedBox.shrink();
    }

    if (badge == VerificationBadge.creator) {
      return Padding(
        padding: const EdgeInsets.only(left: 4.0),
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Icon(
            Icons.star_rounded,
            size: size * 0.7,
            color: Colors.white,
          ),
        ),
      );
    }

    // OFFICIAL or default isVerified
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF20D5EC),
        ),
        child: Icon(
          Icons.check_rounded,
          size: size * 0.7,
          color: Colors.white,
        ),
      ),
    );
  }
}
