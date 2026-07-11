import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effect_asset_loader.dart';
import 'package:flutter/material.dart';

/// Shared TikTok-style camera tool visuals.
class CameraToolIcons {
  CameraToolIcons._();

  static const labelStyle = TextStyle(
    color: Colors.white,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.1,
    shadows: [
      Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 1)),
    ],
  );

  static BoxDecoration circleDecoration({bool active = false}) {
    return BoxDecoration(
      color: active
          ? Colors.white.withValues(alpha: 0.92)
          : Colors.black.withValues(alpha: 0.28),
      shape: BoxShape.circle,
      border: Border.all(
        color: active
            ? Colors.white
            : Colors.white.withValues(alpha: 0.18),
        width: 1,
      ),
      boxShadow: const [
        BoxShadow(
          color: Colors.black26,
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    );
  }

  static BoxDecoration squareDecoration() {
    return BoxDecoration(
      color: Colors.black.withValues(alpha: 0.28),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: const [
        BoxShadow(
          color: Colors.black26,
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    );
  }
}

/// Vertical side-rail tool: circle icon + caption below (legacy compact mode).
class CameraRailTool extends StatelessWidget {
  const CameraRailTool({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.badge,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final String? badge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 42.0 : 48.0;
    final iconSize = compact ? 20.0 : 24.0;
    final bottomPad = compact ? 8.0 : 12.0;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPad),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: CameraToolIcons.circleDecoration(active: active),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    color: active ? Colors.black : Colors.white,
                    size: iconSize,
                  ),
                ),
                if (badge != null)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: compact ? 50 : 56,
              child: Text(
                label,
                style: CameraToolIcons.labelStyle.copyWith(
                  fontSize: compact ? 10 : 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// TikTok side rail row: icon on the screen edge, label toward center.
class CameraRailToolRow extends StatelessWidget {
  const CameraRailToolRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.badge,
    this.iconOnStartEdge = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final String? badge;
  /// When true, icon sits on the physical start edge (left rail in RTL).
  final bool iconOnStartEdge;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: CameraToolIcons.circleDecoration(active: active),
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: active ? Colors.black : Colors.white,
            size: 20,
          ),
        ),
        if (badge != null)
          Positioned(
            right: iconOnStartEdge ? -2 : null,
            left: iconOnStartEdge ? null : -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        if (active)
          Positioned(
            right: iconOnStartEdge ? -3 : null,
            left: iconOnStartEdge ? null : -3,
            top: -3,
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: Color(0xFFFE2C55),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 9,
              ),
            ),
          ),
      ],
    );

    final labelWidget = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 76),
      child: Text(
        label,
        style: CameraToolIcons.labelStyle.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: iconOnStartEdge ? TextAlign.left : TextAlign.right,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 122,
          child: Row(
            mainAxisAlignment: iconOnStartEdge
                ? MainAxisAlignment.start
                : MainAxisAlignment.end,
            children: iconOnStartEdge
                ? [iconWidget, const SizedBox(width: 10), labelWidget]
                : [labelWidget, const SizedBox(width: 10), iconWidget],
          ),
        ),
      ),
    );
  }
}

/// Bottom-bar circular action (effects / upload).
class CameraBottomTool extends StatelessWidget {
  const CameraBottomTool({
    super.key,
    required this.onTap,
    this.icon,
    this.label,
    this.child,
    this.size = 52,
  });

  final VoidCallback onTap;
  final IconData? icon;
  final String? label;
  final Widget? child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: CameraToolIcons.circleDecoration(),
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              child: child ??
                  Icon(icon, color: Colors.white, size: size * 0.46),
            ),
            if (label != null) ...[
              const SizedBox(height: 5),
              Text(
                label!,
                style: CameraToolIcons.labelStyle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Gallery upload square (TikTok-style thumbnail slot).
class CameraGalleryTool extends StatelessWidget {
  const CameraGalleryTool({
    super.key,
    required this.onTap,
    required this.label,
    this.icon = Icons.photo_library_rounded,
  });

  final VoidCallback onTap;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: CameraToolIcons.squareDecoration(),
              alignment: Alignment.center,
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: CameraToolIcons.labelStyle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Effects bottom button — shows selected effect preview when active.
class CameraEffectsTool extends StatelessWidget {
  const CameraEffectsTool({
    super.key,
    required this.onTap,
    required this.label,
    this.emoji,
    this.assetUrl,
    this.previewColor,
    this.hasSelection = false,
  });

  final VoidCallback onTap;
  final String label;
  final String? emoji;
  final String? assetUrl;
  final Color? previewColor;
  final bool hasSelection;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasSelection && previewColor != null
                    ? RadialGradient(
                        colors: [
                          previewColor!.withValues(alpha: 0.9),
                          previewColor!.withValues(alpha: 0.45),
                        ],
                      )
                    : null,
                color: hasSelection ? null : Colors.black.withValues(alpha: 0.28),
                border: Border.all(
                  color: hasSelection
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.18),
                  width: hasSelection ? 2 : 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: _buildPreview(),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: CameraToolIcons.labelStyle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (hasSelection && (assetUrl != null || emoji != null)) {
      return CameraEffectAssetLoader.preview(
        raw: assetUrl,
        emojiFallback: emoji,
        size: 52,
      );
    }
    return const Icon(Icons.auto_awesome, color: Colors.white, size: 24);
  }
}
