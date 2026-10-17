import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/storage/form_draft_cubit.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
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

import '../../../../../../helpers/ai_form_draft_test_doubles.dart';
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

class _CatalogRepo implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

class _MockMobileMoneyAccountBloc
    extends MockBloc<MobileMoneyAccountEvent, MobileMoneyAccountState>
    implements MobileMoneyAccountBloc {}

final _request = PackageRequest(
  id: 'pr-1',
  senderId: 's-1',
  departureCity: 'Lyon',
  arrivalCity: 'Bamako',
  desiredDate: DateTime(2026, 12, 20),
  dateToleranceDays: 3,
  weightKg: 8,
  parcelSize: ParcelSize.medium,
  transportMode: TransportMode.plane,
  categories: const ['Livres'],
  status: PackageRequestStatus.draft,
  createdAt: DateTime(2026, 10),
);

void main() {
  late _MockRepo repo;

  setUpAll(() {
    registerFallbackValue(ParcelSize.small);
    registerFallbackValue(TransportMode.plane);
    registerCityFallbackValues();
  });

  setUp(() {
    DonySnackbar.clearDedup();
    repo = _MockRepo();
    getIt.registerFactoryParam<
      PackageRequestFormBloc,
      PackageRequest?,
      PackageRequestDuplicate?
    >(
      (editing, duplicating) => PackageRequestFormBloc(
        repo,
        analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
        editing: editing,
        duplicating: duplicating,
      ),
    );
    if (getIt.isRegistered<FormDraftCubit>()) {
      getIt.unregister<FormDraftCubit>();
    }
    registerTestFormDraftCubit();
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
              duplicating: state.extra is PackageRequestDuplicate
                  ? state.extra! as PackageRequestDuplicate
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

  AiResolvedDraft outcome() => AiResolvedDraft(
    draft: {
      'departureCity': 'Lyon',
      'arrivalCity': 'Dakar',
      'desiredDate': isoDate(DateTime.now().add(const Duration(days: 30))),
      'dateToleranceDays': 3,
      'weightKg': 5,
      'parcelSize': 'MEDIUM',
      'categories': const ['vêtements'],
      'acceptedPaymentMethods': const ['STRIPE'],
      'totalBudget': 60,
      'currency': 'EUR',
    },
  );

  testWidgets('carte visible en création quand formDraftEnabled', (
    tester,
  ) async {
    useAiFormDraft(enabled: true);
    await open(tester);
    expect(find.byKey(const Key('ai-entry-cta')), findsOneWidget);
  });

  testWidgets('carte absente si formDraftEnabled est faux ou absent', (
    tester,
  ) async {
    useAiFormDraft(enabled: false);
    await open(tester);
    expect(find.byKey(const Key('ai-entry-cta')), findsNothing);
  });

  testWidgets('carte absente en édition', (tester) async {
    useAiFormDraft(enabled: true);
    await open(tester, extra: _request);
    expect(find.byKey(const Key('ai-entry-cta')), findsNothing);
  });

  testWidgets('carte absente en duplication', (tester) async {
    useAiFormDraft(enabled: true);
    await open(tester, extra: PackageRequestDuplicate(_request));
    expect(find.byKey(const Key('ai-entry-cta')), findsNothing);
  });

  testWidgets('carte absente en reprise de brouillon', (tester) async {
    useAiFormDraft(enabled: true);
    await open(
      tester,
      extra: const PackageRequestDraftResume({
        'step': 0,
        'departureCity': 'Paris',
      }),
    );
    expect(find.byKey(const Key('ai-entry-cta')), findsNothing);
  });

  testWidgets('« Créer avec l’IA » remplit le wizard : bandeau, marques', (
    tester,
  ) async {
    final launcher = useAiFormDraft(enabled: true, outcome: outcome());
    await open(tester);

    await tester.tap(find.byKey(const Key('ai-entry-cta')));
    await tester.pumpAndSettle();

    expect(launcher.calls.single.kind, AiFormKind.packageRequest);
    expect(find.byKey(const Key('ai-filled-banner')), findsOneWidget);
    expect(find.byKey(const Key('ai-field-mark')), findsWidgets);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('Lyon'), findsWidgets);

    // Étape 2 : le poids dicté est dans son champ.
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '5'), findsOneWidget);
  });

  testWidgets('« Reparler » qui ne remplit que la date garde les marques', (
    tester,
  ) async {
    final launcher = useAiFormDraft(enabled: true, outcome: outcome());
    await open(tester);
    await tester.tap(find.byKey(const Key('ai-entry-cta')));
    await tester.pumpAndSettle();
    final marks = find.byKey(const Key('ai-field-mark')).evaluate().length;
    expect(marks, greaterThan(1));

    launcher.outcome = const AiResolvedDraft(draft: {'dateToleranceDays': 2});
    await tester.tap(find.byKey(const Key('ai-talk-again')));
    await tester.pumpAndSettle();

    expect(launcher.calls, hasLength(2));
    expect(find.byKey(const Key('ai-field-mark')), findsNWidgets(marks));
  });

  testWidgets('feuille fermée sans remplir : le wizard ne change pas', (
    tester,
  ) async {
    useAiFormDraft(enabled: true);
    await open(tester);
    await tester.tap(find.byKey(const Key('ai-entry-cta')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai-filled-banner')), findsNothing);
    expect(find.byKey(const Key('ai-field-mark')), findsNothing);
  });
}
