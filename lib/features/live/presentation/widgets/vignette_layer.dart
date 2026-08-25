import 'package:flutter/material.dart';

/// Subtle vignette effect over the camera preview.
class VignetteLayer extends StatelessWidget {
  const VignetteLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.3),
          radius: 1.2,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.24)],
        ),
      ),
    );
  }
}
