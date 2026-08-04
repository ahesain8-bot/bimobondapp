import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:flutter/material.dart';

/// TikTok-style video loading indicator: a thin white line at the bottom of
/// the video that rhythmically stretches out from the center and fades.
class VideoLoadingIndicator extends StatefulWidget {
  const VideoLoadingIndicator({super.key});

  @override
  State<VideoLoadingIndicator> createState() => _VideoLoadingIndicatorState();
}

class _VideoLoadingIndicatorState extends State<VideoLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  late final Animation<double> _stretch = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: HomeLayoutConstants.progressBarMinHeight,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _stretch,
          builder: (context, _) {
            final t = _stretch.value;
            return Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                widthFactor: 0.12 + 0.58 * t,
                alignment: Alignment.bottomCenter,
                child: Opacity(
                  opacity: (1 - t) * 0.75 + 0.15,
                  child: Container(
                    height: HomeLayoutConstants.progressBarMinHeight,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        HomeLayoutConstants.progressBarMinHeight / 2,
                      ),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
