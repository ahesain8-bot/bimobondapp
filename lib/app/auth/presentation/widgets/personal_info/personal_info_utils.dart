import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';

/// Edit-profile full name limits (matches common social display-name caps).
abstract final class ProfileFullName {
  static const int maxLength = 30;

  static String clamp(String value) {
    final trimmed = value.trim();
    if (trimmed.length <= maxLength) return trimmed;
    return trimmed.substring(0, maxLength);
  }
}

String? resolvePersonalInfoAvatarUrl({
  required AuthState state,
  UserEntity? user,
}) {
  final fromWidget = user?.avatarUrl?.trim();
  if (fromWidget != null && fromWidget.isNotEmpty) {
    return fromWidget;
  }
  if (state is AuthSuccess) {
    final fromAuth = state.user.avatarUrl?.trim();
    if (fromAuth != null && fromAuth.isNotEmpty) {
      return fromAuth;
    }
  }
  return null;
}

String? localizedPersonalInfoCountry(String? code, AppLocalizations l10n) {
  switch (code) {
    case 'Egypt':
      return l10n.egypt;
    case 'Saudi Arabia':
      return l10n.saudiArabia;
    case 'UAE':
      return l10n.uae;
    case 'USA':
      return l10n.usa;
    case 'UK':
      return l10n.uk;
    default:
      return code;
  }
}

/// Dial code for a profile country value (e.g. `Egypt` → `+20`).
String? dialCodeForPersonalInfoCountry(String? country) {
  switch (country) {
    case 'Egypt':
      return '+20';
    case 'Saudi Arabia':
      return '+966';
    case 'UAE':
      return '+971';
    case 'USA':
      return '+1';
    case 'UK':
      return '+44';
    default:
      return null;
  }
}

/// Profile country for a phone dial code (e.g. `+20` → `Egypt`).
String? personalInfoCountryForDialCode(String? dialCode) {
  switch (dialCode) {
    case '+20':
      return 'Egypt';
    case '+966':
      return 'Saudi Arabia';
    case '+971':
      return 'UAE';
    case '+1':
      return 'USA';
    case '+44':
      return 'UK';
    default:
      return null;
  }
}
