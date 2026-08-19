import 'package:flutter/material.dart';

import '../../domain/entities/gift_entity.dart';

/// Maps gift catalog keys to Material icons / colors (no network assets needed).
class GiftIcon extends StatelessWidget {
  final GiftEntity gift;
  final double size;

  const GiftIcon({super.key, required this.gift, this.size = 32});

  static IconData iconFor(String key) {
    switch (key) {
      case 'rose':
        return Icons.local_florist;
      case 'heart':
        return Icons.favorite;
      case 'teddy':
        return Icons.pets;
      case 'star':
        return Icons.star;
      case 'cake':
        return Icons.cake;
      case 'crown':
        return Icons.emoji_events;
      case 'diamond':
        return Icons.diamond;
      case 'rocket':
        return Icons.rocket_launch;
      case 'ring':
        return Icons.brightness_1;
      case 'car':
        return Icons.directions_car;
      case 'castle':
        return Icons.castle;
      case 'universe':
        return Icons.public;
      default:
        return Icons.card_giftcard;
    }
  }

  static Color colorFor(GiftEntity gift) {
    switch (gift.iconUrl) {
      case 'rose':
        return Colors.pinkAccent;
      case 'heart':
        return Colors.redAccent;
      case 'teddy':
        return Colors.brown;
      case 'star':
        return Colors.amber;
      case 'cake':
        return Colors.pink;
      case 'crown':
        return Colors.amberAccent;
      case 'diamond':
        return Colors.cyanAccent;
      case 'rocket':
        return Colors.deepOrange;
      case 'ring':
        return Colors.lightBlueAccent;
      case 'car':
        return Colors.red;
      case 'castle':
        return Colors.indigoAccent;
      case 'universe':
        return Colors.purpleAccent;
      default:
        return gift.rarity.color;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [colorFor(gift).withOpacity(0.35), Colors.transparent],
        ),
      ),
      child: Icon(
        iconFor(gift.iconUrl),
        size: size * 0.78,
        color: colorFor(gift),
      ),
    );
  }
}
