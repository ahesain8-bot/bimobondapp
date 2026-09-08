import '../domain/live_promotion_models.dart';
import 'live_promotions_repository.dart';

/// Reviewed adapter for the deployed `/promotions/*` envelopes.
///
/// Verified against live responses from the promotions service:
///
/// * `GET /promotions/lives/options` → `{ objectives, audienceModes, genders,
///   ageRange, languages, categories:[{id,name,slug,iconUrl}], customBudget:{
///   durationPresetsDays, coinsPer1000Impressions, … }, targetingNotes }`.
///   It carries **no** country list; the repository fills that from the shared
///   `GET /promotions/options` envelope, which does.
/// * `GET /promotions/packages` → a flat array of
///   `{id,name,durationHours,priceCoins,impressionCount,isActive,isDeleted}`.
/// * `GET /promotions/lives/mine` → `{ data:[…], meta:{total,page,limit,
///   totalPages} }`.
///
/// Campaign, stats and preview envelopes follow the same service's post
/// promotion shape (flat objects, `target*` echoed back). They are parsed
/// permissively **for display only**: nothing here decides that a charge is
/// safe. `LivePromotionCampaign.hasPaymentSummary` still requires every
/// economic field to be present before Pay is enabled, and
/// `LivePromotionsRepository.create` re-checks id, `liveId` and
/// `PENDING_PAYMENT` on the created campaign, so a missing or renamed field
/// disables payment instead of guessing a price.
class LiveApiPromotionContract implements LivePromotionResponseContract {
  const LiveApiPromotionContract();

  @override
  bool get verified => true;

  @override
  LivePromotionOptions options(Object? data) {
    final json = _map(data, 'options');
    final budget = json['customBudget'];
    final durations = budget is Map
        ? _ints(budget['durationPresetsDays'])
        : const <int>[];
    return LivePromotionOptions(
      genders: _options(json['genders']),
      languages: _options(json['languages']),
      categories: _options(json['categories']),
      countries: _options(json['countries']),
      durations: durations.isEmpty ? const [1, 3, 7, 14] : durations,
      rateCoinsPerThousand: budget is Map
          ? _num(budget['coinsPer1000Impressions'])
          : null,
    );
  }

  /// Country chips for the custom audience, read from the shared post
  /// promotions options envelope (`{ countries:[{code,name,regions}] }`).
  @override
  List<LivePromotionOption> countries(Object? data) {
    final json = _map(data, 'countries');
    return _options(json['countries']);
  }

  @override
  List<LivePromotionPackage> packages(Object? data) {
    final raw = data is Map ? data['data'] : data;
    if (raw is! List) {
      throw const LivePromotionContractException('packages');
    }
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => e['isActive'] == true && e['isDeleted'] != true)
        .map((e) {
          final id = _string(e['id']);
          if (id == null) return null;
          final hours = _int(e['durationHours']);
          return LivePromotionPackage(
            id: id,
            name: _string(e['name']) ?? id,
            budgetCoins: _int(e['priceCoins']),
            // The catalog is priced in hours; the LIVE form quotes days.
            durationDays: hours == null || hours <= 0
                ? null
                : (hours / 24).ceil(),
            estimatedImpressions: _int(e['impressionCount']),
          );
        })
        .whereType<LivePromotionPackage>()
        .toList();
  }

  @override
  LivePromotionPreview preview(Object? data) {
    final json = _map(data, 'preview');
    return LivePromotionPreview(
      estimatedViewers: _int(
        json['estimatedViewers'] ?? json['estimatedViews'],
      ),
      estimatedFollowers: _int(json['estimatedFollowers']),
      estimatedImpressions: _int(
        json['estimatedImpressions'] ?? json['impressions'],
      ),
    );
  }

  @override
  LivePromotionCampaign? campaign(Object? data) {
    if (data == null) return null;
    if (data is Map && data.isEmpty) return null;
    final json = _unwrap(_map(data, 'campaign'));
    if (json == null) return null;
    final id = _string(json['id']);
    final liveId = _string(json['liveId']);
    if (id == null || liveId == null) {
      throw const LivePromotionContractException('campaign');
    }
    final rawStatus = _string(json['status']) ?? '';
    final objective = _objective(json['objective']);
    final automatic = json['automaticAudience'] is bool
        ? json['automaticAudience'] as bool
        : null;
    final budgetCoins = _int(json['budgetCoins']);
    final durationDays = _int(json['durationDays']);
    return LivePromotionCampaign(
      id: id,
      liveId: liveId,
      status: LivePromotionStatus.parse(rawStatus),
      rawStatus: rawStatus,
      budgetCoins: budgetCoins,
      durationDays: durationDays,
      objective: objective,
      automaticAudience: automatic,
      // The stored draft is what an edit reopens and what the payment quote is
      // compared against, so it mirrors exactly what the server persisted.
      draft: objective == null || automatic == null
          ? null
          : LivePromotionDraft(
              objective: objective,
              automaticAudience: automatic,
              packageId: _string(json['packageId']),
              budgetCoins: budgetCoins,
              durationDays: durationDays,
              targetGenders: _strings(json['targetGenders']),
              targetAgeMin: _int(json['targetAgeMin']),
              targetAgeMax: _int(json['targetAgeMax']),
              targetCountryCodes: _strings(json['targetCountryCodes']),
              targetLanguages: _strings(json['targetLanguages']),
              targetCategoryIds: _strings(json['targetCategoryIds']),
              targetLatitude: _double(json['targetLatitude']),
              targetLongitude: _double(json['targetLongitude']),
              targetRadiusKm: _double(json['targetRadiusKm']),
            ),
    );
  }

  @override
  LivePromotionStats stats(Object? data) {
    final json = _unwrap(_map(data, 'stats')) ?? const <String, dynamic>{};
    return LivePromotionStats(
      impressions: _int(json['impressions'] ?? json['impressionCount']),
      spendCoins: _num(json['spendCoins'] ?? json['spentCoins']),
      remainingCoins: _num(
        json['remainingCoins'] ?? json['remainingBudgetCoins'],
      ),
    );
  }

  @override
  LivePromotionPage page(Object? data) {
    final json = _map(data, 'mine');
    final rows = json['data'];
    if (rows is! List) {
      throw const LivePromotionContractException('mine');
    }
    final items = <LivePromotionCampaign>[];
    for (final row in rows.whereType<Map>()) {
      // One malformed row must not empty the whole list.
      try {
        final parsed = campaign(row);
        if (parsed != null) items.add(parsed);
      } on LivePromotionContractException {
        continue;
      }
    }
    final meta = json['meta'];
    final page = meta is Map ? _int(meta['page']) ?? 1 : 1;
    final totalPages = meta is Map ? _int(meta['totalPages']) : null;
    return LivePromotionPage(
      items: items,
      hasMore: totalPages != null && page < totalPages,
    );
  }

  static Map<String, dynamic> _map(Object? data, String endpoint) {
    if (data is! Map) throw LivePromotionContractException(endpoint);
    return Map<String, dynamic>.from(data);
  }

  /// Some endpoints answer `{ "data": { … } }` or `{ "campaign": { … } }`.
  static Map<String, dynamic>? _unwrap(Map<String, dynamic> json) {
    for (final key in ['campaign', 'data', 'promotion']) {
      final nested = json[key];
      if (nested is Map) return Map<String, dynamic>.from(nested);
      if (json.containsKey(key) && nested == null && json.length == 1) {
        return null;
      }
    }
    return json;
  }

  /// `{value,label}` for enum-like lists, `{id,name}` for categories and
  /// `{code,name}` for countries — the value is always what the create body
  /// carries back to the server.
  static List<LivePromotionOption> _options(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) {
          final value =
              _string(e['value']) ?? _string(e['id']) ?? _string(e['code']);
          final label = _string(e['label']) ?? _string(e['name']) ?? value;
          return value == null ? null : LivePromotionOption(value, label!);
        })
        .whereType<LivePromotionOption>()
        .toList();
  }

  static LivePromotionObjective? _objective(Object? raw) {
    final value = _string(raw);
    if (value == null) return null;
    for (final o in LivePromotionObjective.values) {
      if (o.wireValue == value) return o;
    }
    return null;
  }

  static String? _string(Object? raw) {
    if (raw == null) return null;
    final value = raw.toString().trim();
    return value.isEmpty ? null : value;
  }

  static List<String> _strings(Object? raw) =>
      raw is! List ? const [] : raw.map(_string).whereType<String>().toList();

  static num? _num(Object? raw) =>
      raw is num ? raw : (raw is String ? num.tryParse(raw.trim()) : null);
  static int? _int(Object? raw) => _num(raw)?.round();
  static double? _double(Object? raw) => _num(raw)?.toDouble();
  static List<int> _ints(Object? raw) =>
      raw is! List ? const [] : raw.map(_int).whereType<int>().toList();
}
