import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// String Extensions
extension StringExtensions on String {
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String get toTitleCase {
    if (isEmpty) return this;
    return split(' ').map((word) => word.capitalize).join(' ');
  }

  String get ellipsize {
    if (length <= 20) return this;
    return '${substring(0, 17)}...';
  }

  String truncate(int maxLength) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - 3)}...';
  }
}

// Number Extensions
extension NumberExtensions on num {
  String get formatNumber {
    if (this >= 1000000) {
      return '${(this / 1000000).toStringAsFixed(1)}M';
    } else if (this >= 1000) {
      return '${(this / 1000).toStringAsFixed(1)}K';
    }
    return toString();
  }

  String get formatCompact {
    final formatter = NumberFormat.compact();
    return formatter.format(this);
  }

  String get formatCurrency {
    final formatter = NumberFormat.currency(symbol: '\$');
    return formatter.format(this);
  }

  Duration get milliseconds => Duration(milliseconds: toInt());
  Duration get seconds => Duration(seconds: toInt());
  Duration get minutes => Duration(minutes: toInt());
  Duration get hours => Duration(hours: toInt());
  Duration get days => Duration(days: toInt());
}

// DateTime Extensions
extension DateTimeExtensions on DateTime {
  String get formatDate => DateFormat('MMM dd, yyyy').format(this);
  String get formatTime => DateFormat('HH:mm').format(this);
  String get formatDateTime => DateFormat('MMM dd, yyyy HH:mm').format(this);
  String get formatRelative => _getRelativeTime(this);

  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && month == yesterday.month && day == yesterday.day;
  }
}

// Widget Extensions
extension WidgetExtensions on Widget {
  Widget get center => Center(child: this);
  Widget get expanded => Expanded(child: this);
  Widget get flexible => Flexible(child: this);

  Widget padding(EdgeInsetsGeometry padding) => Padding(padding: padding, child: this);
  Widget paddingAll(double value) => Padding(padding: EdgeInsets.all(value), child: this);
  Widget paddingHorizontal(double value) => Padding(padding: EdgeInsets.symmetric(horizontal: value), child: this);
  Widget paddingVertical(double value) => Padding(padding: EdgeInsets.symmetric(vertical: value), child: this);

  Widget margin(EdgeInsetsGeometry margin) => Container(margin: margin, child: this);
  Widget marginAll(double value) => Container(margin: EdgeInsets.all(value), child: this);

  Widget align([AlignmentGeometry alignment = Alignment.center]) => Align(alignment: alignment, child: this);

  Widget hero(String tag) => Hero(tag: tag, child: this);

  Widget materialize([Color? color]) => Material(
    type: MaterialType.transparency,
    color: color,
    child: this,
  );

  Widget ignorePointer({bool ignoring = true}) => IgnorePointer(ignoring: ignoring, child: this);
  Widget absorbPointer({bool absorbing = true}) => AbsorbPointer(absorbing: absorbing, child: this);

  Widget withConstraints(BoxConstraints constraints) => ConstrainedBox(
    constraints: constraints,
    child: this,
  );

  Widget withSize({double? width, double? height}) => SizedBox(
    width: width,
    height: height,
    child: this,
  );

  Widget withOpacity(double opacity) => Opacity(
    opacity: opacity,
    child: this,
  );

  Widget withRotation(double turns) => RotatedBox(
    quarterTurns: (turns * 4).round(),
    child: this,
  );

  Widget withScale(double scale) => Transform.scale(
    scale: scale,
    child: this,
  );

  Widget withTranslate(Offset offset) => Transform.translate(
    offset: offset,
    child: this,
  );

  Widget onTap(VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: this,
  );

  Widget onLongPress(VoidCallback onLongPress) => GestureDetector(
    onLongPress: onLongPress,
    child: this,
  );

  Widget withBorderRadius(BorderRadius borderRadius) => ClipRRect(
    borderRadius: borderRadius,
    child: this,
  );

  Widget circleClip() => ClipOval(child: this);

  Widget withShadow({
    Color color = Colors.black,
    double blurRadius = 10,
    double spreadRadius = 0,
    Offset offset = Offset.zero,
  }) => Container(
    decoration: BoxDecoration(
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.3),
          blurRadius: blurRadius,
          spreadRadius: spreadRadius,
          offset: offset,
        ),
      ],
    ),
    child: this,
  );
}

// BuildContext Extensions
extension BuildContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => theme.colorScheme;
  TextTheme get textTheme => theme.textTheme;
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  Size get screenSize => mediaQuery.size;
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;
  double get paddingTop => mediaQuery.padding.top;
  double get paddingBottom => mediaQuery.padding.bottom;
  bool get isKeyboardOpen => mediaQuery.viewInsets.bottom > 0;
  bool get isPortrait => screenWidth < screenHeight;
  bool get isLandscape => screenWidth >= screenHeight;

  void pop<T>([T? result]) => Navigator.of(this).pop(result);
  void unfocus() => FocusScope.of(this).unfocus();

  void showSnackBar(String message, {SnackBarAction? action, Duration? duration}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        duration: duration ?? const Duration(seconds: 4),
      ),
    );
  }

  Future<T?> navigateTo<T>(Widget page) => Navigator.of(this).push<T>(
    MaterialPageRoute(builder: (_) => page),
  );

  Future<T?> replaceWith<T>(Widget page) => Navigator.of(this).pushReplacement<T, dynamic>(
    MaterialPageRoute(builder: (_) => page),
  );

  Future<T?> navigateAndRemoveUntil<T>(Widget page) => Navigator.of(this).pushAndRemoveUntil<T>(
    MaterialPageRoute(builder: (_) => page),
    (_) => false,
  );
}

// List Extensions
extension ListExtensions<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
  T? get lastOrNull => isEmpty ? null : last;

  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }

  List<T> unique() => toSet().toList();

  List<T> separated(T separator) {
    if (length <= 1) return this;
    final result = <T>[];
    for (var i = 0; i < length; i++) {
      result.add(this[i]);
      if (i < length - 1) result.add(separator);
    }
    return result;
  }
}

// Nullable Extensions
extension NullableExtensions<T> on T? {
  R? map<R>(R Function(T) transform) => this != null ? transform(this as T) : null;
  T orElse(T defaultValue) => this ?? defaultValue;
  T? orElseNullable(T? defaultValue) => this ?? defaultValue;
  bool get isNull => this == null;
  bool get isNotNull => this != null;
}
