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
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../../helpers/l10n_test_helpers.dart';
import '../../../../../../helpers/mock_analytics_backend.dart';
import '../../../../../../helpers/mock_recent_city_store.dart';

const _emptyHelpConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": []
}
''';

class _StaticHelpCenterSource implements HelpCenterConfigSource {
  const _StaticHelpCenterSource(this.json);

  final String json;

  @override
  String get activatedJson => json;

  @override
  Future<String?> fetchAndActivate() async => json;
}

class _MockRepo extends Mock implements PackageRequestRepository {}

class _MockCityRepo extends Mock implements CityRepository {}

/// Le cas « pas de budget » à l'étape 3 : le bloc porte l'erreur dans un
/// champ dédié et typé (`PackageRequestFormError.budgetRequired`, jamais un
/// texte), et l'écran choisit sa traduction pour le SnackBar. Cf.
/// `package_request_form_bloc_test.dart` pour le comportement du bloc seul —
/// ce fichier vérifie uniquement le branchement écran ↔ traduction.
void main() {
  late _MockRepo repo;
  late PackageRequestFormBloc capturedBloc;

  setUpAll(() {
    registerFallbackValue(ParcelSize.small);
    registerFallbackValue(TransportMode.plane);
    registerCityFallbackValues();
  });

  setUp(() {
    DonySnackbar.clearDedup();
    repo = _MockRepo();

    getIt.registerFactoryParam<PackageRequestFormBloc, PackageRequest?, void>((
      editing,
      _,
    ) {
      capturedBloc = PackageRequestFormBloc(
        repo,
        analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
      );
      return capturedBloc;
    });
    getIt.registerFactory<PackageRequestPhotosCubit>(
      () => PackageRequestPhotosCubit(
        repo,
        makeDisabledAnalytics(MockAnalyticsBackend()),
      ),
    );
    getIt.registerFactory<CitySearchBloc>(
      () => CitySearchBloc(_MockCityRepo()),
    );
    registerFakeRecentCityStore();
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
    unregisterFakeRecentCityStore();
  });

  Widget buildHarness() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (ctx, state) => Scaffold(
            body: Builder(
              builder: (inner) => ElevatedButton(
                key: const Key('open-create'),
                onPressed: () => inner.push<void>('/wizard'),
                child: const Text('Créer'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/wizard',
          builder: (_, state) => BlocProvider<HelpCenterBloc>(
            create: (_) => HelpCenterBloc(
              HelpCenterRepository(
                const _StaticHelpCenterSource(_emptyHelpConfigJson),
                fallbackJsonLoader: () async => _emptyHelpConfigJson,
              ),
              makeDisabledAnalytics(MockAnalyticsBackend()),
            )..add(const HelpCenterLoadRequested()),
            child: const PackageRequestCreateScreen(),
          ),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router, theme: AppTheme.light());
  }

  /// Pousse le wizard jusqu'à l'étape 3 SANS budget saisi, puis soumet — le
  /// bloc émet `formError: PackageRequestFormError.budgetRequired`.
  Future<void> submitWithoutBudget(WidgetTester tester) async {
    await tester.pumpWidget(buildHarness());
    await tester.tap(find.byKey(const Key('open-create')));
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
      ..add(const FormStep3Submitted());
    await tester.pumpAndSettle();
  }

  testWidgets('pas de budget : le SnackBar affiche la traduction française', (
    tester,
  ) async {
    await submitWithoutBudget(tester);

    expect(find.text('Indiquez un budget pour continuer'), findsOneWidget);
  });

  testWidgets(
    'pas de budget, anglais : le SnackBar affiche la traduction anglaise',
    (tester) async {
      useEnglish();
      await submitWithoutBudget(tester);

      expect(find.text('Enter a budget to continue'), findsOneWidget);
    },
  );
}
