import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/live_entity.dart';
import 'package:bimobondapp/features/live_viewer/domain/repositories/live_repository.dart';
import 'package:bimobondapp/features/live_viewer/domain/usecases/get_live_feed_usecase.dart';
import 'package:bimobondapp/features/live_viewer/presentation/bloc/live_feed/live_feed_bloc.dart';
import 'package:bimobondapp/features/live_viewer/presentation/bloc/live_feed/live_feed_event.dart';
import 'package:bimobondapp/features/live_viewer/presentation/bloc/live_feed/live_feed_state.dart';

/// The silent refresh polls page 1 every few seconds while the viewer may be
/// anywhere in a paginated list. These tests pin down what a page-1 response
/// is and is not allowed to conclude.
void main() {
  const pageSize = 20;

  LiveEntity live(String id) => LiveEntity(
    id: id,
    hostId: 'host-$id',
    hostName: 'Host $id',
    title: 'Live $id',
    category: 'General',
    startTime: DateTime(2026, 1, 1),
  );

  List<LiveEntity> page(int count, {int from = 0}) => List.generate(
    count,
    (index) => live('live-${from + index}'),
  );

  late _ScriptedRepository repository;
  late LiveFeedBloc bloc;

  setUp(() {
    repository = _ScriptedRepository();
    bloc = LiveFeedBloc(getLiveFeedUseCase: GetLiveFeedUseCase(repository));
  });

  tearDown(() => bloc.close());

  Future<void> loadInitial(List<LiveEntity> firstPage) async {
    repository.responses.add(firstPage);
    final done = bloc.stream.firstWhere((s) => s is LiveFeedLoadSuccess);
    bloc.add(const LiveFeedLoadRequested(refresh: true));
    await done;
  }

  Future<LiveFeedState> silentRefresh(List<LiveEntity> freshPageOne) async {
    repository.responses.add(freshPageOne);
    final changed = bloc.stream.first.timeout(
      const Duration(milliseconds: 400),
      onTimeout: () => bloc.state,
    );
    bloc.add(const LiveFeedSilentRefreshRequested());
    return changed;
  }

  test('a new live takes the position the server gave it', () async {
    await loadInitial([live('a'), live('b')]);

    final state = await silentRefresh([live('new'), live('a'), live('b')]);

    expect(
      state.lives.map((l) => l.id),
      ['new', 'a', 'b'],
      reason: 'appending would bury a brand new live at the end of the feed',
    );
  });

  test('a live missing from a short page 1 has ended', () async {
    await loadInitial([live('a'), live('b'), live('c')]);

    final state = await silentRefresh([live('a'), live('c')]);

    expect(state.lives.map((l) => l.id), ['a', 'c']);
  });

  test('a full page 1 never removes anything', () async {
    // Twenty results means there may be more behind them, so a live that is
    // no longer on page 1 may simply have been pushed onto page 2.
    await loadInitial(page(pageSize));

    final shifted = page(pageSize, from: 1);
    final state = await silentRefresh(shifted);

    expect(state.lives, contains(live('live-0')));
    expect(state.lives.length, pageSize + 1);
  });

  test('refreshing page 1 keeps everything paged in beyond it', () async {
    await loadInitial(page(pageSize));
    repository.responses.add(page(3, from: pageSize));
    final loadedMore = bloc.stream.firstWhere(
      (s) => s.lives.length == pageSize + 3,
    );
    bloc.add(const LiveFeedLoadMoreRequested());
    await loadedMore;

    // Page 1 comes back one live shorter: that live ended.
    final state = await silentRefresh(page(pageSize - 1, from: 1));

    expect(state.lives.length, pageSize - 1 + 3);
    expect(
      state.lives.map((l) => l.id),
      containsAll(<String>['live-20', 'live-21', 'live-22']),
      reason: 'page 2 content must survive a page 1 refresh',
    );
    expect(state.lives.map((l) => l.id), isNot(contains('live-0')));
  });

  test('an ended live is removed on the socket signal', () async {
    await loadInitial([live('a'), live('b')]);

    final removed = bloc.stream.first;
    bloc.add(const LiveFeedLiveRemoved('a'));
    final state = await removed;

    expect(state.lives.map((l) => l.id), ['b']);
  });

  test('removing a live that is not in the feed emits nothing', () async {
    await loadInitial([live('a')]);
    var emissions = 0;
    final sub = bloc.stream.listen((_) => emissions++);

    bloc.add(const LiveFeedLiveRemoved('missing'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();

    expect(emissions, 0);
  });

  test('an unchanged page 1 does not rebuild the feed', () async {
    await loadInitial([live('a'), live('b')]);
    var emissions = 0;
    final sub = bloc.stream.listen((_) => emissions++);

    repository.responses.add([live('a'), live('b')]);
    bloc.add(const LiveFeedSilentRefreshRequested());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();

    expect(
      emissions,
      0,
      reason: 'an eight-second poll must not rebuild the PageView',
    );
  });
}

class _ScriptedRepository implements LiveRepository {
  final responses = <List<LiveEntity>>[];

  @override
  Future<Either<Failure, List<LiveEntity>>> getLiveFeed({
    int page = 1,
    int limit = 20,
    String? category,
    bool followingOnly = false,
  }) async {
    if (responses.isEmpty) return const Right(<LiveEntity>[]);
    return Right(responses.removeAt(0));
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
