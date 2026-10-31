// Corps assemblé de l'écran du trajet vu par son voyageur (TripOwnerBody),
// « tableau de bord » du 31/10 : table statut du trajet × situations
// (demandes 0, 1, 3, 8 ; colis 0, 2, 10 ; colis en route, arrivés ; espèces
// seules ; voyage à étapes ; instructions ; retrait par l'équipe) → blocs
// présents ou absents, écrite à la main (pas recalculée par les fonctions de
// production) ; ordre des sections ; visiteur ; mesure de « À traiter » ;
// réponse à une demande qui passe à la suivante ; chaque sheet ouvert depuis
// le corps ; FR / EN, 360 dp × 1,3.
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/trip_audience_cubit.dart';
import 'package:dony/features/matching/bloc/trip_group_cubit.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/trip_audience_model.dart';
import 'package:dony/features/matching/data/models/trip_legs_info.dart';
import 'package:dony/features/matching/data/models/trip_parcels_summary.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_bid_answer.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_owner_body.dart';
import 'package:dony/features/matching/presentation/widgets/trip_parcels_section.dart'
    show TripParcelRow;
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/tracking/bloc/trip_depart_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/stripe_account_test_doubles.dart';
import 'trip_answer_harness.dart';

class _MockDepart extends MockCubit<TripDepartState>
    implements TripDepartCubit {}

/// Les huit statuts : six de l'app, celui de la modération, un inconnu.
const _statuses = [
  'DRAFT',
  'ACTIVE',
  'FULL',
  'IN_PROGRESS',
  'COMPLETED',
  'CANCELLED',
  'REMOVED_BY_ADMIN',
  'SOMETHING_NEW',
];

AnnouncementModel _trip({
  String status = 'ACTIVE',
  Set<BidPaymentMethod> methods = const {BidPaymentMethod.stripe},
  String? instructions,
  TripParcelsSummary? summary,
  String? groupId,
  bool trackingActive = false,
  int? remainingReschedules,
}) => AnnouncementModel(
  id: 'trip-1',
  travelerId: 'trav-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 11, 12),
  availableKg: 20,
  totalKg: 20,
  pricePerKg: 7,
  status: status,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
  acceptedPaymentMethods: methods,
  pickupAddress: const AddressData(label: '12 rue de Paris', lat: 1, lng: 1),
  arrivalInstructions: instructions,
  parcelsSummary: summary,
  tripGroupId: groupId,
  trackingActive: trackingActive,
  remainingReschedules: remainingReschedules,
);

BidModel _bid(String id, String status) => BidModel(
  id: id,
  announcementId: 'trip-1',
  senderId: 'sender-$id',
  senderName: 'Expéditeur $id',
  weightKg: 3,
  description: 'Contenu $id',
  status: status,
  recipientName: 'Fatou',
  recipientPhone: '+221770000000',
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

List<BidModel> _requests(int n) => [
  for (var i = 1; i <= n; i++) _bid('r$i', 'PENDING'),
];

List<BidModel> _parcels(int n, [String status = 'IN_TRANSIT']) => [
  for (var i = 1; i <= n; i++) _bid('p$i', status),
];

const _summary = TripParcelsSummary(
  count: 1,
  totalKg: 3,
  netAmount: 21,
  currency: 'EUR',
);

final _legs = TripLegsInfo.fromJson(const {
  'tripGroupId': 'g',
  'legCount': 2,
  'legs': [
    {'id': 'trip-1', 'legIndex': 1, 'departureDate': '2026-11-12'},
    {'id': 'leg-2', 'legIndex': 2, 'departureDate': '2026-11-14'},
  ],
});

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
  });

  tearDown(() => h.tearDown());

  /// Monte le corps sous les blocs de la route du trajet et le scope de
  /// réponse, comme l'écran. Les écrans poussés sont notés.
  Future<List<String>> pump(
    WidgetTester tester, {
    required AnnouncementModel trip,
    List<BidModel>? bids = const [],
    bool isOwner = true,
    bool group = false,
    bool stripeReady = false,
    Locale locale = const Locale('fr'),
    double textScale = 1,
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
        TripAudienceModel(uniqueViewerCount: 12, shareViewCount: 0),
      ),
    );
    when(() => audience.load(any())).thenAnswer((_) async {});
    final depart = _MockDepart();
    whenListen(
      depart,
      const Stream<TripDepartState>.empty(),
      initialState: const TripDepartState(),
    );
    final groupCubit = MockTripGroupCubit();
    whenListen(
      groupCubit,
      const Stream<TripGroupState>.empty(),
      initialState: group
          ? TripGroupState(status: TripGroupStatus.loaded, info: _legs)
          : const TripGroupState(),
    );

    final pushed = <String>[];
    Widget stub(BuildContext context, GoRouterState state) {
      pushed.add(state.uri.toString());
      return Scaffold(
        body: TextButton(
          onPressed: () => context.pop(),
          child: const Text('back'),
        ),
      );
    }

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => MultiBlocProvider(
            providers: [
              BlocProvider<AnnouncementBloc>.value(value: h.annBloc),
              BlocProvider<BidBloc>.value(value: h.screenBids),
              BlocProvider<TripAudienceCubit>.value(value: audience),
              BlocProvider<TripGroupCubit>.value(value: groupCubit),
              BlocProvider<TripDepartCubit>.value(value: depart),
              BlocProvider<StripeAccountBloc>.value(
                value: stripeReady
                    ? stubStripeAccountBloc(
                        state: const StripeAccountReady(
                          ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
                        ),
                      )
                    : stubStripeAccountBloc(),
              ),
            ],
            child: Scaffold(
              body: TripBidAnswerScope(
                tripId: trip.id,
                bidBloc: h.answerBids,
                acceptanceBloc: h.acceptance,
                child: TripOwnerBody(trip: trip, isOwner: isOwner),
              ),
            ),
          ),
        ),
        GoRoute(path: '/bids/:bidId', builder: stub),
        GoRoute(path: '/announcements/:id/bids', builder: stub),
        GoRoute(path: '/announcements/:id/trip', builder: stub),
        GoRoute(path: '/support', builder: stub),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        routerConfig: router,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    return pushed;
  }

  /// Laisse passer l'ouverture ou la fermeture d'un sheet.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  bool shown(Finder f) => f.evaluate().isNotEmpty;
  Finder key(String k) => find.byKey(Key(k));
  Finder todoSection() => find.text('À traiter');
  Finder activitySection() => find.text('Activité du trajet');
  Finder directCard() => key('trip-direct-request-card');
  String cellValue(WidgetTester tester, String activity) =>
      tester.widget<Text>(key('trip-activity-$activity-value')).data!;

  // ── Table statut × situation ─────────────────────────────────────────────
  // Attendus écrits à la main, ligne par ligne (cible du 31/10, inventaire).

  group('carte de statut (brouillon, complet, arrivé, annulé, retiré)', () {
    const expected = {
      'DRAFT': 'draft',
      'ACTIVE': null,
      'FULL': 'full',
      // En cours ou terminé : le badge du billet suffit.
      'IN_PROGRESS': null,
      'COMPLETED': null,
      'CANCELLED': 'cancelled',
      'REMOVED_BY_ADMIN': 'removedByAdmin',
      'SOMETHING_NEW': null,
    };
    for (final MapEntry(key: status, value: kind) in expected.entries) {
      testWidgets('$status : ${kind ?? 'aucune'}', (tester) async {
        await pump(tester, trip: _trip(status: status));
        expect(key('trip-billet-card'), findsOneWidget);
        for (final k in const [
          'draft',
          'full',
          'arrived',
          'cancelled',
          'removedByAdmin',
        ]) {
          expect(
            key('trip-status-card-$k'),
            k == kind ? findsOneWidget : findsNothing,
            reason: '$status / $k',
          );
        }
      });
    }
  });

  group('carte de statut selon les colis', () {
    testWidgets('IN_PROGRESS, colis arrivés : les colis attendent', (
      tester,
    ) async {
      await pump(
        tester,
        trip: _trip(status: 'IN_PROGRESS', summary: _summary),
        bids: _parcels(2, 'ARRIVED'),
      );
      expect(key('trip-status-card-arrived'), findsOneWidget);
      expect(
        find.text('Trajet arrivé : vos colis attendent leurs destinataires.'),
        findsOneWidget,
      );
    });

    testWidgets('IN_PROGRESS, colis en transit ou en chargement : aucune', (
      tester,
    ) async {
      await pump(
        tester,
        trip: _trip(status: 'IN_PROGRESS', summary: _summary),
        bids: _parcels(1),
      );
      expect(find.byType(DonyStatusBanner), findsNothing);

      await pump(
        tester,
        trip: _trip(status: 'IN_PROGRESS', summary: _summary),
        bids: null,
      );
      expect(find.byType(DonyStatusBanner), findsNothing);
    });

    // Même règle que l'entrée « Reporter » du menu ⋮.
    testWidgets('FULL reportable : la carte propose le report', (tester) async {
      await pump(
        tester,
        trip: _trip(status: 'FULL'),
        bids: [_bid('b1', 'ACCEPTED')],
      );
      expect(find.textContaining('Vous pouvez reporter'), findsOneWidget);
      expect(key('trip-status-card-support'), findsOneWidget);
    });

    testWidgets('FULL déjà reporté deux fois : pas de report promis', (
      tester,
    ) async {
      await pump(
        tester,
        trip: _trip(status: 'FULL', remainingReschedules: 0),
        bids: [_bid('b1', 'ACCEPTED')],
      );
      expect(key('trip-status-card-full'), findsOneWidget);
      expect(find.textContaining('reporter'), findsNothing);
    });

    testWidgets('FULL avec un colis en transit : pas de report promis', (
      tester,
    ) async {
      await pump(
        tester,
        trip: _trip(status: 'FULL', summary: _summary),
        bids: _parcels(1),
      );
      expect(find.textContaining('reporter'), findsNothing);
    });
  });

  group('sans demande ni colis', () {
    // (activité, case Demandes, case Colis, case Gain, audience, Affiche)
    const expected = {
      'DRAFT': (false, false, false, false, false, false),
      'ACTIVE': (true, true, true, true, true, true),
      'FULL': (true, true, true, true, true, false),
      // Parti sans demande : la case Demandes n'a rien à promettre.
      'IN_PROGRESS': (true, false, true, true, true, false),
      'COMPLETED': (true, false, true, true, true, false),
      'CANCELLED': (false, false, false, false, false, false),
      'REMOVED_BY_ADMIN': (false, false, false, false, false, false),
      'SOMETHING_NEW': (true, false, true, true, true, false),
    };
    for (final MapEntry(key: status, value: e) in expected.entries) {
      testWidgets(status, (tester) async {
        await pump(tester, trip: _trip(status: status));
        expect(shown(activitySection()), e.$1, reason: 'section');
        expect(shown(key('trip-activity-row')), e.$1, reason: 'compteurs');
        expect(shown(key('trip-activity-requests')), e.$2, reason: 'demandes');
        expect(shown(key('trip-activity-parcels')), e.$3, reason: 'colis');
        expect(shown(key('trip-activity-gain')), e.$4, reason: 'gain');
        expect(shown(key('trip-audience-card')), e.$5, reason: 'audience');
        expect(shown(key('trip-tile-poster')), e.$6, reason: 'affiche');
        // Rien à traiter.
        expect(todoSection(), findsNothing);
        expect(directCard(), findsNothing);
        expect(key('trip-todo-rows'), findsNothing);
        // Plus aucune carte directe dans le corps.
        expect(key('trip-requests-card'), findsNothing);
        expect(key('trip-summary-card'), findsNothing);
        expect(key('trip-legs-card'), findsNothing);
        expect(find.byType(TripParcelRow), findsNothing);
        // Lieux et paiements renseignés : leurs tuiles, à tous les statuts.
        expect(key('trip-tile-itinerary'), findsOneWidget);
        expect(key('trip-tile-payments'), findsOneWidget);
        expect(find.text('Votre trajet'), findsOneWidget);
      });
    }

    testWidgets('ACTIVE : « 0 demande », sans pastille ; colis à 0 ; gain '
        'inconnu', (tester) async {
      await pump(tester, trip: _trip());
      expect(cellValue(tester, 'requests'), '0');
      expect(key('trip-activity-requests-dot'), findsNothing);
      expect(cellValue(tester, 'parcels'), '0');
      expect(cellValue(tester, 'gain'), '-');
      expect(find.text('12 personnes ont vu votre trajet'), findsOneWidget);
    });
  });

  group('une demande à traiter', () {
    // (« À traiter » et carte directe, case Demandes)
    const expected = {
      'DRAFT': (false, false),
      'ACTIVE': (true, true),
      'FULL': (true, true),
      'IN_PROGRESS': (true, true),
      // Le back refuse toute acceptation sur un trajet terminé : ni carte
      // ni case qui promettrait une réponse.
      'COMPLETED': (false, false),
      'CANCELLED': (false, false),
      'REMOVED_BY_ADMIN': (false, false),
      'SOMETHING_NEW': (false, false),
    };
    for (final MapEntry(key: status, value: e) in expected.entries) {
      testWidgets(status, (tester) async {
        await pump(
          tester,
          trip: _trip(status: status),
          bids: _requests(1),
        );
        expect(shown(todoSection()), e.$1, reason: 'section');
        expect(shown(directCard()), e.$1, reason: 'carte directe');
        expect(shown(key('trip-activity-requests')), e.$2, reason: 'case');
        // La demande n'est plus une tuile de grille.
        expect(key('trip_owner-todo-requests'), findsNothing);
      });
    }
  });

  group('0, 1, 3, 8 demandes (trajet publié)', () {
    // (carte directe, « Voir les N demandes », valeur de la case, pastille)
    const expected = {
      0: (false, false, '0', false),
      1: (true, false, '1', true),
      3: (true, true, '3', true),
      8: (true, true, '8', true),
    };
    for (final MapEntry(key: n, value: e) in expected.entries) {
      testWidgets('$n demande(s)', (tester) async {
        await pump(
          tester,
          trip: _trip(),
          bids: [..._requests(n), _bid('a1', 'ACCEPTED')],
        );
        expect(shown(directCard()), e.$1, reason: 'carte');
        if (e.$1) {
          expect(find.text('Demande 1 sur $n'), findsOneWidget);
          expect(key('trip-direct-request-r1'), findsOneWidget);
        }
        expect(shown(key('trip-direct-request-see-all')), e.$2, reason: 'lien');
        if (e.$2) expect(find.text('Voir les $n demandes'), findsOneWidget);
        expect(cellValue(tester, 'requests'), e.$3);
        expect(shown(key('trip-activity-requests-dot')), e.$4, reason: 'dot');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('liste des colis en chargement : ni carte ni « À traiter », '
        'case Demandes à « - »', (tester) async {
      await pump(tester, trip: _trip(), bids: null);
      expect(directCard(), findsNothing);
      expect(todoSection(), findsNothing);
      expect(cellValue(tester, 'requests'), '-');
      expect(find.text('0'), findsNothing);
    });
  });

  group('0, 2, 10 colis embarqués (trajet en cours)', () {
    for (final n in const [0, 2, 10]) {
      testWidgets('$n colis : la case Colis compte, aucune ligne de colis '
          'dans le corps', (tester) async {
        await pump(
          tester,
          trip: _trip(status: 'IN_PROGRESS', summary: n > 0 ? _summary : null),
          bids: _parcels(n),
        );
        expect(cellValue(tester, 'parcels'), '$n');
        if (n > 0) expect(find.text('$n en route'), findsOneWidget);
        expect(find.byType(TripParcelRow), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('colis en route (résumé servi par le détail)', () {
    const withActivity = {
      'ACTIVE',
      'FULL',
      'IN_PROGRESS',
      'COMPLETED',
      'SOMETHING_NEW',
    };
    for (final status in _statuses) {
      final has = withActivity.contains(status);
      testWidgets(
        '$status : case Gain ${has ? 'avec le montant' : 'absente'}',
        (tester) async {
          await pump(
            tester,
            trip: _trip(status: status, summary: _summary),
            bids: _parcels(1),
          );
          expect(shown(key('trip-activity-gain')), has);
          if (has) expect(cellValue(tester, 'gain'), contains('21'));
          // « Arrivé à destination » est au pied (écran), jamais dans le corps.
          expect(find.text('Arrivé à destination'), findsNothing);
        },
      );
    }
  });

  group('arrivée : instructions ou colis arrivé → tuile « Arrivée »', () {
    for (final status in _statuses) {
      testWidgets(status, (tester) async {
        await pump(
          tester,
          trip: _trip(status: status, instructions: 'Gare routière'),
          bids: _parcels(1, 'ARRIVED'),
        );
        expect(key('trip-tile-arrival'), findsOneWidget);
        // L'encart n'est que dans le sheet.
        expect(key('arrival-instructions-card'), findsNothing);
        expect(find.text('Gare routière'), findsNothing);
      });
    }

    testWidgets('ni instructions ni colis arrivé : pas de tuile', (
      tester,
    ) async {
      await pump(tester, trip: _trip(), bids: _parcels(1));
      expect(key('trip-tile-arrival'), findsNothing);
    });
  });

  group('voyage à étapes (FLUTTER-4D) : dans le sheet Itinéraire', () {
    for (final status in _statuses) {
      testWidgets('$status : pas de carte des étapes dans le corps', (
        tester,
      ) async {
        await pump(
          tester,
          trip: _trip(status: status, groupId: 'g'),
          group: true,
        );
        expect(key('trip-legs-card'), findsNothing);
        expect(key('trip-tile-itinerary'), findsOneWidget);
      });
    }

    testWidgets('tuile « Itinéraire et lieux » : les étapes, une étape '
        'ouvre son trajet', (tester) async {
      final pushed = await pump(tester, trip: _trip(groupId: 'g'), group: true);
      await tester.tap(key('trip-tile-itinerary'));
      await settle(tester);
      expect(key('trip-legs-card'), findsOneWidget);
      await tester.tap(key('trip-leg-open-leg-2'));
      await settle(tester);
      expect(pushed, ['/announcements/leg-2/trip']);
    });
  });

  group('espèces seules, compte de paiement prêt', () {
    const expected = {
      'DRAFT': true,
      'ACTIVE': true,
      'FULL': true,
      'IN_PROGRESS': false,
      'COMPLETED': false,
      'CANCELLED': false,
      'REMOVED_BY_ADMIN': false,
      'SOMETHING_NEW': false,
    };
    for (final MapEntry(key: status, value: card) in expected.entries) {
      testWidgets('$status : ligne carte ${card ? 'présente' : 'absente'}', (
        tester,
      ) async {
        await pump(
          tester,
          trip: _trip(status: status, methods: const {BidPaymentMethod.cash}),
          stripeReady: true,
        );
        expect(shown(key('trip_owner-todo-card')), card);
        expect(shown(key('trip-todo-rows')), card);
        expect(shown(todoSection()), card);
        // L'ancien encart du corps n'existe plus (pas de doublon de clés).
        expect(key('enable-card-on-trip-cta'), findsNothing);
        expect(key('activate-card-payments-cta'), findsNothing);
      });
    }

    // Le back refuse la modification dès qu'un colis est accepté (409
    // `modification-impossible`) : la ligne mènerait à un refus certain.
    for (final status in const ['ACTIVE', 'FULL']) {
      testWidgets('$status avec un colis accepté : ligne carte absente, '
          'carte directe seule', (tester) async {
        await pump(
          tester,
          trip: _trip(status: status, methods: const {BidPaymentMethod.cash}),
          bids: [_bid('r1', 'PENDING'), _bid('b2', 'ACCEPTED')],
          stripeReady: true,
        );
        expect(key('trip_owner-todo-card'), findsNothing);
        expect(directCard(), findsOneWidget);
      });
    }

    testWidgets('ACTIVE avec seulement des demandes : carte directe puis '
        'ligne carte', (tester) async {
      await pump(
        tester,
        trip: _trip(methods: const {BidPaymentMethod.cash}),
        bids: _requests(1),
        stripeReady: true,
      );
      expect(directCard(), findsOneWidget);
      expect(key('trip_owner-todo-card'), findsOneWidget);
      expect(
        tester.getTopLeft(directCard()).dy,
        lessThan(tester.getTopLeft(key('trip-todo-rows')).dy),
      );
    });
  });

  testWidgets('« Je pars » : ligne quand le détail sert trackingActive', (
    tester,
  ) async {
    await pump(
      tester,
      trip: _trip(summary: _summary, trackingActive: true),
      bids: _parcels(1, 'HANDED_OVER'),
    );
    expect(key('trip_owner-todo-depart'), findsOneWidget);
    expect(todoSection(), findsOneWidget);

    // Contrat ancien (détail sans trackingActive) : pas de ligne, rien ne
    // casse.
    await pump(
      tester,
      trip: _trip(summary: _summary),
      bids: _parcels(1, 'HANDED_OVER'),
    );
    expect(key('trip_owner-todo-depart'), findsNothing);
    expect(todoSection(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('REMOVED_BY_ADMIN avec une demande et des colis : carte et '
      'support seuls, ni « À traiter » ni activité', (tester) async {
    await pump(
      tester,
      trip: _trip(status: 'REMOVED_BY_ADMIN', summary: _summary),
      bids: [_bid('r1', 'PENDING'), _bid('p1', 'IN_TRANSIT')],
    );
    expect(key('trip-status-card-removedByAdmin'), findsOneWidget);
    expect(key('trip-status-card-support'), findsOneWidget);
    expect(todoSection(), findsNothing);
    expect(activitySection(), findsNothing);
    expect(key('trip-audience-card'), findsNothing);
  });

  testWidgets('ordre des sections (tableau de bord)', (tester) async {
    await pump(
      tester,
      trip: _trip(status: 'FULL', summary: _summary, trackingActive: true),
      bids: [_bid('r1', 'PENDING'), _bid('p1', 'HANDED_OVER')],
    );
    final order = [
      key('trip-billet-card'),
      key('trip-status-card-full'),
      todoSection(),
      directCard(),
      key('trip-todo-rows'),
      activitySection(),
      key('trip-activity-row'),
      key('trip-audience-card'),
      find.text('Votre trajet'),
    ];
    final ys = [for (final f in order) tester.getTopLeft(f.first).dy];
    for (var i = 1; i < ys.length; i++) {
      expect(ys[i], greaterThan(ys[i - 1]), reason: '${order[i]}');
    }
  });

  testWidgets('visiteur (propriété pas tranchée) : billet et statut seuls', (
    tester,
  ) async {
    await pump(
      tester,
      trip: _trip(status: 'FULL', summary: _summary),
      bids: _requests(1),
      isOwner: false,
    );
    expect(key('trip-billet-card'), findsOneWidget);
    expect(key('trip-status-card-full'), findsOneWidget);
    expect(todoSection(), findsNothing);
    expect(directCard(), findsNothing);
    expect(activitySection(), findsNothing);
    expect(key('trip-audience-card'), findsNothing);
    expect(find.text('Votre trajet'), findsNothing);
  });

  testWidgets('mesure de « À traiter » : carte directe et ligne carte, '
      'role trip_owner, une fois', (tester) async {
    await pump(
      tester,
      trip: _trip(methods: const {BidPaymentMethod.cash}),
      bids: _requests(1),
      stripeReady: true,
    );
    await tester.pump();
    // Une relecture identique ne remesure rien.
    h.screenStates.add(BidListLoaded(_requests(1)));
    await tester.pump();
    await tester.pump();
    verify(
      () => h.backend.capture(AnalyticsEvents.bidDetailTodoTileShown, {
        'tile': 'requests',
        'role': 'trip_owner',
        'status': 'ACTIVE',
      }),
    ).called(1);
    verify(
      () => h.backend.capture(AnalyticsEvents.bidDetailTodoTileShown, {
        'tile': 'card',
        'role': 'trip_owner',
        'status': 'ACTIVE',
      }),
    ).called(1);
  });

  group('répondre depuis l\'écran', () {
    testWidgets('accepter : la carte passe à la suivante, la case Demandes '
        'baisse, l\'écran est relu en silence', (tester) async {
      await pump(tester, trip: _trip(), bids: _requests(3));
      expect(find.text('Demande 1 sur 3'), findsOneWidget);
      expect(cellValue(tester, 'requests'), '3');

      await tester.tap(key('trip-request-accept-r1'));
      await tester.pump();
      await tester.pump();
      expect(h.answerEvents.single, isA<BidAcceptRequested>());
      // Jamais sur le bloc des colis de l'écran.
      expect(h.screenEvents, isEmpty);

      h.answerStates.add(BidAccepted(_requests(1).first));
      await tester.pump();
      await tester.pump();
      expect(find.text('Demande 1 sur 2'), findsOneWidget);
      expect(key('trip-direct-request-r2'), findsOneWidget);
      expect(cellValue(tester, 'requests'), '2');
      expect((h.screenEvents.single as BidListRequested).silent, isTrue);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('dernière demande acceptée : « À traiter » disparaît sans '
        'attendre la relecture', (tester) async {
      await pump(tester, trip: _trip(), bids: _requests(1));
      await tester.tap(key('trip-request-accept-r1'));
      await tester.pump();
      await tester.pump();
      h.answerStates.add(BidAccepted(_requests(1).first));
      await tester.pump();
      await tester.pump();
      expect(directCard(), findsNothing);
      expect(todoSection(), findsNothing);
      expect(cellValue(tester, 'requests'), '0');
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('accepter depuis le sheet des demandes : la carte du corps '
        'suit', (tester) async {
      await pump(tester, trip: _trip(), bids: _requests(3));
      await tester.tap(key('trip-direct-request-see-all'));
      await settle(tester);
      final inSheet = find.descendant(
        of: key('trip-activity-requests-content'),
        matching: key('trip-request-accept-r2'),
      );
      await tester.tap(inSheet);
      await tester.pump();
      await tester.pump();
      h.answerStates.add(BidAccepted(_requests(2).last));
      await tester.pump();
      await tester.pump();
      expect(key('trip-activity-request-r2'), findsNothing);
      // Sous le sheet, la carte montre toujours r1, sur 2.
      expect(find.text('Demande 1 sur 2'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('sheets ouverts depuis le corps', () {
    testWidgets('« Voir les N demandes » : sheet des demandes', (tester) async {
      await pump(tester, trip: _trip(), bids: _requests(3));
      await tester.tap(key('trip-direct-request-see-all'));
      await settle(tester);
      expect(key('trip-activity-requests-content'), findsOneWidget);
      for (final id in ['r1', 'r2', 'r3']) {
        expect(key('trip-activity-request-$id'), findsOneWidget);
      }
    });

    for (final (activity, content) in const [
      ('requests', 'trip-activity-requests-content'),
      ('parcels', 'trip-activity-parcels-content'),
      ('gain', 'trip-activity-gain-content'),
    ]) {
      testWidgets('case $activity : son sheet, une seule fois au double '
          'appui', (tester) async {
        await pump(
          tester,
          trip: _trip(summary: _summary),
          bids: [..._requests(1), ..._parcels(2, 'HANDED_OVER')],
        );
        await tester.tap(key('trip-activity-$activity'));
        await tester.tap(key('trip-activity-$activity'), warnIfMissed: false);
        await settle(tester);
        expect(key(content), findsOneWidget);
        verify(
          () => h.backend.capture(AnalyticsEvents.bidDetailTileOpened, {
            'tile': activity,
            'role': 'trip_owner',
            'source': 'tile',
          }),
        ).called(1);
      });
    }

    testWidgets('case Colis : tous les colis, une ligne vers la fiche', (
      tester,
    ) async {
      final pushed = await pump(
        tester,
        trip: _trip(status: 'IN_PROGRESS', summary: _summary),
        bids: _parcels(10),
        size: const Size(400, 2400),
      );
      await tester.tap(key('trip-activity-parcels'));
      await settle(tester);
      expect(find.byType(TripParcelRow), findsNWidgets(10));
      await tester.tap(key('trip-activity-parcel-p3'));
      await settle(tester);
      expect(pushed, ['/bids/p3']);
    });

    testWidgets('ligne « Ajouter la carte » : son sheet', (tester) async {
      await pump(
        tester,
        trip: _trip(methods: const {BidPaymentMethod.cash}),
        stripeReady: true,
      );
      await tester.tap(key('trip_owner-todo-card'));
      await settle(tester);
      expect(key('trip-todo-card-content'), findsOneWidget);
    });

    testWidgets('ligne « Je pars » : son sheet', (tester) async {
      await pump(
        tester,
        trip: _trip(summary: _summary, trackingActive: true),
        bids: _parcels(1, 'HANDED_OVER'),
      );
      await tester.tap(key('trip_owner-todo-depart'));
      await settle(tester);
      expect(key('trip-todo-depart-content'), findsOneWidget);
    });

    testWidgets('tuile « Itinéraire et lieux » : sheet de lecture', (
      tester,
    ) async {
      await pump(tester, trip: _trip());
      await tester.tap(key('trip-tile-itinerary'));
      await settle(tester);
      expect(key('trip-tile-itinerary-content'), findsOneWidget);
      expect(find.text('12 rue de Paris'), findsOneWidget);
    });
  });

  testWidgets('anglais : titres des sections et carte directe', (tester) async {
    await pump(
      tester,
      trip: _trip(),
      bids: _requests(3),
      locale: const Locale('en'),
    );
    expect(find.text('To do'), findsOneWidget);
    expect(find.text('Request 1 of 3'), findsOneWidget);
    expect(find.text('See all 3 requests'), findsOneWidget);
    expect(find.text('Trip activity'), findsOneWidget);
    expect(find.text('to review'), findsOneWidget);
    expect(find.text('Your trip'), findsOneWidget);
  });

  group('360 dp × 1,3, vraies polices', () {
    for (final locale in const [Locale('fr'), Locale('en')]) {
      testWidgets('${locale.languageCode} : 8 demandes, 10 colis, espèces, '
          'instructions, étapes : aucun débordement', (tester) async {
        await pump(
          tester,
          trip: _trip(
            status: 'FULL',
            summary: _summary,
            instructions: 'Gare',
            methods: const {BidPaymentMethod.cash},
            trackingActive: true,
            groupId: 'g',
          ),
          bids: [..._requests(8), ..._parcels(10, 'HANDED_OVER')],
          group: true,
          stripeReady: true,
          locale: locale,
          textScale: 1.3,
          size: const Size(360, 3200),
        );
        expect(tester.takeException(), isNull);
        expect(directCard(), findsOneWidget);
        expect(key('trip-activity-row'), findsOneWidget);
      });
    }
  });
}
