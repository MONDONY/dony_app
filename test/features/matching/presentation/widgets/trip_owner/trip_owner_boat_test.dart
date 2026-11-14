// Écran du trajet vu par son voyageur, selon le mode (lot 3, bateau) :
// volume restant sur le volume proposé et prix NET au m³, tuile Paiements
// « Payé au dépôt de chaque colis » (bateau allumé), « Arrivé au port de … »
// (icône bateau) et « Bateau parti », dernier retard annoncé, entrée
// « Annoncer un retard » du menu ⋮ (trajet parti, tous modes) et son envoi.
// Avion et route gardent leurs libellés ; jamais d'avion hors avion ; FR et
// EN à 360 dp.
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/config/transport_modes_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/trip_audience_cubit.dart';
import 'package:dony/features/matching/bloc/trip_delay/trip_delay_cubit.dart';
import 'package:dony/features/matching/bloc/trip_group_cubit.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/trip_audience_model.dart';
import 'package:dony/features/matching/data/models/trip_delay_info.dart';
import 'package:dony/features/matching/data/models/trip_parcels_summary.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/presentation/widgets/trip_delay_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_arrival.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_bid_answer.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_owner_actions.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_owner_body.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_owner_options_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_owner_sticky_bar.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_tiles.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_labels.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/tracking/bloc/trip_depart_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/label_fit_expectations.dart';
import '../../../../../helpers/plane_icon_expectations.dart';
import '../../../../../helpers/stripe_account_test_doubles.dart';
import 'trip_answer_harness.dart';
import 'trip_owner_harness.dart' show pumpTripOwnerScreen, ownerTrip, ownerBid;

class _MockDepart extends MockCubit<TripDepartState>
    implements TripDepartCubit {}

class _MockAnnouncements extends Mock implements AnnouncementRepository {}

AnnouncementModel _trip({
  TransportMode? mode = TransportMode.boat,
  String status = 'IN_PROGRESS',
  TripDelayInfo? delay,
  TripParcelsSummary? summary,
  bool trackingActive = false,
  DateTime? departure,
}) {
  final boat = mode == TransportMode.boat;
  return AnnouncementModel(
    id: 'trip-1',
    travelerId: 'trav-1',
    departureCity: boat ? 'Le Havre' : 'Paris',
    arrivalCity: boat ? 'Abidjan' : 'Dakar',
    departureDate: departure ?? DateTime(2026, 12, 2),
    arrivalDate: DateTime(2027, 1, 11),
    arrivalDateMax: boat ? DateTime(2027, 1, 18) : null,
    availableKg: boat ? 0 : 20,
    totalKg: boat ? 0 : 20,
    pricePerKg: boat ? null : 7,
    volumeCapacityM3: boat ? 2 : null,
    availableVolumeM3: boat ? 0.4 : null,
    pricePerM3: boat ? 600 : null,
    pricePerM3Display: boat ? 672 : null,
    status: status,
    transportMode: mode,
    acceptedPaymentMethods: const {
      BidPaymentMethod.stripe,
      BidPaymentMethod.cash,
    },
    pickupAddress: const AddressData(label: 'Entrepôt', lat: 1, lng: 1),
    latestTripDelay: delay,
    parcelsSummary: summary,
    trackingActive: trackingActive,
    createdAt: DateTime(2026, 11),
    updatedAt: DateTime(2026, 11),
  );
}

BidModel _bid(String id, String status, {String? sender}) => BidModel(
  id: id,
  announcementId: 'trip-1',
  senderId: sender ?? 'sender-$id',
  senderName: 'Expéditeur $id',
  weightKg: 3,
  status: status,
  recipientName: 'Aïcha',
  recipientPhone: '+225070000000',
  departureDate: DateTime(2026, 12, 2),
  createdAt: DateTime(2026, 11),
  updatedAt: DateTime(2026, 11),
);

TripDelayInfo _delay({String reason = 'PORT_CONGESTION'}) => TripDelayInfo(
  id: 'd-1',
  reason: reason,
  arrivalDate: DateTime(2027, 1, 16),
  arrivalDateMax: DateTime(2027, 1, 23),
  message: 'Attente à Tanger Med',
  announcedAt: DateTime.utc(2026, 12, 20),
);

void main() {
  late AnswerHarness h;

  setUpAll(() async {
    AnswerHarness.registerFallbacks();
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
    await loadAppFonts();
  });

  setUp(() async {
    h = AnswerHarness();
    await h.setUp();
    tripTodoNow = () => DateTime(2026, 12, 20, 12);
    setTransportModes(const TransportModesAvailability(road: true, boat: true));
  });

  tearDown(() async {
    tripTodoNow = DateTime.now;
    resetTransportModesForTest();
    await h.tearDown();
  });

  /// Monte le corps sous les blocs de la route, comme l'écran.
  Future<void> pumpBody(
    WidgetTester tester, {
    required AnnouncementModel trip,
    List<BidModel>? bids = const [],
    Locale locale = const Locale('fr'),
    Size size = const Size(400, 3200),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    whenListen(
      h.annBloc,
      h.annStates.stream,
      initialState: AnnouncementDetailLoaded(trip),
    );
    whenListen(
      h.screenBids,
      h.screenStates.stream,
      initialState: bids == null ? BidLoading() : BidListLoaded(bids),
    );
    whenListen(h.answerBids, h.answerStates.stream, initialState: BidInitial());
    whenListen(
      h.acceptance,
      h.acceptanceStates.stream,
      initialState: acs.BidAcceptanceInitial(),
    );
    final audience = MockTripAudienceCubit();
    whenListen(
      audience,
      const Stream<TripAudienceState>.empty(),
      initialState: const TripAudienceState.loaded(
        TripAudienceModel(uniqueViewerCount: 3, shareViewCount: 1),
      ),
    );
    when(() => audience.load(any())).thenAnswer((_) async {});
    final depart = _MockDepart();
    whenListen(
      depart,
      const Stream<TripDepartState>.empty(),
      initialState: const TripDepartState(),
    );
    final group = MockTripGroupCubit();
    whenListen(
      group,
      const Stream<TripGroupState>.empty(),
      initialState: const TripGroupState(),
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => MultiBlocProvider(
            providers: [
              BlocProvider<AnnouncementBloc>.value(value: h.annBloc),
              BlocProvider<BidBloc>.value(value: h.screenBids),
              BlocProvider<TripAudienceCubit>.value(value: audience),
              BlocProvider<TripGroupCubit>.value(value: group),
              BlocProvider<TripDepartCubit>.value(value: depart),
              BlocProvider<StripeAccountBloc>.value(
                value: stubStripeAccountBloc(),
              ),
            ],
            child: Scaffold(
              body: TripBidAnswerScope(
                tripId: trip.id,
                bidBloc: h.answerBids,
                acceptanceBloc: h.acceptance,
                child: TripOwnerBody(trip: trip, isOwner: true),
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Finder key(String k) => find.byKey(Key(k));
  Finder within(Finder parent, Finder child) =>
      find.descendant(of: parent, matching: child);
  Finder todo(String kind) => find.byWidgetPredicate(
    (w) =>
        w.key == Key('trip-todo-next-$kind') ||
        w.key == Key('trip-todo-row-$kind'),
  );

  final onBoard = [_bid('b1', 'IN_TRANSIT'), _bid('b2', 'HANDED_OVER')];

  group('tripOwner_boatVolumeAndDepositTile', () {
    testWidgets('volume restant sur proposé, prix NET au m³, payé au dépôt', (
      tester,
    ) async {
      await pumpBody(tester, trip: _trip(), bids: onBoard);
      expect(
        within(key('trip-owner-capacity-pill'), find.text('0,4 m³')),
        findsOneWidget,
      );
      expect(
        within(key('trip-owner-capacity-pill'), find.text('restants sur 2 m³')),
        findsOneWidget,
      );
      expect(
        within(
          key('trip-owner-price-pill'),
          find.text('${formatPriceIn(600, 'EUR')}/m³'),
        ),
        findsOneWidget,
      );
      // Jamais le brut de l'expéditeur, jamais un kilo.
      expect(find.textContaining('672'), findsNothing);
      expect(find.textContaining('/kg'), findsNothing);
      expect(
        within(
          key('trip-tile-payments'),
          find.text('Payé au dépôt de chaque colis'),
        ),
        findsOneWidget,
      );
      expectNoPlaneIcon(tester);
    });

    testWidgets('bateau éteint : moyens de paiement, rien sur le dépôt', (
      tester,
    ) async {
      resetTransportModesForTest();
      await pumpBody(tester, trip: _trip(), bids: onBoard);
      expect(find.text('Payé au dépôt de chaque colis'), findsNothing);
      expect(
        within(key('trip-tile-payments'), find.textContaining('Carte')),
        findsOneWidget,
      );
    });

    testWidgets('sheet Paiements : le versement au dépôt, en bateau seul', (
      tester,
    ) async {
      await pumpBody(tester, trip: _trip(), bids: onBoard);
      await tester.tap(key('trip-tile-payments'));
      await settle(tester);
      expect(
        find.text("Chaque colis vous est versé dès son dépôt à l'entrepôt."),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(5, 5));
      await settle(tester);
      await pumpBody(
        tester,
        trip: _trip(mode: TransportMode.car),
        bids: onBoard,
      );
      await tester.tap(key('trip-tile-payments'));
      await settle(tester);
      expect(key('trip-tile-payments-deposit-note'), findsNothing);
    });

    testWidgets('anglais', (tester) async {
      await pumpBody(
        tester,
        trip: _trip(),
        bids: onBoard,
        locale: const Locale('en'),
      );
      expect(find.text('left of 2 m³'), findsOneWidget);
      expect(find.text('Paid as each parcel is dropped off'), findsOneWidget);
      expect(find.text('Arrived at the port of Abidjan'), findsOneWidget);
      expect(find.text('Arrived at port'), findsOneWidget);
      expectNoPlaneIcon(tester);
    });

    test('tripPaidAtDeposit : bateau et interrupteur allumé seulement', () {
      expect(tripPaidAtDeposit(_trip()), isTrue);
      expect(tripPaidAtDeposit(_trip(mode: TransportMode.car)), isFalse);
      expect(tripPaidAtDeposit(_trip(mode: TransportMode.plane)), isFalse);
      expect(tripPaidAtDeposit(_trip(mode: null)), isFalse);
      resetTransportModesForTest();
      expect(tripPaidAtDeposit(_trip()), isFalse);
    });
  });

  group('départ et arrivée selon le mode', () {
    testWidgets('bateau : « Arrivé au port d’Abidjan », icône du bateau', (
      tester,
    ) async {
      await pumpBody(tester, trip: _trip(), bids: onBoard);
      final card = key('trip-todo-next-arrive');
      expect(
        within(card, find.text("Arrivé au port d'Abidjan")),
        findsOneWidget,
      );
      expect(within(card, find.text('Arrivé au port')), findsOneWidget);
      expect(within(card, findDonyIcon('ship')), findsOneWidget);
      expect(find.text('Arrivé à destination'), findsNothing);
      expectNoPlaneIcon(tester);
    });

    testWidgets('route : « Arrivé à destination », drapeau, kilos', (
      tester,
    ) async {
      await pumpBody(
        tester,
        trip: _trip(mode: TransportMode.car),
        bids: onBoard,
      );
      final card = key('trip-todo-next-arrive');
      expect(within(card, find.text('Arrivé à destination')), findsNWidgets(2));
      expect(within(card, findDonyIcon('flag')), findsOneWidget);
      expect(find.textContaining(RegExp(r'\bport\b')), findsNothing);
      expect(find.textContaining('m³'), findsNothing);
      expect(
        within(key('trip-owner-capacity-pill'), find.text('20 kg')),
        findsOneWidget,
      );
      expectNoPlaneIcon(tester);
    });

    testWidgets('bateau : « Bateau parti » sur la carte et dans son sheet', (
      tester,
    ) async {
      await pumpBody(
        tester,
        trip: _trip(
          status: 'ACTIVE',
          trackingActive: true,
          summary: const TripParcelsSummary(
            count: 1,
            totalKg: 0,
            netAmount: 57,
            currency: 'EUR',
          ),
        ),
        bids: [_bid('b1', 'HANDED_OVER')],
      );
      final card = todo('depart');
      expect(within(card, find.text('Bateau parti')), findsWidgets);
      expect(find.text('Je pars'), findsNothing);
      expect(within(card, findDonyIcon('ship')), findsOneWidget);
      await tester.tap(within(card, find.byType(DonyButton)).first);
      await settle(tester);
      expect(
        within(key('trip-depart-button'), find.text('Bateau parti')),
        findsOneWidget,
      );
      expectNoPlaneIcon(tester);
    });

    test('libellés purs : avion et route gardent les leurs', () {
      final fr = lookupAppLocalizations(const Locale('fr'));
      final en = lookupAppLocalizations(const Locale('en'));
      const depart = TripTodoItem(kind: TripTodoKind.depart, count: 1);
      const arrive = TripTodoItem(kind: TripTodoKind.arrive, count: 1);
      for (final mode in [TransportMode.plane, TransportMode.car, null]) {
        final trip = _trip(mode: mode);
        expect(
          tripTodoTitle(fr, depart, cardReady: false, trip: trip),
          'Je pars',
        );
        expect(
          tripTodoButton(fr, arrive, cardReady: false, trip: trip),
          'Arrivé à destination',
        );
        expect(
          tripTodoIcon(TripTodoKind.arrive, transportModeOrPlane(mode)),
          'flag',
        );
      }
      final boat = _trip();
      expect(
        tripTodoTitle(en, depart, cardReady: false, trip: boat),
        'Ship departed',
      );
      expect(
        tripTodoTitle(en, arrive, cardReady: false, trip: boat),
        'Arrived at the port of Abidjan',
      );
      // Sans trajet : comportement d'avant.
      expect(tripTodoTitle(fr, depart, cardReady: false), 'Je pars');
      expect(tripTodoIcon(TripTodoKind.arrive, TransportMode.boat), 'ship');
    });
  });

  group('dernier retard annoncé', () {
    testWidgets('trajet parti : la carte du retard, motif selon le mode', (
      tester,
    ) async {
      await pumpBody(
        tester,
        trip: _trip(delay: _delay()),
        bids: onBoard,
      );
      expect(key('trip-delay-card'), findsOneWidget);
      expect(find.text('Motif : Congestion au port'), findsOneWidget);
      expect(find.textContaining('Attente à Tanger Med'), findsOneWidget);
      await pumpBody(
        tester,
        trip: _trip(
          mode: TransportMode.car,
          delay: _delay(reason: 'EXTENDED_STOPOVER'),
        ),
        bids: onBoard,
      );
      expect(find.text('Motif : Arrêt prolongé'), findsOneWidget);
      expectNoPlaneIcon(tester);
    });

    testWidgets('trajet terminé : plus de carte', (tester) async {
      await pumpBody(
        tester,
        trip: _trip(status: 'COMPLETED', delay: _delay()),
        bids: [_bid('b1', 'COMPLETED')],
      );
      expect(key('trip-delay-card'), findsNothing);
    });
  });

  group('pied collant à 360 dp', () {
    for (final locale in const [Locale('fr'), Locale('en')]) {
      for (final (name, trip, bids, todoKey, label) in [
        (
          'arrivée',
          _trip(),
          [_bid('b1', 'IN_TRANSIT')],
          'trip-footer-todo-arrive',
          locale.languageCode == 'fr' ? 'Arrivé au port' : 'Arrived at port',
        ),
        (
          'départ',
          _trip(
            status: 'ACTIVE',
            trackingActive: true,
            summary: const TripParcelsSummary(
              count: 1,
              totalKg: 0,
              netAmount: 57,
              currency: 'EUR',
            ),
          ),
          [_bid('b1', 'HANDED_OVER')],
          'trip-footer-todo-depart',
          locale.languageCode == 'fr' ? 'Bateau parti' : 'Ship departed',
        ),
      ]) {
        testWidgets('bateau $name ${locale.languageCode} : une ligne', (
          tester,
        ) async {
          await pumpTripOwnerScreen(
            tester,
            locale: locale,
            bottomBar: TripOwnerStickyBar(
              trip: trip,
              bids: bids,
              isOwner: true,
            ),
          );
          expect(tester.takeException(), isNull);
          final button = key(todoKey);
          expect(within(button, find.text(label)), findsOneWidget);
          expectButtonLabelNominal(tester, button, reason: label);
          expectNoPlaneIcon(tester);
        });
      }
    }
  });

  group('« Annoncer un retard » (menu ⋮)', () {
    late _MockAnnouncements repository;
    late MockAnnouncementBloc annBloc;
    late MockBidBloc bidBloc;

    setUp(() async {
      repository = _MockAnnouncements();
      registerFallbackValue(TripDelayReason.other);
      registerFallbackValue(DateTime(2026));
      getIt.registerFactoryParam<TripDelayCubit, AnnouncementModel, void>(
        (trip, _) =>
            TripDelayCubit(trip, repository, getIt<AnalyticsService>()),
      );
      annBloc = MockAnnouncementBloc();
      bidBloc = MockBidBloc();
      whenListen(
        annBloc,
        const Stream<AnnouncementState>.empty(),
        initialState: AnnouncementInitial(),
      );
      whenListen(
        bidBloc,
        const Stream<BidState>.empty(),
        initialState: BidInitial(),
      );
      when(() => annBloc.isClosed).thenReturn(false);
      when(() => bidBloc.isClosed).thenReturn(false);
    });

    test('entrée seulement sur un trajet parti, tous modes', () {
      for (final mode in [
        TransportMode.boat,
        TransportMode.plane,
        TransportMode.car,
        TransportMode.other,
        null,
      ]) {
        expect(
          tripMenuEntriesFor(
            trip: _trip(mode: mode),
            bids: [_bid('b1', 'IN_TRANSIT')],
            isOwner: true,
          ),
          contains(TripMenuEntry.announceDelay),
          reason: '$mode',
        );
      }
      for (final status in [
        'DRAFT',
        'ACTIVE',
        'FULL',
        'COMPLETED',
        'CANCELLED',
      ]) {
        expect(
          tripMenuEntriesFor(
            trip: _trip(status: status),
            bids: [_bid('b1', 'HANDED_OVER')],
            isOwner: true,
          ),
          isNot(contains(TripMenuEntry.announceDelay)),
          reason: status,
        );
      }
      expect(
        tripMenuEntriesFor(trip: _trip(), bids: const [], isOwner: false),
        isEmpty,
      );
      expect(tripCanAnnounceDelay(ownerTrip(status: 'IN_PROGRESS')), isTrue);
    });

    test('expéditeurs prévenus : distincts, colis remis ou arrivés', () {
      expect(tripDelaySenderCount(null), 0);
      expect(
        tripDelaySenderCount([
          _bid('b1', 'IN_TRANSIT', sender: 'awa'),
          _bid('b2', 'ARRIVED', sender: 'awa'),
          _bid('b3', 'HANDED_OVER', sender: 'kofi'),
          _bid('b4', 'ACCEPTED', sender: 'moussa'),
          _bid('b5', 'PENDING', sender: 'ines'),
        ]),
        2,
      );
    });

    testWidgets('envoi : confirmation, trajet et colis relus en silence', (
      tester,
    ) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      when(
        () => repository.announceDelay(
          announcementId: any(named: 'announcementId'),
          reason: any(named: 'reason'),
          arrivalDate: any(named: 'arrivalDate'),
          arrivalDateMax: any(named: 'arrivalDateMax'),
          message: any(named: 'message'),
        ),
      ).thenAnswer(
        (_) async => TripDelayInfo(
          reason: 'WEATHER',
          arrivalDate: today,
          arrivalDateMax: today,
          announcedAt: now,
        ),
      );
      final trip = AnnouncementModel(
        id: 'trip-1',
        travelerId: 'trav-1',
        departureCity: 'Le Havre',
        arrivalCity: 'Abidjan',
        departureDate: today.subtract(const Duration(days: 3)),
        availableKg: 0,
        totalKg: 0,
        pricePerM3: 600,
        volumeCapacityM3: 2,
        availableVolumeM3: 0.4,
        status: 'IN_PROGRESS',
        transportMode: TransportMode.boat,
        createdAt: DateTime(2026, 11),
        updatedAt: DateTime(2026, 11),
      );
      final bids = [
        ownerBid('b1', 'IN_TRANSIT'),
        ownerBid('b2', 'ARRIVED'),
        ownerBid('b3', 'ACCEPTED'),
      ];
      await pumpTripOwnerScreen(
        tester,
        announcement: annBloc,
        bids: bidBloc,
        size: const Size(390, 900),
        body: (context) => TextButton(
          onPressed: () =>
              showTripOwnerOptionsSheet(context, trip: trip, bids: bids),
          child: const Text('open-menu'),
        ),
      );
      await tester.tap(find.text('open-menu'));
      await tester.pumpAndSettle();
      final entry = key('trip-menu-announceDelay');
      expect(within(entry, find.text('Annoncer un retard')), findsOneWidget);
      expect(
        within(
          entry,
          find.text('Prévenez les expéditeurs de la nouvelle arrivée estimée'),
        ),
        findsOneWidget,
      );
      expect(within(entry, findDonyIcon('hourglass')), findsOneWidget);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.byType(TripDelayBottomSheet), findsOneWidget);
      expect(
        find.text('Les 2 expéditeurs de ce trajet sont prévenus en une fois.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Météo'));
      for (final tile in ['trip-delay-from', 'trip-delay-to']) {
        await tester.tap(key(tile));
        await tester.pumpAndSettle();
        await tester.tap(find.text('${today.day}'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      }
      await tester.tap(key('trip-delay-submit'));
      await tester.pumpAndSettle();

      expect(find.byType(TripDelayBottomSheet), findsNothing);
      expect(
        find.text('Retard annoncé : les expéditeurs sont prévenus.'),
        findsOneWidget,
      );
      final reload =
          verify(() => annBloc.add(captureAny())).captured.single
              as AnnouncementDetailRequested;
      expect(reload.id, 'trip-1');
      expect(reload.silent, isTrue);
      final parcels =
          verify(() => bidBloc.add(captureAny())).captured.single
              as BidListRequested;
      expect(parcels.announcementId, 'trip-1');
      expect(parcels.silent, isTrue);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('feuille fermée sans envoi : rien de relu', (tester) async {
      await pumpTripOwnerScreen(
        tester,
        announcement: annBloc,
        bids: bidBloc,
        body: (context) => TextButton(
          onPressed: () => openTripDelay(context, _trip(), null),
          child: const Text('open'),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Les expéditeurs dont le colis est à bord sont prévenus en une fois.',
        ),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(TripDelayBottomSheet), findsNothing);
      verifyNever(() => annBloc.add(any()));
      verifyNever(() => bidBloc.add(any()));
    });
  });
}
