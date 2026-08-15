import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Returns a pair of colors for gradient based on a seed string (deterministic).
List<Color> _gradientFromSeed(String seed) {
  final List<List<Color>> palettes = [
    [const Color(0xFFFE2C55), const Color(0xFFFF6B9D), const Color(0xFFFFB86B)],
    [const Color(0xFF25F4EE), const Color(0xFF00B0FF), const Color(0xFF6366F1)],
    [const Color(0xFFFFB86B), const Color(0xFFFF6B3D), const Color(0xFFFE2C55)],
    [const Color(0xFF7C3AED), const Color(0xFFEC4899), const Color(0xFFF97316)],
    [const Color(0xFF06B6D4), const Color(0xFF0EA5E9), const Color(0xFF8B5CF6)],
    [const Color(0xFF10B981), const Color(0xFF14B8A6), const Color(0xFF06B6D4)],
    [const Color(0xFFEF4444), const Color(0xFFF97316), const Color(0xFFF59E0B)],
    [const Color(0xFFF472B6), const Color(0xFFC084FC), const Color(0xFF818CF8)],
    [const Color(0xFF84CC16), const Color(0xFF22C55E), const Color(0xFF14B8A6)],
    [const Color(0xFFF43F5E), const Color(0xFF8B5CF6), const Color(0xFF3B82F6)],
  ];
  final hash = seed.codeUnits.fold<int>(0, (a, b) => a + b);
  return palettes[hash % palettes.length];
}

/// Returns a list of decorative icon/emoji-like widgets based on category.
List<IconData> _iconsForCategory(String? category) {
  final cat = (category ?? '').toLowerCase();
  if (cat.contains('music')) return [Icons.music_note, Icons.audiotrack, Icons.headphones, Icons.album];
  if (cat.contains('game')) return [Icons.sports_esports, Icons.gamepad, Icons.videogame_asset, Icons.stadium];
  if (cat.contains('talk') || cat.contains('chat')) return [Icons.chat, Icons.record_voice_over, Icons.forum, Icons.mic];
  if (cat.contains('cook') || cat.contains('food')) return [Icons.restaurant, Icons.local_dining, Icons.ramen_dining, Icons.local_cafe];
  if (cat.contains('fashion') || cat.contains('beauty')) return [Icons.checkroom, Icons.umbrella, Icons.dry_cleaning, Icons.brush];
  if (cat.contains('sport')) return [Icons.sports_soccer, Icons.fitness_center, Icons.directions_run, Icons.sports_basketball];
  if (cat.contains('edu') || cat.contains('study') || cat.contains('book')) return [Icons.school, Icons.menu_book, Icons.psychology, Icons.science];
  if (cat.contains('comedy') || cat.contains('funny')) return [Icons.sentiment_very_satisfied, Icons.theater_comedy, Icons.emoji_events, Icons.celebration];
  if (cat.contains('dance')) return [Icons.music_video, Icons.sports_gymnastics, Icons.celebration, Icons.wb_incandescent];
  if (cat.contains('asmr') || cat.contains('relax')) return [Icons.self_improvement, Icons.nights_stay, Icons.spa, Icons.bedtime];
  return [Icons.live_tv, Icons.favorite, Icons.star, Icons.local_fire_department];
}

/// A deterministic locally-generated "cover image" — gradient + floating decor.
/// Looks great offline and is visually close to a real cover photo.
class FallbackLiveCover extends StatelessWidget {
  final String seed;
  final String? category;
  final String? hostInitial;
  final String? title;
  final bool showOverlayBadge;

  const FallbackLiveCover({
    super.key,
    required this.seed,
    this.category,
    this.hostInitial,
    this.title,
    this.showOverlayBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _gradientFromSeed(seed);
    final icons = _iconsForCategory(category);
    final rand = Random(seed.codeUnits.fold<int>(0, (a, b) => a * 31 + b));
    final initial = (hostInitial?.isNotEmpty == true
        ? hostInitial![0].toUpperCase()
        : (seed.isNotEmpty ? seed[0].toUpperCase() : '?'));

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Big diagonal semi-transparent shapes
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.15),
              ),
            ),
          ),
          // Floating icons
          ...List.generate(6, (i) {
            final icon = icons[i % icons.length];
            final left = rand.nextDouble() * 80;
            final top = rand.nextDouble() * 80;
            final size = 28 + rand.nextDouble() * 48;
            return Positioned(
              left: left,
              top: top,
              child: Opacity(
                opacity: 0.18 + rand.nextDouble() * 0.18,
                child: Icon(
                  icon,
                  size: size,
                  color: Colors.white,
                ),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(
                  begin: 0,
                  end: -8,
                  duration: Duration(milliseconds: 1400 + rand.nextInt(1200)),
                );
          }),
          // Center big host initial avatar circle
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.25),
                    border: Border.all(color: Colors.white54, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 60,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(2, 4),
                        ),
                      ],
                    ),
                  ),
                ),
                if (title != null) ...[
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      title!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (showOverlayBadge)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category ?? 'LIVE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Locally generated avatar (gradient circle + initial).
class FallbackAvatar extends StatelessWidget {
  final String seed;
  final String? name;
  final double radius;

  const FallbackAvatar({
    super.key,
    required this.seed,
    this.name,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _gradientFromSeed(seed);
    final initial = (name?.isNotEmpty == true ? name![0] : seed[0]).toUpperCase();
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.9,
          fontWeight: FontWeight.w700,
          shadows: const [
            Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(1, 2)),
          ],
        ),
      ),
    );
  }
}

/// Animated video/placeholder background to simulate live stream visuals.
class AnimatedVideoPlaceholder extends StatelessWidget {
  final String seed;
  final String? category;
  final String? hostInitial;

  const AnimatedVideoPlaceholder({
    super.key,
    required this.seed,
    this.category,
    this.hostInitial,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        FallbackLiveCover(
          seed: seed,
          category: category,
          hostInitial: hostInitial,
          showOverlayBadge: false,
        ),
        // Simulated scanlines / visual "noise"
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.15, 0.85, 1.0],
                colors: [
                  Colors.black.withOpacity(0.35),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
        ),
        // Pulsing center LIVE icon
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: const Color(0xFFFE2C55).withOpacity(0.85),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFE2C55).withOpacity(0.5),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .fadeIn(duration: 500.ms)
                    .fadeOut(duration: 500.ms),
                const SizedBox(width: 8),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                begin: const Offset(1, 1),
                end: const Offset(1.06, 1.06),
                duration: 1200.ms,
              ),
        ),
        // Simulated audio wave bars at bottom
        Positioned(
          bottom: 60,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(16, (i) {
              final rand = Random(seed.codeUnits.fold<int>(0, (a, b) => a + b) + i);
              final minH = 6.0 + rand.nextDouble() * 6;
              final maxH = 26.0 + rand.nextDouble() * 30;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(2),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .custom(
                      duration: Duration(milliseconds: 400 + rand.nextInt(600)),
                      builder: (context, value, child) {
                        final height = minH + (maxH - minH) * value;
                        return SizedBox(height: height, child: child);
                      },
                    ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
