import 'dart:math' as math;

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/widgets/marker_bitmap_factory.dart';
import 'package:dony/features/matching/presentation/widgets/near_me_radius_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/same_address_announcements_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_announcement_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ── LocationService (unchanged) ───────────────────────────────────────────────

abstract interface class LocationService {
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<Position> getCurrentPosition();
  Future<bool> openAppSettings();
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();
  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();
  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();
  @override
  Future<Position> getCurrentPosition() =>
      Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}

// ── Internal types ────────────────────────────────────────────────────────────

enum _MarkerSide { pickup, delivery }

class _AnnouncementPoint {
  const _AnnouncementPoint(this.announcement, this.side);

  final AnnouncementModel announcement;
  final _MarkerSide side;

  LatLng get location {
    final addr = side == _MarkerSide.pickup
        ? announcement.pickupAddress
        : announcement.deliveryAddress;
    return LatLng(addr!.lat, addr.lng); // ! safe: callers filter null
  }
}

/// A lightweight cluster: one or more [_AnnouncementPoint]s with a centroid.
class _Cluster {
  _Cluster(this.items, this.centroid);

  final List<_AnnouncementPoint> items;
  final LatLng centroid;

  bool get isMultiple => items.length > 1;
  int get count => items.length;
}

// ── Lightweight grid clustering ───────────────────────────────────────────────
//
// Groups points whose lat/lng are within `cellDeg` degrees of each other.
// At zoom 3 we use ~5° cells; at zoom 10 we use 0.1° cells.

List<_Cluster> _gridCluster(
    List<_AnnouncementPoint> points, double zoom) {
  if (points.isEmpty) {
    return [];
  }
  final double cellDeg = _cellDegForZoom(zoom);
  final Map<String, List<_AnnouncementPoint>> grid = {};
  for (final p in points) {
    final lat = p.location.latitude;
    final lng = p.location.longitude;
    final key =
        '${(lat / cellDeg).floor()}_${(lng / cellDeg).floor()}';
    grid.putIfAbsent(key, () => []).add(p);
  }
  return grid.values.map((pts) {
    final avgLat =
        pts.fold<double>(0, (s, p) => s + p.location.latitude) / pts.length;
    final avgLng =
        pts.fold<double>(0, (s, p) => s + p.location.longitude) / pts.length;
    return _Cluster(pts, LatLng(avgLat, avgLng));
  }).toList();
}

double _cellDegForZoom(double zoom) {
  // Smaller cells than before so individual points stay distinct sooner
  // when zooming in. Markers are 56px wide → ~0.7° at zoom 4 still groups
  // visually overlapping pins, but separates Paris/Lyon (≈3.5° apart).
  if (zoom < 4) {
    return 3.0;
  }
  if (zoom < 6) {
    return 1.0;
  }
  if (zoom < 8) {
    return 0.3;
  }
  if (zoom < 10) {
    return 0.1;
  }
  if (zoom < 12) {
    return 0.03;
  }
  if (zoom < 14) {
    return 0.01;
  }
  return 0.003;
}

// ── Widget ────────────────────────────────────────────────────────────────────

class AnnouncementMapView extends StatefulWidget {
  const AnnouncementMapView({
    super.key,
    required this.announcements,
    this.searchDepartureCity,
    this.searchArrivalCity,
    this.locationService = const GeolocatorLocationService(),
    this.onNearMeRequested,
    this.onNearMeDisabled,
    this.isNearMeActive = false,
    this.activeRadiusKm,
    this.userPosition,
  });

  final List<AnnouncementModel> announcements;
  final String? searchDepartureCity;
  final String? searchArrivalCity;
  final LocationService locationService;
  final void Function(double userLat, double userLng, double radiusKm)?
      onNearMeRequested;
  final VoidCallback? onNearMeDisabled;
  final bool isNearMeActive;
  final double? activeRadiusKm;
  final LatLng? userPosition;

  @override
  State<AnnouncementMapView> createState() => _AnnouncementMapViewState();
}

class _AnnouncementMapViewState extends State<AnnouncementMapView> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  final Map<int, BitmapDescriptor> _clusterIcons = {};
  bool _isLocating = false;
  double _currentZoom = 3.5;

  @override
  void initState() {
    super.initState();
    _prewarmCommonIcons();
  }

  @override
  void didUpdateWidget(covariant AnnouncementMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.announcements != widget.announcements) {
      _rebuildMarkers();
    }
    // Auto-fit when "Près de moi" turns on or its radius/position changes
    // (e.g. user toggled it from the filter sheet).
    final nearMeChanged =
        oldWidget.isNearMeActive != widget.isNearMeActive ||
            oldWidget.activeRadiusKm != widget.activeRadiusKm ||
            oldWidget.userPosition != widget.userPosition;
    if (nearMeChanged &&
        widget.isNearMeActive &&
        widget.userPosition != null &&
        widget.activeRadiusKm != null) {
      _fitNearMeBounds(widget.userPosition!, widget.activeRadiusKm!);
    }
  }

  Future<void> _prewarmCommonIcons() async {
    final futures = <Future<BitmapDescriptor>>[];
    for (final mode in TransportMode.values) {
      for (final side in MarkerSide.values) {
        futures.add(MarkerBitmapFactory.pin(
          mode: mode,
          side: side,
          rating: null,
        ));
      }
    }
    await Future.wait(futures);
    if (!mounted) return;
    await _rebuildMarkers();
  }

  List<_AnnouncementPoint> _pickupPoints() => widget.announcements
      .where((a) => a.pickupAddress != null)
      .map((a) => _AnnouncementPoint(a, _MarkerSide.pickup))
      .toList();

  Future<void> _rebuildMarkers() async {
    final allPoints = [..._pickupPoints()];
    final clusters = _gridCluster(allPoints, _currentZoom);
    final futures = clusters.map((c) => _buildMarker(c));
    final built = await Future.wait(futures);
    if (mounted) {
      setState(() => _markers = built.toSet());
    }
  }

  Future<Marker> _buildMarker(_Cluster cluster) async {
    if (cluster.isMultiple) {
      final icon = await _getClusterIcon(cluster.count);
      return Marker(
        markerId: MarkerId(
            'cluster_${cluster.centroid.latitude}_${cluster.centroid.longitude}_${cluster.count}'),
        position: cluster.centroid,
        icon: icon,
        // Circle badge → centred on the position
        anchor: const Offset(0.5, 0.5),
        onTap: () => _onClusterTapped(cluster),
      );
    }
    final item = cluster.items.first;
    final icon = await MarkerBitmapFactory.pin(
      mode: item.announcement.transportMode,
      side: item.side == _MarkerSide.pickup
          ? MarkerSide.pickup
          : MarkerSide.delivery,
      rating: item.announcement.traveler?.averageRating,
    );
    // Default anchor (0.5, 1.0) lands the pin tip — drawn at the very
    // bottom-centre of the bitmap — exactly on the lat/lng coordinate.
    return Marker(
      markerId: MarkerId('${item.side.name}_${item.announcement.id}'),
      position: item.location,
      icon: icon,
      onTap: () => _onMarkerTapped(item.announcement),
    );
  }

  Future<BitmapDescriptor> _getClusterIcon(int count) async {
    if (_clusterIcons.containsKey(count)) {
      return _clusterIcons[count]!;
    }
    final icon = await MarkerBitmapFactory.clusterBadge(count);
    _clusterIcons[count] = icon;
    return icon;
  }

  void _onMarkerTapped(AnnouncementModel a) {
    final authState = context.read<AuthBloc>().state;
    final currentUserId =
        authState is AuthAuthenticated ? authState.user.id : null;
    final isOwn = currentUserId != null && a.travelerId == currentUserId;
    // Match the list view: own trips have no nav, others go to the
    // sender-side announcement detail.
    if (isOwn) return;
    showTravelerAnnouncementSheet(context, announcement: a);
  }

  void _onClusterTapped(_Cluster cluster) {
    final firstLoc = cluster.items.first.location;
    final allSameSpot = cluster.items.every((it) =>
        (it.location.latitude - firstLoc.latitude).abs() < 1e-6 &&
        (it.location.longitude - firstLoc.longitude).abs() < 1e-6);

    if (allSameSpot) {
      // Same exact address → list sheet
      final firstItem = cluster.items.first;
      final addr = firstItem.side == _MarkerSide.pickup
          ? firstItem.announcement.pickupAddress
          : firstItem.announcement.deliveryAddress;
      final authState = context.read<AuthBloc>().state;
      final currentUserId =
          authState is AuthAuthenticated ? authState.user.id : null;
      showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SameAddressAnnouncementsSheet(
          addressLabel: addr?.label ?? 'Adresse',
          announcements: cluster.items.map((it) => it.announcement).toList(),
          currentUserId: currentUserId,
          onTap: (a) {
            Navigator.pop(context);
            showTravelerAnnouncementSheet(context, announcement: a);
          },
        ),
      );
    } else {
      // Different positions → zoom in
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(cluster.centroid, math.min(_currentZoom + 2, 18)),
      );
    }
  }

  // ── "Près de moi" flow ──────────────────────────────────────────────────────

  Future<void> _onNearMeTapped() async {
    if (widget.onNearMeRequested == null) {
      return;
    }

    // 1. Check permissions FIRST (may show system dialog)
    var permission = await widget.locationService.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      _showPermissionDeniedSheet(true);
      return;
    }
    if (permission == LocationPermission.denied) {
      permission = await widget.locationService.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showPermissionDeniedSheet(
          permission == LocationPermission.deniedForever);
      return;
    }

    if (!mounted) {
      return;
    }

    // 2. Start GPS lookup IN PARALLEL (no await yet)
    final positionFuture = widget.locationService.getCurrentPosition();

    // 3. Show radius bottom sheet IMMEDIATELY (user can interact)
    final radiusKm = await showModalBottomSheet<double>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NearMeRadiusSheet(
        initialRadiusKm: widget.activeRadiusKm ?? 25,
      ),
    );

    if (radiusKm == null || !mounted) {
      return;
    }

    // 4. Now await GPS (often already done) — show spinner if still pending
    setState(() => _isLocating = true);
    try {
      final pos = await positionFuture;
      if (!mounted) {
        return;
      }
      // Trigger parent state update — didUpdateWidget will auto-fit the camera
      // once the new props (userPosition, activeRadiusKm, isNearMeActive)
      // propagate. No need to animate here.
      widget.onNearMeRequested!(pos.latitude, pos.longitude, radiusKm);
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  void _showPermissionDeniedSheet(bool isPermanent) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PermissionDeniedSheet(
        key: const Key('permission-denied-sheet'),
        onOpenSettings: () async {
          ctx.pop();
          await widget.locationService.openAppSettings();
        },
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(30.0, -5.0),
            zoom: 3.5,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
            _fitInitialBounds();
          },
          onCameraMove: (position) {
            _currentZoom = position.zoom;
          },
          onCameraIdle: () {
            _rebuildMarkers();
          },
          markers: _markers,
          circles: _radiusCircle(),
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
        ),
        Positioned(
          bottom: DonySpacing.lg + 26,
          right: DonySpacing.lg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NearMeFab(
                key: const Key('near-me-fab'),
                isActive: widget.isNearMeActive,
                isLoading: _isLocating,
                radiusKm: widget.activeRadiusKm,
                onTap: _onNearMeTapped,
                onDoubleTap: widget.isNearMeActive
                    ? widget.onNearMeDisabled
                    : null,
              ),
              const SizedBox(height: 8),
              _ZoomButton(
                icon: Icons.add_rounded,
                onTap: () async {
                  final controller = _mapController;
                  if (controller != null) {
                    await controller.animateCamera(CameraUpdate.zoomIn());
                  }
                },
              ),
              _ZoomButton(
                icon: Icons.remove_rounded,
                onTap: () async {
                  final controller = _mapController;
                  if (controller != null) {
                    await controller.animateCamera(CameraUpdate.zoomOut());
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Set<Circle> _radiusCircle() {
    if (!widget.isNearMeActive ||
        widget.userPosition == null ||
        widget.activeRadiusKm == null) {
      return {};
    }
    return {
      Circle(
        circleId: const CircleId('near-me-radius'),
        center: widget.userPosition!,
        radius: widget.activeRadiusKm! * 1000,
        strokeColor: DonyColors.primary,
        strokeWidth: 2,
        fillColor: DonyColors.primary.withValues(alpha: 0.08),
      ),
    };
  }

  Future<void> _fitNearMeBounds(LatLng center, double radiusKm) async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }
    // 1° latitude ≈ 111 km ; longitude shrinks by cos(lat) towards the poles.
    final latDelta = radiusKm / 111.0;
    final lngDelta = radiusKm /
        (111.0 * math.cos(center.latitude * math.pi / 180).abs());
    final bounds = LatLngBounds(
      southwest:
          LatLng(center.latitude - latDelta, center.longitude - lngDelta),
      northeast:
          LatLng(center.latitude + latDelta, center.longitude + lngDelta),
    );
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60.0));
  }

  Future<void> _fitInitialBounds() async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }
    final allPoints = <LatLng>[
      ..._pickupPoints().map((it) => it.location),
    ];
    if (allPoints.isEmpty) {
      return;
    }
    final bounds = _boundsFromPoints(allPoints);
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60.0));
  }

  LatLngBounds _boundsFromPoints(List<LatLng> points) {
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}

// ── _NearMeFab ────────────────────────────────────────────────────────────────

class _NearMeFab extends StatelessWidget {
  const _NearMeFab({
    super.key,
    required this.isActive,
    required this.isLoading,
    required this.radiusKm,
    required this.onTap,
    this.onDoubleTap,
  });

  final bool isActive;
  final bool isLoading;
  final double? radiusKm;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      onDoubleTap: isLoading ? null : onDoubleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isActive ? DonyColors.primary : DonyColors.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? DonyColors.primary : DonyColors.borderDefault,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isActive ? Colors.white : DonyColors.primary,
                  ),
                )
              : Icon(
                  isActive
                      ? Icons.my_location_rounded
                      : Icons.my_location_outlined,
                  size: 22,
                  color: isActive ? Colors.white : DonyColors.primary,
                ),
        ),
      ),
    );
  }
}

// ── _ZoomButton ───────────────────────────────────────────────────────────────

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: DonyColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: DonyColors.borderDefault),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 22,
          color: DonyColors.primary,
        ),
      ),
    );
  }
}

// ── _PermissionDeniedSheet ───────────────────────────────────────────────────

class _PermissionDeniedSheet extends StatelessWidget {
  const _PermissionDeniedSheet({super.key, required this.onOpenSettings});
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.fromLTRB(
        DonySpacing.lg,
        0,
        DonySpacing.lg,
        MediaQuery.of(context).padding.bottom + DonySpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: DonyColors.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(DonyRadius.sheet)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: DonySpacing.md),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DonyColors.neutral200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Icon(Icons.location_off_rounded,
              size: 48, color: DonyColors.primary),
          const SizedBox(height: DonySpacing.md),
          Text('Géolocalisation désactivée',
              style: tt.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: DonySpacing.sm),
          Text(
            "Autorise l'accès à ta position dans les réglages pour utiliser \"Près de moi\".",
            style: tt.bodyMedium?.copyWith(color: DonyColors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.xl),
          DonyButton(label: 'Ouvrir les réglages', onPressed: onOpenSettings),
        ],
      ),
    );
  }
}
