import 'package:bimobondapp/l10n/app_localizations.dart';

String walletAccountingLabel(AppLocalizations l10n, String type) {
  switch (type) {
    case 'PURCHASE':
      return l10n.walletAccountingPurchase;
    case 'GIFT_PURCHASE':
      return l10n.walletAccountingGiftPurchase;
    case 'GIFT_RECEIVED':
      return l10n.walletAccountingGiftReceived;
    case 'AD_PROMOTION_PURCHASE':
      return l10n.walletAccountingPromotion;
    case 'ADMIN_ADJUSTMENT':
      return l10n.walletAccountingAdmin;
    default:
      return type;
  }
}
