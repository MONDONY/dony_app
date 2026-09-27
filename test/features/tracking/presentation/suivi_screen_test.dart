import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/tracking/bloc/scan_hub_cubit.dart';
import 'package:dony/features/tracking/bloc/suivi_cubit.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/tracking_search_model.dart';
import 'package:dony/features/tracking/data/models/trip_scan_history_entry_model.dart';
import 'package:dony/features/tracking/data/offline_sync_service.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
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
}) => BidModel(
  id: id,
  announcementId: trip,
  senderId: 's',
  status: status,
  recipientName: name,
  trackingNumber: number,
  departureCity: from,
  arrivalCity: to,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  late _MockAnnouncementRepo annRepo;
  late _MockBidRepo bidRepo;
  late _MockTrackingRepo trackingRepo;
  late _MockAnalytics analytics;
  late _MockOfflineSync offlineSync;
  late ChangeNotifier queue;
  late List<String> visited;
  late Map<String, dynamic>? lastExtra;
  ValueChanged<String>? scan;
  ValueListenable<bool>? cameraPaused;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(<String>{});
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
        stub('/tracking/scan/photo'),
        stub('/tracking/scan/identify'),
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
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: auth,
        child: MaterialApp.router(
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
      });
      // Écran recouvert : caméra coupée.
      expect(cameraPaused?.value, isTrue);

      final router = GoRouter.of(
        tester.element(find.text('page /tracking/scan/photo')),
      );
      router.pop();
      await settle(tester);
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

    testWidgets('action d\'une ligne et numéro → identification', (
      tester,
    ) async {
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

      await tester.ensureVisible(find.byKey(const Key('suivi-enter-number')));
      await settle(tester, rounds: 2);
      await tester.tap(find.byKey(const Key('suivi-enter-number')));
      await settle(tester);
      // Étapes différentes selon les colis : l'identification la demandera.
      expect(lastExtra, {'etape': null, 'focusNumber': false});
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
  if (getIt.isRegistered<TrackingBloc>()) getIt.unregister<TrackingBloc>();
  if (getIt.isRegistered<OfflineSyncService>()) {
    getIt.unregister<OfflineSyncService>();
  }
}
