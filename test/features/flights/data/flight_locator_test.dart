import 'package:dony/features/flights/data/datasources/flight_locator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _MockGeolocator extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {}

Position _at(double lat, double lng) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime(2026),
  accuracy: 10,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  late _MockGeolocator geo;
  const locator = GeoFlightLocator();

  setUpAll(() => registerFallbackValue(const LocationSettings()));

  setUp(() {
    geo = _MockGeolocator();
    GeolocatorPlatform.instance = geo;
  });

  test('distance à vol d\'oiseau Paris – Lyon, environ 392 km', () {
    final km = GeoFlightLocator.distanceKm(48.8566, 2.3522, 45.7640, 4.8357);
    expect(km, closeTo(392, 5));
  });

  test('ville la plus proche dans le rayon', () {
    // Versailles : Paris.
    expect(locator.nearestTo(48.80, 2.13)?.code, 'PAR');
    // Villeurbanne : Lyon.
    expect(locator.nearestTo(45.77, 4.88)?.code, 'LYS');
    // Plein Atlantique : aucune.
    expect(locator.nearestTo(30, -40), isNull);
  });

  test(
    'permission déjà accordée et service actif : position lisible',
    () async {
      when(
        () => geo.checkPermission(),
      ).thenAnswer((_) async => LocationPermission.whileInUse);
      when(() => geo.isLocationServiceEnabled()).thenAnswer((_) async => true);
      expect(await locator.canLocate(), isTrue);
    },
  );

  test(
    'permission jamais demandée ici : refusée ou absente, pas de ligne',
    () async {
      when(
        () => geo.checkPermission(),
      ).thenAnswer((_) async => LocationPermission.denied);
      expect(await locator.canLocate(), isFalse);
      verifyNever(() => geo.requestPermission());

      when(() => geo.checkPermission()).thenThrow(Exception('plateforme'));
      expect(await locator.canLocate(), isFalse);
    },
  );

  test('dernière position connue, sinon position fraîche', () async {
    when(() => geo.getLastKnownPosition()).thenAnswer((_) async => null);
    when(
      () => geo.getCurrentPosition(
        locationSettings: any(named: 'locationSettings'),
      ),
    ).thenAnswer((_) async => _at(14.70, -17.45));
    expect((await locator.nearestCity())?.code, 'DKR');

    when(
      () => geo.getLastKnownPosition(),
    ).thenAnswer((_) async => _at(5.35, -4.0));
    expect((await locator.nearestCity())?.code, 'ABJ');

    when(() => geo.getLastKnownPosition()).thenThrow(Exception('gps'));
    expect(await locator.nearestCity(), isNull);
  });
}
