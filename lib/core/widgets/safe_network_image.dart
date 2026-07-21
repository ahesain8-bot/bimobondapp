import 'package:bimobondapp/core/utils/app_media_cache_manager.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// True when [url] is a non-empty http(s) URL that is not a video file.
bool isValidNetworkImageUrl(String? url) {
  if (url == null || url.trim().isEmpty) return false;

  final resolved = MediaUtils.resolveAbsoluteUrl(url.trim());
  final uri = Uri.tryParse(resolved);
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    return false;
  }

  final cleanUrl = resolved.toLowerCase().split('?').first;
  if (cleanUrl.contains('.m3u8')) return false;

  if (MediaUtils.isLikelyImageUrl(resolved)) return true;

  for (final ext in MediaUtils.videoExtensions) {
    if (cleanUrl.endsWith(ext)) return false;
  }

  return true;
}

class SafeNetworkImage extends StatefulWidget {
  const SafeNetworkImage({
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.errorIcon = Icons.broken_image_outlined,
    this.blankOnError = false,
    this.showLoadingIndicator = true,
    this.loadingSize,
    this.onLoadFailed,
    this.onLoaded,
    super.key,
  });

  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData errorIcon;
  final bool blankOnError;
  final bool showLoadingIndicator;
  final double? loadingSize;
  final VoidCallback? onLoadFailed;
  final VoidCallback? onLoaded;

  @override
  State<SafeNetworkImage> createState() => _SafeNetworkImageState();
}

class _SafeNetworkImageState extends State<SafeNetworkImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _imageInfo;
  bool _failed = false;
  bool _resolveStarted = false;
  bool _loadedNotified = false;
  String? _activeUrl;

  String? get _resolvedUrl {
    final raw = widget.imageUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    return MediaUtils.resolveAbsoluteUrl(raw);
  }

  bool get _hasExplicitSize {
    final width = widget.width;
    final height = widget.height;
    return width != null &&
        height != null &&
        width.isFinite &&
        height.isFinite;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureImageResolved();
  }

  @override
  void didUpdateWidget(SafeNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.width != widget.width ||
        oldWidget.height != widget.height) {
      _disposeStream();
      _imageInfo = null;
      _failed = false;
      _loadedNotified = false;
      _activeUrl = null;
      _resolveStarted = false;
      _ensureImageResolved();
      return;
    }

    if (widget.onLoaded != null &&
        oldWidget.onLoaded != widget.onLoaded &&
        (_imageInfo != null || _failed)) {
      _loadedNotified = false;
      _notifyLoaded();
    }
  }

  void _ensureImageResolved() {
    if (_resolveStarted && _activeUrl == _resolvedUrl) return;
    _resolveStarted = true;
    _resolveImage();
  }

  void _resolveImage() {
    _disposeStream();
    _imageInfo = null;

    final url = _resolvedUrl;
    _activeUrl = url;

    if (!isValidNetworkImageUrl(url)) {
      _failed = true;
      _notifyLoaded();
      if (mounted) setState(() {});
      return;
    }

    _failed = false;

    final provider = _imageProvider(url!);
    final stream = provider.resolve(createLocalImageConfiguration(context));
    _stream = stream;
    _listener = ImageStreamListener(
      (info, _) {
        if (!mounted || _activeUrl != url) return;
        setState(() {
          _imageInfo = info;
          _failed = false;
        });
        _notifyLoaded();
      },
      onError: (exception, stackTrace) {
        debugPrint('SafeNetworkImage failed for $url: $exception');
        widget.onLoadFailed?.call();
        if (!mounted || _activeUrl != url) return;
        setState(() {
          _failed = true;
          _imageInfo = null;
        });
        _notifyLoaded();
      },
    );
    stream.addListener(_listener!);
  }

  ImageProvider<Object> _imageProvider(String url) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final pixelRatio = mediaQuery?.devicePixelRatio ?? 1;
    final width = widget.width;
    final height = widget.height;

    int? cacheWidth;
    int? cacheHeight;

    // Supplying one decode dimension preserves the source aspect ratio.
    // Prefer width because most feed/grid images are width-constrained.
    if (width != null && width.isFinite && width > 0) {
      cacheWidth = (width * pixelRatio).ceil().clamp(1, 4096);
    } else if (height != null && height.isFinite && height > 0) {
      cacheHeight = (height * pixelRatio).ceil().clamp(1, 4096);
    } else {
      final screenWidth = mediaQuery?.size.width;
      if (screenWidth != null && screenWidth.isFinite && screenWidth > 0) {
        cacheWidth = (screenWidth * pixelRatio).ceil().clamp(1, 4096);
      }
    }

    // Single fetch path: downloads through the shared disk cache, so the same
    // URL is never downloaded twice (across widgets and app restarts).
    return ResizeImage.resizeIfNeeded(
      cacheWidth,
      cacheHeight,
      CachedNetworkImageProvider(
        url,
        cacheManager: AppMediaCacheManager.instance,
      ),
    );
  }

  void _notifyLoaded() {
    if (_loadedNotified) return;
    _loadedNotified = true;
    widget.onLoaded?.call();
  }

  void _disposeStream() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _disposeStream();
    super.dispose();
  }

  double get _effectiveLoadingSize {
    if (widget.loadingSize != null) return widget.loadingSize!;
    final w = widget.width;
    final h = widget.height;
    if (w != null && h != null && w.isFinite && h.isFinite) {
      // Instagram-style: small fixed spinner relative to the tile.
      return ((w < h ? w : h) * 0.22).clamp(18.0, 28.0);
    }
    return 24;
  }

  Widget _wrapSized(Widget child) {
    if (_hasExplicitSize) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: child,
      );
    }
    return SizedBox.expand(child: child);
  }

  /// Instagram-style fixed circular spinner centered on a muted fill.
  Widget _loadingPlaceholder(ThemeData theme) {
    if (!widget.showLoadingIndicator && widget.blankOnError) {
      return _wrapSized(_blackBox());
    }

    final background = widget.blankOnError
        ? Colors.black
        : theme.brightness == Brightness.light
            ? const Color(0xFFF0F0F0)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35);
    final spinnerSize = _effectiveLoadingSize;
    final spinnerColor = theme.brightness == Brightness.light
        ? const Color(0xFFB0B0B0)
        : theme.colorScheme.onSurface.withValues(alpha: 0.35);

    return _wrapSized(
      ColoredBox(
        color: background,
        child: Center(
          child: SizedBox(
            width: spinnerSize,
            height: spinnerSize,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: spinnerColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _blackBox() {
    return const ColoredBox(color: Colors.black);
  }

  Widget _placeholder(ThemeData theme) {
    if (widget.blankOnError) {
      return _wrapSized(_blackBox());
    }
    return _wrapSized(
      ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        child: Icon(
          widget.errorIcon,
          color: theme.iconTheme.color?.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_failed) {
      return _placeholder(theme);
    }

    if (_imageInfo == null) {
      return _loadingPlaceholder(theme);
    }

    Widget image = RawImage(
      image: _imageInfo!.image,
      fit: widget.fit,
      width: _hasExplicitSize ? widget.width : null,
      height: _hasExplicitSize ? widget.height : null,
      filterQuality: FilterQuality.medium,
    );

    if (!_hasExplicitSize) {
      image = SizedBox.expand(
        child: FittedBox(
          fit: widget.fit,
          clipBehavior: Clip.hardEdge,
          child: image,
        ),
      );
    }

    if (widget.borderRadius != null) {
      image = ClipRRect(borderRadius: widget.borderRadius!, child: image);
    }

    return image;
  }
}

class SafeNetworkAvatar extends StatefulWidget {
  const SafeNetworkAvatar({
    required this.imageUrl,
    required this.radius,
    this.fallbackText,
    this.backgroundColor,
    super.key,
  });

  final String? imageUrl;
  final double radius;
  final String? fallbackText;
  final Color? backgroundColor;

  @override
  State<SafeNetworkAvatar> createState() => _SafeNetworkAvatarState();
}

class _SafeNetworkAvatarState extends State<SafeNetworkAvatar> {
  bool _loadFailed = false;

  @override
  void didUpdateWidget(SafeNetworkAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadFailed = false;
    }
  }

  String? get _resolvedUrl {
    final raw = widget.imageUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    return MediaUtils.resolveAbsoluteUrl(raw);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolved = _resolvedUrl;

    if (!isValidNetworkImageUrl(resolved) || _loadFailed) {
      return _initialsAvatar(theme);
    }

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor:
          widget.backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
      child: ClipOval(
        child: SafeNetworkImage(
          imageUrl: resolved,
          width: widget.radius * 2,
          height: widget.radius * 2,
          fit: BoxFit.cover,
          errorIcon: Icons.person_outline,
          onLoadFailed: () {
            if (mounted) setState(() => _loadFailed = true);
          },
        ),
      ),
    );
  }

  Widget _initialsAvatar(ThemeData theme) {
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor:
          widget.backgroundColor ??
          theme.colorScheme.primary.withValues(alpha: 0.12),
      child: Text(
        _initials(widget.fallbackText),
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          fontSize: widget.radius * 0.55,
        ),
      ),
    );
  }

  String _initials(String? text) {
    final value = text?.trim() ?? '';
    if (value.isEmpty) return '?';
    if (value.startsWith('@')) {
      final handle = value.substring(1).trim();
      if (handle.isNotEmpty) return handle[0].toUpperCase();
    }
    final parts = value.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return value[0].toUpperCase();
  }
}

/// Precache a remote image using the disk cache.
Future<void> precacheSafeNetworkImage(BuildContext context, String url) {
  final resolved = MediaUtils.resolveAbsoluteUrl(url.trim());
  if (!isValidNetworkImageUrl(resolved)) return Future.value();
  return precacheImage(
    CachedNetworkImageProvider(
      resolved,
      cacheManager: AppMediaCacheManager.instance,
    ),
    context,
  );
}
