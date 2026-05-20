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
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: ChatLayoutConstants.moreMenuIconSize,
          height: ChatLayoutConstants.moreMenuIconSize,
          decoration: BoxDecoration(
            color: color.withValues(
              alpha: ChatLayoutConstants.moreMenuIconBackgroundAlpha,
            ),
            borderRadius: BorderRadius.circular(
              ChatLayoutConstants.moreMenuIconRadius,
            ),
          ),
          child: Icon(
            icon,
            color: color,
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
