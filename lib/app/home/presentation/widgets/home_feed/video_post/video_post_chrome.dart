import 'package:flutter/material.dart';

/// TikTok-style rise + fade for actions / caption chrome.
class VideoPostRiseFade extends StatelessWidget {
  const VideoPostRiseFade({
    required this.controller,
    required this.rise,
    required this.fade,
    required this.child,
    super.key,
  });

  final AnimationController? controller;
  final Animation<double>? rise;
  final Animation<double>? fade;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final r = rise;
    final f = fade;
    if (c == null || r == null || f == null) return child;

    return AnimatedBuilder(
      animation: c,
      builder: (context, child) {
        return Opacity(
          opacity: f.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, r.value),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Dim interaction icons while swiping between vertical feed pages.
class VideoPostTransitionDim extends StatelessWidget {
  const VideoPostTransitionDim({
    required this.pageController,
    required this.pageIndex,
    required this.child,
    super.key,
  });

  final PageController? pageController;
  final int? pageIndex;
  final Widget child;

  static double opacityFor(PageController controller, int index) {
    if (!controller.hasClients) return 1.0;
    final page = controller.page;
    if (page == null) return 1.0;
    final distance = (page - index).abs().clamp(0.0, 1.0);
    final dimmed = Curves.easeInCubic.transform(distance);
    return (1.0 - dimmed * 0.85).clamp(0.15, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final controller = pageController;
    final index = pageIndex;
    if (controller == null || index == null) return child;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Opacity(
          opacity: opacityFor(controller, index),
          child: child,
        );
      },
      child: child,
    );
  }
}
