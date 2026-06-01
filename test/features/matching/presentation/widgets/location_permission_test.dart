import 'package:dony/features/matching/presentation/widgets/location_permission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';

class MockLocationService extends Mock implements LocationService {}

Position _fakePosition() => Position(
      latitude: 48.8566,
      longitude: 2.3522,
      timestamp: DateTime(2026, 6, 1),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  group('requestLocationAccess', () {
    late MockLocationService svc;

    setUp(() {
      svc = MockLocationService();
    });

    test('returns serviceDisabled when OS location is off — does NOT call checkPermission',
        () async {
      when(() => svc.isLocationServiceEnabled()).thenAnswer((_) async => false);

      final result = await requestLocationAccess(svc);

      expect(result, LocationAccess.serviceDisabled);
      verifyNever(() => svc.checkPermission());
    });

    test('returns granted when service enabled + checkPermission = whileInUse',
        () async {
      when(() => svc.isLocationServiceEnabled()).thenAnswer((_) async => true);
      when(() => svc.checkPermission())
          .thenAnswer((_) async => LocationPermission.whileInUse);

      final result = await requestLocationAccess(svc);

      expect(result, LocationAccess.granted);
    });

    test('returns granted when service enabled + checkPermission = always',
        () async {
      when(() => svc.isLocationServiceEnabled()).thenAnswer((_) async => true);
      when(() => svc.checkPermission())
          .thenAnswer((_) async => LocationPermission.always);

      final result = await requestLocationAccess(svc);

      expect(result, LocationAccess.granted);
    });

    test(
        'returns granted when checkPermission=denied then requestPermission=whileInUse',
        () async {
      when(() => svc.isLocationServiceEnabled()).thenAnswer((_) async => true);
      when(() => svc.checkPermission())
          .thenAnswer((_) async => LocationPermission.denied);
      when(() => svc.requestPermission())
          .thenAnswer((_) async => LocationPermission.whileInUse);

      final result = await requestLocationAccess(svc);

      expect(result, LocationAccess.granted);
    });

    test(
        'returns denied when checkPermission=denied then requestPermission=denied',
        () async {
      when(() => svc.isLocationServiceEnabled()).thenAnswer((_) async => true);
      when(() => svc.checkPermission())
          .thenAnswer((_) async => LocationPermission.denied);
      when(() => svc.requestPermission())
          .thenAnswer((_) async => LocationPermission.denied);

      final result = await requestLocationAccess(svc);

      expect(result, LocationAccess.denied);
    });

    test('returns deniedForever when checkPermission=deniedForever', () async {
      when(() => svc.isLocationServiceEnabled()).thenAnswer((_) async => true);
      when(() => svc.checkPermission())
          .thenAnswer((_) async => LocationPermission.deniedForever);

      final result = await requestLocationAccess(svc);

      expect(result, LocationAccess.deniedForever);
    });
  });

  group('LocationDeniedSheet widget', () {
    testWidgets('renders serviceDisabled title when access=serviceDisabled',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationDeniedSheet(
              key: const Key('permission-denied-sheet'),
              access: LocationAccess.serviceDisabled,
              onOpenSettings: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('permission-denied-sheet')), findsOneWidget);
      expect(find.text('Localisation désactivée'), findsOneWidget);
      expect(find.text('Ouvrir les réglages'), findsOneWidget);
    });

    testWidgets('renders denied title when access=deniedForever',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationDeniedSheet(
              access: LocationAccess.deniedForever,
              onOpenSettings: () {},
            ),
          ),
        ),
      );

      expect(find.text('Accès à la position refusé'), findsOneWidget);
      expect(find.text('Ouvrir les réglages'), findsOneWidget);
    });

    testWidgets('renders denied title when access=denied', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationDeniedSheet(
              access: LocationAccess.denied,
              onOpenSettings: () {},
            ),
          ),
        ),
      );

      expect(find.text('Accès à la position refusé'), findsOneWidget);
    });

    testWidgets('calls onOpenSettings when button is tapped', (tester) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationDeniedSheet(
              access: LocationAccess.denied,
              onOpenSettings: () => called = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ouvrir les réglages'));
      await tester.pump();

      expect(called, isTrue);
    });
  });
}
