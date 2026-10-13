import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/storage/form_draft_cubit.dart';
import 'package:dony/core/storage/form_draft_store.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_draft.dart';
import 'package:dony/features/package_request/bloc/package_request_photos_cubit.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/package_request_create_screen.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_bloc.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_event.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_state.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../../helpers/form_draft_test_doubles.dart';
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

/// Catalogue embarqué, sans réseau (étape 2).
class _CatalogRepo implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

class _MockMobileMoneyAccountBloc
    extends MockBloc<MobileMoneyAccountEvent, MobileMoneyAccountState>
    implements MobileMoneyAccountBloc {}

void main() {
  late _MockRepo repo;
  late InMemoryFormDraftStorage storage;
  late FormDraftStore store;

  setUpAll(() {
    registerFallbackValue(ParcelSize.small);
    registerFallbackValue(TransportMode.plane);
    registerCityFallbackValues();
  });

  setUp(() {
    DonySnackbar.clearDedup();
    repo = _MockRepo();
    storage = InMemoryFormDraftStorage();
    store = testFormDraftStore(storage: storage);
    getIt.registerFactoryParam<PackageRequestFormBloc, PackageRequest?, void>(
      (editing, _) => PackageRequestFormBloc(
        repo,
        analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
        editing: editing,
      ),
    );
    if (getIt.isRegistered<FormDraftCubit>()) {
      getIt.unregister<FormDraftCubit>();
    }
    registerTestFormDraftCubit(store: store);
    getIt.registerFactory<PackageRequestPhotosCubit>(
      () => PackageRequestPhotosCubit(
        repo,
        makeDisabledAnalytics(MockAnalyticsBackend()),
      ),
    );
    getIt.registerFactory<MobileMoneyAccountBloc>(() {
      final b = _MockMobileMoneyAccountBloc();
      when(() => b.state).thenReturn(const MobileMoneyAccountInitial());
      return b;
    });
    getIt.registerFactory<CitySearchBloc>(
      () => CitySearchBloc(_MockCityRepo()),
    );
    registerFakeRecentCityStore();
    getIt.registerSingleton<IContentCategoryRepository>(_CatalogRepo());
  });

  tearDown(() {
    for (final unregister in [
      () => getIt.unregister<PackageRequestFormBloc>(),
      () => getIt.unregister<PackageRequestPhotosCubit>(),
      () => getIt.unregister<MobileMoneyAccountBloc>(),
      () => getIt.unregister<CitySearchBloc>(),
      () => getIt.unregister<FormDraftCubit>(),
      () => getIt.unregister<IContentCategoryRepository>(),
    ]) {
      try {
        unregister();
      } on Object {
        // Pas enregistré dans ce test.
      }
    }
    unregisterFakeRecentCityStore();
  });

  Future<void> open(WidgetTester tester, {Object? extra}) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (ctx, state) => Scaffold(
            body: Builder(
              builder: (inner) => ElevatedButton(
                key: const Key('open-create'),
                onPressed: () => inner.push<void>('/wizard', extra: extra),
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
            child: PackageRequestCreateScreen(
              initial: state.extra is PackageRequest
                  ? state.extra! as PackageRequest
                  : null,
              resuming: state.extra is PackageRequestDraftResume
                  ? state.extra! as PackageRequestDraftResume
                  : null,
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
    );
    await tester.tap(find.byKey(const Key('open-create')));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> draftData({int step = 1}) => {
    'step': step,
    'departureCity': 'Paris',
    'arrivalCity': 'Dakar',
    'desiredDate': PackageRequestFormDraft.encodeDate(
      DateTime.now().add(const Duration(days: 20)),
    ),
    'dateToleranceDays': 2,
    'transportMode': 'PLANE',
    'weightKg': 4,
    'categories': ['Vêtements'],
  };

  bool wizardOpen() =>
      find.byType(PackageRequestCreateScreen).evaluate().isNotEmpty;

  testWidgets('reprise : étape et saisie rechargées', (tester) async {
    await open(tester, extra: PackageRequestDraftResume(draftData()));

    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '4'), findsOneWidget);
  });

  testWidgets('sortie à l\'étape 1 : « Enregistrer le brouillon » le garde', (
    tester,
  ) async {
    await open(tester, extra: PackageRequestDraftResume(draftData()));

    // Retour à l'étape 1, puis sortie.
    await tester.tap(find.byType(DonyAppBarBackButton));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);
    await tester.tap(find.byType(DonyAppBarBackButton));
    await tester.pumpAndSettle();
    expect(find.text('Garder votre saisie ?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('draft-exit-save')));
    await tester.pumpAndSettle();

    final saved = await store.read(FormDraftKind.packageRequest);
    expect(saved?.step, 0);
    expect(saved?.data['departureCity'], 'Paris');
    expect(saved?.data['weightKg'], 4);
    expect(wizardOpen(), isFalse);
  });

  testWidgets('sortie : « Quitter sans enregistrer » efface le brouillon', (
    tester,
  ) async {
    await store.save(FormDraftKind.packageRequest, draftData());
    await open(tester, extra: PackageRequestDraftResume(draftData(step: 0)));

    await tester.tap(find.byType(DonyAppBarBackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('draft-exit-discard')));
    await tester.pumpAndSettle();

    expect(await store.read(FormDraftKind.packageRequest), isNull);
    expect(wizardOpen(), isFalse);
  });

  testWidgets('bouton « Brouillon » à l\'étape 2 : garde la saisie en cours', (
    tester,
  ) async {
    await open(tester, extra: PackageRequestDraftResume(draftData()));

    await tester.enterText(find.widgetWithText(TextFormField, '4'), '7');
    await tester.pump();
    await tester.tap(find.byKey(const Key('request-save-draft')));
    await tester.pumpAndSettle();

    final saved = await store.read(FormDraftKind.packageRequest);
    expect(saved?.step, 1);
    expect(saved?.data['weightKg'], 7);
    expect(saved?.data['categories'], ['Vêtements']);
    expect(wizardOpen(), isFalse);
  });

  testWidgets('bouton « Brouillon » sur un formulaire vierge : rien à garder', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.byKey(const Key('request-save-draft')));
    await tester.pump();

    expect(find.text('Rien à enregistrer pour l\'instant.'), findsOneWidget);
    expect(storage.values, isEmpty);
    expect(wizardOpen(), isTrue);
  });

  testWidgets('trousseau en panne : message, on reste sur le formulaire', (
    tester,
  ) async {
    storage.failWrites = true;
    await open(tester, extra: PackageRequestDraftResume(draftData()));

    await tester.tap(find.byKey(const Key('request-save-draft')));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Le brouillon n\'a pas pu être enregistré sur ce téléphone.'),
      findsOneWidget,
    );
    expect(wizardOpen(), isTrue);
  });

  testWidgets('modification d\'une demande : pas de bouton brouillon', (
    tester,
  ) async {
    await open(
      tester,
      extra: PackageRequest(
        id: 'pr-1',
        senderId: 's-1',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        desiredDate: DateTime.now().add(const Duration(days: 20)),
        dateToleranceDays: 2,
        weightKg: 5,
        parcelSize: ParcelSize.medium,
        transportMode: TransportMode.plane,
        categories: const ['Vêtements'],
        status: PackageRequestStatus.open,
        createdAt: DateTime(2026, 6),
      ),
    );

    expect(find.byKey(const Key('request-save-draft')), findsNothing);
  });
}
