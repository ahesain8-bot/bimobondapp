/// LIVE contracts are independent of post promotions. Nullable economics stay
/// unknown until a verified response adapter supplies them.
enum LivePromotionObjective {
  views('VIEWS'),
  followers('FOLLOWERS');

  const LivePromotionObjective(this.wireValue);
  final String wireValue;
}

enum LivePromotionStatus {
  pendingPayment('PENDING_PAYMENT'),
  active('ACTIVE'),
  paused('PAUSED'),
  completed('COMPLETED'),
  cancelled('CANCELLED'),
  unknown('UNKNOWN');

  const LivePromotionStatus(this.wireValue);
  final String wireValue;
  static LivePromotionStatus parse(String value) =>
      values.firstWhere((s) => s.wireValue == value, orElse: () => unknown);
  bool get isOpen => this == pendingPayment || this == active || this == paused;
  bool get canEdit => this == pendingPayment;
  bool get canPay => canEdit;
  bool get canPause => this == active;
  bool get canResume => this == paused;
  bool get canCancel => isOpen;
}

enum LivePromotionValidation { budgetMode, minimumBudget, duration, ages, geo }

class LivePromotionDraft {
  const LivePromotionDraft({
    this.objective = LivePromotionObjective.views,
    this.automaticAudience = true,
    this.packageId,
    this.budgetCoins,
    this.durationDays,
    this.targetGenders = const [],
    this.targetAgeMin,
    this.targetAgeMax,
    this.targetCountryCodes = const [],
    this.targetLanguages = const [],
    this.targetCategoryIds = const [],
    this.targetLatitude,
    this.targetLongitude,
    this.targetRadiusKm,
  });
  final LivePromotionObjective objective;
  final bool automaticAudience;
  final String? packageId;
  final int? budgetCoins, durationDays, targetAgeMin, targetAgeMax;
  final List<String> targetGenders,
      targetCountryCodes,
      targetLanguages,
      targetCategoryIds;
  final double? targetLatitude, targetLongitude, targetRadiusKm;

  List<LivePromotionValidation> validate() {
    final errors = <LivePromotionValidation>[];
    final hasPackage = packageId != null && packageId!.trim().isNotEmpty;
    if (hasPackage
        ? budgetCoins != null || durationDays != null
        : budgetCoins == null) {
      errors.add(LivePromotionValidation.budgetMode);
    }
    if (!hasPackage) {
      if (budgetCoins == null || budgetCoins! < 5) {
        errors.add(LivePromotionValidation.minimumBudget);
      }
      if (![1, 3, 7, 14].contains(durationDays)) {
        errors.add(LivePromotionValidation.duration);
      }
    }
    if (!automaticAudience) {
      if (targetAgeMin != null &&
          targetAgeMax != null &&
          targetAgeMin! > targetAgeMax!) {
        errors.add(LivePromotionValidation.ages);
      }
      final geo = [targetLatitude, targetLongitude, targetRadiusKm];
      if (geo.any((v) => v != null) &&
          (geo.any((v) => v == null || !v.isFinite) ||
              (targetLatitude ?? 0).abs() > 90 ||
              (targetLongitude ?? 0).abs() > 180 ||
              (targetRadiusKm ?? 0) <= 0)) {
        errors.add(LivePromotionValidation.geo);
      }
    }
    return errors;
  }

  Map<String, dynamic> toJson({String? liveId}) {
    final errors = validate();
    if (errors.isNotEmpty) throw LivePromotionValidationException(errors);
    return {
      'liveId': ?liveId,
      'objective': objective.wireValue,
      'automaticAudience': automaticAudience,
      if (packageId != null && packageId!.trim().isNotEmpty)
        'packageId': packageId
      else ...{
        'budgetCoins': budgetCoins,
        'durationDays': durationDays,
      },
      if (!automaticAudience) ...{
        if (targetGenders.isNotEmpty) 'targetGenders': targetGenders,
        if (targetAgeMin != null) 'targetAgeMin': targetAgeMin,
        if (targetAgeMax != null) 'targetAgeMax': targetAgeMax,
        if (targetCountryCodes.isNotEmpty)
          'targetCountryCodes': targetCountryCodes,
        if (targetLanguages.isNotEmpty) 'targetLanguages': targetLanguages,
        if (targetCategoryIds.isNotEmpty)
          'targetCategoryIds': targetCategoryIds,
        if (targetLatitude != null) ...{
          'targetLatitude': targetLatitude,
          'targetLongitude': targetLongitude,
          'targetRadiusKm': targetRadiusKm,
        },
      },
    };
  }
}

class LivePromotionCampaign {
  const LivePromotionCampaign({
    required this.id,
    required this.liveId,
    required this.status,
    required this.rawStatus,
    this.budgetCoins,
    this.durationDays,
    this.objective,
    this.automaticAudience,
    this.draft,
  });
  final String id, liveId, rawStatus;
  final LivePromotionStatus status;
  final int? budgetCoins, durationDays;
  final LivePromotionObjective? objective;
  final bool? automaticAudience;
  final LivePromotionDraft? draft;
  bool get hasPaymentSummary =>
      id.isNotEmpty &&
      liveId.isNotEmpty &&
      budgetCoins != null &&
      budgetCoins! > 0 &&
      durationDays != null &&
      durationDays! > 0 &&
      objective != null &&
      automaticAudience != null &&
      (automaticAudience! || draft != null);
}

class LivePromotionOption {
  const LivePromotionOption(this.value, this.label);
  final String value, label;
}

class LivePromotionOptions {
  const LivePromotionOptions({
    this.genders = const [],
    this.languages = const [],
    this.categories = const [],
    this.countries = const [],
    this.durations = const [1, 3, 7, 14],
    this.rateCoinsPerThousand,
  });
  final List<LivePromotionOption> genders, languages, categories, countries;
  final List<int> durations;
  final num? rateCoinsPerThousand;
}

class LivePromotionPackage {
  const LivePromotionPackage({
    required this.id,
    required this.name,
    this.budgetCoins,
    this.durationDays,
    this.estimatedImpressions,
  });
  final String id, name;
  final int? budgetCoins, durationDays, estimatedImpressions;
}

class LivePromotionPreview {
  const LivePromotionPreview({
    this.estimatedViewers,
    this.estimatedFollowers,
    this.estimatedImpressions,
  });
  final int? estimatedViewers, estimatedFollowers, estimatedImpressions;
}

class LivePromotionStats {
  const LivePromotionStats({
    this.impressions,
    this.spendCoins,
    this.remainingCoins,
  });
  final int? impressions;
  final num? spendCoins, remainingCoins;
}

class LivePromotionPage {
  const LivePromotionPage({required this.items, required this.hasMore});
  final List<LivePromotionCampaign> items;
  final bool hasMore;
}

class LivePromotionEligibility {
  const LivePromotionEligibility({
    this.liveId,
    this.authenticatedUserId,
    this.hostUserId,
    this.visibility,
    this.liveStatus,
    this.accountPrivate,
    this.accountBanned,
    this.promotionsEnabled = true,
  });
  final String? liveId, authenticatedUserId, hostUserId, visibility, liveStatus;
  final bool? accountPrivate, accountBanned;
  final bool promotionsEnabled;
  bool get canCreate =>
      promotionsEnabled &&
      liveId != null &&
      liveId!.isNotEmpty &&
      authenticatedUserId != null &&
      authenticatedUserId!.isNotEmpty &&
      authenticatedUserId == hostUserId &&
      visibility == 'PUBLIC' &&
      ['PLANNED', 'LIVE'].contains(liveStatus) &&
      accountPrivate == false &&
      accountBanned == false;
}

class LivePromotionContractException implements Exception {
  const LivePromotionContractException(this.endpoint);
  final String endpoint;
}

class LivePromotionValidationException implements Exception {
  const LivePromotionValidationException(this.errors);
  final List<LivePromotionValidation> errors;
}

class LivePromotionInsufficientBalance implements Exception {
  const LivePromotionInsufficientBalance();
}

class LivePromotionUnavailable implements Exception {
  const LivePromotionUnavailable();
}
