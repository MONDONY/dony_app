import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_map_view.dart';
import 'package:dony/features/matching/presentation/widgets/route_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:geolocator/geolocator.dart';

class MockLocationService extends Mock implements LocationService {}

AnnouncementModel _ann(String dep, String arr, {String id = 'a1'}) =>
    AnnouncementModel(
      id: id,
      travelerId: 't1',
      departureCity: dep,
      arrivalCity: arr,
      departureDate: DateTime(2026, 6, 15),
      availableKg: 8,
      pricePerKg: 12,
      status: 'ACTIVE',
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
      traveler: TravelerProfile(id: 't1', displayName: 'Sékou Ba', kiloPro: false),
    );

Widget _wrap(Widget child) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => Scaffold(body: child)),
      GoRoute(path: '/search/:id', builder: (_, __) => const Scaffold()),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  group('AnnouncementMapView', () {
    final announcements = [
      _ann('Paris', 'Dakar', id: 'a1'),
      _ann('Paris', 'Abidjan', id: 'a2'),
      _ann('Lyon', 'Dakar', id: 'a3'),
    ];

    testWidgets('renders AnnouncementMapView', (tester) async {
      final mockLoc = MockLocationService();
      await tester.pumpWidget(_wrap(AnnouncementMapView(
        announcements: announcements,
        locationService: mockLoc,
      )));
      await tester.pump();
      expect(find.byType(AnnouncementMapView), findsOneWidget);
    });

    testWidgets('shows Près de moi FAB', (tester) async {
      final mockLoc = MockLocationService();
      await tester.pumpWidget(_wrap(AnnouncementMapView(
        announcements: announcements,
        locationService: mockLoc,
      )));
      await tester.pump();
      expect(find.byKey(const Key('near-me-fab')), findsOneWidget);
    });

    testWidgets('tap Près de moi requests permission', (tester) async {
      final mockLoc = MockLocationService();
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

      verify(() => mockLoc.requestPermission()).called(1);
    });

    testWidgets('permission denied shows permission denied sheet', (tester) async {
      final mockLoc = MockLocationService();
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
      expect(find.text('Ouvrir les réglages'), findsOneWidget);
    });

    testWidgets('permanentlyDenied shows sheet with settings button', (tester) async {
      final mockLoc = MockLocationService();
      when(() => mockLoc.checkPermission())
          .thenAnswer((_) async => LocationPermission.deniedForever);

      await tester.pumpWidget(_wrap(AnnouncementMapView(
        announcements: announcements,
        locationService: mockLoc,
      )));
      await tester.pump();
      await tester.tap(find.byKey(const Key('near-me-fab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('permission-denied-sheet')), findsOneWidget);
    });

    testWidgets('position hors zone shows no-service sheet', (tester) async {
      final mockLoc = MockLocationService();
      when(() => mockLoc.checkPermission())
          .thenAnswer((_) async => LocationPermission.always);
      when(() => mockLoc.getCurrentPosition()).thenAnswer((_) async => Position(
            latitude: 44.84,
            longitude: -0.58,
            timestamp: DateTime.now(),
            accuracy: 10,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          ));

      await tester.pumpWidget(_wrap(AnnouncementMapView(
        announcements: announcements,
        locationService: mockLoc,
      )));
      await tester.pump();
      await tester.tap(find.byKey(const Key('near-me-fab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('no-service-sheet')), findsOneWidget);
      expect(find.textContaining('Paris, Lyon ou Marseille'), findsOneWidget);
    });

    testWidgets('position near Paris activates near-me filter', (tester) async {
      final mockLoc = MockLocationService();
      when(() => mockLoc.checkPermission())
          .thenAnswer((_) async => LocationPermission.always);
      when(() => mockLoc.getCurrentPosition()).thenAnswer((_) async => Position(
            latitude: 48.86,
            longitude: 2.35,
            timestamp: DateTime.now(),
            accuracy: 10,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          ));

      await tester.pumpWidget(_wrap(AnnouncementMapView(
        announcements: announcements,
        locationService: mockLoc,
      )));
      await tester.pump();
      await tester.tap(find.byKey(const Key('near-me-fab')));
      await tester.pumpAndSettle();

      expect(find.text('Paris'), findsWidgets);
    });
  });
}
