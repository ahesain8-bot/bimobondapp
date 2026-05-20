import 'package:flutter/material.dart';

/// Snaps vertical [PageView] scrolling to one full page per swipe.
class OnePageScrollPhysics extends ScrollPhysics {
  const OnePageScrollPhysics({super.parent});

  @override
  OnePageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return OnePageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final tolerance = this.tolerance;
    final target = _getTargetPixels(position, tolerance, velocity);
    if (target != position.pixels) {
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        target,
        velocity,
        tolerance: tolerance,
      );
    }
    return null;
  }

  double _getTargetPixels(
    ScrollMetrics position,
    Tolerance tolerance,
    double velocity,
  ) {
    final page = position.pixels / position.viewportDimension;

    if (velocity < -tolerance.velocity) {
      return page.floorToDouble() * position.viewportDimension;
    }
    if (velocity > tolerance.velocity) {
      return page.ceilToDouble() * position.viewportDimension;
    }
    return page.roundToDouble() * position.viewportDimension;
  }

  @override
  bool get allowImplicitScrolling => false;
}
