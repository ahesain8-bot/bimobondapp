import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'tiktok_live_tokens.dart';

/// Floating gift-goal card — layout matched to TikTok LIVE multi-guest reference.
class GiftGoalCard extends StatelessWidget {
  final String title;
  final int current;
  final int target;
  final int coinCost;
  final VoidCallback onSend;
  final VoidCallback onClose;

  const GiftGoalCard({
    super.key,
    required this.title,
    required this.current,
    required this.target,
    this.coinCost = 100,
    required this.onSend,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (current / target.clamp(1, 1 << 30)).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEEEEEE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.black45),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Text('🫶', style: TextStyle(fontSize: 36)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              GestureDetector(
                onTap: onSend,
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: TikTokLiveTokens.liveRed,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Send',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      height: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$current/$target',
                style: const TextStyle(
                  color: Color(0xFF9B5CFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE8E8E8),
                    valueColor:
                        const AlwaysStoppedAnimation(Color(0xFFB388FF)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.monetization_on,
                  color: Color(0xFFFFC107), size: 18),
              const SizedBox(width: 2),
              Text(
                '$coinCost',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.08, end: 0);
  }
}
