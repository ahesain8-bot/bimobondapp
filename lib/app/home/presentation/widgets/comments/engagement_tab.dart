import 'package:flutter/material.dart';

/// Compact tab label for the engagement sheet header.
class EngagementTab extends StatelessWidget {
  const EngagementTab({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 40,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
