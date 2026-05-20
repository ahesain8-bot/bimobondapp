import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AddPostChevronIcon extends StatelessWidget {
  const AddPostChevronIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Icon(
      isRtl ? LucideIcons.chevronLeft : LucideIcons.chevronRight,
      size: 16,
    );
  }
}
