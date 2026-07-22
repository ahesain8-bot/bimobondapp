import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// After email/password (or other) signup — always land on interests onboarding.
void navigateAfterSignUp(
  BuildContext context, {
  UserEntity? user,
  String? pendingVerificationEmail,
}) {
  navigateAfterAuth(
    context,
    user: user,
    forceInterests: true,
    pendingVerificationEmail: pendingVerificationEmail,
  );
}

/// Post-auth routing (auth + user-interests docs):
/// 1. New user with incomplete profile → edit profile
/// 2. New user / `needsInterests` / forced signup → interests (min 3)
/// 3. Otherwise → home
void navigateAfterAuth(
  BuildContext context, {
  UserEntity? user,
  String? pendingVerificationEmail,
  bool forceInterests = false,
}) {
  final email = pendingVerificationEmail?.trim();

  final forceProfileSetup =
      user?.isNewUser == true && user?.isProfileIncomplete == true;
  if (forceProfileSetup) {
    context.goNamed(
      'personal_info',
      queryParameters: {'onboarding': '1'},
    );
    return;
  }

  final needsInterests =
      forceInterests ||
      user?.needsInterests == true ||
      user?.isNewUser == true;
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
