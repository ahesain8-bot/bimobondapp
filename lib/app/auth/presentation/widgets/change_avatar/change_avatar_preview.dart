import 'dart:io';

import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';

class ChangeAvatarPreview extends StatelessWidget {
  const ChangeAvatarPreview({
    required this.avatarUrl,
    required this.fallbackName,
    required this.selectedFile,
    required this.isUploading,
    super.key,
  });

  final String? avatarUrl;
  final String fallbackName;
  final File? selectedFile;
  final bool isUploading;

  static const double _radius = 100;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (selectedFile != null)
            CircleAvatar(
              radius: _radius,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              backgroundImage: FileImage(selectedFile!),
            )
          else
            SafeNetworkAvatar(
              imageUrl: avatarUrl,
              radius: _radius,
              fallbackText: fallbackName.isNotEmpty ? fallbackName : 'User',
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          if (isUploading)
            Container(
              width: _radius * 2,
              height: _radius * 2,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: const CustomLoadingWidget(size: 60),
            ),
        ],
      ),
    );
  }
}
