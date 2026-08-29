import 'package:bimobondapp/app/video_templates/presentation/widgets/editor/template_editor_theme.dart';
import 'package:flutter/material.dart';

/// TikTok-style export overlay: dimmed barrier + dialog with circular % progress.
class TemplateEditorExportOverlay extends StatelessWidget {
  const TemplateEditorExportOverlay({
    super.key,
    required this.progress,
    required this.label,
  });

  /// Overall progress in `0..1`. Values `<= 0` show an indeterminate ring.
  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    final determinate = progress > 0.001;
    final pct = (p * 100).round().clamp(0, 100);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ModalBarrier(
            dismissible: false,
            color: Color(0x99000000),
          ),
          Center(
            child: Container(
              width: 168,
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 88,
                    height: 88,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 88,
                          height: 88,
                          child: CircularProgressIndicator(
                            value: determinate ? p : null,
                            strokeWidth: 5,
                            strokeCap: StrokeCap.round,
                            backgroundColor: Colors.white.withValues(alpha: 0.14),
                            color: TemplateEditorTheme.accent,
                          ),
                        ),
                        Text(
                          '$pct%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()],
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (label.trim().isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
