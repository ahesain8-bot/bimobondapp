import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

IconData categoryIconForSlug(String slug) {
  switch (slug.toLowerCase()) {
    case 'fashion':
      return LucideIcons.shirt;
    case 'music':
      return LucideIcons.music;
    case 'art':
      return LucideIcons.palette;
    case 'jewelry':
      return LucideIcons.gem;
    case 'watches':
      return LucideIcons.watch;
    case 'cars':
      return LucideIcons.carFront;
    case 'sports':
      return LucideIcons.trophy;
    case 'gaming':
      return LucideIcons.gamepad2;
    case 'tech':
    case 'technology':
      return LucideIcons.cpu;
    case 'food':
      return LucideIcons.utensils;
    default:
      return LucideIcons.tag;
  }
}
