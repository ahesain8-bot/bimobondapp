import 'dart:math' as math;

import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart';
import 'package:bimobondapp/core/data/user_location_store.dart';
import 'package:bimobondapp/core/services/app_location_service.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Read-only map preview showing the user's location and geo-target radius.
class PromoteRadiusMapPreview extends StatefulWidget {
  const PromoteRadiusMapPreview({
    super.key,
    required this.radiusKm,
  });

  final int radiusKm;

  @override
  State<PromoteRadiusMapPreview> createState() => _PromoteRadiusMapPreviewState();
}

class _PromoteRadiusMapPreviewState extends State<PromoteRadiusMapPreview> {
  final MapController _mapController = MapController();

  LatLng? _center;
  bool _loading = true;
  bool _requestingLocation = false;

  @override
  void initState() {
    super.initState();
    _resolveLocation();
  }

  @override
  void didUpdateWidget(PromoteRadiusMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.radiusKm != widget.radiusKm && _center != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitToRadius());
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _resolveLocation({bool requestIfMissing = true}) async {
    setState(() {
      _loading = true;
      _requestingLocation = requestIfMissing;
    });

    final store = sl<UserLocationStore>();
    if (store.hasLocation) {
      _setCenter(LatLng(store.latitude!, store.longitude!));
      return;
    }

    if (!requestIfMissing) {
      setState(() {
        _loading = false;
        _requestingLocation = false;
      });
      return;
    }

    final granted = await sl<AppLocationService>().requestAndSaveLocation();
    if (!mounted) return;

    if (granted && store.hasLocation) {
      _setCenter(LatLng(store.latitude!, store.longitude!));
      return;
    }

    setState(() {
      _loading = false;
      _requestingLocation = false;
    });
  }

  void _setCenter(LatLng center) {
    setState(() {
      _center = center;
      _loading = false;
      _requestingLocation = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitToRadius());
  }

  void _fitToRadius() {
    final center = _center;
    if (center == null) return;

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: SizedBox(
        height: 196,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: _buildBody(context, l10n, scheme),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme scheme,
  ) {
    if (_loading) {
      return const Center(child: CustomLoadingWidget());
    }

    final center = _center;
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
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                ),
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
                  LucideIcons.navigation,
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
