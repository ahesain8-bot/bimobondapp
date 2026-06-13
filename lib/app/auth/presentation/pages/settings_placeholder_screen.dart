import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Simple placeholder for settings sub-pages not yet implemented.
class SettingsPlaceholderScreen extends StatelessWidget {
  const SettingsPlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: title,
        showBackButton: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        onBackPressed: () => context.pop(),
      ),
      body: const SizedBox.shrink(),
    );
  }
}
