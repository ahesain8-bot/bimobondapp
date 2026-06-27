import 'dart:async';
import 'dart:math' as math;

import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart';
import 'package:bimobondapp/core/data/user_location_store.dart';
import 'package:bimobondapp/core/services/app_location_service.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/geo_place_resolver.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
  final MapController _mapController = MapController();

  LatLng? _userLocation;
  LatLng? _center;
  bool _loading = true;
  bool _requestingLocation = false;
  bool _resolvingPlace = false;
  bool _mapReady = false;
  GeoPlaceInfo? _placeInfo;
  Timer? _placeDebounce;
  int _placeRequestId = 0;

  LatLng? get _selectedCenter => _center ?? _userLocation;

  @override
  void initState() {
    super.initState();
    _syncCenterFromWidget(fallbackToUser: false);
    if (_center != null) {
      _loading = false;
    }
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
    if (_selectedCenter != null) {
      _scheduleCameraFit();
    }
  }

  @override
  void didUpdateWidget(PromoteRadiusMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final centerChanged =
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude;
    final radiusChanged = oldWidget.radiusKm != widget.radiusKm;
    final detectChanged = oldWidget.detectLocation != widget.detectLocation;

    if (detectChanged && widget.detectLocation && !_loading) {
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
    _mapController.dispose();
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
    setState(() {
      _loading = true;
      _requestingLocation = requestIfMissing;
    });

    final store = sl<UserLocationStore>();
    if (store.viewerCoordinates != null) {
      _applyUserLocation(
        LatLng(store.latitude!, store.longitude!),
        notifyParent: widget.latitude == null || widget.longitude == null,
      );
      return;
    }

    if (!requestIfMissing) {
      setState(() {
        _loading = false;
        _requestingLocation = false;
      });
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

    setState(() {
      _loading = false;
      _requestingLocation = false;
    });
  }

  void _applyUserLocation(LatLng location, {required bool notifyParent}) {
    setState(() {
      _userLocation = location;
      _loading = false;
      _requestingLocation = false;
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

  void _onMapTap(TapPosition _, LatLng point) {
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
    if (userLocation == null || center == null) return true;
    return (userLocation.latitude - center.latitude).abs() < 0.00001 &&
        (userLocation.longitude - center.longitude).abs() < 0.00001;
  }

  void _fitToRadius() {
    final center = _selectedCenter;
    if (center == null || !_mapReady) return;

    final km = widget.radiusKm.toDouble().clamp(1, 500);
    final latDelta = km / 111.0;
    final lngDelta = km / (111.0 * math.cos(center.latitude * math.pi / 180));

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(center.latitude - latDelta, center.longitude - lngDelta),
          LatLng(center.latitude + latDelta, center.longitude + lngDelta),
        ),
        padding: const EdgeInsets.all(28),
      ),
    );
  }

  void _onMapReady() {
    _mapReady = true;
    _fitToRadius();
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
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          child: SizedBox(
            height: 196,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: _buildMapBody(context, l10n, scheme),
            ),
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
    if (_loading) {
      return const SkeletonWidget(height: double.infinity, borderRadius: 0);
    }

    final center = _selectedCenter;
    if (center == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.mapPinOff,
                size: 28,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.chatLocationPermissionDenied,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _requestingLocation
                    ? null
                    : () => _resolveLocation(requestIfMissing: true),
                child: _requestingLocation
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CustomLoadingWidget(size: 18),
                      )
                    : Text(l10n.notificationsRetry),
              ),
            ],
          ),
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 10,
        onMapReady: _onMapReady,
        onTap: _onMapTap,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.dubai.bimobondapp',
        ),
        CircleLayer(
          circles: [
            CircleMarker(
              point: center,
              radius: widget.radiusKm * 1000,
              useRadiusInMeter: true,
              color: scheme.primary.withValues(alpha: 0.18),
              borderColor: scheme.primary,
              borderStrokeWidth: 2,
            ),
          ],
        ),
        if (_userLocation != null && !_isAtUserLocation)
          MarkerLayer(
            markers: [
              Marker(
                point: _userLocation!,
                width: 14,
                height: 14,
                alignment: Alignment.center,
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.secondary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: center,
              width: 36,
              height: 36,
              alignment: Alignment.center,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  LucideIcons.mapPin,
                  size: 16,
                  color: scheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
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
