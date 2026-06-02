import 'package:bimobondapp/core/utils/media_utils.dart';
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

  return !MediaUtils.isVideo(resolved);
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
    this.onLoadFailed,
    super.key,
  });

  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData errorIcon;

  /// When true, loading/error states are solid black with no icon (e.g. video posters).
  final bool blankOnError;
  final VoidCallback? onLoadFailed;

  @override
  State<SafeNetworkImage> createState() => _SafeNetworkImageState();
}

class _SafeNetworkImageState extends State<SafeNetworkImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _imageInfo;
  bool _failed = false;
  bool _resolveStarted = false;

  String? get _resolvedUrl {
    final raw = widget.imageUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    return MediaUtils.resolveAbsoluteUrl(raw);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_resolveStarted) {
      _resolveStarted = true;
      _resolveImage();
    }
  }

  @override
  void didUpdateWidget(SafeNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _disposeStream();
      _imageInfo = null;
      _failed = false;
      _resolveStarted = true;
      _resolveImage();
    }
  }

  void _resolveImage() {
    final url = _resolvedUrl;
    if (!isValidNetworkImageUrl(url)) {
      _failed = true;
      return;
    }

    final provider = NetworkImage(url!);
    final stream = provider.resolve(createLocalImageConfiguration(context));
    _stream = stream;
    _listener = ImageStreamListener(
      (info, _) {
        if (!mounted) return;
        setState(() {
          _imageInfo = info;
          _failed = false;
        });
      },
      onError: (exception, stackTrace) {
        debugPrint('SafeNetworkImage failed for $url: $exception');
        widget.onLoadFailed?.call();
        if (!mounted) return;
        setState(() {
          _failed = true;
          _imageInfo = null;
        });
      },
    );
    stream.addListener(_listener!);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_failed) {
      return _placeholder(theme);
    }

    if (_imageInfo == null) {
      if (widget.blankOnError) {
        return _blackBox();
      }
      return Container(
        width: widget.width,
        height: widget.height,
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
            ),
          ),
        ),
      );
    }

    Widget image = RawImage(
      image: _imageInfo!.image,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      filterQuality: FilterQuality.medium,
    );

    if (widget.borderRadius != null) {
      image = ClipRRect(borderRadius: widget.borderRadius!, child: image);
    }

    return image;
  }

  Widget _blackBox() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.black,
    );
  }

  Widget _placeholder(ThemeData theme) {
    if (widget.blankOnError) {
      return _blackBox();
    }
    return Container(
      width: widget.width,
      height: widget.height,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Icon(
        widget.errorIcon,
        color: theme.iconTheme.color?.withValues(alpha: 0.35),
      ),
    );
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
          widget.backgroundColor ??
          theme.colorScheme.surfaceContainerHighest,
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
