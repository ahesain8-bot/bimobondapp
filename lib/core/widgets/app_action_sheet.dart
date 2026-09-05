import 'package:flutter/material.dart';

import 'app_form_dialog.dart';

/// Bottom-sheet sibling of [AppFormDialog].
///
/// Shares the modal radius, ink and rhythm so a menu of actions and the form it
/// leads to read as one system. Rows are [AppActionTile]; anything taller than
/// [_maxHeightFactor] scrolls instead of swallowing the screen behind it.
abstract final class AppActionSheet {
  AppActionSheet._();

  /// Keeps the sheet from covering the content it was opened over — important
  /// on top of live video, where the stream has to stay watchable.
  static const double _maxHeightFactor = 0.7;

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required List<Widget> children,
    String? subtitle,
    Brightness? brightness,
  }) {
    final forced = brightness;
    final palette = forced == null
        ? AppModalPalette.of(context)
        : AppModalPalette.forBrightness(Theme.of(context).colorScheme, forced);

    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => AppModalPaletteScope(
        palette: palette,
        child: _ActionSheetBody(
          title: title,
          subtitle: subtitle,
          children: children,
        ),
      ),
    );
  }
}

class _ActionSheetBody extends StatelessWidget {
  const _ActionSheetBody({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = AppModalPalette.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppModalTokens.cornerRadius),
        ),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.sizeOf(context).height *
                AppActionSheet._maxHeightFactor,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.fieldBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: palette.title,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: palette.helper,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row of an [AppActionSheet]: icon chip, title and a line of context.
class AppActionTile extends StatelessWidget {
  const AppActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.featured = false,
    this.enabled = true,
  });

  final IconData icon;
  final String title;

  /// One quiet line saying what the action does, or what state it is in.
  final String? subtitle;

  /// Runs once the sheet has closed, so an action can hand straight over to a
  /// dialog without stacking two barriers.
  final VoidCallback onTap;

  /// Accent wash for the one row that should lead — the gift flow, typically.
  final bool featured;

  final bool enabled;

  static const double _radius = AppModalTokens.fieldRadius;

  @override
  Widget build(BuildContext context) {
    final palette = AppModalPalette.of(context);
    final sub = subtitle;

    return Opacity(
      opacity: enabled ? 1 : 0.42,
      child: Material(
        color: featured
            ? palette.accent.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(_radius),
        child: InkWell(
          onTap: enabled
              ? () {
                  Navigator.of(context).maybePop();
                  onTap();
                }
              : null,
          borderRadius: BorderRadius.circular(_radius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: featured
                        ? palette.accent.withValues(alpha: 0.18)
                        : palette.fieldFill,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: featured ? palette.accent : palette.title,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.title,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                      if (sub != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.helper,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
