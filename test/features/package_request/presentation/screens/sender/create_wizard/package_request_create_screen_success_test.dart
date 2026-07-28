import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_photos_cubit.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/package_request_create_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../../helpers/mock_analytics_backend.dart';

/// Widget test de la publication/édition d'une demande d'envoi — le SnackBar
/// de succès a été remplacé par `DonySuccessScreen` (Task 14). Le
/// `PackageRequestFormBloc` réel (avec `PackageRequestRepository` mocké) est
/// injecté via `getIt` (comme le fait `PackageRequestCreateScreen` en
/// interne) puis piloté directement par ses events — on n'a pas besoin de
/// remplir les 3 étapes du wizard à la main pour exercer le listener de
/// succès.
class _MockRepo extends Mock implements PackageRequestRepository {}

class _MockCityRepo extends Mock implements CityRepository {}

void main() {
  late _MockRepo repo;
  late PackageRequestFormBloc capturedBloc;

  final fakeRequest = PackageRequest(
    id: 'pr-created-1',
    senderId: 's-1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    desiredDate: DateTime(2026, 8, 15),
    dateToleranceDays: 3,
    weightKg: 5,
    parcelSize: ParcelSize.medium,
    transportMode: TransportMode.plane,
    categories: const ['Vêtements'],
    status: PackageRequestStatus.open,
    createdAt: DateTime(2026, 6, 10),
  );

  final editRequest = PackageRequest(
    id: 'pr-edit-1',
    senderId: 's-1',
    departureCity: 'Lyon',
    arrivalCity: 'Bamako',
    desiredDate: DateTime(2026, 7, 20),
    dateToleranceDays: 3,
    weightKg: 8,
    parcelSize: ParcelSize.medium,
    transportMode: TransportMode.plane,
    categories: const ['Vêtements'],
    status: PackageRequestStatus.open,
    createdAt: DateTime(2026, 5, 10),
  );

  setUpAll(() {
    registerFallbackValue(ParcelSize.small);
    registerFallbackValue(TransportMode.plane);
  });

  setUp(() {
    repo = _MockRepo();
    when(
      () => repo.create(
        departureCity: any(named: 'departureCity'),
        arrivalCity: any(named: 'arrivalCity'),
        desiredDate: any(named: 'desiredDate'),
        dateToleranceDays: any(named: 'dateToleranceDays'),
        weightKg: any(named: 'weightKg'),
        parcelSize: any(named: 'parcelSize'),
        transportMode: any(named: 'transportMode'),
        categories: any(named: 'categories'),
        negotiable: any(named: 'negotiable'),
        acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
        totalBudgetEur: any(named: 'totalBudgetEur'),
        description: any(named: 'description'),
        photoKeys: any(named: 'photoKeys'),
        pickupNeighborhood: any(named: 'pickupNeighborhood'),
        deliveryNeighborhood: any(named: 'deliveryNeighborhood'),
      ),
    ).thenAnswer((_) async => fakeRequest);

    when(
      () => repo.update(
        any(),
        departureCity: any(named: 'departureCity'),
        arrivalCity: any(named: 'arrivalCity'),
        desiredDate: any(named: 'desiredDate'),
        dateToleranceDays: any(named: 'dateToleranceDays'),
        weightKg: any(named: 'weightKg'),
        parcelSize: any(named: 'parcelSize'),
        transportMode: any(named: 'transportMode'),
        categories: any(named: 'categories'),
        negotiable: any(named: 'negotiable'),
        acceptedPaymentMethods: any(named: 'acceptedPaymentMethods'),
        totalBudgetEur: any(named: 'totalBudgetEur'),
        description: any(named: 'description'),
        photoUrl: any(named: 'photoUrl'),
        pickupNeighborhood: any(named: 'pickupNeighborhood'),
        deliveryNeighborhood: any(named: 'deliveryNeighborhood'),
        photoKeys: any(named: 'photoKeys'),
      ),
    ).thenAnswer((_) async => editRequest);

    getIt.registerFactoryParam<PackageRequestFormBloc, PackageRequest?, void>(
      (editing, _) {
        capturedBloc = PackageRequestFormBloc(
          repo,
          analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
          editing: editing,
        );
        return capturedBloc;
      },
    );
    getIt.registerFactory<PackageRequestPhotosCubit>(
      () => PackageRequestPhotosCubit(
        repo,
        makeDisabledAnalytics(MockAnalyticsBackend()),
      ),
    );
    getIt.registerFactory<CitySearchBloc>(
      () => CitySearchBloc(_MockCityRepo()),
    );
  });

  tearDown(() {
    if (getIt.isRegistered<PackageRequestFormBloc>()) {
      getIt.unregister<PackageRequestFormBloc>();
    }
    if (getIt.isRegistered<PackageRequestPhotosCubit>()) {
      getIt.unregister<PackageRequestPhotosCubit>();
    }
    if (getIt.isRegistered<CitySearchBloc>()) {
      getIt.unregister<CitySearchBloc>();
    }
  });

  Widget buildHarness() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (ctx, state) => Scaffold(
            body: Builder(
              builder: (inner) => Column(
                children: [
                  ElevatedButton(
                    key: const Key('open-create'),
                    onPressed: () => inner.push<void>('/wizard'),
                    child: const Text('Créer'),
                  ),
                  ElevatedButton(
                    key: const Key('open-edit'),
                    onPressed: () =>
                        inner.push<void>('/wizard', extra: editRequest),
                    child: const Text('Éditer'),
                  ),
                ],
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/wizard',
          builder: (_, state) => PackageRequestCreateScreen(
            initial: state.extra as PackageRequest?,
          ),
        ),
        GoRoute(
          path: '/package-requests/:id',
          builder: (_, state) => Scaffold(
            body: Text('Détail ${state.pathParameters['id']}'),
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Accueil')),
        ),
      ],
    );
    return MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
    );
  }

  Future<void> driveToSuccess(
    WidgetTester tester, {
    bool editing = false,
  }) async {
    await tester.pumpWidget(buildHarness());
    await tester.tap(
      find.byKey(Key(editing ? 'open-edit' : 'open-create')),
    );
    await tester.pumpAndSettle();

    capturedBloc
      ..add(
        FormStep1Submitted(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          desiredDate: DateTime(2026, 8, 15),
          dateToleranceDays: 3,
          transportMode: TransportMode.plane,
        ),
      )
      ..add(
        const FormStep2Submitted(
          weightKg: 5,
          parcelSize: ParcelSize.medium,
          categories: ['Vêtements'],
        ),
      )
      ..add(const FormStep3Submitted(targetPriceEur: 25));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'création réussie affiche DonySuccessScreen (plus de SnackBar)',
      (tester) async {
    await driveToSuccess(tester);

    expect(find.byType(SnackBar), findsNothing);
    expect(
      find.text('Demande publiée — les voyageurs sont notifiés'),
      findsNothing,
    );

    expect(find.byType(DonySuccessScreen), findsOneWidget);
    final successScreen = tester.widget<DonySuccessScreen>(
      find.byType(DonySuccessScreen),
    );
    expect(successScreen.mascotteType, DonyMascotteType.succes);
    expect(find.text('Demande publiée !'), findsOneWidget);
    expect(
      find.text(
        'Les voyageurs sont notifiés. Tu recevras des offres très vite.',
      ),
      findsOneWidget,
    );
    expect(find.text('Voir ma demande'), findsOneWidget);
  });

  testWidgets(
      'édition réussie affiche DonySuccessScreen avec le libellé édition',
      (tester) async {
    await driveToSuccess(tester, editing: true);

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Demande modifiée'), findsNothing);

    expect(find.byType(DonySuccessScreen), findsOneWidget);
    expect(find.text('Demande modifiée !'), findsOneWidget);
    expect(find.text('Tes modifications sont en ligne.'), findsOneWidget);
    expect(find.text('Voir ma demande'), findsOneWidget);
  });

  testWidgets(
      'CTA « Voir ma demande » ferme le wizard et navigue vers le détail',
      (tester) async {
    await driveToSuccess(tester);
    expect(find.byType(DonySuccessScreen), findsOneWidget);

    await tester.tap(find.text('Voir ma demande'));
    await tester.pumpAndSettle();

    expect(find.byType(DonySuccessScreen), findsNothing);
    expect(find.byType(PackageRequestCreateScreen), findsNothing);
    expect(find.text('Détail pr-created-1'), findsOneWidget);
  });

  testWidgets(
      'bouton fermer (X) par défaut ramène vers /home',
      (tester) async {
    await driveToSuccess(tester);
    expect(find.byType(DonySuccessScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();

    expect(find.byType(DonySuccessScreen), findsNothing);
    expect(find.byType(PackageRequestCreateScreen), findsNothing);
    expect(find.text('Accueil'), findsOneWidget);
  });
}
