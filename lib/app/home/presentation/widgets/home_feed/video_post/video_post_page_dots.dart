import 'package:flutter/material.dart';

class VideoPostPageDots extends StatelessWidget {
  const VideoPostPageDots({
    required this.currentPage,
    required this.total,
    super.key,
  });

  final int currentPage;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: List.generate(
        total,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: currentPage == index ? 20 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: currentPage == index
                ? Colors.white
                : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
