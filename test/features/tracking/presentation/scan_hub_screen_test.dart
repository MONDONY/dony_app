import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:dony/features/tracking/bloc/scan_hub_cubit.dart';
import 'package:dony/features/tracking/presentation/screens/scan_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../../helpers/mock_analytics_backend.dart';

const _emptyHelpConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": []
}
''';

const _qrHelpConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": [
    {
      "id": "qr_handover",
      "title": "Remise et retrait par QR",
      "description": "Scanner au départ, en transit et à l'arrivée.",
      "youtubeVideoId": "dQw4w9WgXcQ",
      "order": 1,
      "active": true,
      "contexts": ["qrHandover"]
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

class _MockScanHubCubit extends MockCubit<ScanHubState>
    implements ScanHubCubit {}

// Étend directement PathProviderPlatform (pas `PlatformInterface implements`)
// — le token privé de vérification n'est accessible qu'en héritant réellement
// de la classe, cf. le même pattern dans qr_sheet_test.dart.
class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => '.dart_tool/test_hive';
  @override
  Future<String?> getApplicationSupportPath() async => '.dart_tool/test_hive';
  @override
  Future<String?> getApplicationCachePath() async => '.dart_tool/test_hive';
  @override
  Future<String?> getApplicationDocumentsPath() async => '.dart_tool/test_hive';
  @override
  Future<String?> getLibraryPath() async => '.dart_tool/test_hive';
  @override
  Future<String?> getExternalStoragePath() async => '.dart_tool/test_hive';
  @override
  Future<List<String>?> getExternalCachePaths() async => [
    '.dart_tool/test_hive',
  ];
  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async => ['.dart_tool/test_hive'];
  @override
  Future<String?> getDownloadsPath() async => '.dart_tool/test_hive';
}

AnnouncementModel _trip(String id, {String status = 'IN_PROGRESS'}) =>
    AnnouncementModel(
      id: id,
      travelerId: 'traveler-1',
      status: status,
      departureDate: DateTime(2026, 6, 22),
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      availableKg: 10,
      totalKg: 20,
      pricePerKg: 5,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

BidModel _bid(String id, String status, {String? recipientName}) => BidModel(
  id: id,
  announcementId: 'trip-1',
  senderId: 's',
  status: status,
  recipientName: recipientName,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

GoRouter _router(
  ScanHubCubit cubit, {
  String helpConfigJson = _emptyHelpConfigJson,
}) => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => MultiBlocProvider(
        providers: [
          BlocProvider<ScanHubCubit>.value(value: cubit),
          BlocProvider<HelpCenterBloc>(
            create: (_) => HelpCenterBloc(
              HelpCenterRepository(
                _StaticHelpCenterSource(helpConfigJson),
                fallbackJsonLoader: () async => _emptyHelpConfigJson,
              ),
              makeDisabledAnalytics(MockAnalyticsBackend()),
            )..add(const HelpCenterLoadRequested()),
          ),
        ],
        child: const ScanHubView(),
      ),
    ),
    GoRoute(
      path: '/tracking/scan/identify',
      builder: (_, _) => const Scaffold(body: Text('identify')),
    ),
    GoRoute(
      path: '/tracking/offline-queue',
      builder: (_, _) => const Scaffold(body: Text('offline-queue')),
    ),
    GoRoute(
      path: '/announcements/trips',
      builder: (_, _) => const Scaffold(body: Text('mes-trajets')),
    ),
    GoRoute(
      path: '/bids/:id',
      builder: (_, state) =>
          Scaffold(body: Text('bid-${state.pathParameters['id']}')),
    ),
    GoRoute(
      path: '/profile/help/tutorial/:tutorialId',
      builder: (_, state) => Scaffold(
        body: Text('TutorialStub:${state.pathParameters['tutorialId']}'),
      ),
    ),
  ],
);

Widget _wrap(
  ScanHubCubit cubit, {
  String helpConfigJson = _emptyHelpConfigJson,
}) => MaterialApp.router(
  routerConfig: _router(cubit, helpConfigJson: helpConfigJson),
);

void main() {
  late _MockScanHubCubit cubit;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    PathProviderPlatform.instance = _FakePathProviderPlatform();
    Hive.init('.dart_tool/test_hive');
    // Ce test widget ne passe jamais par setupDependencies() (DI complète de
    // l'app) — GetIt est donc vide ici. On enregistre HiveService nous-mêmes,
    // comme le fait déjà offline_scan_queue_screen_test.dart pour le même cas.
    if (getIt.isRegistered<HiveService>()) {
      getIt.unregister<HiveService>();
    }
    getIt.registerLazySingleton<HiveService>(() => HiveService());
    await getIt<HiveService>().init();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    if (getIt.isRegistered<HiveService>()) {
      getIt.unregister<HiveService>();
    }
  });

  setUp(() async {
    cubit = _MockScanHubCubit();
    // selectTrip renvoie Future<void> : sans stub, l'appel depuis le onTap
    // d'une pastille du switcher lève « Null is not a subtype of Future<void> »
    // et corrompt le teardown du harness.
    when(() => cubit.selectTrip(any())).thenAnswer((_) async {});
    await getIt<HiveService>().offlineQueue.clear();
  });

  ScanHubLoaded loadedState({
    List<AnnouncementModel>? trips,
    String? selectedTripId,
    Map<String, List<BidModel>>? bidsByTrip,
  }) {
    final resolvedTrips = trips ?? [_trip('trip-1')];
    return ScanHubLoaded(
      trips: resolvedTrips,
      selectedTripId: selectedTripId ?? resolvedTrips.first.id,
      bidsByTrip: bidsByTrip ?? {resolvedTrips.first.id: []},
      scanHistory: const [],
    );
  }

  testWidgets('affiche titre et 3 boutons scan rapide quand ScanHubLoaded', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(loadedState());
    await tester.pumpWidget(_wrap(cubit));
    await tester.pumpAndSettle();
    expect(find.text('Lecture & Suivi'), findsOneWidget);
    expect(find.text('Départ'), findsOneWidget);
    expect(find.text('Transit'), findsOneWidget);
    expect(find.text('Arrivée'), findsOneWidget);
  });

  testWidgets('affiche corridor du trajet réel', (tester) async {
    when(() => cubit.state).thenReturn(loadedState());
    await tester.pumpWidget(_wrap(cubit));
    await tester.pumpAndSettle();
    expect(find.textContaining('Paris'), findsOneWidget);
    expect(find.textContaining('Dakar'), findsOneWidget);
  });

  testWidgets('affiche état vide quand ScanHubEmpty', (tester) async {
    when(() => cubit.state).thenReturn(const ScanHubEmpty());
    await tester.pumpWidget(_wrap(cubit));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Aucun trajet à traiter'), findsOneWidget);
  });

  testWidgets('affiche loading quand ScanHubLoading', (tester) async {
    when(() => cubit.state).thenReturn(const ScanHubLoading());
    await tester.pumpWidget(_wrap(cubit));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('tap Départ navigue vers identify', (tester) async {
    when(() => cubit.state).thenReturn(loadedState());
    await tester.pumpWidget(_wrap(cubit));
    await tester.tap(find.text('Départ'));
    await tester.pumpAndSettle();
    expect(find.text('identify'), findsOneWidget);
  });

  testWidgets(
    'état vide — tap Voir mes trajets navigue vers /announcements/trips',
    (tester) async {
      when(() => cubit.state).thenReturn(const ScanHubEmpty());
      await tester.pumpWidget(_wrap(cubit));
      await tester.tap(find.text('Voir mes trajets'));
      await tester.pumpAndSettle();
      expect(find.text('mes-trajets'), findsOneWidget);
    },
  );

  group('switcher multi-trajet', () {
    testWidgets('masqué quand un seul trajet actif', (tester) async {
      when(() => cubit.state).thenReturn(loadedState());
      await tester.pumpWidget(_wrap(cubit));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('trip_switcher')), findsNothing);
    });

    testWidgets('visible quand plusieurs trajets actifs, filtre au tap', (
      tester,
    ) async {
      final tripA = _trip('trip-a');
      final tripB = _trip('trip-b');
      when(() => cubit.state).thenReturn(
        loadedState(
          trips: [tripA, tripB],
          selectedTripId: 'trip-a',
          bidsByTrip: {'trip-a': [], 'trip-b': []},
        ),
      );
      await tester.pumpWidget(_wrap(cubit));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('trip_switcher')), findsOneWidget);

      // Le bandeau « Changer de trajet » ouvre le volet ; on y choisit trip-b.
      await tester.tap(find.byKey(const Key('trip_switcher')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('trip_option_trip-b')));
      await tester.pumpAndSettle();
      verify(() => cubit.selectTrip('trip-b')).called(1);
    });
  });

  group('liste des colis', () {
    testWidgets('affiche une ligne par colis avec son nom', (tester) async {
      when(() => cubit.state).thenReturn(
        loadedState(
          bidsByTrip: {
            'trip-1': [_bid('bid-1', 'ACCEPTED', recipientName: 'Awa Ndiaye')],
          },
        ),
      );
      await tester.pumpWidget(_wrap(cubit));
      await tester.pumpAndSettle();
      expect(find.textContaining('Awa Ndiaye'), findsOneWidget);
    });

    testWidgets(
      'tap sur la ligne (hors bouton Scan) navigue vers la fiche colis',
      (tester) async {
        when(() => cubit.state).thenReturn(
          loadedState(
            bidsByTrip: {
              'trip-1': [
                _bid('bid-1', 'ACCEPTED', recipientName: 'Awa Ndiaye'),
              ],
            },
          ),
        );
        await tester.pumpWidget(_wrap(cubit));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Awa Ndiaye'));
        await tester.pumpAndSettle();
        expect(find.text('bid-bid-1'), findsOneWidget);
      },
    );

    testWidgets(
      'tap Scan sur une ligne route vers identify avec l\'étape déduite',
      (tester) async {
        when(() => cubit.state).thenReturn(
          loadedState(
            bidsByTrip: {
              'trip-1': [
                _bid('bid-1', 'HANDED_OVER', recipientName: 'Awa Ndiaye'),
              ],
            },
          ),
        );
        await tester.pumpWidget(_wrap(cubit));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Scan'));
        await tester.pumpAndSettle();
        expect(find.text('identify'), findsOneWidget);
      },
    );

    testWidgets(
      'les points de progression reflètent colisStepProgress (HANDED_OVER '
      '→ départ scanné, transit/arrivée non)',
      (tester) async {
        when(() => cubit.state).thenReturn(
          loadedState(
            bidsByTrip: {
              'trip-1': [
                _bid('bid-1', 'HANDED_OVER', recipientName: 'Awa Ndiaye'),
              ],
            },
          ),
        );
        await tester.pumpWidget(_wrap(cubit));
        await tester.pumpAndSettle();
        // HANDED_OVER → colisStepProgress = (depart: true, transit: false,
        // arrivee: false) : 1 point rempli, 2 points restants.
        expect(find.byKey(const Key('step_dot_done')), findsOneWidget);
        expect(find.byKey(const Key('step_dot_todo')), findsNWidgets(2));
      },
    );
  });

  group('carte tutoriel contextuelle', () {
    testWidgets(
      'affiche la carte sous l\'explication QR et navigue vers le tutoriel au tap',
      (tester) async {
        when(() => cubit.state).thenReturn(loadedState());
        await tester.pumpWidget(
          _wrap(cubit, helpConfigJson: _qrHelpConfigJson),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));

        final etapesTop = tester.getTopLeft(find.text('LECTURE RAPIDE')).dy;
        final cardTop = tester
            .getTopLeft(find.text('Besoin d\'aide ? Voir le tutoriel'))
            .dy;
        expect(cardTop, greaterThan(etapesTop));

        await tester.tap(find.text('Besoin d\'aide ? Voir le tutoriel'));
        await tester.pumpAndSettle();

        expect(find.text('TutorialStub:qr_handover'), findsOneWidget);
      },
    );
  });

  group('historique des scans', () {
    testWidgets('message vide quand aucun scan', (tester) async {
      when(() => cubit.state).thenReturn(loadedState());
      await tester.pumpWidget(_wrap(cubit));
      await tester.pumpAndSettle();
      expect(find.text('Aucune lecture pour l\'instant'), findsOneWidget);
    });
  });

  group('bandeau synchro', () {
    testWidgets('absent quand la queue offline est vide', (tester) async {
      when(() => cubit.state).thenReturn(loadedState());
      await tester.pumpWidget(_wrap(cubit));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sync_banner')), findsNothing);
    });

    testWidgets(
      'visible et tap navigue vers /tracking/offline-queue quand un scan du trajet actif est en attente',
      (tester) async {
        when(() => cubit.state).thenReturn(
          loadedState(
            bidsByTrip: {
              'trip-1': [_bid('bid-1', 'ACCEPTED')],
            },
          ),
        );
        // Écriture disque Hive réelle → doit tourner dans la vraie zone async
        // (runAsync), sinon l'horloge fake du testWidgets ne complète jamais
        // l'I/O et le test hang jusqu'au timeout de 10 min.
        await tester.runAsync(() async {
          await getIt<HiveService>().offlineQueue.add({
            'bidId': 'bid-1',
            'eventType': 'DEPART',
            'offlineTimestamp': DateTime.now().toUtc().toIso8601String(),
          });
        });

        await tester.pumpWidget(_wrap(cubit));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('sync_banner')), findsOneWidget);

        await tester.tap(find.byKey(const Key('sync_banner')));
        await tester.pumpAndSettle();
        expect(find.text('offline-queue'), findsOneWidget);
      },
    );

    testWidgets(
      'absent quand la queue offline ne contient que des colis d\'un autre trajet',
      (tester) async {
        when(() => cubit.state).thenReturn(
          loadedState(
            bidsByTrip: {
              'trip-1': [_bid('bid-1', 'ACCEPTED')],
            },
          ),
        );
        // Écriture disque Hive réelle → runAsync (cf. test précédent), sinon
        // hang du testWidgets sous horloge fake.
        await tester.runAsync(() async {
          await getIt<HiveService>().offlineQueue.add({
            'bidId': 'bid-from-another-trip',
            'eventType': 'DEPART',
            'offlineTimestamp': DateTime.now().toUtc().toIso8601String(),
          });
        });

        await tester.pumpWidget(_wrap(cubit));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('sync_banner')), findsNothing);
      },
    );
  });

  testWidgets('aucun overflow sur petit écran (320 dp)', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    when(() => cubit.state).thenReturn(
      loadedState(
        bidsByTrip: {
          'trip-1': [_bid('bid-1', 'ACCEPTED', recipientName: 'Awa Ndiaye')],
        },
      ),
    );
    await tester.pumpWidget(_wrap(cubit));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
