import 'dart:convert';

import 'package:bimobondapp/app/live_promotions/data/live_promotion_api_contract.dart';
import 'package:bimobondapp/app/live_promotions/domain/live_promotion_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captured from the deployed promotions service, trimmed to the fields the
/// client reads. Update these fixtures, not the parser, when the API changes.
const optionsFixture = '''
{
  "kind": "LIVE",
  "objectives": [
    {"value": "VIEWS", "label": "More viewers", "description": "…"},
    {"value": "FOLLOWERS", "label": "More followers", "description": "…"}
  ],
  "audienceModes": [
    {"value": "AUTOMATIC", "label": "Automatic", "description": "…"},
    {"value": "CUSTOM", "label": "Custom", "description": "…"}
  ],
  "genders": [
    {"value": "MALE", "label": "Male"},
    {"value": "FEMALE", "label": "Female"},
    {"value": "OTHER", "label": "Other"}
  ],
  "ageRange": {"min": 13, "max": 100},
  "languages": [
    {"value": "ar", "label": "Arabic"},
    {"value": "en", "label": "English"}
  ],
  "categories": [
    {"id": "cat-1", "name": "Music", "slug": "music", "iconUrl": "https://x/1"},
    {"id": "cat-2", "name": "Gaming", "slug": "gaming", "iconUrl": null}
  ],
  "customBudget": {
    "minCoins": 5,
    "maxCoins": 100000,
    "minDurationDays": 1,
    "maxDurationDays": 90,
    "defaultDurationDays": 1,
    "durationPresetsDays": [1, 3, 7, 14],
    "coinsPer1000Impressions": 5,
    "estimateVariance": {"minFactor": 0.7, "maxFactor": 1.15}
  },
  "targetingNotes": {"geo": "…"}
}
''';

const packagesFixture = '''
[
  {"id": "pkg-1", "name": "Starter", "iconUrl": null, "durationHours": 24,
   "priceCoins": 5, "impressionCount": 1000, "isActive": true, "isDeleted": false},
  {"id": "pkg-2", "name": "Boost", "iconUrl": null, "durationHours": 24,
   "priceCoins": 20, "impressionCount": 5000, "isActive": true, "isDeleted": false},
  {"id": "pkg-3", "name": "Retired", "iconUrl": null, "durationHours": 24,
   "priceCoins": 50, "impressionCount": 15000, "isActive": false, "isDeleted": true}
]
''';

const emptyMineFixture =
    '{"data":[],"meta":{"total":0,"page":1,"limit":20,"totalPages":1}}';

Object? decode(String source) => jsonDecode(source);

void main() {
  const contract = LiveApiPromotionContract();

  test('deployed options envelope parses without a country list', () {
    final options = contract.options(decode(optionsFixture));
    expect(options.genders.map((e) => e.value), ['MALE', 'FEMALE', 'OTHER']);
    expect(options.languages.map((e) => e.label), ['Arabic', 'English']);
    // Categories arrive as {id,name}; the create body sends the id.
    expect(options.categories.map((e) => e.value), ['cat-1', 'cat-2']);
    expect(options.categories.first.label, 'Music');
    expect(options.countries, isEmpty);
    expect(options.durations, [1, 3, 7, 14]);
    expect(options.rateCoinsPerThousand, 5);
  });

  test('countries come from the shared promotions options envelope', () {
    final countries = contract.countries(
      decode(
        '{"countries":[{"code":"EG","name":"Egypt","regions":[]},'
        '{"code":"JO","name":"Jordan","regions":[]}]}',
      ),
    );
    expect(countries.map((e) => e.value), ['EG', 'JO']);
    expect(countries.map((e) => e.label), ['Egypt', 'Jordan']);
  });

  test('packages drop inactive rows and quote hours as days', () {
    final packages = contract.packages(decode(packagesFixture));
    expect(packages.map((e) => e.id), ['pkg-1', 'pkg-2']);
    expect(packages.first.budgetCoins, 5);
    expect(packages.first.durationDays, 1);
    expect(packages.first.estimatedImpressions, 1000);
  });

  test('an empty campaign page reports no further pages', () {
    final page = contract.page(decode(emptyMineFixture));
    expect(page.items, isEmpty);
    expect(page.hasMore, false);
  });

  test('a listed page with more pages sets hasMore', () {
    final page = contract.page(
      decode(
        '{"data":[{"id":"c1","liveId":"l1","status":"ACTIVE",'
        '"objective":"VIEWS","automaticAudience":true,"budgetCoins":20,'
        '"durationDays":1}],"meta":{"total":30,"page":1,"limit":20,'
        '"totalPages":2}}',
      ),
    );
    expect(page.items.single.id, 'c1');
    expect(page.hasMore, true);
  });

  test('a campaign keeps its stored targeting so edit and quote match', () {
    final campaign = contract.campaign(
      decode(
        '{"id":"c1","liveId":"l1","status":"PENDING_PAYMENT",'
        '"objective":"FOLLOWERS","automaticAudience":false,'
        '"budgetCoins":20,"durationDays":3,"targetGenders":["FEMALE"],'
        '"targetAgeMin":18,"targetAgeMax":34,"targetCountryCodes":["EG"],'
        '"targetLanguages":["ar"],"targetCategoryIds":["cat-1"],'
        '"targetLatitude":30.0444,"targetLongitude":31.2357,'
        '"targetRadiusKm":50}',
      ),
    )!;
    expect(campaign.status, LivePromotionStatus.pendingPayment);
    expect(campaign.objective, LivePromotionObjective.followers);
    expect(campaign.hasPaymentSummary, true);
    final draft = campaign.draft!;
    expect(draft.targetGenders, ['FEMALE']);
    expect(draft.targetCountryCodes, ['EG']);
    expect(draft.targetRadiusKm, 50);
    expect(campaign.draft!.toComparableJson()['targetAgeMax'], 34);
  });

  test('no open campaign for a live is absence, not an error', () {
    expect(contract.campaign(null), isNull);
    expect(contract.campaign(<String, dynamic>{}), isNull);
    expect(contract.campaign(decode('{"data":null}')), isNull);
  });

  test('a campaign missing its economics cannot reach payment', () {
    final campaign = contract.campaign(
      decode(
        '{"id":"c1","liveId":"l1","status":"PENDING_PAYMENT",'
        '"objective":"VIEWS","automaticAudience":true}',
      ),
    )!;
    expect(campaign.hasPaymentSummary, false);
  });

  test('an unknown server status stays read-only', () {
    final campaign = contract.campaign(
      decode(
        '{"id":"c1","liveId":"l1","status":"SOMETHING_NEW",'
        '"objective":"VIEWS","automaticAudience":true,"budgetCoins":20,'
        '"durationDays":1}',
      ),
    )!;
    expect(campaign.status, LivePromotionStatus.unknown);
    expect(campaign.rawStatus, 'SOMETHING_NEW');
    expect(campaign.status.canPay, false);
    expect(campaign.status.canCancel, false);
  });

  test('a campaign without an id is a contract failure, not an empty card', () {
    expect(
      () => contract.campaign(decode('{"liveId":"l1","status":"ACTIVE"}')),
      throwsA(isA<LivePromotionContractException>()),
    );
    expect(
      () => contract.packages(decode('{"unexpected":true}')),
      throwsA(isA<LivePromotionContractException>()),
    );
    expect(
      () => contract.page(decode('{"meta":{}}')),
      throwsA(isA<LivePromotionContractException>()),
    );
  });

  test('one malformed row does not empty the campaign list', () {
    final page = contract.page(
      decode(
        '{"data":[{"status":"ACTIVE"},{"id":"c2","liveId":"l2",'
        '"status":"ACTIVE","objective":"VIEWS","automaticAudience":true}],'
        '"meta":{"page":1,"totalPages":1}}',
      ),
    );
    expect(page.items.map((e) => e.id), ['c2']);
  });

  test('stats and preview read the documented numbers', () {
    final stats = contract.stats(
      decode('{"impressions":120,"spendCoins":6.5,"remainingCoins":13.5}'),
    );
    expect(stats.impressions, 120);
    expect(stats.spendCoins, 6.5);
    expect(stats.remainingCoins, 13.5);
    final preview = contract.preview(
      decode(
        '{"estimatedViewers":800,"estimatedFollowers":40,'
        '"estimatedImpressions":4000}',
      ),
    );
    expect(preview.estimatedViewers, 800);
    expect(preview.estimatedFollowers, 40);
    expect(preview.estimatedImpressions, 4000);
  });
}
