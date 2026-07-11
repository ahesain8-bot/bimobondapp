import 'package:bimobondapp/app/wallets/domain/entities/balance_entity.dart';

abstract final class BalanceMockData {
  BalanceMockData._();

  static const double estimatedBalanceUsd = 51.0;
  static const double scheduledPayoutsUsd = 151.0;
  static const int coinBalance = 5000;
  static const String currencyCode = 'USD';

  static const latestTransactionId = 'tx-purchase-coins';

  static List<BalanceProgramEntity> programs = const [
    BalanceProgramEntity(nameKey: 'balanceProgramCreatorRewards', amountUsd: 50),
    BalanceProgramEntity(
      nameKey: 'balanceProgramTiktokGo',
      amountUsd: 100,
      secondaryAmountLabel: 'JPY 14,729.62',
    ),
    BalanceProgramEntity(nameKey: 'balanceProgramSeries', amountUsd: 1),
  ];

  static List<PayoutSetupStep> payoutSteps = const [
    PayoutSetupStep(
      id: 'payout_method',
      titleKey: 'balancePayoutMethodTitle',
      subtitleKey: 'balancePayoutMethodSubtitle',
    ),
    PayoutSetupStep(
      id: 'tax',
      titleKey: 'balanceTaxInfoTitle',
      subtitleKey: 'balanceTaxInfoSubtitle',
    ),
    PayoutSetupStep(
      id: 'identity',
      titleKey: 'balanceIdentityTitle',
      subtitleKey: 'balanceIdentitySubtitle',
    ),
  ];

  static const payoutMethods = [
    PayoutMethodOption(
      type: PayoutMethodType.zaloPay,
      titleKey: 'balancePayoutZaloPay',
      subtitleKey: 'balancePayoutZaloPayDetails',
    ),
    PayoutMethodOption(
      type: PayoutMethodType.bank,
      titleKey: 'balancePayoutBank',
      subtitleKey: 'balancePayoutBankDetails',
    ),
    PayoutMethodOption(
      type: PayoutMethodType.paypal,
      titleKey: 'balancePayoutPayPal',
      subtitleKey: 'balancePayoutPayPalDetails',
    ),
  ];

  static List<BalanceTransactionEntity> transactions = [
    BalanceTransactionEntity(
      id: 'tx-creator-jul',
      title: 'Creator rewards program',
      kind: BalanceTransactionKind.creatorRewards,
      filter: BalanceTransactionFilter.revenue,
      amountUsd: 3.98,
      date: DateTime(2023, 7, 19),
      subtitle: 'Rewards',
    ),
    BalanceTransactionEntity(
      id: 'tx-exchange-jul',
      title: 'Exchange for Coins',
      kind: BalanceTransactionKind.exchangeCoins,
      filter: BalanceTransactionFilter.expense,
      amountUsd: 10,
      amountCoins: 1000,
      date: DateTime(2023, 7, 18),
      subtitle: 'Coins',
    ),
    BalanceTransactionEntity(
      id: 'tx-purchase-coins',
      title: 'Purchase of Coins',
      kind: BalanceTransactionKind.purchaseCoins,
      filter: BalanceTransactionFilter.expense,
      amountUsd: 10,
      amountCoins: 1000,
      date: DateTime(2023, 7, 17),
      subtitle: 'Coins',
    ),
    BalanceTransactionEntity(
      id: 'tx-live-jun',
      title: 'LIVE rewards',
      kind: BalanceTransactionKind.liveRewards,
      filter: BalanceTransactionFilter.revenue,
      amountUsd: 12.5,
      date: DateTime(2023, 6, 28),
      subtitle: 'LIVE',
    ),
    BalanceTransactionEntity(
      id: 'tx-payout-dec',
      title: 'Weekly Payout on Dec 20',
      kind: BalanceTransactionKind.weeklyPayout,
      filter: BalanceTransactionFilter.payout,
      amountUsd: 100.32,
      date: DateTime(2023, 12, 20),
      subtitle: 'Payout',
      earnedPeriod: 'Earned Dec 13 - 20',
      breakdown: {
        'LIVE rewards': 45.12,
        'Creator rewards program': 35.20,
        'Subscription': 20.0,
      },
      paymentMethodLabel: 'PayPal(grey***7@gmail.com)',
      activityType: 'LIVE rewards',
      transactionId: 'TXN-20231220-ABC123456789',
      createdAt: DateTime(2023, 12, 20, 9, 0),
      updatedAt: DateTime(2023, 12, 21, 14, 30),
    ),
    BalanceTransactionEntity(
      id: 'tx-payout-dec-13',
      title: 'Weekly Payout on Dec 13',
      kind: BalanceTransactionKind.weeklyPayout,
      filter: BalanceTransactionFilter.payout,
      amountUsd: 87.45,
      date: DateTime(2023, 12, 13),
      subtitle: 'Payout',
      earnedPeriod: 'Earned Dec 6 - 13',
      paymentMethodLabel: 'PayPal(grey***7@gmail.com)',
      activityType: 'Creator rewards program',
      transactionId: 'TXN-20231213-DEF987654321',
      createdAt: DateTime(2023, 12, 13, 9, 0),
      updatedAt: DateTime(2023, 12, 14, 11, 15),
    ),
    BalanceTransactionEntity(
      id: 'tx-refund',
      title: 'Refund',
      kind: BalanceTransactionKind.purchaseCoins,
      filter: BalanceTransactionFilter.refund,
      amountUsd: 5,
      date: DateTime(2023, 5, 10),
      subtitle: 'Refund',
    ),
  ];

  static BalanceTransactionEntity? transactionById(String id) {
    for (final tx in transactions) {
      if (tx.id == id) return tx;
    }
    return null;
  }

  static List<BalanceTransactionEntity> filteredTransactions(
    BalanceTransactionFilter filter,
  ) {
    if (filter == BalanceTransactionFilter.all) return transactions;
    return transactions.where((tx) => tx.filter == filter).toList();
  }
}
