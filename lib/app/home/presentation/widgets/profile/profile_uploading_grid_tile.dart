import 'dart:io';

import 'package:bimobondapp/app/posts/presentation/utils/pending_post_uploads.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:flutter/material.dart';

/// TikTok-style uploading cell — cover + circular progress with % in the center.
class ProfileUploadingGridTile extends StatelessWidget {
  const ProfileUploadingGridTile({
    required this.upload,
    super.key,
  });

  final PendingPostUpload upload;

  @override
  Widget build(BuildContext context) {
    final file = upload.coverFile;
    final isVideo = file != null && _looksLikeVideo(file);
    final progress = upload.progress.clamp(0.0, 1.0);
    final hasProgress = progress > 0;
    final percent = (progress * 100).round().clamp(0, 100);

    return ClipRRect(
      borderRadius: BorderRadius.circular(ProfileLayoutConstants.gridItemRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (file != null && !isVideo)
            Image.file(file, fit: BoxFit.cover)
          else if (file != null)
            ColoredBox(
              color: Colors.grey.shade900,
              child: Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Color(0xFF1C1C1E),
                ),
              ),
            )
          else
            const ColoredBox(color: Color(0xFF1C1C1E)),
          const ColoredBox(color: Color(0x66000000)),
          Center(
            child: SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      value: hasProgress ? progress : null,
                      strokeWidth: 3.5,
                      color: Colors.white,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                  Text(
                    hasProgress ? '$percent%' : '…',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static bool _looksLikeVideo(File file) {
    final p = file.path.toLowerCase();
    return p.endsWith('.mp4') ||
        p.endsWith('.mov') ||
        p.endsWith('.m4v') ||
        p.endsWith('.webm');
  }
}
