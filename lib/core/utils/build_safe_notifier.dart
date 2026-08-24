import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// A [ChangeNotifier] that refuses to notify in the middle of a build.
///
/// Notifying while the framework is building throws
/// "setState() or markNeedsBuild() called during build" from every
/// [ListenableBuilder] listening to it. That happens whenever a notifier is
/// driven by something outside the widget lifecycle — a socket push, a camera
/// frame, a platform callback — because none of those know what the framework
/// is doing when they land.
///
/// [notifySafely] delivers immediately when it is safe to, and otherwise
/// defers to just after the current frame. Repeat calls inside one frame
/// collapse into a single notification, so a notifier firing at frame rate
/// cannot queue up a callback per event.
mixin BuildSafeNotifier on ChangeNotifier {
  bool _deferred = false;
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void notifySafely() {
    if (_isDisposed) return;

    final phase = SchedulerBinding.instance.schedulerPhase;
    final building =
        phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;

    if (!building) {
      notifyListeners();
      return;
    }

    if (_deferred) return;
    _deferred = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _deferred = false;
      if (_isDisposed) return;
      notifyListeners();
    });
  }
}

/// [ListenableBuilder] for a [Listenable] you do not own and therefore cannot
/// make build-safe at the source — a third-party controller, a LiveKit `Room`,
/// a platform plugin's notifier.
///
/// A plain [ListenableBuilder] calls `setState` the instant the listenable
/// fires; if that lands mid-build the framework throws. This one defers such a
/// rebuild to just after the frame, collapsing repeats.
class BuildSafeListenableBuilder extends StatefulWidget {
  const BuildSafeListenableBuilder({
    super.key,
    required this.listenable,
    required this.builder,
    this.child,
  });

  final Listenable listenable;
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  @override
  State<BuildSafeListenableBuilder> createState() =>
      _BuildSafeListenableBuilderState();
}

class _BuildSafeListenableBuilderState
    extends State<BuildSafeListenableBuilder> {
  bool _deferred = false;

  @override
  void initState() {
    super.initState();
    widget.listenable.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant BuildSafeListenableBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.listenable, widget.listenable)) return;
    oldWidget.listenable.removeListener(_onChanged);
    widget.listenable.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;

    final phase = SchedulerBinding.instance.schedulerPhase;
    final building =
        phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;

    if (!building) {
      setState(() {});
      return;
    }

    if (_deferred) return;
    _deferred = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _deferred = false;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, widget.child);
}
