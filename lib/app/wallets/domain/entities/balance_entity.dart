enum BalanceTransactionFilter {
  all,
  revenue,
  expense,
  payout,
  refund,
}

enum BalanceTransactionKind {
  creatorRewards,
  liveRewards,
  purchaseCoins,
  exchangeCoins,
  weeklyPayout,
  subscription,
  tiktokGoRewards,
  series,
}

enum BalanceTransactionStatus {
  completed,
  pending,
  failed,
}

enum PayoutMethodType {
  bank,
  paypal,
  zaloPay,
}

class BalanceTransactionEntity {
  const BalanceTransactionEntity({
    required this.id,
    required this.title,
    required this.kind,
    required this.filter,
    required this.amountUsd,
    required this.date,
    this.amountCoins,
    this.subtitle,
    this.status = BalanceTransactionStatus.completed,
    this.earnedPeriod,
    this.breakdown = const {},
    this.paymentMethodLabel,
    this.activityType,
    this.transactionId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final BalanceTransactionKind kind;
  final BalanceTransactionFilter filter;
  final double amountUsd;
  final int? amountCoins;
  final DateTime date;
  final String? subtitle;
  final BalanceTransactionStatus status;
  final String? earnedPeriod;
  final Map<String, double> breakdown;
  final String? paymentMethodLabel;
  final String? activityType;
  final String? transactionId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isCredit =>
      filter == BalanceTransactionFilter.revenue ||
      filter == BalanceTransactionFilter.refund;
}

class BalanceProgramEntity {
  const BalanceProgramEntity({
    required this.nameKey,
    required this.amountUsd,
    this.secondaryAmountLabel,
    this.setupRequired = true,
  });

  final String nameKey;
  final double amountUsd;
  final String? secondaryAmountLabel;
  final bool setupRequired;
}

class PayoutSetupStep {
  const PayoutSetupStep({
    required this.id,
    required this.titleKey,
    required this.subtitleKey,
    this.isComplete = false,
    this.completedValue,
  });

  final String id;
  final String titleKey;
  final String subtitleKey;
  final bool isComplete;
  final String? completedValue;

  PayoutSetupStep copyWith({
    bool? isComplete,
    String? completedValue,
  }) {
    return PayoutSetupStep(
      id: id,
      titleKey: titleKey,
      subtitleKey: subtitleKey,
      isComplete: isComplete ?? this.isComplete,
      completedValue: completedValue ?? this.completedValue,
    );
  }
}

class PayoutMethodOption {
  const PayoutMethodOption({
    required this.type,
    required this.titleKey,
    required this.subtitleKey,
  });

  final PayoutMethodType type;
  final String titleKey;
  final String subtitleKey;
}
