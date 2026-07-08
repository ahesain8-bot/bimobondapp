import 'dart:async';
import 'dart:math' as math;

import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart';
import 'package:bimobondapp/core/data/user_location_store.dart';
import 'package:bimobondapp/core/services/app_location_service.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/geo_place_resolver.dart';
import 'package:bimobondapp/core/utils/google_maps_constants.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Interactive map for geo-targeting: tap to pick center, default is user location.
class PromoteRadiusMapPreview extends StatefulWidget {
  const PromoteRadiusMapPreview({
    super.key,
    required this.radiusKm,
    this.latitude,
    this.longitude,
    required this.onCenterChanged,
    this.detectLocation = false,
  });

  final int radiusKm;
  final double? latitude;
  final double? longitude;
  final ValueChanged<LatLng> onCenterChanged;
  final bool detectLocation;

  @override
  State<PromoteRadiusMapPreview> createState() =>
      _PromoteRadiusMapPreviewState();
}

class _PromoteRadiusMapPreviewState extends State<PromoteRadiusMapPreview> {
  GoogleMapController? _mapController;

  LatLng? _userLocation;
  LatLng? _center;
  bool _requestingLocation = false;
  bool _resolvingPlace = false;
  bool _mapReady = false;
  bool _mountMap = false;
  bool _locationUnavailable = false;
  GeoPlaceInfo? _placeInfo;
  Timer? _placeDebounce;
  int _placeRequestId = 0;

  LatLng get _fallbackCenter => const LatLng(
    GoogleMapsConstants.fallbackLatitude,
    GoogleMapsConstants.fallbackLongitude,
  );

  LatLng get _selectedCenter => _center ?? _userLocation ?? _fallbackCenter;

  @override
  void initState() {
    super.initState();
    _syncCenterFromWidget(fallbackToUser: false);
    _center ??= _fallbackCenter;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _mountMap = true);
    });
    unawaited(_bootstrap());
  }

  void _syncCenterFromWidget({required bool fallbackToUser}) {
    final lat = widget.latitude;
    final lng = widget.longitude;
    if (lat != null && lng != null) {
      _center = LatLng(lat, lng);
      return;
    }
    if (fallbackToUser && _userLocation != null) {
      _center = _userLocation;
    }
  }

  Future<void> _bootstrap() async {
    await _resolveLocation(requestIfMissing: widget.detectLocation);
    if (!mounted) return;
    _syncCenterFromWidget(fallbackToUser: true);
    _schedulePlaceLookup(_selectedCenter);
    _scheduleCameraFit();
  }

  @override
  void didUpdateWidget(PromoteRadiusMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final centerChanged =
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude;
    final radiusChanged = oldWidget.radiusKm != widget.radiusKm;
    final detectChanged = oldWidget.detectLocation != widget.detectLocation;

    if (detectChanged && widget.detectLocation) {
      unawaited(_resolveLocation(requestIfMissing: true));
    }

    if (centerChanged) {
      setState(() => _syncCenterFromWidget(fallbackToUser: false));
      _schedulePlaceLookup(_selectedCenter);
    }

    if (centerChanged || radiusChanged) {
      _scheduleCameraFit();
    }
  }

  void _scheduleCameraFit() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitToRadius());
  }

  void _setCenter(LatLng point, {required bool notifyParent}) {
    setState(() => _center = point);
    if (notifyParent) {
      widget.onCenterChanged(point);
    }
    _schedulePlaceLookup(point);
    _scheduleCameraFit();
  }

  @override
  void dispose() {
    _placeDebounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _schedulePlaceLookup(LatLng? center) {
    _placeDebounce?.cancel();
    if (center == null) {
      setState(() {
        _resolvingPlace = false;
        _placeInfo = null;
      });
      return;
    }

    setState(() => _resolvingPlace = true);
    _placeDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_resolvePlaceLabel(center));
    });
  }

  Future<void> _resolvePlaceLabel(LatLng center) async {
    final requestId = ++_placeRequestId;
    final place = await GeoPlaceResolver.resolve(
      latitude: center.latitude,
      longitude: center.longitude,
    );
    if (!mounted || requestId != _placeRequestId) return;
    setState(() {
      _placeInfo = place;
      _resolvingPlace = false;
    });
  }

  Future<void> _resolveLocation({bool requestIfMissing = true}) async {
    if (!requestIfMissing) return;

    setState(() => _requestingLocation = true);

    final store = sl<UserLocationStore>();
    if (store.viewerCoordinates != null) {
      _applyUserLocation(
        LatLng(store.latitude!, store.longitude!),
        notifyParent: widget.latitude == null || widget.longitude == null,
      );
      return;
    }

    if (!requestIfMissing) {
      _applyFallbackCenter(
        notifyParent: widget.latitude == null && widget.longitude == null,
      );
      return;
    }

    final granted = await sl<AppLocationService>().ensureViewerLocation();
    if (!mounted) return;

    if (granted && store.viewerCoordinates != null) {
      _applyUserLocation(
        LatLng(store.latitude!, store.longitude!),
        notifyParent: widget.latitude == null || widget.longitude == null,
      );
      return;
    }

    _applyFallbackCenter(
      notifyParent: widget.latitude == null && widget.longitude == null,
    );
  }

  void _applyFallbackCenter({required bool notifyParent}) {
    final fallback = _fallbackCenter;
    final shouldNotify = notifyParent && _center == null;
    setState(() {
      _requestingLocation = false;
      _locationUnavailable = _userLocation == null;
      _center ??= fallback;
    });
    if (shouldNotify) {
      widget.onCenterChanged(fallback);
    }
    _schedulePlaceLookup(_selectedCenter);
    _scheduleCameraFit();
  }

  void _applyUserLocation(LatLng location, {required bool notifyParent}) {
    setState(() {
      _userLocation = location;
      _requestingLocation = false;
      _locationUnavailable = false;
      if (_center == null || notifyParent) {
        _center = location;
      }
    });
    if (notifyParent) {
      widget.onCenterChanged(location);
    }
    _schedulePlaceLookup(_selectedCenter);
    _scheduleCameraFit();
  }

  void _onMapTap(LatLng point) {
    _setCenter(point, notifyParent: true);
  }

  void _resetToUserLocation() {
    final userLocation = _userLocation;
    if (userLocation == null) {
      unawaited(_resolveLocation(requestIfMissing: true));
      return;
    }
    _setCenter(userLocation, notifyParent: true);
  }

  bool get _isAtUserLocation {
    final userLocation = _userLocation;
    final center = _selectedCenter;
    if (userLocation == null) return true;
    return (userLocation.latitude - center.latitude).abs() < 0.00001 &&
        (userLocation.longitude - center.longitude).abs() < 0.00001;
  }

  Future<void> _fitToRadius() async {
    final controller = _mapController;
    final center = _selectedCenter;
    if (controller == null || !_mapReady) return;

    final km = widget.radiusKm.toDouble().clamp(1, 500);
    final latDelta = km / 111.0;
    final lngDelta = km / (111.0 * math.cos(center.latitude * math.pi / 180));

    final bounds = LatLngBounds(
      southwest: LatLng(
        center.latitude - latDelta,
        center.longitude - lngDelta,
      ),
      northeast: LatLng(
        center.latitude + latDelta,
        center.longitude + lngDelta,
      ),
    );

    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 28),
      );
    } catch (_) {}
  }

  void _onMapReady(GoogleMapController controller) {
    _mapController = controller;
    _mapReady = true;
    _fitToRadius();
  }

  Set<Circle> _buildCircles(ColorScheme scheme, LatLng center) {
    return {
      Circle(
        circleId: const CircleId('promote_radius'),
        center: center,
        radius: widget.radiusKm * 1000,
        fillColor: scheme.primary.withValues(alpha: 0.18),
        strokeColor: scheme.primary,
        strokeWidth: 2,
      ),
    };
  }

  Set<Marker> _buildMarkers(ColorScheme scheme, LatLng center) {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('promote_center'),
        position: center,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    };

    final userLocation = _userLocation;
    if (userLocation != null && !_isAtUserLocation) {
      markers.add(
        Marker(
          markerId: const MarkerId('promote_user'),
          position: userLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.promoteGeoMapHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 196,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: _buildMapBody(context, l10n, scheme),
          ),
        ),
        const SizedBox(height: 8),
        _buildPlaceLabel(theme, scheme),
        if (_userLocation != null && !_isAtUserLocation) ...[
          const SizedBox(height: 6),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: _resetToUserLocation,
              icon: Icon(
                LucideIcons.crosshair,
                size: 16,
                color: scheme.primary,
              ),
              label: Text(l10n.promoteGeoUseMyLocation),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlaceLabel(ThemeData theme, ColorScheme scheme) {
    if (_resolvingPlace) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: scheme.primary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            AppLocalizations.of(context)!.promoteGeoPlaceLoading,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    final place = _placeInfo;
    if (place == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlaceDetailRow(
            icon: LucideIcons.building2,
            label: AppLocalizations.of(context)!.promoteGeoCity,
            value: place.city,
            scheme: scheme,
            theme: theme,
          ),
          const SizedBox(height: 6),
          _PlaceDetailRow(
            icon: LucideIcons.map,
            label: AppLocalizations.of(context)!.promoteGeoRegion,
            value: place.region,
            scheme: scheme,
            theme: theme,
          ),
          const SizedBox(height: 6),
          _PlaceDetailRow(
            icon: LucideIcons.flag,
            label: AppLocalizations.of(context)!.promoteGeoCountry,
            value: place.country,
            scheme: scheme,
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildMapBody(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme scheme,
  ) {
    final center = _selectedCenter;
    final usingFallback = _locationUnavailable;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (!_mountMap)
          const Center(child: CustomLoadingWidget(size: 28))
        else
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: CameraPosition(target: center, zoom: 11),
            onMapCreated: _onMapReady,
            onTap: _onMapTap,
            circles: _buildCircles(scheme, center),
            markers: _buildMarkers(scheme, center),
            myLocationEnabled: _userLocation != null,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            liteModeEnabled: false,
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            },
          ),
        if (usingFallback)
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  l10n.chatLocationPermissionDenied,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ),
        if (_requestingLocation)
          const Center(child: CustomLoadingWidget(size: 28)),
      ],
    );
  }
}

class _PlaceDetailRow extends StatelessWidget {
  const _PlaceDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.scheme,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final String value;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: scheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
