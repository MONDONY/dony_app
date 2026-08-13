import 'package:dio/dio.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/storage/hive_service.dart';
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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../../helpers/currency_test_doubles.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../../helpers/mock_analytics_backend.dart';
import '../../../../../../helpers/mock_recent_city_store.dart';

const _emptyHelpConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": []
}
''';

const _requestPublishHelpConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": [
    {
      "id": "request_publish_basics",
      "title": "Publier une demande",
      "description": "Décrire son colis pour recevoir des offres.",
      "youtubeVideoId": "dQw4w9WgXcQ",
      "order": 1,
      "active": true,
      "contexts": ["requestPublish"]
    }
  ]
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

  final fakeDraftRequest = PackageRequest(
    id: 'pr-draft-1',
    senderId: 's-1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    desiredDate: DateTime(2026, 8, 15),
    dateToleranceDays: 3,
    weightKg: 5,
    parcelSize: ParcelSize.medium,
    transportMode: TransportMode.plane,
    categories: const ['Vêtements'],
    status: PackageRequestStatus.draft,
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
    registerCityFallbackValues();
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

    // Cas saveAsDraft:true isolé de la stub générique ci-dessus (qui, faute
    // de matcher explicite sur ce paramètre nommé, ne capture que la valeur
    // par défaut `false`) — le brouillon renvoie une PackageRequest au
    // status DRAFT.
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
        saveAsDraft: true,
      ),
    ).thenAnswer((_) async => fakeDraftRequest);

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

    getIt.registerFactoryParam<PackageRequestFormBloc, PackageRequest?, void>((
      editing,
      _,
    ) {
      capturedBloc = PackageRequestFormBloc(
        repo,
        analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
        editing: editing,
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

  Widget buildHarness({String helpConfigJson = _emptyHelpConfigJson}) {
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
          builder: (_, state) => BlocProvider<HelpCenterBloc>(
            create: (_) => HelpCenterBloc(
              HelpCenterRepository(
                _StaticHelpCenterSource(helpConfigJson),
                fallbackJsonLoader: () async => _emptyHelpConfigJson,
              ),
              makeDisabledAnalytics(MockAnalyticsBackend()),
            )..add(const HelpCenterLoadRequested()),
            child: PackageRequestCreateScreen(
              initial: state.extra as PackageRequest?,
            ),
          ),
        ),
        GoRoute(
          path: '/package-requests/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Détail ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Accueil')),
        ),
        GoRoute(
          path: '/profile/help/tutorial/:tutorialId',
          builder: (_, state) => Scaffold(
            body: Text('TutorialStub:${state.pathParameters['tutorialId']}'),
          ),
        ),
        GoRoute(
          path: '/profile/upgrade-to-pro',
          builder: (_, _) => const Scaffold(body: Text('UpgradeToProStub')),
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
    bool saveAsDraft = false,
    String helpConfigJson = _emptyHelpConfigJson,
  }) async {
    await tester.pumpWidget(buildHarness(helpConfigJson: helpConfigJson));
    await tester.tap(find.byKey(Key(editing ? 'open-edit' : 'open-create')));
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
      ..add(FormStep3Submitted(targetPriceEur: 25, saveAsDraft: saveAsDraft));
    await tester.pumpAndSettle();
  }

  /// Pousse le wizard jusqu'à l'étape 3 (budget) sans la soumettre — utile
  /// pour piloter le CTA « Aperçu » et la sheet qu'il ouvre depuis l'UI
  /// réelle, plutôt que de dispatcher `FormStep3Submitted` directement.
  Future<void> driveToStep3(WidgetTester tester) async {
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
      ..add(const PackageRequestTotalBudgetChanged(25));
    await tester.pumpAndSettle();
  }

  /// Matcher `repo.create` complet, à combiner avec `.thenAnswer`/`.thenThrow`
  /// (stub) ou `.called(1)` (verify) — évite de dupliquer les 15 paramètres
  /// nommés à chaque nouveau cas `saveAsDraft`.
  Future<PackageRequest> Function() createCall({required bool saveAsDraft}) =>
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
        saveAsDraft: saveAsDraft,
      );

  List<dynamic> captureSaveAsDraftCalls() => verify(
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
      saveAsDraft: captureAny(named: 'saveAsDraft'),
    ),
  ).captured;

  testWidgets('carte tutoriel contextuelle affichée avant la première étape et '
      'navigue vers le tutoriel au tap', (tester) async {
    await tester.pumpWidget(
      buildHarness(helpConfigJson: _requestPublishHelpConfigJson),
    );
    await tester.tap(find.byKey(const Key('open-create')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(PackageRequestCreateScreen), findsOneWidget);
    expect(find.text('Besoin d\'aide ? Voir le tutoriel'), findsOneWidget);

    await tester.tap(find.text('Besoin d\'aide ? Voir le tutoriel'));
    await tester.pumpAndSettle();

    expect(find.text('TutorialStub:request_publish_basics'), findsOneWidget);
  });

  testWidgets('bandeau devise invalide : ne prétend pas publier en EUR', (
    tester,
  ) async {
    registerCurrencyPreference(42);
    await tester.pumpWidget(buildHarness());
    await tester.tap(find.byKey(const Key('open-create')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('currency-publish-banner')), findsOneWidget);
    expect(find.text('Devise à confirmer'), findsOneWidget);
    expect(find.text('Publié en Euro (EUR)'), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('currency-publish-banner'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('step1-departure-city'))).dy,
      ),
    );
  });

  testWidgets('bandeau devise absent en édition de demande', (tester) async {
    await tester.pumpWidget(buildHarness());
    await tester.tap(find.byKey(const Key('open-edit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('currency-publish-banner')), findsNothing);
  });

  testWidgets('création réussie affiche DonySuccessScreen (plus de SnackBar)', (
    tester,
  ) async {
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
    },
  );

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
    },
  );

  testWidgets(
    'édition : CTA « Voir ma demande » ferme le wizard SANS repousser un '
    'second écran détail (régression : le retour au caller par pop(true) '
    'doublonnait avec un router.push vers la même demande)',
    (tester) async {
      await driveToSuccess(tester, editing: true);
      expect(find.byType(DonySuccessScreen), findsOneWidget);

      await tester.tap(find.text('Voir ma demande'));
      await tester.pumpAndSettle();

      expect(find.byType(DonySuccessScreen), findsNothing);
      expect(find.byType(PackageRequestCreateScreen), findsNothing);
      // pop(true) suffit : on retrouve l'appelant (ici le launcher du
      // harness), jamais une route détail poussée par-dessus.
      expect(find.text('Détail pr-edit-1'), findsNothing);
      expect(find.byKey(const Key('open-edit')), findsOneWidget);
    },
  );

  testWidgets('bouton fermer (X) par défaut ramène vers /home', (tester) async {
    await driveToSuccess(tester);
    expect(find.byType(DonySuccessScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();

    expect(find.byType(DonySuccessScreen), findsNothing);
    expect(find.byType(PackageRequestCreateScreen), findsNothing);
    expect(find.text('Accueil'), findsOneWidget);
  });

  // ── Task 3 : sheet d'aperçu + option brouillon ──────────────────────────

  testWidgets(
    'succès en brouillon affiche le titre, le CTA et l\'analyticsContext '
    'dédiés (variante DonySuccessScreen)',
    (tester) async {
      await driveToSuccess(tester, saveAsDraft: true);

      expect(find.byType(DonySuccessScreen), findsOneWidget);
      final successScreen = tester.widget<DonySuccessScreen>(
        find.byType(DonySuccessScreen),
      );
      expect(find.text('Brouillon enregistré !'), findsOneWidget);
      expect(
        find.text('Tu pourras la publier quand tu le souhaites.'),
        findsOneWidget,
      );
      expect(find.text('Voir mon brouillon'), findsOneWidget);
      expect(successScreen.analyticsContext, 'package_request_draft_saved');
    },
  );

  testWidgets(
    'CTA « Aperçu » à l\'étape finale ouvre PackageRequestPreviewSheet',
    (tester) async {
      await driveToStep3(tester);

      expect(find.text('Aperçu'), findsOneWidget);
      await tester.tap(find.text('Aperçu'));
      await tester.pumpAndSettle();

      expect(find.text('Aperçu de ta demande'), findsOneWidget);
      expect(find.byKey(const Key('preview-publish')), findsOneWidget);
      expect(find.byKey(const Key('preview-save-draft')), findsOneWidget);
    },
  );

  testWidgets(
    'confirmer l\'aperçu publie la demande normalement (saveAsDraft: false)',
    (tester) async {
      await driveToStep3(tester);

      await tester.tap(find.text('Aperçu'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('preview-publish')));
      await tester.pumpAndSettle();

      expect(captureSaveAsDraftCalls(), [false]);
      verifyNever(createCall(saveAsDraft: true));

      expect(find.byType(DonySuccessScreen), findsOneWidget);
      expect(find.text('Demande publiée !'), findsOneWidget);
    },
  );

  testWidgets('enregistrer en brouillon depuis l\'aperçu (saveAsDraft: true)', (
    tester,
  ) async {
    await driveToStep3(tester);

    await tester.tap(find.text('Aperçu'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('preview-save-draft')));
    await tester.pumpAndSettle();

    expect(captureSaveAsDraftCalls(), [true]);
    verifyNever(createCall(saveAsDraft: false));

    expect(find.byType(DonySuccessScreen), findsOneWidget);
    expect(find.text('Brouillon enregistré !'), findsOneWidget);
  });

  testWidgets('limite de brouillons atteinte affiche le dialogue et propose de '
      'passer en PRO', (tester) async {
    // Écrase le stub saveAsDraft:true du setUp (qui répond fakeDraftRequest)
    // pour ce test seulement — même instance de repo, dernier stub gagne.
    when(createCall(saveAsDraft: true)).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/package-requests'),
        error: const ForbiddenException(
          'Limite de 1 brouillon(s) atteinte.',
          'draft-limit-reached',
        ),
      ),
    );

    await driveToStep3(tester);

    await tester.tap(find.text('Aperçu'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('preview-save-draft')));
    await tester.pumpAndSettle();

    expect(find.text('Limite de brouillons atteinte'), findsOneWidget);
    expect(find.text('Limite de 1 brouillon(s) atteinte.'), findsOneWidget);
    expect(find.byType(DonySuccessScreen), findsNothing);

    await tester.tap(find.text('Passer en PRO'));
    await tester.pumpAndSettle();

    expect(find.text('UpgradeToProStub'), findsOneWidget);
  });
}
