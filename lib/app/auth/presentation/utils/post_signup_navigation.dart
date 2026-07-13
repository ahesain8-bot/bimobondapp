import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// After signup flows that should always land on interests first
/// (e.g. email verification pending before AuthSuccess has `needsInterests`).
void navigateAfterSignUp(
  BuildContext context, {
  String? pendingVerificationEmail,
}) {
  navigateAfterAuth(
    context,
    forceInterests: true,
    pendingVerificationEmail: pendingVerificationEmail,
  );
}

/// Post-auth routing: interests onboarding when required, else home / email verify.
void navigateAfterAuth(
  BuildContext context, {
  UserEntity? user,
  String? pendingVerificationEmail,
  bool forceInterests = false,
}) {
  final email = pendingVerificationEmail?.trim();
  final needsInterests = forceInterests || user?.needsInterests == true;

  if (needsInterests) {
    context.goNamed(
      'interest_selection',
      queryParameters: {
        if (email != null && email.isNotEmpty) 'email': email,
      },
    );
    return;
  }

  if (email != null && email.isNotEmpty) {
    context.goNamed(
      'email_verification',
      queryParameters: {'email': email},
    );
    return;
  }

  context.goNamed('home');
}
