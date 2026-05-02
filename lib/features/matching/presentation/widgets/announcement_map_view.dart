import 'package:dony/core/constants/cities.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/route_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ── LocationService abstraction (inchangée) ───────────────────────────────────

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

// ── Widget principal ──────────────────────────────────────────────────────────

class AnnouncementMapView extends StatefulWidget {
  final List<AnnouncementModel> announcements;
  final String? searchDepartureCity;
  final String? searchArrivalCity;
  final LocationService locationService;

  const AnnouncementMapView({
    super.key,
    required this.announcements,
    this.searchDepartureCity,
    this.searchArrivalCity,
    this.locationService = const GeolocatorLocationService(),
  });

  @override
  State<AnnouncementMapView> createState() => _AnnouncementMapViewState();
}

class _AnnouncementMapViewState extends State<AnnouncementMapView> {
  GoogleMapController? _mapController;
  City? _selectedDepartureCity;
  bool _isNearMeActive = false;
  String? _nearMeCityName;
  bool _isLocating = false;

  // ── Comptages ───────────────────────────────────────────────────────────────

  Map<String, int> get _departureCounts {
    final map = <String, int>{};
    for (final a in widget.announcements) {
      map[a.departureCity] = (map[a.departureCity] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> get _arrivalCounts {
    final map = <String, int>{};
    for (final a in widget.announcements) {
      map[a.arrivalCity] = (map[a.arrivalCity] ?? 0) + 1;
    }
    return map;
  }

  Set<String> get _allRoutePairs => widget.announcements
      .map((a) => '${a.departureCity}→${a.arrivalCity}')
      .toSet();

  // ── Marqueurs ───────────────────────────────────────────────────────────────

  Set<Marker> _buildDepartureMarkers() {
    final counts = _departureCounts;
    return CityConstants.departures
        .where((c) => counts.containsKey(c.displayName))
        .map((c) => Marker(
              markerId: MarkerId('dep_${c.id}'),
              position: c.coordinates,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
              infoWindow: InfoWindow(
                title: c.displayName,
                snippet: '${counts[c.displayName]} trajet(s)',
              ),
              onTap: () => _onDepartureTapped(c),
            ))
        .toSet();
  }

  Set<Marker> _buildArrivalMarkers() {
    final counts = _arrivalCounts;
    final selected = _selectedDepartureCity;
    return CityConstants.arrivals
        .where((c) {
          if (selected != null) {
            return _allRoutePairs
                .contains('${selected.displayName}→${c.displayName}');
          }
          return counts.containsKey(c.displayName);
        })
        .map((c) => Marker(
              markerId: MarkerId('arr_${c.id}'),
              position: c.coordinates,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange,
              ),
              infoWindow: InfoWindow(
                title: c.displayName,
                snippet: '${counts[c.displayName] ?? 0} trajet(s)',
              ),
              onTap: () => _onArrivalTapped(c),
            ))
        .toSet();
  }

  // ── Interactions ────────────────────────────────────────────────────────────

  void _onDepartureTapped(City city) {
    final isDeselecting = _selectedDepartureCity?.id == city.id;
    setState(() {
      _selectedDepartureCity = isDeselecting ? null : city;
    });
    if (!isDeselecting) {
      _showRouteBottomSheet(DepartureCityFilter(city));
    }
  }

  void _onArrivalTapped(City city) {
    _showRouteBottomSheet(ArrivalCityFilter(city));
  }

  void _showRouteBottomSheet(TripFilter filter) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RouteBottomSheet(
        announcements: widget.announcements,
        filter: filter,
      ),
    );
  }

  // ── Caméra ──────────────────────────────────────────────────────────────────

  Future<void> _fitInitialBounds() async {
    final controller = _mapController;
    if (controller == null) return;

    final dep = widget.searchDepartureCity;
    final arr = widget.searchArrivalCity;
    final depCity =
        dep != null ? CityConstants.findById(dep.toLowerCase()) : null;
    final arrCity =
        arr != null ? CityConstants.findById(arr.toLowerCase()) : null;

    final List<LatLng> points;
    if (depCity != null && arrCity != null) {
      points = [depCity.coordinates, arrCity.coordinates];
    } else {
      points = CityConstants.all.map((c) => c.coordinates).toList();
    }
    if (points.isEmpty) return;

    final bounds = _boundsFromPoints(points);
    await controller
        .animateCamera(CameraUpdate.newLatLngBounds(bounds, 60.0));
  }

  LatLngBounds _boundsFromPoints(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  // ── Géolocalisation ─────────────────────────────────────────────────────────

  Future<void> _onNearMeTapped() async {
    if (_isNearMeActive) {
      setState(() {
        _isNearMeActive = false;
        _nearMeCityName = null;
        _selectedDepartureCity = null;
      });
      return;
    }

    setState(() => _isLocating = true);
    try {
      var permission = await widget.locationService.checkPermission();

      if (permission == LocationPermission.deniedForever) {
        _showPermissionDeniedSheet(isPermanent: true);
        return;
      }

      if (permission == LocationPermission.denied) {
        permission = await widget.locationService.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showPermissionDeniedSheet(
          isPermanent: permission == LocationPermission.deniedForever,
        );
        return;
      }

      final position = await widget.locationService.getCurrentPosition();
      final userLatLng = LatLng(position.latitude, position.longitude);
      final nearestCity = CityConstants.findNearest(userLatLng);

      if (nearestCity == null) {
        _showNoServiceBottomSheet();
        return;
      }

      setState(() {
        _isNearMeActive = true;
        _nearMeCityName = nearestCity.displayName;
        _selectedDepartureCity = nearestCity;
      });

      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(nearestCity.coordinates, 8.0),
      );

      if (mounted) {
        _showRouteBottomSheet(DepartureCityFilter(nearestCity));
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _showPermissionDeniedSheet({required bool isPermanent}) {
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

  void _showNoServiceBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NoServiceSheet(key: Key('no-service-sheet')),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{
      ..._buildDepartureMarkers(),
      ..._buildArrivalMarkers(),
    };

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
          markers: markers,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
        ),
        Positioned(
          bottom: DonySpacing.lg,
          right: DonySpacing.lg,
          child: _NearMeFab(
            key: const Key('near-me-fab'),
            isActive: _isNearMeActive,
            isLoading: _isLocating,
            cityName: _nearMeCityName,
            onTap: _onNearMeTapped,
          ),
        ),
      ],
    );
  }
}

// ── Composants privés (inchangés sauf _CityMarker supprimé) ───────────────────

class _NearMeFab extends StatelessWidget {
  final bool isActive;
  final bool isLoading;
  final String? cityName;
  final VoidCallback onTap;

  const _NearMeFab({
    super.key,
    required this.isActive,
    required this.isLoading,
    required this.cityName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isActive ? DonyColors.primary : DonyColors.surface,
          borderRadius: BorderRadius.circular(DonyRadius.full),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isActive ? Colors.white : DonyColors.primary,
                ),
              )
            else
              Icon(
                isActive
                    ? Icons.my_location_rounded
                    : Icons.my_location_outlined,
                size: 16,
                color: isActive ? Colors.white : DonyColors.primary,
              ),
            if (cityName != null) ...[
              const SizedBox(width: DonySpacing.xs),
              Text(
                cityName!,
                style: tt.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else ...[
              const SizedBox(width: DonySpacing.xs),
              Text(
                'Près de moi',
                style: tt.labelMedium?.copyWith(
                  color: isActive ? Colors.white : DonyColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PermissionDeniedSheet extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const _PermissionDeniedSheet({
    super.key,
    required this.onOpenSettings,
  });

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
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DonyRadius.sheet),
        ),
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
          const Icon(
            Icons.location_off_rounded,
            size: 48,
            color: DonyColors.primary,
          ),
          const SizedBox(height: DonySpacing.md),
          Text(
            'Géolocalisation désactivée',
            style: tt.titleLarge,
            textAlign: TextAlign.center,
          ),
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

class _NoServiceSheet extends StatelessWidget {
  const _NoServiceSheet({super.key});

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
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DonyRadius.sheet),
        ),
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
          const Icon(
            Icons.location_searching_rounded,
            size: 48,
            color: DonyColors.primary,
          ),
          const SizedBox(height: DonySpacing.md),
          Text(
            'Aucune ville desservie près de toi',
            style: tt.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            'Les départs se font depuis Paris, Lyon ou Marseille.',
            style: tt.bodyMedium?.copyWith(color: DonyColors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.md),
        ],
      ),
    );
  }
}
