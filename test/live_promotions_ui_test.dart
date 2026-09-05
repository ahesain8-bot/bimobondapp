import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:bimobondapp/app/live_promotions/presentation/controllers/live_promotions_controller.dart';
import 'package:bimobondapp/app/live_promotions/presentation/pages/live_promotions_screen.dart';
import 'package:bimobondapp/app/live_promotions/domain/live_promotion_models.dart';
import 'live_promotions_domain_test.dart' show Repo, eligible;

Widget app(Widget home, {String language = 'en'}) => MaterialApp(
  locale: Locale(language),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: home,
);
void main() {
  for (final language in ['en', 'ar']) {
    testWidgets(
      '$language pre-live explains persisted ID and never creates or pays',
      (tester) async {
        final repo = Repo();
        final c = LivePromotionsController(
          repository: repo,
          refreshWallet: () async => 100,
        );
        await tester.pumpWidget(
          app(
            LivePromotionsScreen(preLive: true, controller: c),
            language: language,
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(LivePromotionsScreen));
        final l = AppLocalizations.of(context)!;
        expect(find.text(l.lpPreLive), findsOneWidget);
        expect(repo.creates, 0);
        expect(repo.pays, 0);
        expect(repo.reads, 0);
        expect(
          Directionality.of(context),
          language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        await tester.pumpWidget(const SizedBox());
        await c.close();
      },
    );
    testWidgets('$language form fits narrow screen and creation does not pay', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(280, 750);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = Repo();
      final c = LivePromotionsController(
        repository: repo,
        refreshWallet: () async => 100,
        refreshEligibility: (_) async => eligible,
      );
      await tester.pumpWidget(
        app(
          LivePromotionsScreen(liveId: 'live-1', controller: c),
          language: language,
        ),
      );
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(LivePromotionsScreen)),
      )!;
      expect(repo.pays, 0);
      expect(repo.creates, 0);
      await tester.scrollUntilVisible(
        find.text(l.lpCreate),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      for (
        var i = 0;
        i < 15 && find.text(l.lpCreate).hitTestable().evaluate().isEmpty;
        i++
      ) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -300));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text(l.lpCreate).hitTestable());
      await tester.pumpAndSettle();
      expect(repo.creates, 1);
      expect(repo.pays, 0);
      expect(find.text(l.lpPending), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await c.close();
    });
  }
  testWidgets(
    'payment requires explicit confirmation and opening details does not pay',
    (tester) async {
      final repo = Repo();
      final c = LivePromotionsController(
        repository: repo,
        refreshWallet: () async => 100,
      );
      await tester.pumpWidget(
        app(LivePromotionsScreen(campaignId: 'campaign-1', controller: c)),
      );
      await tester.pumpAndSettle();
      expect(repo.pays, 0);
      await tester.scrollUntilVisible(
        find.text('Review payment'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Review payment'));
      await tester.pumpAndSettle();
      expect(repo.pays, 0);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Confirm and pay'), findsOneWidget);
      await tester.tap(find.text('Confirm and pay'));
      await tester.pumpAndSettle();
      expect(repo.pays, 1);
      expect(c.state.campaign!.status, LivePromotionStatus.active);
      await tester.pumpWidget(const SizedBox());
      await c.close();
    },
  );
  testWidgets('unknown campaign status offers no payment or mutation actions', (
    tester,
  ) async {
    final repo = Repo()
      ..current = const LivePromotionCampaign(
        id: 'campaign-1',
        liveId: 'live-1',
        status: LivePromotionStatus.unknown,
        rawStatus: 'FUTURE_STATUS',
      );
    final c = LivePromotionsController(
      repository: repo,
      refreshWallet: () async => 100,
    );
    await tester.pumpWidget(
      app(LivePromotionsScreen(campaignId: 'campaign-1', controller: c)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Status unavailable — refresh'), findsOneWidget);
    expect(find.text('Review payment'), findsNothing);
    expect(find.text('Cancel campaign'), findsNothing);
    expect(find.text('Edit campaign'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await c.close();
  });
}
