import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:flutter/material.dart';

class CameraAppLoading extends StatelessWidget {
  const CameraAppLoading({
    super.key,
    this.message,
    this.progress,
  });

  final String? message;

  /// Optional overall progress in `0..1`. When set, shows a percent + bar.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final pct = p == null ? null : (p.clamp(0.0, 1.0) * 100).round();
    final label = message;
    final showPct = pct != null;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CustomLoadingWidget(size: 60),
            if (showPct) ...[
              const SizedBox(height: 20),
              Text(
                '$pct%',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
              ),
            ],
            if (label != null && label.isNotEmpty) ...[
              SizedBox(height: showPct ? 8 : 16),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
            if (showPct) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: p! <= 0 ? null : p.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.white24,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
