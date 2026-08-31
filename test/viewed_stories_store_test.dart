import 'package:bimobondapp/core/data/viewed_stories_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('binding a user while a sibling builds defers notification', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'viewed_stories_user-1': <String>['story-1'],
    });
    final preferences = await SharedPreferences.getInstance();
    final store = ViewedStoriesStore(preferences);
    final mountBinder = ValueNotifier<bool>(false);
    addTearDown(store.dispose);
    addTearDown(mountBinder.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            ListenableBuilder(
              listenable: store,
              builder: (context, _) =>
                  Text(store.isViewed('story-1') ? 'viewed' : 'not viewed'),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: mountBinder,
              builder: (context, shouldMount, _) => shouldMount
                  ? _BindViewedStoriesUser(store)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
    expect(find.text('not viewed'), findsOneWidget);

    mountBinder.value = true;
    await tester.pump();

    expect(
      tester.takeException(),
      isNull,
      reason: 'the existing sibling must not be dirtied during build',
    );

    await tester.pump();
    expect(find.text('viewed'), findsOneWidget);
  });
}

class _BindViewedStoriesUser extends StatefulWidget {
  const _BindViewedStoriesUser(this.store);

  final ViewedStoriesStore store;

  @override
  State<_BindViewedStoriesUser> createState() => _BindViewedStoriesUserState();
}

class _BindViewedStoriesUserState extends State<_BindViewedStoriesUser> {
  @override
  void initState() {
    super.initState();
    widget.store.bindUser('user-1');
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
