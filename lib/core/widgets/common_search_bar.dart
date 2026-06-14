import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CommonSearchBar extends StatefulWidget {
  const CommonSearchBar({
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.hintText,
    this.fillColor,
    super.key,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final VoidCallback? onClear;
  final String? hintText;
  final Color? fillColor;

  @override
  State<CommonSearchBar> createState() => _CommonSearchBarState();
}

class _CommonSearchBarState extends State<CommonSearchBar> {
  late final TextEditingController _effectiveController;
  bool _showClearButton = false;

  @override
  void initState() {
    super.initState();
    _effectiveController = widget.controller ?? TextEditingController();
    _effectiveController.addListener(_onTextChanged);
    _showClearButton = _effectiveController.text.isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant CommonSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_onTextChanged);
      _effectiveController = widget.controller ?? TextEditingController();
      _effectiveController.addListener(_onTextChanged);
      _showClearButton = _effectiveController.text.isNotEmpty;
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _effectiveController.dispose();
    } else {
      _effectiveController.removeListener(_onTextChanged);
    }
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _effectiveController.text.isNotEmpty;
    if (_showClearButton != hasText) {
      setState(() {
        _showClearButton = hasText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fallbackColor = isDark ? const Color(0xFF1E1E1E) : theme.colorScheme.surface;

    final field = TextField(
      controller: _effectiveController,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      readOnly: widget.readOnly,
      onTap: widget.readOnly ? widget.onTap : null,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => widget.onSubmitted?.call(),
      style: theme.textTheme.bodyMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: TextStyle(
          color: theme.hintColor.withValues(alpha: 0.5),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          LucideIcons.search,
          size: 20,
          color: theme.hintColor,
        ),
        suffixIcon: !widget.readOnly && _showClearButton
            ? IconButton(
                icon: Icon(LucideIcons.x, size: 18, color: theme.hintColor),
                onPressed: () {
                  _effectiveController.clear();
                  widget.onClear?.call();
                  // Trigger onChanged callback with empty query if present
                  widget.onChanged?.call('');
                },
              )
            : null,
        filled: true,
        fillColor: widget.fillColor ?? fallbackColor,
        contentPadding: const EdgeInsets.symmetric(vertical: AppSizes.p12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          borderSide: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
        ),
      ),
    );

    if (widget.readOnly) {
      return GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AbsorbPointer(child: field),
      );
    }

    return field;
  }
}
