import 'package:bimobondapp/core/widgets/app_coin_icon.dart';
import 'package:flutter/material.dart';

/// Shape, rhythm and sizing shared by every form modal.
///
/// Kept in one place so a new dialog cannot drift into its own radius or
/// padding scale.
abstract final class AppModalTokens {
  AppModalTokens._();

  static const double cornerRadius = 22;
  static const double fieldRadius = 14;
  static const double actionRadius = 14;
  static const double maxWidth = 380;
  static const double actionHeight = 48;

  static const EdgeInsets insetPadding = EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 24,
  );
  static const EdgeInsets contentPadding = EdgeInsets.fromLTRB(20, 22, 20, 18);
  static const EdgeInsets fieldPadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 14,
  );

  static const double titleGap = 18;
  static const double fieldGap = 16;
  static const double labelGap = 8;
  static const double helperGap = 6;
  static const double actionsGap = 20;
  static const double actionSpacing = 10;
}

/// Neutral ink and surface pairs the modal pieces share.
///
/// The brand colour is reserved for the focus ring and the primary action, so
/// a form never reads as a wall of pink.
@immutable
class AppModalPalette {
  const AppModalPalette({
    required this.surface,
    required this.title,
    required this.label,
    required this.helper,
    required this.hint,
    required this.input,
    required this.fieldFill,
    required this.fieldBorder,
    required this.accent,
    required this.onAccent,
    required this.error,
  });

  /// The palette an enclosing [AppFormDialog] installed, or one derived from
  /// the ambient theme when a piece is used on its own.
  factory AppModalPalette.of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppModalPaletteScope>();
    if (scope != null) return scope.palette;
    final theme = Theme.of(context);
    return AppModalPalette.forBrightness(theme.colorScheme, theme.brightness);
  }

  factory AppModalPalette.forBrightness(
    ColorScheme scheme,
    Brightness brightness,
  ) {
    final isDark = brightness == Brightness.dark;
    return AppModalPalette(
      surface: isDark ? const Color(0xFF1D1D22) : Colors.white,
      title: isDark ? Colors.white : const Color(0xFF15151A),
      label: isDark ? const Color(0xFFB6B6C2) : const Color(0xFF5B5B68),
      helper: isDark ? const Color(0xFF8E8E9C) : const Color(0xFF83838F),
      hint: isDark ? const Color(0xFF6E6E7C) : const Color(0xFFA2A2AE),
      input: isDark ? Colors.white : const Color(0xFF15151A),
      fieldFill: isDark ? const Color(0xFF26262D) : const Color(0xFFF5F5F8),
      fieldBorder: isDark ? const Color(0xFF33333C) : const Color(0xFFE4E4EB),
      accent: scheme.primary,
      onAccent: scheme.onPrimary,
      error: scheme.error,
    );
  }

  final Color surface;
  final Color title;
  final Color label;
  final Color helper;
  final Color hint;
  final Color input;
  final Color fieldFill;
  final Color fieldBorder;
  final Color accent;
  final Color onAccent;
  final Color error;

  @override
  bool operator ==(Object other) {
    return other is AppModalPalette &&
        other.surface == surface &&
        other.title == title &&
        other.label == label &&
        other.helper == helper &&
        other.hint == hint &&
        other.input == input &&
        other.fieldFill == fieldFill &&
        other.fieldBorder == fieldBorder &&
        other.accent == accent &&
        other.onAccent == onAccent &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(
    surface,
    title,
    label,
    helper,
    hint,
    input,
    fieldFill,
    fieldBorder,
    accent,
    onAccent,
    error,
  );
}

/// Hands one palette to every piece inside a modal, so a forced brightness
/// reaches the fields and buttons and not just the container.
class AppModalPaletteScope extends InheritedWidget {
  const AppModalPaletteScope({
    super.key,
    required this.palette,
    required super.child,
  });

  final AppModalPalette palette;

  @override
  bool updateShouldNotify(AppModalPaletteScope oldWidget) {
    return palette != oldWidget.palette;
  }
}

/// Rounded card every form modal is presented in.
///
/// Built on [Dialog] so the keyboard inset animation and the safe area that
/// `showDialog` already provides keep working; the title and the actions stay
/// pinned while only [children] scroll once the keyboard claims the screen.
class AppFormDialog extends StatelessWidget {
  const AppFormDialog({
    super.key,
    required this.title,
    required this.children,
    required this.primaryLabel,
    required this.onPrimary,
    this.subtitle,
    this.secondaryLabel,
    this.onSecondary,
    this.brightness,
  });

  final String title;

  /// Optional one-line context under the title.
  final String? subtitle;

  /// Form body — usually a list of [AppFormField].
  final List<Widget> children;

  final String primaryLabel;
  final VoidCallback? onPrimary;

  /// Omitted entirely when null, so single-action modals stay clean.
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Pins the palette instead of following the ambient theme, for modals that
  /// open over a permanently dark surface such as the stories viewer.
  final Brightness? brightness;

  @override
  Widget build(BuildContext context) {
    final forced = brightness;
    final palette = forced == null
        ? AppModalPalette.of(context)
        : AppModalPalette.forBrightness(Theme.of(context).colorScheme, forced);
    final secondary = secondaryLabel;

    return Dialog(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      clipBehavior: Clip.antiAlias,
      insetPadding: AppModalTokens.insetPadding,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(AppModalTokens.cornerRadius),
        ),
      ),
      child: AppModalPaletteScope(
        palette: palette,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppModalTokens.maxWidth),
          child: Padding(
            padding: AppModalTokens.contentPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                const SizedBox(height: AppModalTokens.titleGap),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
                ),
                const SizedBox(height: AppModalTokens.actionsGap),
                Row(
                  children: [
                    if (secondary != null) ...[
                      Expanded(
                        flex: 4,
                        child: AppDialogSecondaryButton(
                          label: secondary,
                          onPressed: onSecondary,
                        ),
                      ),
                      const SizedBox(width: AppModalTokens.actionSpacing),
                    ],
                    Expanded(
                      flex: 6,
                      child: AppDialogPrimaryButton(
                        label: primaryLabel,
                        onPressed: onPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Field caption, always above its input rather than floating in the border.
class AppFormLabel extends StatelessWidget {
  const AppFormLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppModalPalette.of(context).label,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
    );
  }
}

/// Subdued line under an input for hints, ranges or errors.
class AppFormHelperText extends StatelessWidget {
  const AppFormHelperText(this.text, {super.key, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final palette = AppModalPalette.of(context);
    return Text(
      text,
      style: TextStyle(
        color: isError ? palette.error : palette.helper,
        fontSize: 12,
        height: 1.3,
      ),
    );
  }
}

/// Label + input + helper, the single text-entry style for every modal.
///
/// [maxLength] still clamps input the way a bare `TextField` does; only the
/// default counter is replaced by the compact one on the helper row.
class AppFormField extends StatelessWidget {
  const AppFormField({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.maxLength,
    this.maxLines = 1,
    this.autofocus = false,
    this.showCoinPrefix = false,
    this.bottomGap = AppModalTokens.fieldGap,
  });

  final TextEditingController controller;
  final String? label;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLength;
  final int maxLines;
  final bool autofocus;

  /// Marks the input as a coin amount using the app-wide coin icon.
  final bool showCoinPrefix;

  final double bottomGap;

  @override
  Widget build(BuildContext context) {
    final palette = AppModalPalette.of(context);
    final helper = errorText ?? helperText;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            AppFormLabel(label!),
            const SizedBox(height: AppModalTokens.labelGap),
          ],
          TextField(
            controller: controller,
            autofocus: autofocus,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            maxLength: maxLength,
            maxLines: maxLines,
            cursorColor: palette.accent,
            style: TextStyle(
              color: palette.input,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: palette.hint,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              filled: true,
              fillColor: palette.fieldFill,
              isDense: true,
              counterText: '',
              contentPadding: AppModalTokens.fieldPadding,
              prefixIcon: showCoinPrefix
                  ? const Padding(
                      padding: EdgeInsetsDirectional.only(start: 14, end: 8),
                      child: AppCoinIcon(size: 18),
                    )
                  : null,
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              border: _border(palette.fieldBorder),
              enabledBorder: _border(palette.fieldBorder),
              focusedBorder: _border(palette.accent, width: 1.6),
              errorBorder: _border(palette.error),
              focusedErrorBorder: _border(palette.error, width: 1.6),
            ),
          ),
          if (helper != null || maxLength != null) ...[
            const SizedBox(height: AppModalTokens.helperGap),
            Row(
              children: [
                if (helper != null)
                  Expanded(
                    child: AppFormHelperText(
                      helper,
                      isError: errorText != null,
                    ),
                  )
                else
                  const Spacer(),
                if (maxLength != null)
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) => Text(
                      '${value.text.characters.length}/$maxLength',
                      style: TextStyle(
                        color: palette.hint,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppModalTokens.fieldRadius),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

/// Dominant confirm action of a modal.
class AppDialogPrimaryButton extends StatelessWidget {
  const AppDialogPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = AppModalPalette.of(context);
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: palette.accent,
        foregroundColor: palette.onAccent,
        disabledBackgroundColor: palette.accent.withValues(alpha: 0.35),
        elevation: 0,
        minimumSize: const Size.fromHeight(AppModalTokens.actionHeight),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppModalTokens.actionRadius),
          ),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }
}

/// Lighter dismiss action that sits beside [AppDialogPrimaryButton].
class AppDialogSecondaryButton extends StatelessWidget {
  const AppDialogSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = AppModalPalette.of(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: palette.label,
        minimumSize: const Size.fromHeight(AppModalTokens.actionHeight),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppModalTokens.actionRadius),
          ),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}
