enum PasswordStrengthLevel { none, weak, fair, good, strong }

class PasswordStrengthResult {
  const PasswordStrengthResult({
    required this.level,
    required this.filledSegments,
  });

  final PasswordStrengthLevel level;
  final int filledSegments;
}

class PasswordRequirements {
  const PasswordRequirements({
    required this.hasValidLength,
    required this.hasLetter,
    required this.hasNumber,
    required this.hasSpecialChar,
  });

  static const int minLength = 8;
  static const int maxLength = 20;

  final bool hasValidLength;
  final bool hasLetter;
  final bool hasNumber;
  final bool hasSpecialChar;

  bool get isValid =>
      hasValidLength && hasLetter && hasNumber && hasSpecialChar;

  int get metCount =>
      [hasValidLength, hasLetter, hasNumber, hasSpecialChar]
          .where((met) => met)
          .length;

  static PasswordRequirements evaluate(String password) {
    return PasswordRequirements(
      hasValidLength:
          password.length >= minLength && password.length <= maxLength,
      hasLetter: RegExp(r'[a-zA-Z]').hasMatch(password),
      hasNumber: RegExp(r'[0-9]').hasMatch(password),
      hasSpecialChar: RegExp(
        r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;/]',
      ).hasMatch(password),
    );
  }
}

class PasswordStrength {
  PasswordStrength._();

  static const int maxSegments = 4;

  static PasswordStrengthResult evaluate(String password) {
    if (password.isEmpty) {
      return const PasswordStrengthResult(
        level: PasswordStrengthLevel.none,
        filledSegments: 0,
      );
    }

    final requirements = PasswordRequirements.evaluate(password);
    final met = requirements.metCount;

    if (met == 0) {
      return const PasswordStrengthResult(
        level: PasswordStrengthLevel.weak,
        filledSegments: 1,
      );
    }
    if (met == 1) {
      return const PasswordStrengthResult(
        level: PasswordStrengthLevel.weak,
        filledSegments: 1,
      );
    }
    if (met == 2) {
      return const PasswordStrengthResult(
        level: PasswordStrengthLevel.fair,
        filledSegments: 2,
      );
    }
    if (met == 3) {
      return const PasswordStrengthResult(
        level: PasswordStrengthLevel.good,
        filledSegments: 3,
      );
    }
    return const PasswordStrengthResult(
      level: PasswordStrengthLevel.strong,
      filledSegments: 4,
    );
  }
}
