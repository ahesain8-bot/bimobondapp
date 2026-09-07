import 'package:bimobondapp/features/live/domain/entities/live_game.dart';
import 'package:bimobondapp/features/live/domain/repositories/live_games_repository.dart';
import 'package:bimobondapp/features/live/presentation/bloc/live_games/live_games_bloc.dart';
import 'package:bimobondapp/features/live/presentation/widgets/room/live_games_sheet.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _Games extends Fake implements LiveGamesRepository {
  _Games(this.game);
  LiveGame game;
  int starts = 0;

  @override
  Future<List<LiveGameCatalogEntry>> catalog() async => const [
    LiveGameCatalogEntry(type: LiveGameType.luckyDraw, name: 'Lucky draw'),
  ];

  @override
  Future<LiveGame?> activeGame(String liveId) async => game;

  @override
  Future<LiveGame?> startGame(
    String liveId, {
    required LiveGameType type,
    String? question,
    List<String>? options,
    int? correctIndex,
    List<String>? prizes,
  }) async {
    starts++;
    return game = LiveGame(
      id: 'next',
      type: type,
      status: LiveGameStatus.active,
    );
  }
}

Future<LiveGamesBloc> _mount(WidgetTester tester, _Games games) async {
  final bloc = LiveGamesBloc(repository: games);
  addTearDown(bloc.close);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlocProvider.value(
          value: bloc,
          child: const LiveGamesSheet(isHost: true),
        ),
      ),
    ),
  );
  bloc.add(const LiveGamesStarted('live-1'));
  await tester.pumpAndSettle();
  return bloc;
}

void main() {
  testWidgets('the host can start another game after the previous one ended', (
    tester,
  ) async {
    final games = _Games(
      const LiveGame(
        id: 'old',
        type: LiveGameType.luckyDraw,
        status: LiveGameStatus.ended,
      ),
    );
    final bloc = await _mount(tester, games);
    final l = AppLocalizations.of(tester.element(find.byType(LiveGamesSheet)))!;
    expect(find.widgetWithText(FilledButton, l.liveGamesStart), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, l.liveGamesStart));
    await tester.pumpAndSettle();
    expect(games.starts, 1);
    expect(bloc.state.game!.id, 'next');
    expect(find.widgetWithText(FilledButton, l.liveGamesStart), findsNothing);
  });

  testWidgets('a long quiz is scrollable on a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _mount(
      tester,
      _Games(
        LiveGame(
          id: 'quiz',
          type: LiveGameType.quiz,
          status: LiveGameStatus.active,
          question: 'A question with several long choices',
          options: List.generate(
            6,
            (i) =>
                'Choice $i with enough text to wrap onto several lines on a narrow phone.',
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final l = AppLocalizations.of(tester.element(find.byType(LiveGamesSheet)))!;
      await tester.ensureVisible(find.text(l.liveGameEnd));
    await tester.pumpAndSettle();
      expect(find.text(l.liveGameEnd).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
