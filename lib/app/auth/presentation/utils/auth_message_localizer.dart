import 'package:bimobondapp/l10n/app_localizations.dart';

String localizeAuthMessage(AppLocalizations l10n, String key) {
  switch (key) {
    case 'loginFailed':
      return l10n.loginFailed;
    case 'verificationFailed':
      return l10n.verificationFailed;
    case 'invalidOtpCode':
      return l10n.invalidOtpCode;
    case 'googleLoginFailed':
      return l10n.googleLoginFailed;
    case 'updateProfileFailed':
      return l10n.updateProfileFailed;
    case 'signupFailed':
      return l10n.signupFailed;
    default:
      return key;
  }
}
