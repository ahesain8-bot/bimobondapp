import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';

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
