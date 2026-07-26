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
/// After successful login, go directly to home tab.
void navigateAfterAuth(
  BuildContext context, {
  UserEntity? user,
  String? pendingVerificationEmail,
  bool forceInterests = false,
}) {
  final email = pendingVerificationEmail?.trim();

  if (email != null && email.isNotEmpty) {
    context.goNamed(
      'email_verification',
      queryParameters: {'email': email},
    );
    return;
  }

  if (forceInterests) {
    context.goNamed(
      'interest_selection',
    );
    return;
  }

  context.goNamed('home');
}
