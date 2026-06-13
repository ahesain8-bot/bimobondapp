import 'package:bimobondapp/app/auth/presentation/widgets/auth/auth_glass_icon_hero.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class EmailVerificationHero extends StatelessWidget {
  const EmailVerificationHero({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthGlassIconHero(icon: LucideIcons.mail);
  }
}
