import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/utils/extensions.dart';
import 'fallback_media.dart';
import 'ranking_sheet.dart';

Future<void> showLeagueMatchOverlay(
  BuildContext context, {
  required List<RankingEntry> entries,
  required RankingEntry myEntry,
  required int pointsToNext,
  VoidCallback? onSendGift,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => LeagueMatchOverlay(
      entries: entries,
      myEntry: myEntry,
      pointsToNext: pointsToNext,
      onSendGift: onSendGift,
    ),
  );
}

/// League Match dark leaderboard overlay (TikTok LIVE).
class LeagueMatchOverlay extends StatefulWidget {
  final List<RankingEntry> entries;
  final RankingEntry myEntry;
  final int pointsToNext;
  final VoidCallback? onSendGift;

  const LeagueMatchOverlay({
    super.key,
    required this.entries,
    required this.myEntry,
    required this.pointsToNext,
    this.onSendGift,
  });

  @override
  State<LeagueMatchOverlay> createState() => _LeagueMatchOverlayState();
}

class _LeagueMatchOverlayState extends State<LeagueMatchOverlay> {
  String _path = 'B';

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.78;

    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: Color(0xFF0E0E12),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 152,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Base: deep red left → black center → navy right
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFF4A0E1C),
                        Color(0xFF1A080E),
                        Color(0xFF0A0A0C),
                        Color(0xFF061428),
                        Color(0xFF0A2048),
                      ],
                      stops: [0.0, 0.32, 0.5, 0.68, 1.0],
                    ),
                  ),
                ),
                // Diagonal light rays (red left / blue right)
                const CustomPaint(painter: _LeagueRayBurstPainter()),
                // Trophy (frost circle) — top-left
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Icon(
                      Icons.emoji_events_outlined,
                      color: Colors.white.withValues(alpha: 0.92),
                      size: 18,
                    ),
                  ),
                ),
                // Countdown — top-right
                Positioned(
                  top: 16,
                  right: 14,
                  child: Text(
                    'Ends in 3 days',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Original trophy logo + title
                const Align(
                  alignment: Alignment(0, -0.08),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🏆', style: TextStyle(fontSize: 44, height: 1)),
                      SizedBox(height: 6),
                      Text(
                        'League Match',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final path in ['D', 'C', 'B', 'A']) ...[
                  if (path != 'D') const SizedBox(width: 6),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _path = path),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          gradient: _path == path
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF8B1A2B),
                                    Color(0xFF5A1020),
                                  ],
                                )
                              : null,
                          color: _path == path
                              ? null
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _path == path ? 'Path $path' : path,
                          style: TextStyle(
                            color: Colors.white.withValues(
                              alpha: _path == path ? 1 : 0.55,
                            ),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: widget.entries.length,
              itemBuilder: (context, i) {
                final e = widget.entries[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${e.rank}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      ClipOval(
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: CachedNetworkImage(
                            imageUrl: e.avatarUrl ?? '',
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => FallbackAvatar(
                              seed: e.userId,
                              name: e.username,
                              radius: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                e.username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A4A8A),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$_path${(e.rank % 4) + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        e.score.formatNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            color: Colors.black,
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: CachedNetworkImage(
                            imageUrl: widget.myEntry.avatarUrl ?? '',
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const FallbackAvatar(
                              seed: 'me',
                              name: 'You',
                              radius: 18,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -8,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF2D55),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '+${widget.myEntry.rank}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.myEntry.username,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A4A8A),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'B4',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${widget.pointsToNext.formatNumber} points to reach #99',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onSendGift?.call();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF2D55),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        'Send Gift',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: 0.1, end: 0, duration: 240.ms);
  }
}

/// Red / blue diagonal light rays behind the league logo (TikTok reference).
class _LeagueRayBurstPainter extends CustomPainter {
  const _LeagueRayBurstPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width * 0.5, size.height * 0.38);
    final length = size.width * 0.78;

    // Soft ambient blooms under the rays
    canvas.drawCircle(
      origin.translate(-size.width * 0.08, -8),
      size.width * 0.42,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xFFB02040).withValues(alpha: 0.45),
                const Color(0x00000000),
              ],
            ).createShader(
              Rect.fromCircle(
                center: origin.translate(-size.width * 0.08, -8),
                radius: size.width * 0.42,
              ),
            ),
    );
    canvas.drawCircle(
      origin.translate(size.width * 0.08, -8),
      size.width * 0.42,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xFF1A4A9A).withValues(alpha: 0.45),
                const Color(0x00000000),
              ],
            ).createShader(
              Rect.fromCircle(
                center: origin.translate(size.width * 0.08, -8),
                radius: size.width * 0.42,
              ),
            ),
    );

    void drawFan({
      required double startAngle,
      required double endAngle,
      required int count,
      required Color color,
    }) {
      for (var i = 0; i < count; i++) {
        final t = count == 1 ? 0.5 : i / (count - 1);
        final angle = startAngle + (endAngle - startAngle) * t;
        // Alternate thicker / thinner beams
        final halfW = (i.isEven ? 7.0 : 3.5) * (1.0 - t * 0.15);
        final tip = Offset(
          origin.dx + math.cos(angle) * length,
          origin.dy + math.sin(angle) * length,
        );
        final perp = Offset(-math.sin(angle), math.cos(angle));
        final path = Path()
          ..moveTo(origin.dx, origin.dy)
          ..lineTo(tip.dx + perp.dx * halfW, tip.dy + perp.dy * halfW)
          ..lineTo(tip.dx - perp.dx * halfW, tip.dy - perp.dy * halfW)
          ..close();

        final bounds = Rect.fromPoints(origin, tip).inflate(halfW);
        canvas.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment(
                ((origin.dx - bounds.left) / bounds.width) * 2 - 1,
                ((origin.dy - bounds.top) / bounds.height) * 2 - 1,
              ),
              end: Alignment(
                ((tip.dx - bounds.left) / bounds.width) * 2 - 1,
                ((tip.dy - bounds.top) / bounds.height) * 2 - 1,
              ),
              colors: [
                color.withValues(alpha: 0.50),
                color.withValues(alpha: 0.16),
                color.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds),
        );
      }
    }

    // Left fan — pink / burgundy rays toward top-left
    drawFan(
      startAngle: -math.pi * 0.95,
      endAngle: -math.pi * 0.52,
      count: 10,
      color: const Color(0xFFE04060),
    );
    // Right fan — indigo / blue rays toward top-right
    drawFan(
      startAngle: -math.pi * 0.48,
      endAngle: -math.pi * 0.05,
      count: 10,
      color: const Color(0xFF3A78E0),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
