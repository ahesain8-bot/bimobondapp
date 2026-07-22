import 'dart:async';

import 'package:flutter/material.dart';

/// API cooldown for OTP / forgot-password resend is 60 seconds.
mixin OtpResendCooldownMixin<T extends StatefulWidget> on State<T> {
  static const int resendCooldownSeconds = 60;

  Timer? _resendTimer;
  int _resendSecondsLeft = 0;

  bool get canResendCode => _resendSecondsLeft <= 0;

  int get resendSecondsLeft => _resendSecondsLeft;

  /// Starts (or restarts) the cooldown. Call after a successful send/resend,
  /// and optionally in [initState] when the screen opens after an OTP was sent.
  void startResendCooldown([int seconds = resendCooldownSeconds]) {
    _resendTimer?.cancel();
    setState(() => _resendSecondsLeft = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSecondsLeft <= 1) {
        timer.cancel();
        setState(() => _resendSecondsLeft = 0);
        return;
      }
      setState(() => _resendSecondsLeft -= 1);
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }
}
