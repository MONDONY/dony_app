import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:dony/features/tracking/bloc/scan_hub_cubit.dart';
import 'package:dony/features/tracking/bloc/suivi_cubit.dart';
import 'package:dony/features/tracking/bloc/suivi_validation_cubit.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/scan_method.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/data/models/tracking_search_model.dart';
import 'package:dony/features/tracking/data/models/trip_scan_history_entry_model.dart';
import 'package:dony/features/tracking/data/offline_sync_service.dart';
import 'package:dony/features/tracking/data/scan_locator.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:dony/features/tracking/presentation/screens/scan_photo_screen.dart';
import 'package:dony/features/tracking/presentation/screens/suivi_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockAnnouncementRepo extends Mock implements AnnouncementRepository {}

class _MockBidRepo extends Mock implements BidRepository {}

class _MockTrackingRepo extends Mock implements TrackingRepository {}

class _MockOfflineSync extends Mock implements OfflineSyncService {}

class _MockLocator extends Mock implements ScanLocator {}

const _here = ScanPosition(lat: 14.7, lon: -17.4, label: 'Dakar');

UserModel _user(List<String> roles) =>
    UserModel(id: 'u1', roles: roles, kycStatus: 'APPROVED', status: 'ACTIVE');

AnnouncementModel _trip(
  String id,
  String status,
  String from,
  String to, {
  DateTime? date,
}) => AnnouncementModel(
  id: id,
  travelerId: 'u1',
  status: status,
  departureDate: date ?? DateTime(2026, 9, 26),
  departureCity: from,
  arrivalCity: to,
  availableKg: 10,
  totalKg: 20,
  pricePerKg: 5,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

BidModel _bid(
  String id,
  String status, {
  String trip = 'trip-a',
  String? name,
  String? number,
  String? from,
  String? to,
  double? weight,
}) => BidModel(
  id: id,
  announcementId: trip,
  senderId: 's',
  status: status,
  recipientName: name,
  trackingNumber: number,
  weightKg: weight,
  departureCity: from,
  arrivalCity: to,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// Catalogue du Centre d'aide : un tutoriel de la remise par QR, ou rien.
String _helpConfig({required bool withQrTutorial}) =>
    '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": [${withQrTutorial ? '''
    {
      "id": "qr_handover",
      "title": "Remettre un colis avec le QR",
      "description": "Scanner le QR du colis à chaque étape.",
      "youtubeVideoId": "dQw4w9WgXcQ",
      "order": 1,
      "active": true,
      "contexts": ["qrHandover"]
    }''' : ''}]
}
''';

class _StaticHelpSource implements HelpCenterConfigSource {
  const _StaticHelpSource(this.json);

  final String json;

  @override
  String get activatedJson => json;

  @override
  Future<String?> fetchAndActivate() async => json;
}

void main() {
  late _MockAnnouncementRepo annRepo;
  late _MockBidRepo bidRepo;
  late _MockTrackingRepo trackingRepo;
  late _MockAnalytics analytics;
  late _MockOfflineSync offlineSync;
  late _MockLocator locator;
  late ChangeNotifier queue;
  late List<String> visited;
  late Map<String, dynamic>? lastExtra;
  ValueChanged<String>? scan;
  ValueListenable<bool>? cameraPaused;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(<String>{});
    registerFallbackValue(ScanMethod.qr);
  });

  void stubTrips(
    List<AnnouncementModel> trips,
    Map<String, List<BidModel>> bids, {
    List<TripScanHistoryEntryModel> history = const [],
  }) {
    when(
      () => annRepo.getMyAnnouncements(),
    ).thenAnswer((_) async => (announcements: trips, totalElements: 0));
    for (final entry in bids.entries) {
      when(
        () => bidRepo.getBidsForAnnouncement(entry.key),
      ).thenAnswer((_) async => entry.value);
    }
    when(
      () => trackingRepo.getTripScanHistory(any()),
    ).thenAnswer((_) async => history);
  }

  void stubDefaultTrips() => stubTrips(
    [
      _trip('trip-a', 'IN_PROGRESS', 'Bobo-Dioulasso', 'Yaoundé'),
      _trip('trip-b', 'ACTIVE', 'Paris', 'Dakar', date: DateTime(2026, 10, 3)),
    ],
    {
      'trip-a': [
        _bid('madou', 'ACCEPTED', name: 'Madou', number: 'DON-MAD001'),
        _bid('kadi', 'IN_TRANSIT', name: 'Kadi', number: 'DON-KAD002'),
      ],
      'trip-b': [_bid('fatou', 'ACCEPTED', trip: 'trip-b', name: 'Fatou')],
    },
    history: [
      TripScanHistoryEntryModel(
        donNumber: 'DON-KAD002',
        recipientName: 'Kadi',
        eventType: 'TRANSIT',
        scannedAt: DateTime(2026, 9, 26, 12, 58),
        scanMethod: ScanMethod.qr,
      ),
      TripScanHistoryEntryModel(
        donNumber: 'DON-KAD002',
        recipientName: 'Kadi',
        eventType: 'DEPART',
        scannedAt: DateTime(2026, 9, 26, 9, 40),
        scanMethod: ScanMethod.manual,
      ),
      // Colis retiré du trajet depuis : ne compte pour aucune ligne.
      TripScanHistoryEntryModel(
        donNumber: 'DON-OLD009',
        recipientName: 'Awa',
        eventType: 'DEPART',
        scannedAt: DateTime(2026, 9, 26, 8, 12),
      ),
    ],
  );

  setUp(() {
    DonySnackbar.clearDedup();
    annRepo = _MockAnnouncementRepo();
    bidRepo = _MockBidRepo();
    trackingRepo = _MockTrackingRepo();
    analytics = _MockAnalytics();
    offlineSync = _MockOfflineSync();
    locator = _MockLocator();
    when(() => locator.capture()).thenAnswer((_) async => _here);
    when(
      () => offlineSync.queueScan(
        bidId: any(named: 'bidId'),
        eventType: any(named: 'eventType'),
        photoPath: any(named: 'photoPath'),
        gpsLat: any(named: 'gpsLat'),
        gpsLon: any(named: 'gpsLon'),
        gpsLabel: any(named: 'gpsLabel'),
        scanMethod: any(named: 'scanMethod'),
        notBefore: any(named: 'notBefore'),
      ),
    ).thenAnswer((_) async => 1);
    when(() => offlineSync.discard(any())).thenAnswer((_) async {});
    when(
      () => offlineSync.sendScheduled(any(), position: any(named: 'position')),
    ).thenAnswer(
      (_) async => TrackingEventModel(
        id: 'e1',
        bidId: 'sali',
        eventType: 'TRANSIT',
        scannedAt: DateTime(2026, 9, 28),
        createdAt: DateTime(2026, 9, 28),
      ),
    );
    queue = ChangeNotifier();
    visited = [];
    lastExtra = null;
    scan = null;
    cameraPaused = null;

    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(() => bidRepo.getMyBids()).thenAnswer(
      (_) async => [
        _bid(
          'ship-1',
          'IN_TRANSIT',
          from: 'Paris',
          to: 'Dakar',
          number: 'DON-SHIP01',
        ),
        _bid('ship-old', 'COMPLETED'),
      ],
    );
    when(() => offlineSync.pendingCountFor(any())).thenReturn(0);
    when(() => offlineSync.queueChanges).thenReturn(queue);

    _unregisterAll();
    getIt
      ..registerFactory<SuiviCubit>(
        () => SuiviCubit(bidRepo, trackingRepo, analytics),
      )
      ..registerFactory<ScanHubCubit>(
        () => ScanHubCubit(annRepo, bidRepo, analytics, trackingRepo),
      )
      ..registerFactory<SuiviValidationCubit>(
        () => SuiviValidationCubit(offlineSync, locator, analytics),
      )
      ..registerFactory<TrackingBloc>(() {
        final bloc = _MockTrackingBloc();
        when(() => bloc.state).thenReturn(TrackingEventsLoaded(const []));
        return bloc;
      })
      ..registerSingleton<OfflineSyncService>(offlineSync);
  });

  tearDown(() {
    queue.dispose();
    _unregisterAll();
  });

  Widget fakeCamera(
    BuildContext context,
    ValueChanged<String> onBidId,
    ValueListenable<bool> paused,
    ValueListenable<bool> torchOn,
  ) {
    scan = onBidId;
    cameraPaused = paused;
    return const ColoredBox(
      key: Key('fake-camera'),
      color: DonyColors.neutral900,
    );
  }

  GoRoute stub(String path, {Widget Function(GoRouterState)? page}) => GoRoute(
    path: path,
    builder: (_, state) {
      visited.add(path);
      lastExtra = state.extra as Map<String, dynamic>?;
      return page?.call(state) ?? Scaffold(body: Text('page $path'));
    },
  );

  Future<void> pump(
    WidgetTester tester, {
    List<String> roles = const ['SENDER', 'TRAVELER'],
    String location = '/',
    List<AuthState> authLater = const [],
    bool qrTutorial = false,
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    final auth = _MockAuthBloc();
    whenListen(
      auth,
      Stream.fromIterable(authLater),
      initialState: AuthAuthenticated(_user(roles)),
    );
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/',
          builder: (_, state) => SuiviScreen(
            requestedMode: suiviModeFromQuery(
              state.uri.queryParameters['mode'],
            ),
            cameraBuilder: fakeCamera,
          ),
        ),
        stub(
          '/tracking/scan/photo',
          page: (state) => Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => context.pop(
                  const ScanPhotoResult(
                    photoPath: '/tmp/colis.jpg',
                    position: _here,
                  ),
                ),
                child: const Text('page /tracking/scan/photo'),
              ),
            ),
          ),
        ),
        stub('/tracking/scan/identify'),
        stub('/profile/help/tutorial/:id'),
        stub('/tracking/offline-queue'),
        stub('/announcements/trips'),
        stub('/bids/:id'),
        stub(
          '/tracking/scan/qr-picker',
          page: (_) => Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => context.pop('ship-1'),
                child: const Text('lire le QR'),
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    final helpJson = _helpConfig(withQrTutorial: qrTutorial);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: auth),
          BlocProvider<HelpCenterBloc>(
            create: (_) => HelpCenterBloc(
              HelpCenterRepository(
                _StaticHelpSource(helpJson),
                fallbackJsonLoader: () async => helpJson,
              ),
              analytics,
            )..add(const HelpCenterLoadRequested()),
          ),
        ],
        // Le vrai thème de l'app (app.dart) : ses boutons ont une largeur
        // minimale infinie, qu'un thème par défaut masquait (recette Redmi).
        child: MaterialApp.router(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          locale: AppL10n.fr,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await settle(tester);
  }

  Finder text(String s) => find.text(s, findRichText: true);

  void verifyNeverSubmitted() => verifyNever(
    () => offlineSync.sendScheduled(any(), position: any(named: 'position')),
  );

  /// Validation mise en file dès le « Valider », puis envoyée une fois (avec
  /// la position relevée, quand [at] est donnée).
  Future<void> verifySent({
    required String bidId,
    required String step,
    required ScanMethod method,
    String? photoPath,
    ScanPosition? at,
  }) async {
    verify(
      () => offlineSync.queueScan(
        bidId: bidId,
        eventType: step,
        photoPath: photoPath,
        gpsLat: any(named: 'gpsLat'),
        gpsLon: any(named: 'gpsLon'),
        gpsLabel: any(named: 'gpsLabel'),
        scanMethod: method,
        notBefore: any(named: 'notBefore'),
      ),
    ).called(1);
    final position =
        verify(
              () => offlineSync.sendScheduled(
                1,
                position: captureAny(named: 'position'),
              ),
            ).captured.single
            as Future<ScanPosition?>;
    if (at != null) {
      final sent = await position;
      expect((sent?.lat, sent?.lon, sent?.label), (at.lat, at.lon, at.label));
    }
  }

  /// Trajet avec un colis remis (étape suivante : transit) et un colis au
  /// départ, plus un colis sur un autre trajet.
  void stubTransitTrips() => stubTrips(
    [
      _trip('trip-a', 'IN_PROGRESS', 'Bobo-Dioulasso', 'Yaoundé'),
      _trip('trip-b', 'ACTIVE', 'Paris', 'Dakar', date: DateTime(2026, 10, 3)),
    ],
    {
      'trip-a': [
        _bid(
          'sali',
          'HANDED_OVER',
          name: 'Sali',
          number: 'DON-SAL003',
          weight: 4.5,
        ),
        _bid('madou', 'ACCEPTED', name: 'Madou', number: 'DON-MAD001'),
      ],
      'trip-b': [
        _bid(
          'fatou',
          'ACCEPTED',
          trip: 'trip-b',
          name: 'Fatou',
          number: 'DON-FAT004',
        ),
      ],
    },
  );

  /// Amène [key] dans la partie visible de la feuille, puis le touche.
  Future<void> tapVisible(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await settle(tester, rounds: 1);
    await tester.tap(find.byKey(key));
    await settle(tester);
  }

  /// Déplie la feuille sur le champ numéro via « QR illisible ? ».
  Future<void> openNumberField(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('suivi-enter-number')));
    await settle(tester, rounds: 2);
    await tester.tap(find.byKey(const Key('suivi-enter-number')));
    await settle(tester);
  }

  /// « Forcer une étape » → Transit : le prochain colis valide son transit.
  Future<void> forceTransit(WidgetTester tester) async {
    await openNumberField(tester);
    await tapVisible(tester, const Key('suivi-force-step'));
    await tester.tap(find.byKey(const Key('suivi-force-TRANSIT')));
    await settle(tester);
  }

  Future<void> submitNumber(WidgetTester tester, String number) async {
    await tester.ensureVisible(
      find.byKey(const Key('suivi-validate-number-field')),
    );
    await settle(tester, rounds: 1);
    await tester.enterText(
      find.byKey(const Key('suivi-validate-number-field')),
      number,
    );
    // Validation au clavier : le focus fait défiler la feuille, un tap sur
    // le bouton tomberait pendant le défilement.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
  }

  group('expéditeur (non voyageur)', () {
    testWidgets('ni sélecteur ni caméra, Mes envois et bouton QR', (
      tester,
    ) async {
      await pump(tester, roles: ['SENDER']);

      expect(find.byKey(const Key('suivi-mode-valider')), findsNothing);
      expect(find.byKey(const Key('fake-camera')), findsNothing);
      expect(scan, isNull);
      expect(find.byType(DonyFeedbackButton), findsOneWidget);
      expect(text('Scanner un QR code'), findsOneWidget);
      expect(text('Paris → Dakar'), findsOneWidget);
      expect(text('En route'), findsOneWidget);
      // Envoi livré : hors de « Mes envois ».
      expect(find.byKey(const Key('suivi-shipment-ship-old')), findsNothing);
    });

    testWidgets('tap sur un envoi → parcours en lecture seule', (tester) async {
      await pump(tester, roles: ['SENDER']);
      await tester.tap(find.byKey(const Key('suivi-shipment-ship-1')));
      await settle(tester);
      expect(text('Suivi du colis'), findsOneWidget);
    });

    testWidgets('lecteur QR plein écran → parcours du colis lu', (
      tester,
    ) async {
      await pump(tester, roles: ['SENDER']);
      await tester.tap(find.byKey(const Key('suivi-scan-qr')));
      await settle(tester);
      await tester.tap(text('lire le QR'));
      await settle(tester);
      expect(text('Suivi du colis'), findsOneWidget);
    });

    testWidgets('numéro trouvé → parcours ; introuvable → erreur', (
      tester,
    ) async {
      when(() => trackingRepo.searchByTrackingNumber('DON-ABC123')).thenAnswer(
        (_) async => const TrackingSearchModel(
          trackingNumber: 'DON-ABC123',
          bidId: 'bid-9',
          departureCity: 'Lyon',
          arrivalCity: 'Abidjan',
          currentStep: 'IN_TRANSIT',
          stepLabel: 'En transit',
          paymentStatus: 'ESCROWED',
        ),
      );
      when(
        () => trackingRepo.searchByTrackingNumber('DON-NOPE'),
      ).thenThrow(Exception('404'));
      await pump(tester, roles: ['SENDER']);

      await tester.enterText(
        find.byKey(const Key('suivi-number-field')),
        'don-nope',
      );
      await tester.tap(find.byKey(const Key('suivi-number-submit')));
      await settle(tester);
      expect(find.byKey(const Key('suivi-search-error')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('suivi-number-field')),
        'don-abc123',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);
      expect(text('Suivi du colis'), findsOneWidget);
      expect(text('Lyon → Abidjan'), findsWidgets);
    });

    testWidgets('échec de Mes envois → Réessayer', (tester) async {
      when(() => bidRepo.getMyBids()).thenThrow(Exception('offline'));
      await pump(tester, roles: ['SENDER']);
      expect(text('Impossible de charger tes envois.'), findsOneWidget);

      when(() => bidRepo.getMyBids()).thenAnswer((_) async => []);
      await tester.tap(text('Réessayer'));
      await settle(tester);
      expect(text('Aucun envoi en cours.'), findsOneWidget);
    });
  });

  group('voyageur', () {
    testWidgets('colis à valider → Valider par défaut, caméra et feuille', (
      tester,
    ) async {
      stubDefaultTrips();
      await pump(tester);

      expect(find.byKey(const Key('fake-camera')), findsOneWidget);
      expect(
        text(
          "Scanne le QR d'un colis de ton trajet.\n"
          "L'étape suivante est validée toute seule.",
        ),
        findsOneWidget,
      );
      expect(text('Bobo-Dioulasso → Yaoundé'), findsOneWidget);
      expect(text('Madou'), findsWidgets);
      expect(text('Valider le départ'), findsOneWidget);
      expect(text("Valider l'arrivée"), findsOneWidget);
      expect(text('Transit fait à 12:58'), findsOneWidget);
      expect(text('Pas encore remis'), findsOneWidget);
      expect(find.byType(DonyFeedbackButton), findsOneWidget);
      expect(cameraPaused?.value, isFalse);
    });

    testWidgets('un état d\'auth transitoire ne bascule pas l\'onglet', (
      tester,
    ) async {
      stubDefaultTrips();
      await pump(tester, authLater: [const AuthLoading()]);
      expect(find.byKey(const Key('suivi-mode-valider')), findsOneWidget);
      expect(find.byKey(const Key('fake-camera')), findsOneWidget);
    });

    testWidgets('rien à valider → Suivre par défaut', (tester) async {
      stubTrips(
        [_trip('trip-a', 'IN_PROGRESS', 'Paris', 'Dakar')],
        {
          'trip-a': [_bid('done', 'COMPLETED')],
        },
      );
      await pump(tester);
      expect(
        text(
          'Scanne un QR pour voir où en est le colis.\n'
          "Rien n'est validé dans ce mode.",
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Mes envois', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('?mode=suivre impose Suivre, puis bascule vers Valider', (
      tester,
    ) async {
      stubDefaultTrips();
      await pump(tester, location: '/?mode=suivre');
      expect(
        find.textContaining('Mes envois', findRichText: true),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('suivi-mode-valider')));
      await settle(tester);
      expect(text('Bobo-Dioulasso → Yaoundé'), findsOneWidget);
      expect(
        find.textContaining('Mes envois', findRichText: true),
        findsNothing,
      );
    });

    testWidgets('Changer de trajet : groupes En cours / À venir', (
      tester,
    ) async {
      stubDefaultTrips();
      await pump(tester);

      await tester.tap(find.byKey(const Key('suivi-change-trip')));
      await settle(tester);
      expect(text('Choisir un trajet'), findsOneWidget);
      expect(text('En cours'), findsOneWidget);
      expect(text('À venir'), findsOneWidget);
      expect(text('sam. 26 sept. · 2 colis · 2 à valider'), findsOneWidget);

      await tester.tap(find.byKey(const Key('trip_option_trip-b')));
      await settle(tester);
      expect(
        tester.widget<Text>(find.byKey(const Key('suivi-selected-trip'))).data,
        'Paris → Dakar',
      );
    });

    testWidgets('QR d\'un colis du trajet → parcours photo de l\'étape', (
      tester,
    ) async {
      stubDefaultTrips();
      await pump(tester);

      scan!('madou');
      await settle(tester);
      expect(visited, contains('/tracking/scan/photo'));
      expect(lastExtra, {
        'bidId': 'madou',
        'etape': 'DEPART',
        'packageLabel': 'Madou',
        'returnResult': true,
      });
      // Écran recouvert : caméra coupée.
      expect(cameraPaused?.value, isTrue);

      // Photo prise : bandeau « Annuler », envoi à la fin du délai.
      await tester.tap(text('page /tracking/scan/photo'));
      await settle(tester, rounds: 2);
      expect(cameraPaused?.value, isFalse);
      expect(text('Départ de Madou validé'), findsOneWidget);
      verifyNeverSubmitted();

      await tester.pump(const Duration(seconds: 5));
      await settle(tester, rounds: 2);
      await verifySent(
        bidId: 'madou',
        step: 'DEPART',
        method: ScanMethod.qr,
        photoPath: '/tmp/colis.jpg',
        at: _here,
      );
      expect(text('Départ de Madou validé'), findsNothing);
      // Position relevée avant la photo : pas de nouveau relevé.
      verifyNever(() => locator.capture());
    });

    testWidgets('photo du départ abandonnée → rien n\'est programmé', (
      tester,
    ) async {
      stubDefaultTrips();
      await pump(tester);
      scan!('madou');
      await settle(tester);
      GoRouter.of(tester.element(find.text('page /tracking/scan/photo'))).pop();
      await settle(tester);
      expect(find.byKey(const Key('suivi-undo-1')), findsNothing);
      expect(cameraPaused?.value, isFalse);
    });

    testWidgets('QR d\'un colis livré → message, pas de parcours', (
      tester,
    ) async {
      stubTrips(
        [_trip('trip-a', 'IN_PROGRESS', 'Paris', 'Dakar')],
        {
          'trip-a': [
            _bid('done', 'COMPLETED', name: 'Awa'),
            _bid('todo', 'ACCEPTED', name: 'Ali'),
          ],
        },
      );
      await pump(tester);
      scan!('done');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        text('Toutes les étapes de Awa sont déjà validées.'),
        findsOneWidget,
      );
      expect(visited, isNot(contains('/tracking/scan/photo')));
      await settle(tester, rounds: 12);
    });

    testWidgets('QR d\'un autre trajet → passer sur ce trajet', (tester) async {
      stubDefaultTrips();
      await pump(tester);

      scan!('fatou');
      await settle(tester);
      expect(text("Ce colis n'est pas sur ce trajet"), findsOneWidget);
      expect(
        text(
          'Le colis de Fatou voyage sur ton trajet du sam. 3 oct. : '
          'Paris → Dakar.',
        ),
        findsOneWidget,
      );
      expect(cameraPaused?.value, isTrue);

      await tester.tap(find.byKey(const Key('suivi-switch-trip')));
      await settle(tester);
      expect(
        tester.widget<Text>(find.byKey(const Key('suivi-selected-trip'))).data,
        'Paris → Dakar',
      );
      expect(cameraPaused?.value, isFalse);
    });

    testWidgets('QR d\'un autre trajet → scanner un autre colis', (
      tester,
    ) async {
      stubDefaultTrips();
      await pump(tester);

      scan!('fatou');
      await settle(tester);
      await tester.tap(find.byKey(const Key('suivi-scan-another')));
      await settle(tester);
      expect(
        tester.widget<Text>(find.byKey(const Key('suivi-selected-trip'))).data,
        'Bobo-Dioulasso → Yaoundé',
      );
      expect(cameraPaused?.value, isFalse);
    });

    testWidgets('QR inconnu → suivre ce colis', (tester) async {
      stubDefaultTrips();
      await pump(tester);

      scan!('00000000-0000-0000-0000-000000000000');
      await settle(tester);
      expect(text("Ce colis n'est pas sur tes trajets"), findsOneWidget);

      await tester.tap(find.byKey(const Key('suivi-follow-parcel')));
      await settle(tester);
      expect(text('Suivi du colis'), findsOneWidget);
      expect(
        find.textContaining('Mes envois', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('QR inconnu → scanner un autre colis', (tester) async {
      stubDefaultTrips();
      await pump(tester);

      scan!('00000000-0000-0000-0000-000000000000');
      await settle(tester);
      await tester.tap(find.byKey(const Key('suivi-scan-another')));
      await settle(tester);
      expect(text("Ce colis n'est pas sur tes trajets"), findsNothing);
      expect(cameraPaused?.value, isFalse);
    });

    testWidgets('QR en mode Suivre → parcours en lecture seule', (
      tester,
    ) async {
      stubDefaultTrips();
      await pump(tester, location: '/?mode=suivre');
      scan!('fatou');
      await settle(tester);
      expect(text('Suivi du colis'), findsOneWidget);
    });

    testWidgets('action d\'une ligne → identification', (tester) async {
      stubDefaultTrips();
      await pump(tester);

      await tester.ensureVisible(find.byKey(const Key('suivi-validate-kadi')));
      await settle(tester, rounds: 2);
      await tester.tap(find.byKey(const Key('suivi-validate-kadi')));
      await settle(tester);
      expect(visited.last, '/tracking/scan/identify');
      expect(lastExtra, {'etape': 'ARRIVEE', 'focusNumber': true});
      GoRouter.of(
        tester.element(find.text('page /tracking/scan/identify')),
      ).pop();
      await settle(tester);
    });

    testWidgets('feuille tirée en haut → caméra en pause, Scanner la replie', (
      tester,
    ) async {
      stubDefaultTrips();
      await pump(tester);

      await tester.drag(
        find.byKey(const Key('suivi-sheet')),
        const Offset(0, -700),
      );
      await settle(tester);
      expect(cameraPaused?.value, isTrue);
      expect(text('Caméra en pause'), findsOneWidget);

      await tester.tap(find.byKey(const Key('suivi-resume-scan')));
      await settle(tester);
      expect(cameraPaused?.value, isFalse);
      expect(text('Caméra en pause'), findsNothing);
    });

    testWidgets('scans hors ligne en attente → bannière vers la file', (
      tester,
    ) async {
      when(() => offlineSync.pendingCountFor(any())).thenReturn(2);
      stubDefaultTrips();
      await pump(tester);

      expect(
        text(
          '2 scans en attente. Ils partent tout seuls dès le retour du '
          'réseau.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('suivi-pending-scans')));
      await settle(tester);
      expect(visited, contains('/tracking/offline-queue'));
    });

    testWidgets('aucun trajet, mode Valider demandé → état vide', (
      tester,
    ) async {
      stubTrips(const [], const {});
      await pump(tester, location: '/?mode=valider');
      expect(text("Rien à valider pour l'instant"), findsOneWidget);
      expect(find.byKey(const Key('fake-camera')), findsNothing);

      await tester.tap(text('Voir mes trajets'));
      await settle(tester);
      expect(visited, contains('/announcements/trips'));
    });

    testWidgets('erreur de chargement → Valider, Réessayer recharge', (
      tester,
    ) async {
      when(() => annRepo.getMyAnnouncements()).thenThrow(Exception('offline'));
      await pump(tester);
      expect(text('Impossible de charger les trajets'), findsOneWidget);

      stubDefaultTrips();
      await tester.tap(text('Réessayer'));
      await settle(tester);
      expect(text('Bobo-Dioulasso → Yaoundé'), findsOneWidget);
    });
  });

  group('validation rapide', () {
    testWidgets('QR d\'un transit : bandeau, envoi au bout de 5 s', (
      tester,
    ) async {
      stubTransitTrips();
      await pump(tester);
      await forceTransit(tester);
      clearInteractions(annRepo);

      scan!('sali');
      await settle(tester, rounds: 1);
      expect(visited, isNot(contains('/tracking/scan/photo')));
      expect(text('Transit de Sali validé'), findsOneWidget);
      expect(text('Envoi dans 5 s'), findsOneWidget);
      // La caméra continue pendant le délai.
      expect(cameraPaused?.value, isFalse);
      verifyNeverSubmitted();

      await tester.pump(const Duration(seconds: 2));
      expect(text('Envoi dans 3 s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await settle(tester, rounds: 2);
      await verifySent(
        bidId: 'sali',
        step: 'TRANSIT',
        method: ScanMethod.qr,
        at: _here,
      );
      expect(text('Transit de Sali validé'), findsNothing);
      // Colis et derniers scans rechargés sans démonter la caméra.
      verify(() => annRepo.getMyAnnouncements()).called(1);
      expect(find.byKey(const Key('fake-camera')), findsOneWidget);
      verify(
        () => analytics.logEvent(
          'suivi_step_validated',
          properties: {'step': 'TRANSIT', 'method': 'qr'},
        ),
      ).called(1);
    });

    testWidgets('Annuler : rien n\'est envoyé', (tester) async {
      stubTransitTrips();
      await pump(tester);
      await forceTransit(tester);

      scan!('sali');
      await settle(tester, rounds: 1);
      await tester.tap(find.byKey(const Key('suivi-undo-1')));
      await tester.pump(const Duration(seconds: 6));
      await settle(tester, rounds: 2);
      expect(text('Transit de Sali validé'), findsNothing);
      verifyNeverSubmitted();
      // Retirée de la file hors ligne : rien ne partira après un redémarrage.
      verify(() => offlineSync.discard(1)).called(1);
      verify(
        () => analytics.logEvent(
          'suivi_step_undone',
          properties: {'step': 'TRANSIT'},
        ),
      ).called(1);
    });

    testWidgets('colis déjà en attente, saisi par numéro → message', (
      tester,
    ) async {
      stubTransitTrips();
      await pump(tester);
      await forceTransit(tester);

      scan!('sali');
      await settle(tester, rounds: 1);
      await openNumberField(tester);
      await tester.enterText(
        find.byKey(const Key('suivi-validate-number-field')),
        'DON-SAL003',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        text('La validation de Sali part dans quelques secondes.'),
        findsOneWidget,
      );
      expect(text('Valider avec le numéro'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      await settle(tester, rounds: 12);
      await verifySent(bidId: 'sali', step: 'TRANSIT', method: ScanMethod.qr);
    });

    testWidgets('sans réseau → en attente d\'envoi', (tester) async {
      when(
        () =>
            offlineSync.sendScheduled(any(), position: any(named: 'position')),
      ).thenAnswer((_) async => null);
      stubTransitTrips();
      await pump(tester);
      await forceTransit(tester);

      scan!('sali');
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        text(
          "Transit de Sali en attente d'envoi. Il part dès le retour du "
          'réseau.',
        ),
        findsOneWidget,
      );
      await settle(tester, rounds: 12);
    });

    testWidgets('refus du back → message d\'échec', (tester) async {
      when(
        () =>
            offlineSync.sendScheduled(any(), position: any(named: 'position')),
      ).thenThrow(const ConflictException('déjà scanné'));
      stubTransitTrips();
      await pump(tester);
      await forceTransit(tester);

      scan!('sali');
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(text('Transit de Sali non validé'), findsOneWidget);
      await settle(tester, rounds: 12);
    });

    testWidgets('onglet démonté pendant le délai → envoi immédiat', (
      tester,
    ) async {
      stubTransitTrips();
      await pump(tester);
      await forceTransit(tester);

      scan!('sali');
      await settle(tester, rounds: 1);
      verifyNeverSubmitted();

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await verifySent(bidId: 'sali', step: 'TRANSIT', method: ScanMethod.qr);
    });

    testWidgets('app en arrière-plan pendant le délai → envoi immédiat', (
      tester,
    ) async {
      stubTransitTrips();
      await pump(tester);
      await forceTransit(tester);

      scan!('sali');
      await settle(tester, rounds: 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      await verifySent(bidId: 'sali', step: 'TRANSIT', method: ScanMethod.qr);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester, rounds: 2);
    });
  });

  group('feuille dépliée : étape et numéro', () {
    testWidgets('QR illisible → feuille dépliée, étape automatique', (
      tester,
    ) async {
      stubTransitTrips();
      await pump(tester);
      expect(
        find.byKey(const Key('suivi-validate-number-field')),
        findsNothing,
      );

      await openNumberField(tester);
      expect(cameraPaused?.value, isTrue);
      expect(find.byKey(const Key('suivi-enter-number')), findsNothing);
      expect(text('Étape : automatique'), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const Key('suivi-validate-number-field')),
      );
      expect(field.focusNode!.hasFocus, isTrue);

      // Explication repliée, dépliée au tap.
      await tapVisible(tester, const Key('suivi-step-mode'));
      expect(
        text(
          "Chaque scan valide l'étape suivante du colis. Force une étape "
          'seulement pour rattraper un oubli.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Forcer une étape → identification avec l\'étape', (
      tester,
    ) async {
      stubTransitTrips();
      await pump(tester);
      await openNumberField(tester);

      await tapVisible(tester, const Key('suivi-force-step'));
      // Seul le transit est marqué facultatif.
      expect(text('Facultatif'), findsOneWidget);
      await tester.tap(find.byKey(const Key('suivi-force-DEPART')));
      await settle(tester);
      expect(visited.last, '/tracking/scan/identify');
      expect(lastExtra, {'etape': 'DEPART', 'focusNumber': true});
    });

    testWidgets('transit forcé : consigne, puis retour en automatique', (
      tester,
    ) async {
      stubTransitTrips();
      await pump(tester);
      await forceTransit(tester);
      // Feuille repliée sur la caméra, consigne du transit.
      expect(cameraPaused?.value, isFalse);
      expect(
        text(
          'Transit facultatif : scanne le colis à valider.\n'
          "L'étape repasse ensuite en automatique.",
        ),
        findsOneWidget,
      );

      // Colis pas encore parti : refusé avant tout envoi.
      scan!('madou');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(text("Valide d'abord le départ de Madou."), findsOneWidget);
      await settle(tester, rounds: 12);

      await openNumberField(tester);
      expect(text('Étape : transit, facultatif'), findsOneWidget);
      await tapVisible(tester, const Key('suivi-step-auto'));
      expect(text('Étape : automatique'), findsOneWidget);
    });

    testWidgets('numéro, transit forcé : récap, photo obligatoire, bandeau', (
      tester,
    ) async {
      stubTransitTrips();
      await pump(tester);
      await forceTransit(tester);
      await openNumberField(tester);
      await submitNumber(tester, 'don-sal003');

      expect(text('Valider avec le numéro'), findsOneWidget);
      expect(text('Colis de Sali'), findsOneWidget);
      expect(text('4,5 kg · DON-SAL003'), findsOneWidget);
      expect(text('Départ'), findsOneWidget);
      expect(text('Transit'), findsOneWidget);
      expect(
        text(
          'Sans QR code, une photo du colis est obligatoire. Ta position '
          "est enregistrée avec l'étape.",
        ),
        findsOneWidget,
      );
      verifyNever(() => trackingRepo.searchByTrackingNumber(any()));

      await tester.tap(find.byKey(const Key('suivi-number-photo')));
      await settle(tester);
      expect(lastExtra, {
        'bidId': 'sali',
        'etape': 'TRANSIT',
        'packageLabel': 'Sali',
        'returnResult': true,
      });
      await tester.tap(text('page /tracking/scan/photo'));
      await settle(tester, rounds: 2);
      expect(text('Transit de Sali validé'), findsOneWidget);
      expect(
        find.textContaining('Photo prise · envoi dans', findRichText: true),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 5));
      await settle(tester, rounds: 2);
      await verifySent(
        bidId: 'sali',
        step: 'TRANSIT',
        method: ScanMethod.manual,
        photoPath: '/tmp/colis.jpg',
        at: _here,
      );
      verify(
        () => analytics.logEvent(
          'suivi_step_validated',
          properties: {'step': 'TRANSIT', 'method': 'manual'},
        ),
      ).called(1);
    });

    testWidgets('numéro d\'une arrivée → parcours photo puis code', (
      tester,
    ) async {
      stubDefaultTrips();
      when(
        () => trackingRepo.searchByTrackingNumber(any()),
      ).thenThrow(const NotFoundException());
      await pump(tester);
      await openNumberField(tester);
      await submitNumber(tester, 'DON-KAD002');
      await tester.tap(find.byKey(const Key('suivi-number-photo')));
      await settle(tester);
      expect(lastExtra, {
        'bidId': 'kadi',
        'etape': 'ARRIVEE',
        'packageLabel': 'Kadi',
        'scanMethod': ScanMethod.manual,
      });
    });

    testWidgets('récap fermé → rien n\'est programmé', (tester) async {
      stubTransitTrips();
      await pump(tester);
      await openNumberField(tester);
      await submitNumber(tester, 'DON-SAL003');
      await tester.tapAt(const Offset(20, 20));
      await settle(tester);
      expect(text('Valider avec le numéro'), findsNothing);
      expect(visited, isNot(contains('/tracking/scan/photo')));
    });

    testWidgets('numéro d\'un autre trajet → passer sur ce trajet', (
      tester,
    ) async {
      stubTransitTrips();
      await pump(tester);
      await openNumberField(tester);
      await submitNumber(tester, 'DON-FAT004');
      expect(text("Ce colis n'est pas sur ce trajet"), findsOneWidget);
    });

    testWidgets('numéro d\'un colis inconnu → suivre seulement', (
      tester,
    ) async {
      when(() => trackingRepo.searchByTrackingNumber('DON-AUTRE1')).thenAnswer(
        (_) async => const TrackingSearchModel(
          trackingNumber: 'DON-AUTRE1',
          bidId: 'ailleurs',
          departureCity: 'Lyon',
          arrivalCity: 'Abidjan',
          currentStep: 'IN_TRANSIT',
          stepLabel: 'En transit',
          paymentStatus: 'ESCROWED',
        ),
      );
      stubTransitTrips();
      await pump(tester);
      await openNumberField(tester);
      await submitNumber(tester, 'DON-AUTRE1');
      expect(text("Ce colis n'est pas sur tes trajets"), findsOneWidget);
    });

    testWidgets('numéro introuvable ou non lié au compte', (tester) async {
      when(
        () => trackingRepo.searchByTrackingNumber('DON-NOPE01'),
      ).thenThrow(const NotFoundException());
      when(
        () => trackingRepo.searchByTrackingNumber('DON-PRIVE1'),
      ).thenThrow(const ForbiddenException());
      stubTransitTrips();
      await pump(tester);
      await openNumberField(tester);

      await submitNumber(tester, 'DON-NOPE01');
      expect(
        text('Numéro introuvable. Vérifie-le et réessaie.'),
        findsOneWidget,
      );

      await submitNumber(tester, 'DON-PRIVE1');
      expect(text("Ce colis n'est pas lié à ton compte"), findsOneWidget);
      expect(text('Réessayer'), findsNothing);
    });
  });

  group('mode Suivre : colis non lié au compte', () {
    testWidgets('numéro refusé (403) → message dédié, sans Réessayer', (
      tester,
    ) async {
      when(
        () => trackingRepo.searchByTrackingNumber('DON-PRIVE1'),
      ).thenThrow(const ForbiddenException());
      await pump(tester, roles: ['SENDER']);
      await tester.enterText(
        find.byKey(const Key('suivi-number-field')),
        'DON-PRIVE1',
      );
      await tester.tap(find.byKey(const Key('suivi-number-submit')));
      await settle(tester);
      expect(text("Ce colis n'est pas lié à ton compte"), findsOneWidget);
      expect(
        text(
          "Seuls l'expéditeur et le voyageur peuvent le suivre ici. Demande "
          "le lien de suivi à l'expéditeur.",
        ),
        findsOneWidget,
      );
      expect(text('Réessayer'), findsNothing);
      expect(find.byKey(const Key('suivi-search-error')), findsNothing);
    });

    testWidgets('QR refusé (403) → parcours avec message dédié', (
      tester,
    ) async {
      getIt
        ..unregister<TrackingBloc>()
        ..registerFactory<TrackingBloc>(() {
          final bloc = _MockTrackingBloc();
          when(
            () => bloc.state,
          ).thenReturn(TrackingEventsError(const ForbiddenException()));
          return bloc;
        });
      stubDefaultTrips();
      await pump(tester, location: '/?mode=suivre');
      scan!('00000000-0000-0000-0000-000000000000');
      await settle(tester);
      expect(text("Ce colis n'est pas lié à ton compte"), findsOneWidget);
      expect(text('Réessayer'), findsNothing);
    });
  });

  group('provenance et aide', () {
    testWidgets('derniers scans : étape suivie de QR ou numéro', (
      tester,
    ) async {
      stubDefaultTrips();
      await pump(tester);
      await tester.drag(
        find.byKey(const Key('suivi-sheet')),
        const Offset(0, -700),
      );
      await settle(tester);
      await tester.ensureVisible(text('Transit · QR'));
      await settle(tester, rounds: 1);

      expect(text('Transit · QR'), findsOneWidget);
      expect(text('Départ · numéro'), findsOneWidget);
      // Provenance inconnue (ancien scan) : l'étape seule.
      expect(
        find.descendant(
          of: find.ancestor(of: text('Awa'), matching: find.byType(Row)),
          matching: text('Départ'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('« ? » en mode Valider ouvre le tutoriel de la remise QR', (
      tester,
    ) async {
      stubDefaultTrips();
      await pump(tester, qrTutorial: true);

      final help = find.byKey(const Key('suivi-help'));
      expect(help, findsOneWidget);
      expect(find.byTooltip('Comment ça marche ?'), findsOneWidget);
      expect(tester.getSize(help).height, greaterThanOrEqualTo(44));

      await tester.tap(help);
      await settle(tester);
      expect(visited, contains('/profile/help/tutorial/:id'));
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.helpTutorialOpened,
          properties: {'tutorial_id': 'qr_handover', 'source': 'qr_handover'},
        ),
      ).called(1);
    });

    testWidgets('« ? » absent en mode Suivre', (tester) async {
      stubDefaultTrips();
      await pump(tester, qrTutorial: true, location: '/?mode=suivre');
      expect(find.byKey(const Key('suivi-help')), findsNothing);
    });

    testWidgets('« ? » absent quand le catalogue n\'a pas le tutoriel', (
      tester,
    ) async {
      stubDefaultTrips();
      await pump(tester);
      expect(find.byKey(const Key('suivi-help')), findsNothing);
    });
  });

  // Recette Redmi : sous le thème de l'app, les boutons « Suivre » et
  // « Valider » du champ numéro (largeur minimale infinie dans une Row)
  // cassaient la mise en page, feuille blanche ou superposée.
  group('vrai thème de l\'app, clair et sombre', () {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('Valider replié puis déplié sur le champ numéro ($mode)', (
        tester,
      ) async {
        stubDefaultTrips();
        await pump(tester, themeMode: mode);
        expect(tester.takeException(), isNull);
        expect(text('Bobo-Dioulasso → Yaoundé'), findsOneWidget);
        expect(text('QR illisible ? Saisir le numéro'), findsOneWidget);

        await openNumberField(tester);
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('suivi-validate-number-field')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('suivi-validate-number-submit')),
          findsOneWidget,
        );
        expect(text('Forcer une étape'), findsOneWidget);
      });

      testWidgets('Suivre un colis ($mode)', (tester) async {
        stubDefaultTrips();
        await pump(tester, themeMode: mode, location: '/?mode=suivre');
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('suivi-number-field')), findsOneWidget);
        expect(find.byKey(const Key('suivi-number-submit')), findsOneWidget);
        expect(
          find.textContaining('Mes envois', findRichText: true),
          findsOneWidget,
        );
      });

      testWidgets('expéditeur seul ($mode)', (tester) async {
        await pump(tester, roles: ['SENDER'], themeMode: mode);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('suivi-number-field')), findsOneWidget);
        expect(
          find.textContaining('Mes envois', findRichText: true),
          findsOneWidget,
        );
      });
    }
  });
}

/// `flutter_animate` et les feuilles laissent des animations finies : on
/// pompe par pas plutôt que `pumpAndSettle`, que les indicateurs de
/// chargement bloqueraient.
Future<void> settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void _unregisterAll() {
  if (getIt.isRegistered<SuiviCubit>()) getIt.unregister<SuiviCubit>();
  if (getIt.isRegistered<ScanHubCubit>()) getIt.unregister<ScanHubCubit>();
  if (getIt.isRegistered<SuiviValidationCubit>()) {
    getIt.unregister<SuiviValidationCubit>();
  }
  if (getIt.isRegistered<TrackingBloc>()) getIt.unregister<TrackingBloc>();
  if (getIt.isRegistered<OfflineSyncService>()) {
    getIt.unregister<OfflineSyncService>();
  }
}
