import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

/// Abstraction over device location APIs (injectable for tests).
abstract interface class LocationService {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<Position> getCurrentPosition();
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
  Future<Position> getCurrentPosition() =>
      Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
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

/// Bottom sheet shown when location can't be used, with a CTA to open the
/// relevant settings (app permission, or OS location services).
class LocationDeniedSheet extends StatelessWidget {
  const LocationDeniedSheet({
    super.key,
    required this.access,
    required this.onOpenSettings,
  });

  final LocationAccess access;
  final VoidCallback onOpenSettings;

  static Future<void> show(
    BuildContext context, {
    required LocationAccess access,
    LocationService service = const GeolocatorLocationService(),
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LocationDeniedSheet(
        key: const Key('permission-denied-sheet'),
        access: access,
        onOpenSettings: () async {
          ctx.pop();
          if (access == LocationAccess.serviceDisabled) {
            await service.openLocationSettings();
          } else {
            await service.openAppSettings();
          }
        },
      ),
    );
  }

  String get _title => access == LocationAccess.serviceDisabled
      ? 'Localisation désactivée'
      : 'Accès à la position refusé';

  String get _body => access == LocationAccess.serviceDisabled
      ? "Active la localisation de ton téléphone pour voir ce qui est près de toi."
      : "Autorise l'accès à ta position dans les réglages pour utiliser « Près de moi » et te situer sur la carte.";

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
          Icon(Icons.location_off_rounded, size: 48, color: cs.primary),
          const SizedBox(height: DonySpacing.md),
          Text(_title, style: tt.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: DonySpacing.sm),
          Text(
            _body,
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
