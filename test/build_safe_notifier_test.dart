import 'package:bimobondapp/core/utils/build_safe_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Badge extends ChangeNotifier with BuildSafeNotifier {
  int value = 0;

  void bump() {
    value++;
    notifySafely();
  }
}

void main() {
  testWidgets('notifying during build does not throw', (tester) async {
    final badge = _Badge();
    addTearDown(badge.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ListenableBuilder(
          listenable: badge,
          builder: (context, _) =>
              _NotifyDuringBuild(badge: badge, child: Text('v${badge.value}')),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.takeException(),
      isNull,
      reason: 'the mid-build notification must be deferred, not thrown',
    );
    expect(find.textContaining('v'), findsOneWidget);
  });

  testWidgets('the deferred rebuild still lands', (tester) async {
    final badge = _Badge();
    addTearDown(badge.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ListenableBuilder(
          listenable: badge,
          builder: (context, _) => Text('v${badge.value}'),
        ),
      ),
    );
    expect(find.text('v0'), findsOneWidget);

    badge.bump();
    await tester.pump();

    expect(find.text('v1'), findsOneWidget);
  });

  testWidgets('BuildSafeListenableBuilder survives a mid-build notify', (
    tester,
  ) async {
    final controller = ValueNotifier<int>(0);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: BuildSafeListenableBuilder(
          listenable: controller,
          builder: (context, _) => Builder(
            builder: (context) {
              // A third-party notifier firing while the tree is building.
              if (controller.value == 0) {
                controller.value = 1;
              }
              return Text('n${controller.value}');
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('n1'), findsOneWidget);
  });

  test('notifying after dispose is a no-op', () {
    final badge = _Badge()..dispose();

    expect(badge.bump, returnsNormally);
  });
}

/// Fires the notifier from inside the build phase, which is what a socket
/// push or a camera frame effectively does when it lands at the wrong moment.
class _NotifyDuringBuild extends StatelessWidget {
  const _NotifyDuringBuild({required this.badge, required this.child});

  final _Badge badge;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (badge.value == 0) badge.bump();
    return child;
  }
}
