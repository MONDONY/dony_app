import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/content_category.dart';
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

class _MockNegotiationBloc
    extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}

PackageRequest _fakeRequest({
  PackageRequestStatus status = PackageRequestStatus.open,
}) =>
    PackageRequest(
      id: 'pr-1',
      senderId: 'sender-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      desiredDate: DateTime(2026, 8, 15),
      dateToleranceDays: 3,
      weightKg: 5.0,
      parcelSize: ParcelSize.medium,
      transportMode: TransportMode.plane,
      contentCategory: ContentCategory.vetements,
      status: status,
      createdAt: DateTime(2026, 1, 1),
    );

Widget _buildApp({required String requestId}) {
  final router = GoRouter(
    initialLocation: '/package-requests/$requestId',
    routes: [
      GoRoute(
        path: '/package-requests/:id',
        builder: (ctx, state) => PackageRequestDetailScreen(
          requestId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/package-requests/:id/shipment',
        builder: (ctx, state) =>
            const Scaffold(body: Text('Shipment screen')),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.light,
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  late _MockPackageRequestRepository repo;
  late _MockNegotiationBloc negotiationBloc;

  setUp(() {
    repo = _MockPackageRequestRepository();
    negotiationBloc = _MockNegotiationBloc();

    when(() => negotiationBloc.state).thenReturn(const NegotiationInitial());
    when(() => negotiationBloc.stream)
        .thenAnswer((_) => const Stream<NegotiationState>.empty());

    if (!getIt.isRegistered<PackageRequestRepository>()) {
      getIt.registerSingleton<PackageRequestRepository>(repo);
    }
    if (!getIt.isRegistered<NegotiationBloc>()) {
      getIt.registerSingleton<NegotiationBloc>(negotiationBloc);
    }
  });

  tearDown(() async {
    if (getIt.isRegistered<PackageRequestRepository>()) {
      await getIt.unregister<PackageRequestRepository>();
    }
    if (getIt.isRegistered<NegotiationBloc>()) {
      await getIt.unregister<NegotiationBloc>();
    }
  });

  testWidgets('renders app bar title "Ma demande"', (tester) async {
    when(() => repo.getById('pr-1'))
        .thenAnswer((_) async => _fakeRequest());
    when(() => repo.listThreadsForRequest('pr-1'))
        .thenAnswer((_) async => []);

    await tester.pumpWidget(_buildApp(requestId: 'pr-1'));
    await tester.pumpAndSettle();

    expect(find.text('Ma demande'), findsOneWidget);
  });

  testWidgets('shows error view when getById throws', (tester) async {
    when(() => repo.getById('pr-1')).thenThrow(Exception('Network error'));
    when(() => repo.listThreadsForRequest('pr-1'))
        .thenAnswer((_) async => []);

    await tester.pumpWidget(_buildApp(requestId: 'pr-1'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Exception: Network error'), findsOneWidget);
  });

  testWidgets('shows request details when loaded', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    when(() => repo.getById('pr-1'))
        .thenAnswer((_) async => _fakeRequest());
    when(() => repo.listThreadsForRequest('pr-1'))
        .thenAnswer((_) async => []);

    await tester.pumpWidget(_buildApp(requestId: 'pr-1'));
    await tester.pumpAndSettle();

    // The app bar title should be visible
    expect(find.text('Ma demande'), findsOneWidget);
    // The corridor text should appear somewhere
    expect(find.textContaining('Paris'), findsWidgets);
  });

  testWidgets('shows Annuler button when status is open', (tester) async {
    when(() => repo.getById('pr-1'))
        .thenAnswer((_) async => _fakeRequest(status: PackageRequestStatus.open));
    when(() => repo.listThreadsForRequest('pr-1'))
        .thenAnswer((_) async => []);

    await tester.pumpWidget(_buildApp(requestId: 'pr-1'));
    await tester.pumpAndSettle();

    expect(find.text('Annuler la demande'), findsOneWidget);
  });

  testWidgets('shows Compléter les détails button when status is accepted',
      (tester) async {
    when(() => repo.getById('pr-1')).thenAnswer(
        (_) async => _fakeRequest(status: PackageRequestStatus.accepted));
    when(() => repo.listThreadsForRequest('pr-1'))
        .thenAnswer((_) async => []);

    await tester.pumpWidget(_buildApp(requestId: 'pr-1'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Compléter les détails'), findsOneWidget);
  });

  testWidgets('retry button reloads data after error', (tester) async {
    var callCount = 0;
    when(() => repo.getById('pr-1')).thenAnswer((_) async {
      callCount++;
      if (callCount == 1) throw Exception('Network error');
      return _fakeRequest();
    });
    when(() => repo.listThreadsForRequest('pr-1'))
        .thenAnswer((_) async => []);

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
