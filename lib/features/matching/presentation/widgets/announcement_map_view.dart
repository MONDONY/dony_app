import 'dart:math' as math;

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/marker_bitmap_factory.dart';
import 'package:dony/features/matching/presentation/widgets/marker_urgency.dart';
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

enum _MarkerSide { pickup }

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
  _Cluster(this.items, this.centroid, {required this.isSameSpot});

  final List<_AnnouncementPoint> items;
  final LatLng centroid;
  /// True when all items are within ~10 m of each other (same building/address).
  /// Pre-computed at cluster-build time so tap handlers don't need to recheck.
  final bool isSameSpot;

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

    // Pre-compute whether all items share the same physical address (~10 m).
    // 1e-4° ≈ 11 m at equator — captures same-building geocoding variations.
    const kSameSpot = 1e-4;
    final first = pts.first.location;
    final isSameSpot = pts.every(
      (p) =>
          (p.location.latitude - first.latitude).abs() < kSameSpot &&
          (p.location.longitude - first.longitude).abs() < kSameSpot,
    );

    return _Cluster(pts, LatLng(avgLat, avgLng), isSameSpot: isSameSpot);
  }).toList();
}

/// Merges singleton clusters whose single point falls within [kSameSpot]
/// degrees of another singleton's point.
///
/// This is needed because two addresses at the same physical location can
/// straddle a grid-cell boundary (especially at high zoom where cellDeg is
/// small), producing two separate 1-item clusters instead of one 2-item
/// same-spot cluster.
List<_Cluster> _mergeSameSpotSingletons(List<_Cluster> clusters) {
  const kSameSpot = 1e-4;

  final multi = <_Cluster>[];
  final singles = <_Cluster>[];

  for (final c in clusters) {
    if (c.isMultiple) {
      multi.add(c);
    } else {
      singles.add(c);
    }
  }

  if (singles.length < 2) return [...multi, ...singles];

  final used = List.filled(singles.length, false);
  final merged = <_Cluster>[];

  for (int i = 0; i < singles.length; i++) {
    if (used[i]) continue;
    final group = [singles[i]];
    used[i] = true;
    final locI = singles[i].items.first.location;

    for (int j = i + 1; j < singles.length; j++) {
      if (used[j]) continue;
      final locJ = singles[j].items.first.location;
      if ((locI.latitude - locJ.latitude).abs() < kSameSpot &&
          (locI.longitude - locJ.longitude).abs() < kSameSpot) {
        group.add(singles[j]);
        used[j] = true;
      }
    }

    if (group.length == 1) {
      merged.add(singles[i]);
    } else {
      final allItems = group.expand((c) => c.items).toList();
      final avgLat =
          allItems.fold<double>(0, (s, p) => s + p.location.latitude) /
              allItems.length;
      final avgLng =
          allItems.fold<double>(0, (s, p) => s + p.location.longitude) /
              allItems.length;
      merged.add(_Cluster(allItems, LatLng(avgLat, avgLng), isSameSpot: true));
    }
  }

  return [...multi, ...merged];
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

// ── Map style (beige/crème, style Cocolis) ────────────────────────────────────

/// Custom map style (beige/cream, Cocolis-inspired). Pass to [AnnouncementMapView.mapStyle].
const String kAnnouncementMapStyle = '''[
  {"elementType":"geometry","stylers":[{"color":"#f5f0e8"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#746855"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#f5f1e6"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative.land_parcel","elementType":"labels.text.fill","stylers":[{"color":"#ae9e90"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road.arterial","elementType":"labels.text.fill","stylers":[{"color":"#93817c"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#f8c967"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#e9bc62"}]},
  {"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#806b63"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry.fill","stylers":[{"color":"#b9d3c2"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#92998d"}]}
]''';

// ── Widget ────────────────────────────────────────────────────────────────────

class AnnouncementMapView extends StatefulWidget {
  const AnnouncementMapView({
    super.key,
    required this.announcements,
    this.extraMarkers = const {},
    this.searchDepartureCity,
    this.searchArrivalCity,
    this.locationService = const GeolocatorLocationService(),
    this.onNearMeRequested,
    this.onNearMeDisabled,
    this.isNearMeActive = false,
    this.activeRadiusKm,
    this.userPosition,
    this.fabBottomPadding = 0,
    this.mapStyle,
    this.selectedAnnouncementId,
    this.onAnnouncementSelected,
  });

  final List<AnnouncementModel> announcements;
  /// Additional markers to render alongside announcement markers (e.g. package requests).
  /// They bypass the cluster logic and are drawn as-is.
  final Set<Marker> extraMarkers;
  final String? searchDepartureCity;
  final String? searchArrivalCity;
  final LocationService locationService;
  final void Function(double userLat, double userLng, double radiusKm)?
      onNearMeRequested;
  final VoidCallback? onNearMeDisabled;
  final bool isNearMeActive;
  final double? activeRadiusKm;
  final LatLng? userPosition;
  final double fabBottomPadding;
  /// Style JSON Google Maps. Null = style par défaut Google Maps.
  final String? mapStyle;
  /// ID of the currently selected announcement (highlighted marker).
  final String? selectedAnnouncementId;
  /// Called when user taps a single marker.
  final void Function(String id)? onAnnouncementSelected;

  @override
  State<AnnouncementMapView> createState() => _AnnouncementMapViewState();
}

class _AnnouncementMapViewState extends State<AnnouncementMapView> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  final Map<int, BitmapDescriptor> _clusterIcons = {};
  bool _isLocating = false;
  double _currentZoom = 3.5;
  // Cached brightness — updated in didChangeDependencies (safe to read in initState-triggered async work).
  Brightness _brightness = Brightness.light;

  @override
  void initState() {
    super.initState();
    _prewarmCommonIcons();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newBrightness = Theme.of(context).brightness;
    if (newBrightness != _brightness) {
      _brightness = newBrightness;
      _rebuildMarkers();
    }
  }

  @override
  void didUpdateWidget(covariant AnnouncementMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.announcements != widget.announcements ||
        oldWidget.selectedAnnouncementId != widget.selectedAnnouncementId) {
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
    // Price pills don't need prewarm — built lazily and cached per price
    await _rebuildMarkers();
  }

  List<_AnnouncementPoint> _pickupPoints() => widget.announcements
      .where((a) => a.pickupAddress != null)
      .map((a) => _AnnouncementPoint(a, _MarkerSide.pickup))
      .toList();

  Future<void> _rebuildMarkers() async {
    final allPoints = [..._pickupPoints()];
    final rawClusters = _gridCluster(allPoints, _currentZoom);
    // Merge singleton clusters that straddle a grid-cell boundary but share
    // the same physical address (within the kSameSpot threshold).
    final clusters = _mergeSameSpotSingletons(rawClusters);
    final futures = clusters.map((c) => _buildMarker(c));
    final built = await Future.wait(futures);
    if (mounted) {
      setState(() => _markers = built.toSet());
    }
  }

  Future<Marker> _buildMarker(_Cluster cluster) async {
    if (cluster.isMultiple) {
      if (cluster.isSameSpot) {
        // Same address: stacked pill with count badge.
        // Show cheapest price and most urgent (earliest) departure.
        final cheapest = cluster.items
            .map((it) => it.announcement.pricePerKg)
            .reduce(math.min);
        final earliest = cluster.items
            .map((it) => it.announcement.departureDate)
            .reduce((a, b) => a.isBefore(b) ? a : b);
        final urgencyColor = MarkerUrgencyColor.fromDeparture(earliest,
            brightness: _brightness);
        final isSelected = cluster.items
            .any((it) => it.announcement.id == widget.selectedAnnouncementId);
        final icon = await MarkerBitmapFactory.stackedPricePill(
          pricePerKg: cheapest,
          count: cluster.count,
          dotColor: urgencyColor,
          isSelected: isSelected,
        );
        return Marker(
          markerId: MarkerId(
              'same_spot_${cluster.centroid.latitude}_${cluster.centroid.longitude}'),
          position: cluster.centroid,
          icon: icon,
          anchor: const Offset(0.5, 1.0),
          onTap: () => _onClusterTapped(cluster),
        );
      }

      // Proximity cluster: classic blue badge.
      final icon = await _getClusterIcon(cluster.count);
      return Marker(
        markerId: MarkerId(
            'cluster_${cluster.centroid.latitude}_${cluster.centroid.longitude}_${cluster.count}'),
        position: cluster.centroid,
        icon: icon,
        anchor: const Offset(0.5, 0.5),
        onTap: () => _onClusterTapped(cluster),
      );
    }

    // Single marker.
    final item = cluster.items.first;
    final urgencyColor = MarkerUrgencyColor.fromDeparture(
        item.announcement.departureDate,
        brightness: _brightness);
    final isSelected = item.announcement.id == widget.selectedAnnouncementId;
    final icon = await MarkerBitmapFactory.pricePill(
      pricePerKg: item.announcement.pricePerKg,
      dotColor: urgencyColor,
      isSelected: isSelected,
    );
    return Marker(
      markerId: MarkerId('${item.side.name}_${item.announcement.id}'),
      position: item.location,
      icon: icon,
      anchor: const Offset(0.5, 1.0),
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
    widget.onAnnouncementSelected?.call(a.id);
    final authState = context.read<AuthBloc>().state;
    final currentUserId =
        authState is AuthAuthenticated ? authState.user.id : null;
    final isOwn = currentUserId != null && a.travelerId == currentUserId;
    if (isOwn) return;
    showTravelerAnnouncementSheet(context, announcement: a);
  }

  void _onClusterTapped(_Cluster cluster) {
    if (cluster.isSameSpot) {
      // Same address → list sheet (type known at build time, no recheck needed).
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
      // Proximity cluster → zoom in to separate the pins.
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
            cluster.centroid, math.min(_currentZoom + 2, 18)),
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
    final radiusKm = await NearMeRadiusSheet.show(
      context,
      initialRadiusKm: widget.activeRadiusKm ?? 25,
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
    final fabBottom = widget.fabBottomPadding + DonySpacing.lg;

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(30.0, -5.0),
            zoom: 3.5,
          ),
          style: widget.mapStyle,
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
          markers: {..._markers, ...widget.extraMarkers},
          circles: _radiusCircle(),
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
        ),
        Positioned(
          bottom: fabBottom,
          right: DonySpacing.lg,
          child: _NearMeFab(
            key: const Key('near-me-fab'),
            isActive: widget.isNearMeActive,
            isLoading: _isLocating,
            radiusKm: widget.activeRadiusKm,
            onTap: _onNearMeTapped,
            onDoubleTap: widget.isNearMeActive ? widget.onNearMeDisabled : null,
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
    final primary = Theme.of(context).colorScheme.primary;
    return {
      Circle(
        circleId: const CircleId('near-me-radius'),
        center: widget.userPosition!,
        radius: widget.activeRadiusKm! * 1000,
        strokeColor: primary,
        strokeWidth: 2,
        fillColor: primary.withValues(alpha: 0.08),
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
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      onDoubleTap: isLoading ? null : onDoubleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isActive ? cs.primary : cs.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? cs.primary : cs.outline,
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
                    color: isActive ? Colors.white : cs.primary,
                  ),
                )
              : Icon(
                  isActive
                      ? Icons.my_location_rounded
                      : Icons.my_location_outlined,
                  size: 22,
                  color: isActive ? Colors.white : cs.primary,
                ),
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(
        DonySpacing.lg,
        0,
        DonySpacing.lg,
        MediaQuery.of(context).padding.bottom + DonySpacing.lg,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(DonyRadius.sheet)),
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
                color: cs.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Icon(Icons.location_off_rounded,
              size: 48, color: cs.primary),
          const SizedBox(height: DonySpacing.md),
          Text('Géolocalisation désactivée',
              style: tt.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: DonySpacing.sm),
          Text(
            "Autorise l'accès à ta position dans les réglages pour utiliser \"Près de moi\".",
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.xl),
          DonyButton(label: 'Ouvrir les réglages', onPressed: onOpenSettings),
        ],
      ),
    );
  }
}
