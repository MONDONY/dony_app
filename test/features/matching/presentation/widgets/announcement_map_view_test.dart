import 'dart:async';

import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_map_view.dart';
import 'package:dony/features/matching/presentation/widgets/location_permission.dart';
import 'package:dony/features/matching/presentation/widgets/marker_bitmap_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
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

AnnouncementModel _ann(
  String id,
  String dep,
  String arr, {
  AddressData? pickup,
  AddressData? delivery,
}) =>
    AnnouncementModel(
      id: id,
      travelerId: 't1',
      departureCity: dep,
      arrivalCity: arr,
      departureDate: DateTime(2026, 6, 15),
      availableKg: 8,
      totalKg: 8,
      pricePerKg: 12,
      status: 'ACTIVE',
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
      pickupAddress: pickup,
      deliveryAddress: delivery,
      traveler: TravelerProfile(id: 't1', displayName: 'Sékou Ba', kiloPro: false),
    );

Widget _wrap(Widget child) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => Scaffold(body: child)),
      GoRoute(path: '/announcements/:id', builder: (_, __) => const Scaffold()),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  group('AnnouncementMapView', () {
    final announcements = [
      _ann('a1', 'Paris', 'Dakar',
          pickup: const AddressData(label: '1', lat: 48.85, lng: 2.35),
          delivery: const AddressData(label: 'D1', lat: 14.69, lng: -17.44)),
      _ann('a2', 'Paris', 'Dakar',
          pickup: const AddressData(label: '2', lat: 48.86, lng: 2.36),
          delivery: const AddressData(label: 'D2', lat: 14.70, lng: -17.45)),
    ];

    testWidgets('renders the map and the Près de moi FAB', (tester) async {
      final mockLoc = MockLocationService();
      when(() => mockLoc.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockLoc.checkPermission())
          .thenAnswer((_) async => LocationPermission.deniedForever);
      await tester.pumpWidget(_wrap(AnnouncementMapView(
        announcements: announcements,
        locationService: mockLoc,
      )));
      await tester.pump();
      expect(find.byType(AnnouncementMapView), findsOneWidget);
      expect(find.byKey(const Key('near-me-fab')), findsOneWidget);
    });

    testWidgets('recenter FAB shows permission sheet when denied',
        (tester) async {
      final mockLoc = MockLocationService();
      when(() => mockLoc.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockLoc.checkPermission())
          .thenAnswer((_) async => LocationPermission.denied);
      when(() => mockLoc.requestPermission())
          .thenAnswer((_) async => LocationPermission.denied);

      await tester.pumpWidget(_wrap(AnnouncementMapView(
        announcements: announcements,
        locationService: mockLoc,
      )));
      await tester.pump();
      await tester.tap(find.byKey(const Key('near-me-fab')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('permission-denied-sheet')), findsOneWidget);
    });

    testWidgets('recenter FAB requests current position when granted',
        (tester) async {
      final mockLoc = MockLocationService();
      when(() => mockLoc.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockLoc.checkPermission())
          .thenAnswer((_) async => LocationPermission.whileInUse);
      when(() => mockLoc.getCurrentPosition())
          .thenAnswer((_) async => _fakePosition());
      when(() => mockLoc.getPositionStream())
          .thenAnswer((_) => const Stream<Position>.empty());

      await tester.pumpWidget(_wrap(AnnouncementMapView(
        announcements: announcements,
        locationService: mockLoc,
      )));
      // Let the open-flow (_initLocationOnOpen) fully resolve before counting.
      await tester.pumpAndSettle();
      clearInteractions(mockLoc);
      await tester.tap(find.byKey(const Key('near-me-fab')));
      await tester.pumpAndSettle();
      verify(() => mockLoc.getCurrentPosition()).called(1);
    });

    testWidgets('FAB enters follow mode (active icon) after tap when granted',
        (tester) async {
      final mockLoc = MockLocationService();
      when(() => mockLoc.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockLoc.checkPermission())
          .thenAnswer((_) async => LocationPermission.whileInUse);
      when(() => mockLoc.getCurrentPosition())
          .thenAnswer((_) async => _fakePosition());
      when(() => mockLoc.getPositionStream())
          .thenAnswer((_) => const Stream<Position>.empty());

      await tester.pumpWidget(_wrap(AnnouncementMapView(
        announcements: announcements,
        locationService: mockLoc,
      )));
      await tester.pump();
      // before tap: not following → outlined icon
      expect(find.byIcon(Icons.my_location_outlined), findsOneWidget);
      await tester.tap(find.byKey(const Key('near-me-fab')));
      await tester.pumpAndSettle();
      // after tap: following → filled icon + stream subscribed
      expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);
      verify(() => mockLoc.getPositionStream()).called(1);
    });

    testWidgets('legacy announcement (null pickup) is silently filtered',
        (tester) async {
      final list = [
        _ann('a3', 'Paris', 'Dakar',
            pickup: const AddressData(label: '3', lat: 48.86, lng: 2.36),
            delivery: const AddressData(label: 'D3', lat: 14.70, lng: -17.45)),
        _ann('a4', 'Paris', 'Dakar'), // no pickup, no delivery
      ];
      final mockLoc = MockLocationService();
      when(() => mockLoc.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      when(() => mockLoc.checkPermission())
          .thenAnswer((_) async => LocationPermission.deniedForever);
      await tester.pumpWidget(_wrap(AnnouncementMapView(
        announcements: list,
        locationService: mockLoc,
      )));
      await tester.pump();
      expect(find.byType(AnnouncementMapView), findsOneWidget);
    });

    testWidgets(
        'FAB shows permission-denied-sheet when location service is disabled',
        (tester) async {
      final mockLoc = MockLocationService();
      // Service is off — requestLocationAccess short-circuits with serviceDisabled.
      when(() => mockLoc.isLocationServiceEnabled())
          .thenAnswer((_) async => false);

      await tester.pumpWidget(_wrap(AnnouncementMapView(
        announcements: announcements,
        locationService: mockLoc,
      )));
      await tester.pump();

      await tester.tap(find.byKey(const Key('near-me-fab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('permission-denied-sheet')), findsOneWidget);
    });

    testWidgets('cancels the position stream on dispose', (tester) async {
      final controller = StreamController<Position>();
      final mockLoc = MockLocationService();
      when(() => mockLoc.isLocationServiceEnabled()).thenAnswer((_) async => true);
      when(() => mockLoc.checkPermission())
          .thenAnswer((_) async => LocationPermission.whileInUse);
      when(() => mockLoc.getCurrentPosition())
          .thenAnswer((_) async => _fakePosition());
      when(() => mockLoc.getPositionStream())
          .thenAnswer((_) => controller.stream);

      // Use an empty announcement list so _rebuildMarkers() has no markers to
      // build — Future.wait([]) resolves immediately, avoiding the toImage()
      // async raster work that would otherwise interfere with pumpAndSettle.
      await tester.pumpWidget(_wrap(AnnouncementMapView(
        announcements: const [],
        locationService: mockLoc,
      )));
      await tester.pump();
      await tester.tap(find.byKey(const Key('near-me-fab')));
      // Use finite pumps instead of pumpAndSettle: an active stream subscription
      // on a never-closing StreamController keeps the FakeAsync zone "busy",
      // causing pumpAndSettle to loop until the 10-minute test timeout.
      // 500 ms covers the async chain + AnimatedContainer(200ms) animation.
      await tester.pump(const Duration(milliseconds: 500));
      expect(controller.hasListener, isTrue); // following → subscribed

      await tester.pumpWidget(const SizedBox()); // dispose the map
      await tester.pump();
      expect(controller.hasListener, isFalse); // subscription cancelled
      controller.close(); // ignore: unawaited_futures
    });

    testWidgets('stays in follow mode when a position is emitted',
        (tester) async {
      final controller = StreamController<Position>();
      final mockLoc = MockLocationService();
      when(() => mockLoc.isLocationServiceEnabled()).thenAnswer((_) async => true);
      when(() => mockLoc.checkPermission())
          .thenAnswer((_) async => LocationPermission.whileInUse);
      when(() => mockLoc.getCurrentPosition())
          .thenAnswer((_) async => _fakePosition());
      when(() => mockLoc.getPositionStream())
          .thenAnswer((_) => controller.stream);

      // Empty announcements → no marker-building raster work during pumps.
      await tester.pumpWidget(_wrap(AnnouncementMapView(
        announcements: const [],
        locationService: mockLoc,
      )));
      await tester.pump();
      await tester.tap(find.byKey(const Key('near-me-fab')));
      // Same reasoning: avoid pumpAndSettle with an open StreamController.
      await tester.pump(const Duration(milliseconds: 500));

      controller.add(_fakePosition()); // emit a live position
      await tester.pump();
      // still following (no crash, icon stays filled)
      expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);
      controller.close(); // ignore: unawaited_futures
    });
  });

  testWidgets(
    'builds markers for announcements with each transport mode',
    (tester) async {
      MarkerBitmapFactory.clearCache();

      final mockLoc = MockLocationService();
      // Short-circuit the open-flow so it never calls real platform GPS.
      when(() => mockLoc.isLocationServiceEnabled())
          .thenAnswer((_) async => false);

      final announcements = [
        for (final mode in TransportMode.values)
          AnnouncementModel(
            id: 'a-${mode.name}',
            travelerId: 't-1',
            departureCity: 'Paris',
            arrivalCity: 'Dakar',
            departureDate: DateTime.now().add(const Duration(days: 5)),
            availableKg: 5.0,
            totalKg: 5.0,
            pricePerKg: 10.0,
            status: 'ACTIVE',
            pickupAddress: const AddressData(label: 'Lyon', lat: 45.748, lng: 4.846),
            deliveryAddress: const AddressData(label: 'Dakar', lat: 14.693, lng: -17.447),
            transportMode: mode,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnnouncementMapView(
              announcements: announcements,
              locationService: mockLoc,
            ),
          ),
        ),
      );
      // Allow async marker building to complete
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Smoke check: widget mounted, no crash on building markers for any mode
      expect(find.byType(AnnouncementMapView), findsOneWidget);
    },
  );
}
