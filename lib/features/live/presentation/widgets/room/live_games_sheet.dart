import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/live_game.dart';
import '../../bloc/live_games/live_games_bloc.dart';

/// Official games surface for both sides of the room (feature 22).
///
/// The host starts and ends the one ACTIVE game; the viewer plays it once.
/// Results — the wheel prize, the lucky-draw winner, the quiz answer — are
/// rendered only after the server sends them.
class LiveGamesSheet extends StatelessWidget {
  const LiveGamesSheet({super.key, required this.isHost});

  final bool isHost;

  static String typeLabel(BuildContext context, LiveGameType type) {
    final l = AppLocalizations.of(context)!;
    return switch (type) {
      LiveGameType.quiz => l.liveGameQuiz,
      LiveGameType.wheel => l.liveGameWheel,
      LiveGameType.luckyDraw => l.liveGameLuckyDraw,
      LiveGameType.unknown => l.liveGameUnsupported,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return BlocConsumer<LiveGamesBloc, LiveGamesState>(
      listener: (context, state) {
        final text = switch (state.notice) {
          LiveGamesNotice.alreadyRunning => l.liveGamesActiveOne,
          null => state.message,
        };
        if (text != null && text.isNotEmpty) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(text)));
          context.read<LiveGamesBloc>().add(const LiveGameMessageShown());
        }
      },
      builder: (context, state) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.liveGamesTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (state.loading)
                    const Center(child: CircularProgressIndicator())
                  else if (state.game != null)
                    _GameView(
                      game: state.game!,
                      isHost: isHost,
                      busy: state.busy,
                    )
                  else
                    Text(l.liveGamesNone),
                  if (!state.loading && isHost && !state.hasActiveGame) ...[
                    const SizedBox(height: 12),
                    for (final entry in state.catalog)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          entry.name.isNotEmpty
                              ? entry.name
                              : typeLabel(context, entry.type),
                        ),
                        subtitle: entry.description == null
                            ? null
                            : Text(entry.description!),
                        trailing: FilledButton(
                          onPressed: state.busy
                              ? null
                              : () => _startGame(context, entry.type),
                          child: Text(l.liveGamesStart),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _startGame(BuildContext context, LiveGameType type) async {
    final bloc = context.read<LiveGamesBloc>();
    if (type == LiveGameType.luckyDraw) {
      bloc.add(const LiveGameStartRequested(type: LiveGameType.luckyDraw));
      return;
    }
    final config = await showModalBottomSheet<LiveGameStartRequested>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GameSetupSheet(type: type),
    );
    if (config != null) bloc.add(config);
  }
}

class _GameView extends StatelessWidget {
  const _GameView({
    required this.game,
    required this.isHost,
    required this.busy,
  });

  final LiveGame game;
  final bool isHost;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final bloc = context.read<LiveGamesBloc>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          LiveGamesSheet.typeLabel(context, game.type),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (game.type == LiveGameType.unknown)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l.liveGameUnsupported),
          ),
        if (game.question != null) ...[
          const SizedBox(height: 8),
          Text(game.question!, style: const TextStyle(fontSize: 15)),
        ],
        if (game.type == LiveGameType.quiz)
          ...List.generate(game.options.length, (index) {
            final isMine = game.myOptionIndex == index;
            // The answer is only ever marked when the server revealed it.
            final isCorrect = game.answerRevealed && game.correctIndex == index;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: OutlinedButton(
                onPressed: busy || !game.canPlay
                    ? null
                    : () => bloc.add(LiveGamePlayRequested(optionIndex: index)),
                style: OutlinedButton.styleFrom(
                  backgroundColor: isCorrect
                      ? Colors.green.withValues(alpha: 0.15)
                      : isMine
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(game.options[index])),
                    if (isCorrect) const Icon(Icons.check, size: 16),
                  ],
                ),
              ),
            );
          }),
        if (game.type == LiveGameType.quiz && !game.answerRevealed)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l.liveGameAnswerHidden,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        if (game.type == LiveGameType.wheel) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final prize in game.prizes) Chip(label: Text(prize)),
            ],
          ),
        ],
        if (game.type != LiveGameType.quiz && game.canPlay) ...[
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy
                ? null
                : () => bloc.add(const LiveGamePlayRequested()),
            child: Text(l.liveGamePlay),
          ),
        ],
        if (game.myPlayed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l.liveGamePlayed),
          ),
        if (game.playCount != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(l.liveGamePlays(game.playCount!)),
          ),
        // Results come from the server only. While the game runs and nothing
        // was sent, the sheet says it is waiting instead of showing a guess.
        if (game.isActive &&
            game.type != LiveGameType.quiz &&
            game.resultPrize == null &&
            game.winnerName == null &&
            game.myPlayed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l.liveGameWaitingResult),
          ),
        if (game.resultPrize != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l.liveGameResultPrize(game.resultPrize!)),
          ),
        if (game.winnerName != null || game.winnerUserId != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l.liveGameWinner(game.winnerName ?? game.winnerUserId!),
            ),
          ),
        if (isHost && game.isActive) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: busy
                ? null
                : () => bloc.add(const LiveGameEndRequested()),
            child: Text(l.liveGameEnd),
          ),
        ],
      ],
    );
  }
}

/// Host setup for QUIZ and WHEEL. LUCKY_DRAW needs no body at all.
class _GameSetupSheet extends StatefulWidget {
  const _GameSetupSheet({required this.type});

  final LiveGameType type;

  @override
  State<_GameSetupSheet> createState() => _GameSetupSheetState();
}

class _GameSetupSheetState extends State<_GameSetupSheet> {
  final _question = TextEditingController();
  final _entries = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];
  int _correctIndex = 0;

  @override
  void dispose() {
    _question.dispose();
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  bool get _isQuiz => widget.type == LiveGameType.quiz;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final filled = _entries
        .map((e) => e.text.trim())
        .where((e) => e.isNotEmpty)
        .length;
    final canSubmit =
        filled >= 2 && (!_isQuiz || _question.text.trim().isNotEmpty);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                LiveGamesSheet.typeLabel(context, widget.type),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_isQuiz)
                TextField(
                  controller: _question,
                  maxLength: 120,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l.liveGameQuestion,
                    counterText: '',
                  ),
                ),
              for (var i = 0; i < _entries.length; i++)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _entries[i],
                        maxLength: 60,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: _isQuiz
                              ? l.liveGameOption(i + 1)
                              : l.liveGamePrize(i + 1),
                          counterText: '',
                        ),
                      ),
                    ),
                    if (_isQuiz)
                      IconButton(
                        tooltip: l.liveGameCorrectOption,
                        onPressed: () => setState(() => _correctIndex = i),
                        icon: Icon(
                          _correctIndex == i
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                        ),
                      ),
                  ],
                ),
              if (_isQuiz)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l.liveGameCorrectOption,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              TextButton.icon(
                onPressed: _entries.length >= 6
                    ? null
                    : () =>
                          setState(() => _entries.add(TextEditingController())),
                icon: const Icon(Icons.add, size: 18),
                label: Text(_isQuiz ? l.liveGameAddOption : l.liveGameAddPrize),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: canSubmit ? _submit : null,
                child: Text(l.liveGamesStart),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final values = _entries
        .map((e) => e.text.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (values.length < 2) return;
    if (_isQuiz) {
      // The chosen answer must still exist after empty entries were dropped.
      final chosen = _entries[_correctIndex].text.trim();
      final index = values.indexOf(chosen);
      if (chosen.isEmpty || index < 0) return;
      Navigator.of(context).pop(
        LiveGameStartRequested(
          type: LiveGameType.quiz,
          question: _question.text.trim(),
          options: values,
          correctIndex: index,
        ),
      );
      return;
    }
    Navigator.of(
      context,
    ).pop(LiveGameStartRequested(type: LiveGameType.wheel, prizes: values));
  }
}
