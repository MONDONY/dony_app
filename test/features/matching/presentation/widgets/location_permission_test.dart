import 'package:dony/features/matching/presentation/widgets/location_permission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';

class MockLocationService extends Mock implements LocationService {}

void main() {
  group('requestLocationAccess', () {
    late MockLocationService svc;

    setUp(() {
      svc = MockLocationService();
    });

    test(
      'returns serviceDisabled when OS location is off — does NOT call checkPermission',
      () async {
        when(
          () => svc.isLocationServiceEnabled(),
        ).thenAnswer((_) async => false);

        final result = await requestLocationAccess(svc);

        expect(result, LocationAccess.serviceDisabled);
        verifyNever(() => svc.checkPermission());
      },
    );

    test(
      'returns granted when service enabled + checkPermission = whileInUse',
      () async {
        when(
          () => svc.isLocationServiceEnabled(),
        ).thenAnswer((_) async => true);
        when(
          () => svc.checkPermission(),
        ).thenAnswer((_) async => LocationPermission.whileInUse);

        final result = await requestLocationAccess(svc);

        expect(result, LocationAccess.granted);
      },
    );

    test(
      'returns granted when service enabled + checkPermission = always',
      () async {
        when(
          () => svc.isLocationServiceEnabled(),
        ).thenAnswer((_) async => true);
        when(
          () => svc.checkPermission(),
        ).thenAnswer((_) async => LocationPermission.always);

        final result = await requestLocationAccess(svc);

        expect(result, LocationAccess.granted);
      },
    );

    test(
      'returns granted when checkPermission=denied then requestPermission=whileInUse',
      () async {
        when(
          () => svc.isLocationServiceEnabled(),
        ).thenAnswer((_) async => true);
        when(
          () => svc.checkPermission(),
        ).thenAnswer((_) async => LocationPermission.denied);
        when(
          () => svc.requestPermission(),
        ).thenAnswer((_) async => LocationPermission.whileInUse);

        final result = await requestLocationAccess(svc);

        expect(result, LocationAccess.granted);
      },
    );

    test(
      'returns denied when checkPermission=denied then requestPermission=denied',
      () async {
        when(
          () => svc.isLocationServiceEnabled(),
        ).thenAnswer((_) async => true);
        when(
          () => svc.checkPermission(),
        ).thenAnswer((_) async => LocationPermission.denied);
        when(
          () => svc.requestPermission(),
        ).thenAnswer((_) async => LocationPermission.denied);

        final result = await requestLocationAccess(svc);

        expect(result, LocationAccess.denied);
      },
    );

    test('returns deniedForever when checkPermission=deniedForever', () async {
      when(() => svc.isLocationServiceEnabled()).thenAnswer((_) async => true);
      when(
        () => svc.checkPermission(),
      ).thenAnswer((_) async => LocationPermission.deniedForever);

      final result = await requestLocationAccess(svc);

      expect(result, LocationAccess.deniedForever);
    });

    test('maps unableToDetermine to denied', () async {
      when(() => svc.isLocationServiceEnabled()).thenAnswer((_) async => true);
      when(
        () => svc.checkPermission(),
      ).thenAnswer((_) async => LocationPermission.unableToDetermine);

      final result = await requestLocationAccess(svc);

      expect(result, LocationAccess.denied);
    });
  });

  group('LocationDeniedSheet widget', () {
    testWidgets(
      'renders serviceDisabled title and key when access=serviceDisabled',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LocationDeniedSheet(
                key: const Key('permission-denied-sheet'),
                access: LocationAccess.serviceDisabled,
              ),
            ),
          ),
        );

        expect(
          find.byKey(const Key('permission-denied-sheet')),
          findsOneWidget,
        );
        expect(find.text('Localisation désactivée'), findsOneWidget);
        // Button is in stickyBottom, NOT in the content widget
        expect(find.text('Ouvrir les réglages'), findsNothing);
      },
    );

    testWidgets('renders denied title when access=deniedForever', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationDeniedSheet(access: LocationAccess.deniedForever),
          ),
        ),
      );

      expect(find.text('Accès à la position refusé'), findsOneWidget);
      expect(find.text('Ouvrir les réglages'), findsNothing);
    });

    testWidgets('renders denied title when access=denied', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationDeniedSheet(access: LocationAccess.denied),
          ),
        ),
      );

      expect(find.text('Accès à la position refusé'), findsOneWidget);
    });

    testWidgets(
      'show() — serviceDisabled: sheet appears and calls openLocationSettings on tap',
      (tester) async {
        final mockSvc = MockLocationService();
        when(
          () => mockSvc.openLocationSettings(),
        ).thenAnswer((_) async => true);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => LocationDeniedSheet.show(
                    ctx,
                    access: LocationAccess.serviceDisabled,
                    service: mockSvc,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('permission-denied-sheet')),
          findsOneWidget,
        );
        expect(find.text('Ouvrir les réglages'), findsOneWidget);

        await tester.tap(find.text('Ouvrir les réglages'));
        await tester.pumpAndSettle();

        verify(() => mockSvc.openLocationSettings()).called(1);
      },
    );

    testWidgets(
      'show() — denied: sheet appears and calls openAppSettings on tap',
      (tester) async {
        final mockSvc = MockLocationService();
        when(() => mockSvc.openAppSettings()).thenAnswer((_) async => true);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => LocationDeniedSheet.show(
                    ctx,
                    access: LocationAccess.denied,
                    service: mockSvc,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('permission-denied-sheet')),
          findsOneWidget,
        );
        expect(find.text('Ouvrir les réglages'), findsOneWidget);

        await tester.tap(find.text('Ouvrir les réglages'));
        await tester.pumpAndSettle();

        verify(() => mockSvc.openAppSettings()).called(1);
      },
    );
  });
}
