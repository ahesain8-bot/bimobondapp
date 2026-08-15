import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'tiktok_live_tokens.dart';

/// Centered "Send your first gift" rose prompt — matched to TikTok LIVE.
Future<bool?> showFirstGiftModal(
  BuildContext context, {
  required String hostName,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.50),
    builder: (ctx) => FirstGiftModal(hostName: hostName),
  );
}

class FirstGiftModal extends StatelessWidget {
  final String hostName;

  const FirstGiftModal({super.key, required this.hostName});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: const Icon(Icons.close, size: 20, color: Colors.black54),
              ),
            ),
            const SizedBox(height: 4),
            const Text('🌹', style: TextStyle(fontSize: 72))
                .animate()
                .scale(
                  begin: const Offset(0.85, 0.85),
                  end: const Offset(1, 1),
                  duration: 320.ms,
                  curve: Curves.easeOutBack,
                ),
            const SizedBox(height: 8),
            const Text(
              'Send your first gift',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send your first gift to show appreciation for $hostName',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.black.withValues(alpha: 0.50),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TikTokLiveTokens.liveRed,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(23),
                  ),
                ),
                child: const Text(
                  'Send for 1 coin',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    height: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "This message won't be shown for quick gifts in the future.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.black.withValues(alpha: 0.35),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 160.ms).scale(
          begin: const Offset(0.94, 0.94),
          end: const Offset(1, 1),
          duration: 200.ms,
        );
  }
}
