import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/package_request_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockPackageRequestRepository extends Mock
    implements PackageRequestRepository {}

class _MockNegotiationBloc extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}

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
  createdAt: DateTime(2026, 1, 1),
);

Widget _buildApp({required String requestId}) {
  final router = GoRouter(
    initialLocation: '/package-requests/$requestId',
    routes: [
      GoRoute(
        path: '/package-requests/:id',
        builder: (ctx, state) =>
            PackageRequestDetailScreen(requestId: state.pathParameters['id']!),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router, theme: AppTheme.light());
}

/// Harness avec une route parente réelle, poussée avant le détail — permet
/// d'observer si `context.pop()` ferme bien l'écran (retour sur "open") ou
/// si l'écran reste ouvert (ex: annulation échouée).
Widget _buildPushableApp({required String requestId}) {
  final router = GoRouter(
    initialLocation: '/list',
    routes: [
      GoRoute(
        path: '/list',
        builder: (ctx, __) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => ctx.push('/package-requests/$requestId'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/package-requests/:id',
        builder: (ctx, state) =>
            PackageRequestDetailScreen(requestId: state.pathParameters['id']!),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router, theme: AppTheme.light());
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  late _MockPackageRequestRepository repo;
  late _MockNegotiationBloc negotiationBloc;
  late _MockAnalyticsService analytics;

  setUp(() {
    DonySnackbar.clearDedup();
    repo = _MockPackageRequestRepository();
    negotiationBloc = _MockNegotiationBloc();
    analytics = _MockAnalyticsService();

    when(() => negotiationBloc.state).thenReturn(const NegotiationInitial());
    when(
      () => negotiationBloc.stream,
    ).thenAnswer((_) => const Stream<NegotiationState>.empty());
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});

    if (!getIt.isRegistered<PackageRequestRepository>()) {
      getIt.registerSingleton<PackageRequestRepository>(repo);
    }
    if (!getIt.isRegistered<NegotiationBloc>()) {
      getIt.registerSingleton<NegotiationBloc>(negotiationBloc);
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
    if (getIt.isRegistered<NegotiationBloc>()) {
      await getIt.unregister<NegotiationBloc>();
    }
    if (getIt.isRegistered<AnalyticsService>()) {
      await getIt.unregister<AnalyticsService>();
    }
  });

  testWidgets('renders app bar title "Ma demande"', (tester) async {
    when(() => repo.getById('pr-1')).thenAnswer((_) async => _fakeRequest());
    when(() => repo.listThreadsForRequest('pr-1')).thenAnswer((_) async => []);

    await tester.pumpWidget(_buildApp(requestId: 'pr-1'));
    await tester.pumpAndSettle();

    expect(find.text('Ma demande'), findsOneWidget);
  });

  testWidgets('shows error view when getById throws', (tester) async {
    when(() => repo.getById('pr-1')).thenThrow(Exception('Network error'));
    when(() => repo.listThreadsForRequest('pr-1')).thenAnswer((_) async => []);

    await tester.pumpWidget(_buildApp(requestId: 'pr-1'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Exception: Network error'), findsOneWidget);
  });

  testWidgets('shows request details when loaded', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    when(() => repo.getById('pr-1')).thenAnswer((_) async => _fakeRequest());
    when(() => repo.listThreadsForRequest('pr-1')).thenAnswer((_) async => []);

    await tester.pumpWidget(_buildApp(requestId: 'pr-1'));
    await tester.pumpAndSettle();

    // The app bar title should be visible
    expect(find.text('Ma demande'), findsOneWidget);
    // The corridor text should appear somewhere
    expect(find.textContaining('Paris'), findsWidgets);
  });

  testWidgets('shows Annuler tile when status is open', (tester) async {
    when(
      () => repo.getById('pr-1'),
    ).thenAnswer((_) async => _fakeRequest(status: PackageRequestStatus.open));
    when(() => repo.listThreadsForRequest('pr-1')).thenAnswer((_) async => []);

    await tester.pumpWidget(_buildApp(requestId: 'pr-1'));
    await tester.pumpAndSettle();

    expect(find.text('Annuler'), findsOneWidget);
  });

  testWidgets('aucun CTA « Compléter les détails » pour une demande acceptée', (
    tester,
  ) async {
    when(() => repo.getById('pr-1')).thenAnswer(
      (_) async => _fakeRequest(status: PackageRequestStatus.accepted),
    );
    when(() => repo.listThreadsForRequest('pr-1')).thenAnswer((_) async => []);

    await tester.pumpWidget(_buildApp(requestId: 'pr-1'));
    await tester.pumpAndSettle();

    // Détails + paiement se font dans le fil de négo : plus de CTA ici une fois
    // la demande acceptée (elle vit désormais dans l'onglet Envois).
    expect(find.textContaining('Compléter'), findsNothing);
    expect(find.text('Annuler'), findsNothing);
  });

  testWidgets('draft request shows Publier tile', (tester) async {
    when(
      () => repo.getById('pr-1'),
    ).thenAnswer((_) async => _fakeRequest(status: PackageRequestStatus.draft));
    when(() => repo.listThreadsForRequest('pr-1')).thenAnswer((_) async => []);

    await tester.pumpWidget(_buildApp(requestId: 'pr-1'));
    await tester.pumpAndSettle();

    expect(find.text('Publier'), findsOneWidget);
  });

  testWidgets('AppBar has no more overflow menu', (tester) async {
    when(() => repo.getById('pr-1')).thenAnswer((_) async => _fakeRequest());
    when(() => repo.listThreadsForRequest('pr-1')).thenAnswer((_) async => []);

    await tester.pumpWidget(_buildApp(requestId: 'pr-1'));
    await tester.pumpAndSettle();

    // L'ancien "..." était une DonyIcon (SVG), jamais un Icons.more_horiz
    // Material — vérifier son vrai tooltip, seul signal fiable qu'il a
    // disparu (byIcon(Icons.more_horiz) serait vacuous, déjà vrai avant).
    expect(find.byTooltip("Plus d'options"), findsNothing);
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

    await tester.pumpWidget(_buildApp(requestId: 'pr-1'));
    await tester.pumpAndSettle();

    expect(find.text('Publier'), findsOneWidget);

    await tester.tap(find.text('Publier'));
    await tester.pumpAndSettle();

    verify(() => repo.publish('pr-1')).called(1);
    // Chargement initial + rechargement après succès de l'action.
    verify(() => repo.getById('pr-1')).called(2);
    verify(
      () => analytics.logEvent(AnalyticsEvents.packageRequestPublished),
    ).called(1);
    // Rechargé en OPEN : la tuile Publier n'a plus lieu d'être.
    expect(find.text('Publier'), findsNothing);
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

    await tester.pumpWidget(_buildApp(requestId: 'pr-1'));
    await tester.pumpAndSettle();

    expect(find.text('Dépublier'), findsOneWidget);

    await tester.tap(find.text('Dépublier'));
    await tester.pumpAndSettle();

    verify(() => repo.unpublish('pr-1')).called(1);
    verify(
      () => analytics.logEvent(AnalyticsEvents.packageRequestUnpublished),
    ).called(1);
    // Rechargé en DRAFT : la grille montre de nouveau Publier.
    expect(find.text('Publier'), findsOneWidget);
  });

  testWidgets(
    'confirming Annuler tile calls repo.cancel and closes the screen',
    (tester) async {
      when(() => repo.getById('pr-1')).thenAnswer(
        (_) async => _fakeRequest(status: PackageRequestStatus.open),
      );
      when(
        () => repo.listThreadsForRequest('pr-1'),
      ).thenAnswer((_) async => []);
      when(() => repo.cancel('pr-1')).thenAnswer((_) async {});

      await tester.pumpWidget(_buildPushableApp(requestId: 'pr-1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Ma demande'), findsOneWidget);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(find.text('Annuler cette demande ?'), findsOneWidget);

      await tester.tap(find.text('Annuler la demande'));
      await tester.pumpAndSettle();

      verify(() => repo.cancel('pr-1')).called(1);
      // L'écran s'est bien fermé — retour sur la route parente.
      expect(find.text('Ma demande'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    },
  );

  testWidgets(
    'cancel failure keeps the screen open and shows an error snackbar '
    '(régression : le pop ne doit pas s\'exécuter sur échec)',
    (tester) async {
      when(() => repo.getById('pr-1')).thenAnswer(
        (_) async => _fakeRequest(status: PackageRequestStatus.open),
      );
      when(
        () => repo.listThreadsForRequest('pr-1'),
      ).thenAnswer((_) async => []);
      when(() => repo.cancel('pr-1')).thenThrow(Exception('boom'));

      await tester.pumpWidget(_buildPushableApp(requestId: 'pr-1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler la demande'));
      await tester.pumpAndSettle();

      verify(() => repo.cancel('pr-1')).called(1);
      // L'annulation a échoué : l'écran doit rester ouvert, pas se fermer
      // silencieusement pendant que le snackbar d'erreur s'affiche.
      expect(find.text('Ma demande'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    },
  );

  testWidgets('retry button reloads data after error', (tester) async {
    var callCount = 0;
    when(() => repo.getById('pr-1')).thenAnswer((_) async {
      callCount++;
      if (callCount == 1) throw Exception('Network error');
      return _fakeRequest();
    });
    when(() => repo.listThreadsForRequest('pr-1')).thenAnswer((_) async => []);

    await tester.pumpWidget(_buildApp(requestId: 'pr-1'));
    await tester.pumpAndSettle();

    // Should show error
    expect(find.text('Réessayer'), findsOneWidget);

    // Tap retry
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    // Should now show the request
    expect(find.text('Ma demande'), findsOneWidget);
  });
}
