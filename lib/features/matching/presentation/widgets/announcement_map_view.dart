import 'dart:math' as math;

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/location_permission.dart';
import 'package:dony/features/matching/presentation/widgets/map_camera_math.dart';
import 'package:dony/features/matching/presentation/widgets/map_styles.dart';
import 'package:dony/features/matching/presentation/widgets/marker_bitmap_factory.dart';
import 'package:dony/features/matching/presentation/widgets/marker_clustering.dart';
import 'package:dony/features/matching/presentation/widgets/marker_urgency.dart';
import 'package:dony/features/matching/presentation/widgets/same_address_announcements_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_announcement_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

export 'package:dony/features/matching/presentation/widgets/location_permission.dart'
    show LocationService, GeolocatorLocationService, LocationAccess;

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

// ── Widget ────────────────────────────────────────────────────────────────────

class AnnouncementMapView extends StatefulWidget {
  const AnnouncementMapView({
    super.key,
    required this.announcements,
    this.extraMarkers = const {},
    this.searchDepartureCity,
    this.searchArrivalCity,
    this.locationService = const GeolocatorLocationService(),
    this.isNearMeActive = false,
    this.activeRadiusKm,
    this.userPosition,
    this.fabBottomPadding = 0,
    this.mapStyle,
    this.selectedAnnouncementId,
    this.onAnnouncementSelected,
    this.onNearMeToggle,
    this.isLocating = false,
  });

  final List<AnnouncementModel> announcements;

  /// Additional markers to render alongside announcement markers (e.g. package requests).
  /// They bypass the cluster logic and are drawn as-is.
  final Set<Marker> extraMarkers;
  final String? searchDepartureCity;
  final String? searchArrivalCity;
  final LocationService locationService;
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

  /// Called when the user taps the single "Près de moi" FAB. When null, the
  /// FAB is hidden. The parent owns the near-me filter lifecycle (permission,
  /// radius, search) — this widget only renders the toggle and frames the map.
  final VoidCallback? onNearMeToggle;

  /// True while the parent acquires the position after a FAB tap (FAB spinner).
  final bool isLocating;

  @override
  State<AnnouncementMapView> createState() => _AnnouncementMapViewState();
}

class _AnnouncementMapViewState extends State<AnnouncementMapView> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  final Map<int, BitmapDescriptor> _clusterIcons = {};
  double _currentZoom = 3.5;
  bool _locationGranted = false;
  LatLng? _myLocation;
  bool _awaitingFirstLocation = false;
  // Cached brightness — updated in didChangeDependencies (safe to read in initState-triggered async work).
  Brightness _brightness = Brightness.light;
  // Improvement A: signature guard to skip redundant re-clustering.
  String? _lastMarkerSignature;

  @override
  void initState() {
    super.initState();
    _prewarmCommonIcons();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLocationOnOpen());
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
      // The parent only activates near-me once it holds a granted position, so
      // turn on the native blue dot here even if the open-flow was denied.
      if (!_locationGranted) {
        setState(() => _locationGranted = true);
      }
      _fitNearMeBounds(widget.userPosition!, widget.activeRadiusKm!);
    }
  }

  Future<void> _prewarmCommonIcons() async {
    // Price pills don't need prewarm — built lazily and cached per price
    await _rebuildMarkers();
  }

  Future<void> _initLocationOnOpen() async {
    _awaitingFirstLocation = true;
    final access = await requestLocationAccess(widget.locationService);
    if (access != LocationAccess.granted) {
      _awaitingFirstLocation = false;
      if (mounted) {
        _applyInitialCamera(); // fallback annonces, silencieux (pas de point bleu)
      }
      return;
    }
    if (!mounted) {
      _awaitingFirstLocation = false;
      return;
    }
    setState(() => _locationGranted = true);
    try {
      final pos = await widget.locationService.getCurrentPosition();
      if (!mounted) {
        return;
      }
      _awaitingFirstLocation = false;
      setState(() => _myLocation = LatLng(pos.latitude, pos.longitude));
      _applyInitialCamera();
    } catch (_) {
      _awaitingFirstLocation = false;
      if (mounted) {
        _applyInitialCamera();
      }
    }
  }

  void _applyInitialCamera() {
    final controller = _mapController;
    if (controller == null) {
      return; // onMapCreated rappellera
    }
    final me = _myLocation;
    if (me != null) {
      // Cadre ~1000 km autour de la position : l'user voit sa zone + les
      // annonces dans ce rayon, sans zoomer trop près (échelle région/pays).
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(boundsAround(me, 1000), 60.0),
      );
    } else if (!_awaitingFirstLocation) {
      _fitInitialBounds();
    }
  }

  List<_AnnouncementPoint> _pickupPoints() => widget.announcements
      .where((a) => a.pickupAddress != null)
      .map((a) => _AnnouncementPoint(a, _MarkerSide.pickup))
      .toList();

  /// Everything that affects the rendered marker set. Panning within the same
  /// zoom bucket leaves this unchanged, so `_rebuildMarkers` can skip the work.
  String _markerSignature() {
    final buf = StringBuffer();
    for (final a in widget.announcements) {
      if (a.pickupAddress == null) {
        continue;
      }
      buf
        ..write(a.id)
        ..write(':')
        ..write((a.pricePerKg * 100).round()) // cents → stable integer key
        ..write(':')
        ..write(a.departureDate.millisecondsSinceEpoch)
        ..write(';');
    }
    buf
      ..write('|sel=')
      ..write(widget.selectedAnnouncementId)
      ..write('|b=')
      ..write(_brightness.index)
      ..write('|c=')
      ..write(cellDegForZoom(_currentZoom));
    return buf.toString();
  }

  Future<void> _rebuildMarkers({bool force = false}) async {
    final signature = _markerSignature();
    if (!force && signature == _lastMarkerSignature) {
      return;
    }
    _lastMarkerSignature = signature;
    final allPoints = [..._pickupPoints()];
    final rawClusters = gridCluster<_AnnouncementPoint>(
      allPoints,
      _currentZoom,
      (p) => p.location,
    );
    // Merge singleton clusters that straddle a grid-cell boundary but share
    // the same physical address (within the kSameSpot threshold).
    final clusters = mergeSameSpotSingletons<_AnnouncementPoint>(
      rawClusters,
      (p) => p.location,
    );
    final futures = clusters.map((c) => _buildMarker(c));
    final built = await Future.wait(futures);
    if (!mounted) {
      _lastMarkerSignature =
          null; // unmounted mid-build → don't suppress a later rebuild
      return;
    }
    setState(() => _markers = built.toSet());
  }

  Future<Marker> _buildMarker(MarkerCluster<_AnnouncementPoint> cluster) async {
    if (cluster.isMultiple) {
      if (cluster.isSameSpot) {
        // Same address: stacked pill with count badge.
        // Show cheapest price and most urgent (earliest) departure.
        // Prix affiché à l'expéditeur (net + commission) — cohérent avec les cartes/sheets.
        final cheapestItem = cluster.items.reduce(
          (a, b) =>
              a.announcement.senderPricePerKg < b.announcement.senderPricePerKg
              ? a
              : b,
        );
        final cheapest = cheapestItem.announcement.senderPricePerKg;
        final earliest = cluster.items
            .map((it) => it.announcement.departureDate)
            .reduce((a, b) => a.isBefore(b) ? a : b);
        final urgencyColor = MarkerUrgencyColor.fromDeparture(
          earliest,
          brightness: _brightness,
        );
        final isSelected = cluster.items.any(
          (it) => it.announcement.id == widget.selectedAnnouncementId,
        );
        final icon = await MarkerBitmapFactory.stackedPricePill(
          pricePerKg: cheapest,
          count: cluster.count,
          dotColor: urgencyColor,
          isSelected: isSelected,
          brightness: _brightness,
          prefix: '✈️',
          currencyCode: cheapestItem.announcement.currency,
        );
        return Marker(
          markerId: MarkerId(
            'same_spot_${cluster.centroid.latitude}_${cluster.centroid.longitude}',
          ),
          position: cluster.centroid,
          icon: icon,
          onTap: () => _onClusterTapped(cluster),
        );
      }

      // Proximity cluster: classic blue badge.
      final icon = await _getClusterIcon(cluster.count);
      return Marker(
        markerId: MarkerId(
          'cluster_${cluster.centroid.latitude}_${cluster.centroid.longitude}_${cluster.count}',
        ),
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
      brightness: _brightness,
    );
    final isSelected = item.announcement.id == widget.selectedAnnouncementId;
    final icon = await MarkerBitmapFactory.pricePill(
      pricePerKg: item.announcement.senderPricePerKg,
      dotColor: urgencyColor,
      isSelected: isSelected,
      brightness: _brightness,
      prefix: '✈️',
      currencyCode: item.announcement.currency,
    );
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
    widget.onAnnouncementSelected?.call(a.id);
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState.currentUserId;
    final isOwn = currentUserId != null && a.travelerId == currentUserId;
    if (isOwn) return;
    showTravelerAnnouncementSheet(context, announcement: a);
  }

  void _onClusterTapped(MarkerCluster<_AnnouncementPoint> cluster) {
    if (cluster.isSameSpot) {
      // Same address → list sheet (type known at build time, no recheck needed).
      final firstItem = cluster.items.first;
      final addr = firstItem.side == _MarkerSide.pickup
          ? firstItem.announcement.pickupAddress
          : firstItem.announcement.deliveryAddress;
      final authState = context.read<AuthBloc>().state;
      final currentUserId = authState.currentUserId;
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
          cluster.centroid,
          math.min(_currentZoom + 2, 18),
        ),
      );
    }
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
          style: widget.mapStyle ?? resolveMapStyle(_brightness),
          onMapCreated: (controller) {
            _mapController = controller;
            _applyInitialCamera();
          },
          onCameraMove: (position) {
            _currentZoom = position.zoom;
          },
          onCameraIdle: () => _rebuildMarkers(),
          markers: {..._markers, ...widget.extraMarkers},
          circles: _radiusCircle(),
          myLocationEnabled: _locationGranted,
          // Notre FAB est l'unique contrôle de localisation — on masque le
          // bouton natif Google pour ne pas avoir deux boutons qui se doublent.
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
        if (widget.onNearMeToggle != null)
          Positioned(
            bottom: fabBottom,
            right: DonySpacing.lg,
            child: _NearMeFab(
              key: const Key('near-me-fab'),
              isActive: widget.isNearMeActive,
              isLoading: widget.isLocating,
              onTap: widget.onNearMeToggle!,
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
    final lngDelta =
        radiusKm / (111.0 * math.cos(center.latitude * math.pi / 180).abs());
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
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60.0));
  }

  Future<void> _fitInitialBounds() async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }
    final allPoints = <LatLng>[..._pickupPoints().map((it) => it.location)];
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
    required this.onTap,
  });

  final bool isActive;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: isActive
          ? 'Désactiver « Près de moi »'
          : 'Voir les voyageurs près de moi',
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isActive ? cs.primary : cs.surface,
            shape: BoxShape.circle,
            border: Border.all(color: isActive ? cs.primary : cs.outline),
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
                : DonyIcon(
                    'navigation',
                    size: 22,
                    color: isActive ? Colors.white : cs.primary,
                  ),
          ),
        ),
      ),
    );
  }
}
