import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_map_view.dart';
import 'package:dony/features/matching/presentation/widgets/location_permission.dart';
import 'package:dony/features/matching/presentation/widgets/marker_bitmap_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockLocationService extends Mock implements LocationService {}

/// Short-circuits the open-flow (`_initLocationOnOpen`) so it never touches real
/// platform GPS: a disabled service makes `requestLocationAccess` bail silently.
MockLocationService _stubDeniedService() {
  final mockLoc = MockLocationService();
  when(() => mockLoc.isLocationServiceEnabled())
      .thenAnswer((_) async => false);
  return mockLoc;
}

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
      await tester.pumpWidget(_wrap(AnnouncementMapView(
        announcements: announcements,
        locationService: _stubDeniedService(),
        onNearMeToggle: () {},
      )));
      await tester.pump();
      expect(find.byType(AnnouncementMapView), findsOneWidget);
      expect(find.byKey(const Key('near-me-fab')), findsOneWidget);
    });

    testWidgets('hides the FAB when onNearMeToggle is null', (tester) async {
      await tester.pumpWidget(_wrap(AnnouncementMapView(
        announcements: announcements,
        locationService: _stubDeniedService(),
      )));
      await tester.pump();
      expect(find.byKey(const Key('near-me-fab')), findsNothing);
    });

    testWidgets('tapping the FAB invokes onNearMeToggle', (tester) async {
      var toggled = 0;
      await tester.pumpWidget(_wrap(AnnouncementMapView(
        announcements: announcements,
        locationService: _stubDeniedService(),
        onNearMeToggle: () => toggled++,
      )));
      await tester.pump();
      await tester.tap(find.byKey(const Key('near-me-fab')));
      await tester.pump();
      expect(toggled, 1);
    });

    testWidgets('FAB shows the active (filled) icon when near-me is active',
        (tester) async {
      await tester.pumpWidget(_wrap(AnnouncementMapView(
        announcements: announcements,
        locationService: _stubDeniedService(),
        onNearMeToggle: () {},
        isNearMeActive: true,
      )));
      await tester.pump();
      expect(find.byIcon(Icons.near_me_rounded), findsOneWidget);
      expect(find.byIcon(Icons.near_me_outlined), findsNothing);
    });

    testWidgets('FAB shows a spinner while locating', (tester) async {
      await tester.pumpWidget(_wrap(AnnouncementMapView(
        announcements: announcements,
        locationService: _stubDeniedService(),
        onNearMeToggle: () {},
        isLocating: true,
      )));
      await tester.pump();
      expect(
          find.descendant(
            of: find.byKey(const Key('near-me-fab')),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget);
    });

    testWidgets('legacy announcement (null pickup) is silently filtered',
        (tester) async {
      final list = [
        _ann('a3', 'Paris', 'Dakar',
            pickup: const AddressData(label: '3', lat: 48.86, lng: 2.36),
            delivery: const AddressData(label: 'D3', lat: 14.70, lng: -17.45)),
        _ann('a4', 'Paris', 'Dakar'), // no pickup, no delivery
      ];
      await tester.pumpWidget(_wrap(AnnouncementMapView(
        announcements: list,
        locationService: _stubDeniedService(),
        onNearMeToggle: () {},
      )));
      await tester.pump();
      expect(find.byType(AnnouncementMapView), findsOneWidget);
    });
  });

  testWidgets(
    'builds markers for announcements with each transport mode',
    (tester) async {
      MarkerBitmapFactory.clearCache();

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
              locationService: _stubDeniedService(),
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
