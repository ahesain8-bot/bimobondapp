import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void navigateAfterSignUp(
  BuildContext context, {
  String? pendingVerificationEmail,
}) {
  final email = pendingVerificationEmail?.trim();
  if (email != null && email.isNotEmpty) {
    context.goNamed(
      'interest_selection',
      queryParameters: {'email': email},
    );
    return;
  }

  context.goNamed('interest_selection');
}
