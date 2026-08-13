// Task 5 fix-up — PackageRequestDetailBottomSheet (chemin principal, ouvert
// depuis my_package_requests_screen.dart) n'avait aucun test dans
// l'implémentation initiale de la Task 5, alors que c'est la partie la plus
// réécrite du diff (_SheetBody + ValueNotifier<_SheetBtnConfig?> → un seul
// _SheetFrame stateful). Ces tests exercent réellement les tuiles de la
// grille (Publier/Dépublier/Annuler), pas seulement leur présence.

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/package_request_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockPackageRequestRepository extends Mock
    implements PackageRequestRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

PackageRequest _fakeRequest({
  PackageRequestStatus status = PackageRequestStatus.open,
}) => PackageRequest(
  id: 'pr-1',
  senderId: 'sender-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  desiredDate: DateTime(2026, 8, 15),
  dateToleranceDays: 3,
  weightKg: 5.0,
  parcelSize: ParcelSize.medium,
  transportMode: TransportMode.plane,
  categories: const ['Vêtements'],
  status: status,
  createdAt: DateTime(2026),
);

Widget _buildApp() {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Center(
        child: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => PackageRequestDetailBottomSheet.show(ctx, 'pr-1'),
            child: const Text('open sheet'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  late _MockPackageRequestRepository repo;
  late _MockAnalyticsService analytics;

  setUp(() {
    DonySnackbar.clearDedup();
    repo = _MockPackageRequestRepository();
    analytics = _MockAnalyticsService();

    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});

    if (!getIt.isRegistered<PackageRequestRepository>()) {
      getIt.registerSingleton<PackageRequestRepository>(repo);
    }
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerSingleton<AnalyticsService>(analytics);
  });

  tearDown(() async {
    if (getIt.isRegistered<PackageRequestRepository>()) {
      await getIt.unregister<PackageRequestRepository>();
    }
    if (getIt.isRegistered<AnalyticsService>()) {
      await getIt.unregister<AnalyticsService>();
    }
  });

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens showing the header title and hero card', (tester) async {
    when(() => repo.getById('pr-1')).thenAnswer((_) async => _fakeRequest());
    when(() => repo.listThreadsForRequest('pr-1')).thenAnswer((_) async => []);

    await openSheet(tester);

    expect(find.text('Ma demande'), findsOneWidget);
    expect(find.textContaining('Paris'), findsWidgets);
  });

  testWidgets('tapping Publier tile calls repo.publish and reloads', (
    tester,
  ) async {
    var status = PackageRequestStatus.draft;
    when(
      () => repo.getById('pr-1'),
    ).thenAnswer((_) async => _fakeRequest(status: status));
    when(() => repo.listThreadsForRequest('pr-1')).thenAnswer((_) async => []);
    when(() => repo.publish('pr-1')).thenAnswer((_) async {
      status = PackageRequestStatus.open;
      return _fakeRequest(status: status);
    });

    await openSheet(tester);

    expect(find.text('Publier'), findsOneWidget);

    await tester.tap(find.text('Publier'));
    await tester.pumpAndSettle();

    verify(() => repo.publish('pr-1')).called(1);
    verify(() => repo.getById('pr-1')).called(2);
    verify(
      () => analytics.logEvent(AnalyticsEvents.packageRequestPublished),
    ).called(1);
    expect(find.text('Publier'), findsNothing);
    // La sheet est restée ouverte (rechargement, pas fermeture).
    expect(find.text('Ma demande'), findsOneWidget);
  });

  testWidgets('tapping Dépublier tile calls repo.unpublish and reloads', (
    tester,
  ) async {
    var status = PackageRequestStatus.open;
    when(
      () => repo.getById('pr-1'),
    ).thenAnswer((_) async => _fakeRequest(status: status));
    when(() => repo.listThreadsForRequest('pr-1')).thenAnswer((_) async => []);
    when(() => repo.unpublish('pr-1')).thenAnswer((_) async {
      status = PackageRequestStatus.draft;
      return _fakeRequest(status: status);
    });

    await openSheet(tester);

    expect(find.text('Dépublier'), findsOneWidget);

    await tester.tap(find.text('Dépublier'));
    await tester.pumpAndSettle();

    verify(() => repo.unpublish('pr-1')).called(1);
    verify(
      () => analytics.logEvent(AnalyticsEvents.packageRequestUnpublished),
    ).called(1);
    expect(find.text('Publier'), findsOneWidget);
  });

  testWidgets(
    'confirming Annuler tile calls repo.cancel and closes the sheet',
    (tester) async {
      when(() => repo.getById('pr-1')).thenAnswer((_) async => _fakeRequest());
      when(
        () => repo.listThreadsForRequest('pr-1'),
      ).thenAnswer((_) async => []);
      when(() => repo.cancel('pr-1')).thenAnswer((_) async {});

      await openSheet(tester);
      expect(find.text('Ma demande'), findsOneWidget);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(find.text('Annuler cette demande ?'), findsOneWidget);

      await tester.tap(find.text('Annuler la demande'));
      await tester.pumpAndSettle();

      verify(() => repo.cancel('pr-1')).called(1);
      // La sheet s'est fermée — on retrouve le bouton d'ouverture.
      expect(find.text('Ma demande'), findsNothing);
      expect(find.text('open sheet'), findsOneWidget);
    },
  );

  testWidgets('cancel failure keeps the sheet open and shows an error snackbar '
      '(régression : le pop ne doit pas s\'exécuter sur échec)', (
    tester,
  ) async {
    when(() => repo.getById('pr-1')).thenAnswer((_) async => _fakeRequest());
    when(() => repo.listThreadsForRequest('pr-1')).thenAnswer((_) async => []);
    when(() => repo.cancel('pr-1')).thenThrow(Exception('boom'));

    await openSheet(tester);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler la demande'));
    await tester.pumpAndSettle();

    verify(() => repo.cancel('pr-1')).called(1);
    // La sheet doit rester ouverte — pas de fermeture silencieuse pendant
    // que le snackbar d'erreur s'affiche.
    expect(find.text('Ma demande'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
