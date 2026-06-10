import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';

/// Grid tile used for chat attachments and add-post media picker sheets.
class AttachmentGridMenuItem extends StatelessWidget {
  const AttachmentGridMenuItem({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.glassStyle = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool glassStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor = glassStyle
        ? Colors.white.withValues(alpha: 0.9)
        : theme.textTheme.labelSmall?.color;
    final iconBackgroundAlpha = glassStyle
        ? 0.18
        : ChatLayoutConstants.moreMenuIconBackgroundAlpha;
    final iconColor = glassStyle ? Colors.white : color;
    final tileColor = glassStyle
        ? Colors.white.withValues(alpha: iconBackgroundAlpha)
        : color.withValues(alpha: iconBackgroundAlpha);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: ChatLayoutConstants.moreMenuIconSize,
          height: ChatLayoutConstants.moreMenuIconSize,
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(
              ChatLayoutConstants.moreMenuIconRadius,
            ),
            border: glassStyle
                ? Border.all(color: Colors.white.withValues(alpha: 0.16))
                : null,
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: ChatLayoutConstants.moreMenuItemIconSize,
          ),
        ),
        const SizedBox(height: AppSizes.p8),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: ChatLayoutConstants.moreMenuLabelFontSize,
            fontWeight: FontWeight.w600,
            color: labelColor,
          ),
        ),
      ],
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          ChatLayoutConstants.moreMenuIconRadius,
        ),
        child: content,
      ),
    );
  }
}
