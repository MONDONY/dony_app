import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Abstraction over device location APIs (injectable for tests).
abstract interface class LocationService {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<Position> getCurrentPosition();
  Stream<Position> getPositionStream();
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();
  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();
  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();
  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();
  @override
  Future<Position> getCurrentPosition() => Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
  );
  @override
  Stream<Position> getPositionStream() => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    ),
  );
  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}

/// Outcome of a location-access request.
enum LocationAccess { granted, denied, deniedForever, serviceDisabled }

/// Checks OS location services + app permission, requesting permission once if
/// undecided. Pure of UI — callers decide what to show.
Future<LocationAccess> requestLocationAccess(LocationService service) async {
  if (!await service.isLocationServiceEnabled()) {
    return LocationAccess.serviceDisabled;
  }
  var permission = await service.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await service.requestPermission();
  }
  switch (permission) {
    case LocationPermission.always:
    case LocationPermission.whileInUse:
      return LocationAccess.granted;
    case LocationPermission.deniedForever:
      return LocationAccess.deniedForever;
    case LocationPermission.denied:
    case LocationPermission.unableToDetermine:
      return LocationAccess.denied;
  }
}

/// Content of the "location unavailable" sheet (icon + title + body).
/// Shown via [show], which pins the CTA in `stickyBottom` per the design rules.
class LocationDeniedSheet extends StatelessWidget {
  const LocationDeniedSheet({super.key, required this.access});

  final LocationAccess access;

  static Future<void> show(
    BuildContext context, {
    required LocationAccess access,
    LocationService service = const GeolocatorLocationService(),
  }) {
    final isServiceOff = access == LocationAccess.serviceDisabled;
    return DonyBottomSheet.show<void>(
      context,
      child: LocationDeniedSheet(
        key: const Key('permission-denied-sheet'),
        access: access,
      ),
      stickyBottom: Builder(
        builder: (ctx) => DonyButton(
          label: 'Ouvrir les réglages',
          onPressed: () async {
            Navigator.of(ctx, rootNavigator: true).pop();
            if (isServiceOff) {
              await service.openLocationSettings();
            } else {
              await service.openAppSettings();
            }
          },
        ),
      ),
    );
  }

  String get _title => access == LocationAccess.serviceDisabled
      ? 'Localisation désactivée'
      : 'Accès à la position refusé';

  String get _body => access == LocationAccess.serviceDisabled
      ? 'Active la localisation de ton téléphone pour voir ce qui est près de toi.'
      : "Autorise l'accès à ta position dans les réglages pour utiliser « Près de moi » et te situer sur la carte.";

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.sm,
        DonySpacing.lg,
        DonySpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon('map-pin-off', size: 48, color: cs.primary),
          const SizedBox(height: DonySpacing.md),
          Text(_title, style: tt.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: DonySpacing.sm),
          Text(
            _body,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
