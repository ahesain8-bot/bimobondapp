import 'package:flutter/material.dart';

/// Snaps vertical [PageView] scrolling to one full page per swipe.
class OnePageScrollPhysics extends ScrollPhysics {
  const OnePageScrollPhysics({super.parent});

  // A near-critically-damped spring gives the full-screen feed a softer
  // settle without the bounce or oscillation of the platform default.
  static const SpringDescription _softSpring = SpringDescription(
    mass: 1,
    stiffness: 170,
    damping: 25,
  );

  @override
  SpringDescription get spring => _softSpring;

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

    final tolerance = toleranceFor(position);
    final target = _getTargetPixels(position, tolerance, velocity);
    if (target != position.pixels) {
      // Very fast flicks otherwise hit the target too abruptly. Keep enough
      // momentum to feel responsive while preserving a smooth one-page glide.
      final maxSettleVelocity = position.viewportDimension * 2.2;
      final settleVelocity = velocity.clamp(
        -maxSettleVelocity,
        maxSettleVelocity,
      );
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        target,
        settleVelocity,
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
