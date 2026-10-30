// Corps assemblé de l'écran du trajet vu par son voyageur (TripOwnerBody) :
// table statut du trajet × situations (demandes, colis en route, arrivée,
// voyage à étapes, espèces seules, instructions) → sections présentes ou
// absentes, écrite à la main (pas recalculée par les fonctions de
// production) ; ordre des sections ; visiteur ; mesure des tuiles « À
// traiter » ; tuiles qui ouvrent leur sheet.
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/trip_audience_cubit.dart';
import 'package:dony/features/matching/bloc/trip_group_cubit.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/trip_legs_info.dart';
import 'package:dony/features/matching/data/models/trip_parcels_summary.dart';
import 'package:dony/features/matching/presentation/widgets/trip_audience_section.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_owner_body.dart';
import 'package:dony/features/matching/presentation/widgets/trip_parcels_section.dart'
    show TripParcelsSection;
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/tracking/bloc/trip_depart_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/mock_analytics_backend.dart';
import '../../../../../helpers/stripe_account_test_doubles.dart';
import 'trip_card_harness.dart'
    show MockAnnouncementBloc, MockBidBloc, loadAppFonts;

class _MockAudience extends MockCubit<TripAudienceState>
    implements TripAudienceCubit {}

class _MockGroup extends MockCubit<TripGroupState> implements TripGroupCubit {}

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
  senderName: 'Awa Diop',
  weightKg: 3,
  status: status,
  recipientName: 'Fatou',
  recipientPhone: '+221770000000',
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

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
  late MockAnalyticsBackend backend;
  late List<String> opened;

  setUpAll(() async {
    registerFallbackValue(AnnouncementDetailRequested('fallback'));
    registerFallbackValue(BidListRequested('fallback'));
    await initializeDateFormatting('fr');
    await loadAppFonts();
  });

  setUp(() async {
    backend = MockAnalyticsBackend();
    final analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
    await getIt.reset();
    getIt.registerSingleton<AnalyticsService>(analytics);
    DonySnackbar.clearDedup();
    opened = [];
  });

  tearDown(() async => getIt.reset());

  /// Monte le corps sous les blocs de la route du trajet.
  Future<void> pump(
    WidgetTester tester, {
    required AnnouncementModel trip,
    List<BidModel>? bids = const [],
    bool isOwner = true,
    bool group = false,
    bool stripeReady = false,
  }) async {
    tester.view.physicalSize = const Size(400, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final ann = MockAnnouncementBloc();
    whenListen(
      ann,
      const Stream<AnnouncementState>.empty(),
      initialState: AnnouncementDetailLoaded(trip),
    );
    final bidBloc = MockBidBloc();
    whenListen(
      bidBloc,
      const Stream<BidState>.empty(),
      initialState: bids == null ? BidLoading() : BidListLoaded(bids),
    );
    final audience = _MockAudience();
    when(() => audience.state).thenReturn(const TripAudienceState.hidden());
    when(() => audience.load(any())).thenAnswer((_) async {});
    final depart = _MockDepart();
    whenListen(
      depart,
      const Stream<TripDepartState>.empty(),
      initialState: const TripDepartState(),
    );
    final groupCubit = _MockGroup();
    whenListen(
      groupCubit,
      const Stream<TripGroupState>.empty(),
      initialState: group
          ? TripGroupState(status: TripGroupStatus.loaded, info: _legs)
          : const TripGroupState(),
    );

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => MultiBlocProvider(
            providers: [
              BlocProvider<AnnouncementBloc>.value(value: ann),
              BlocProvider<BidBloc>.value(value: bidBloc),
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
              body: TripOwnerBody(trip: trip, isOwner: isOwner),
            ),
          ),
        ),
        GoRoute(
          path: '/demandes',
          builder: (context, state) {
            opened.add(state.uri.toString());
            return const Scaffold(body: Text('demandes'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  bool shown(Finder f) => f.evaluate().isNotEmpty;
  Finder key(String k) => find.byKey(Key(k));

  // ── Table statut × situation ─────────────────────────────────────────────
  // Attendus écrits à la main, ligne par ligne (cible validée et inventaire).

  group('carte de statut', () {
    const expected = {
      'DRAFT': 'draft',
      'ACTIVE': null,
      'FULL': 'full',
      'IN_PROGRESS': 'inProgress',
      'COMPLETED': 'completed',
      'CANCELLED': 'cancelled',
      'REMOVED_BY_ADMIN': 'removedByAdmin',
      'SOMETHING_NEW': null,
    };
    for (final MapEntry(key: status, value: kind) in expected.entries) {
      testWidgets('$status : ${kind ?? 'aucune'}', (tester) async {
        await pump(tester, trip: _trip(status: status));
        expect(key('trip-billet-card'), findsOneWidget);
        for (final k in expected.values.whereType<String>()) {
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
        bids: [_bid('b1', 'ARRIVED'), _bid('b2', 'ARRIVED')],
      );
      expect(key('trip-status-card-arrived'), findsOneWidget);
      expect(key('trip-status-card-inProgress'), findsNothing);
      expect(
        find.text('Trajet arrivé : vos colis attendent leurs destinataires.'),
        findsOneWidget,
      );
    });

    testWidgets('IN_PROGRESS, colis en transit : en cours', (tester) async {
      await pump(
        tester,
        trip: _trip(status: 'IN_PROGRESS', summary: _summary),
        bids: [_bid('b1', 'IN_TRANSIT')],
      );
      expect(key('trip-status-card-inProgress'), findsOneWidget);
      expect(key('trip-status-card-arrived'), findsNothing);
      expect(
        find.text('Trajet en cours : vos colis voyagent avec vous.'),
        findsOneWidget,
      );
    });

    testWidgets('IN_PROGRESS, colis en chargement : en cours', (tester) async {
      await pump(
        tester,
        trip: _trip(status: 'IN_PROGRESS', summary: _summary),
        bids: null,
      );
      expect(key('trip-status-card-inProgress'), findsOneWidget);
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
      expect(key('trip-status-card-support'), findsOneWidget);
    });

    testWidgets('FULL avec un colis en transit : pas de report promis', (
      tester,
    ) async {
      await pump(
        tester,
        trip: _trip(status: 'FULL', summary: _summary),
        bids: [_bid('b1', 'IN_TRANSIT')],
      );
      expect(find.textContaining('reporter'), findsNothing);
    });

    testWidgets('REMOVED_BY_ADMIN : lien vers le support', (tester) async {
      await pump(tester, trip: _trip(status: 'REMOVED_BY_ADMIN'));
      expect(key('trip-status-card-support'), findsOneWidget);
      expect(find.text('Contacter le support'), findsOneWidget);
    });
  });

  group('sans demande ni colis', () {
    // (audience, Demandes, Colis, tuile Affiche)
    const expected = {
      'DRAFT': (false, false, false, false),
      'ACTIVE': (true, true, true, true),
      'FULL': (true, true, true, false),
      'IN_PROGRESS': (true, false, true, false),
      'COMPLETED': (true, false, true, false),
      'CANCELLED': (false, false, true, false),
      'REMOVED_BY_ADMIN': (false, false, false, false),
      'SOMETHING_NEW': (true, false, true, false),
    };
    for (final MapEntry(key: status, value: e) in expected.entries) {
      testWidgets(status, (tester) async {
        await pump(tester, trip: _trip(status: status));
        expect(shown(find.byType(TripAudienceSection)), e.$1, reason: 'aud');
        expect(shown(key('trip-requests-card')), e.$2, reason: 'demandes');
        expect(shown(find.byType(TripParcelsSection)), e.$3, reason: 'colis');
        expect(shown(key('trip-tile-poster')), e.$4, reason: 'affiche');
        // Rien à traiter, aucun gain.
        expect(find.text('À traiter'), findsNothing);
        expect(key('trip-summary-card'), findsNothing);
        // Lieux et paiements renseignés : leurs tuiles, à tous les statuts.
        expect(key('trip-tile-itinerary'), findsOneWidget);
        expect(key('trip-tile-payments'), findsOneWidget);
        expect(find.text('Votre trajet'), findsOneWidget);
      });
    }
  });

  group('une demande à traiter', () {
    // (tuile « À traiter » requests, carte Demandes)
    const expected = {
      'DRAFT': (false, false),
      'ACTIVE': (true, true),
      'FULL': (true, true),
      'IN_PROGRESS': (true, true),
      // Le back refuse toute acceptation sur un trajet terminé : ni tuile ni
      // carte qui promettrait une réponse.
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
          bids: [_bid('b1', 'PENDING')],
        );
        expect(shown(key('trip_owner-todo-requests')), e.$1, reason: 'tuile');
        expect(shown(find.text('À traiter')), e.$1, reason: 'section');
        expect(shown(key('trip-requests-card')), e.$2, reason: 'carte');
      });
    }
  });

  group('colis en route (résumé servi par le détail)', () {
    for (final status in _statuses) {
      testWidgets('$status : carte Gain', (tester) async {
        await pump(
          tester,
          trip: _trip(status: status, summary: _summary),
          bids: [_bid('b1', 'IN_TRANSIT')],
        );
        expect(key('trip-summary-card'), findsOneWidget);
        // « Arrivé à destination » est au pied (écran), jamais dans le corps.
        expect(find.text('Arrivé à destination'), findsNothing);
      });
    }
  });

  group('arrivée : instructions ou colis arrivé → tuile « Arrivée »', () {
    for (final status in _statuses) {
      testWidgets(status, (tester) async {
        await pump(
          tester,
          trip: _trip(status: status, instructions: 'Gare routière'),
          bids: [_bid('b1', 'ARRIVED')],
        );
        expect(key('trip-tile-arrival'), findsOneWidget);
        // L'encart a quitté le corps : seulement dans le sheet.
        expect(key('arrival-instructions-card'), findsNothing);
        expect(find.text('Gare routière'), findsNothing);
      });
    }

    testWidgets('ni instructions ni colis arrivé : pas de tuile', (
      tester,
    ) async {
      await pump(tester, trip: _trip(), bids: [_bid('b1', 'IN_TRANSIT')]);
      expect(key('trip-tile-arrival'), findsNothing);
    });
  });

  group('voyage à étapes (FLUTTER-4D)', () {
    for (final status in _statuses) {
      testWidgets('$status : carte des étapes', (tester) async {
        await pump(tester, trip: _trip(status: status), group: true);
        expect(key('trip-legs-card'), findsOneWidget);
      });
    }

    testWidgets('trajet isolé : pas de carte', (tester) async {
      await pump(tester, trip: _trip());
      expect(key('trip-legs-card'), findsNothing);
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
      testWidgets('$status : tuile carte ${card ? 'présente' : 'absente'}', (
        tester,
      ) async {
        await pump(
          tester,
          trip: _trip(status: status, methods: const {BidPaymentMethod.cash}),
          stripeReady: true,
        );
        expect(shown(key('trip_owner-todo-card')), card);
        // L'ancien encart du corps n'existe plus (pas de doublon de clés).
        expect(key('enable-card-on-trip-cta'), findsNothing);
        expect(key('activate-card-payments-cta'), findsNothing);
      });
    }

    // Le back refuse la modification dès qu'un colis est accepté (409
    // `modification-impossible`) : la tuile mènerait à un refus certain.
    for (final status in const ['ACTIVE', 'FULL']) {
      testWidgets('$status avec un colis accepté : tuile carte absente', (
        tester,
      ) async {
        await pump(
          tester,
          trip: _trip(status: status, methods: const {BidPaymentMethod.cash}),
          bids: [_bid('b1', 'PENDING'), _bid('b2', 'ACCEPTED')],
          stripeReady: true,
        );
        expect(key('trip_owner-todo-card'), findsNothing);
        expect(key('trip_owner-todo-requests'), findsOneWidget);
      });
    }

    testWidgets('ACTIVE avec seulement des demandes : tuile carte', (
      tester,
    ) async {
      await pump(
        tester,
        trip: _trip(methods: const {BidPaymentMethod.cash}),
        bids: [_bid('b1', 'PENDING')],
        stripeReady: true,
      );
      expect(key('trip_owner-todo-card'), findsOneWidget);
    });
  });

  testWidgets('« Je pars » : tuile quand le détail sert trackingActive', (
    tester,
  ) async {
    await pump(
      tester,
      trip: _trip(summary: _summary, trackingActive: true),
      bids: [_bid('b1', 'HANDED_OVER')],
    );
    expect(key('trip_owner-todo-depart'), findsOneWidget);

    // Contrat ancien (détail sans trackingActive) : pas de tuile, rien ne
    // casse.
    await pump(
      tester,
      trip: _trip(summary: _summary),
      bids: [_bid('b1', 'HANDED_OVER')],
    );
    expect(key('trip_owner-todo-depart'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ordre des sections (cible validée)', (tester) async {
    await pump(
      tester,
      trip: _trip(status: 'FULL', summary: _summary, groupId: 'g'),
      bids: [_bid('b1', 'PENDING'), _bid('b2', 'IN_TRANSIT')],
      group: true,
    );
    final order = [
      key('trip-billet-card'),
      key('trip-status-card-full'),
      find.text('À traiter'),
      key('trip-legs-card'),
      key('trip-requests-card'),
      find.byType(TripParcelsSection),
      key('trip-summary-card'),
      find.text('Votre trajet'),
    ];
    final ys = [for (final f in order) tester.getTopLeft(f.first).dy];
    for (var i = 1; i < ys.length; i++) {
      expect(ys[i], greaterThan(ys[i - 1]), reason: '${order[i]}');
    }
  });

  testWidgets('dix colis : carte Colis à deux lignes, total et bouton', (
    tester,
  ) async {
    await pump(
      tester,
      trip: _trip(status: 'IN_PROGRESS', summary: _summary),
      bids: [for (var i = 0; i < 10; i++) _bid('b$i', 'IN_TRANSIT')],
    );
    expect(find.text('Colis dans le trajet · 10'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TripParcelsSection),
        matching: find.textContaining('Awa Diop'),
      ),
      findsNWidgets(2),
    );
    expect(find.text('Voir les 8 autres colis'), findsOneWidget);
    expect(key('trip-parcels-see-list'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('liste des colis en chargement : carte Demandes neutre', (
    tester,
  ) async {
    await pump(tester, trip: _trip(), bids: null);
    expect(key('trip-requests-card'), findsOneWidget);
    expect(find.text('Aucune demande à traiter'), findsNothing);
  });

  testWidgets('visiteur (propriété pas tranchée) : billet et statut seuls', (
    tester,
  ) async {
    await pump(
      tester,
      trip: _trip(status: 'FULL', summary: _summary),
      bids: [_bid('b1', 'PENDING')],
      isOwner: false,
    );
    expect(key('trip-billet-card'), findsOneWidget);
    expect(key('trip-status-card-full'), findsOneWidget);
    expect(find.text('À traiter'), findsNothing);
    expect(find.byType(TripAudienceSection), findsNothing);
    expect(key('trip-requests-card'), findsNothing);
    expect(find.byType(TripParcelsSection), findsNothing);
    expect(key('trip-summary-card'), findsNothing);
    expect(find.text('Votre trajet'), findsNothing);
  });

  testWidgets('mesure des tuiles « À traiter » : role trip_owner, une fois', (
    tester,
  ) async {
    await pump(
      tester,
      trip: _trip(methods: const {BidPaymentMethod.cash}),
      bids: [_bid('b1', 'PENDING')],
      stripeReady: true,
    );
    await tester.pump();
    verify(
      () => backend.capture(AnalyticsEvents.bidDetailTodoTileShown, {
        'tile': 'requests',
        'role': 'trip_owner',
        'status': 'ACTIVE',
      }),
    ).called(1);
    verify(
      () => backend.capture(AnalyticsEvents.bidDetailTodoTileShown, {
        'tile': 'card',
        'role': 'trip_owner',
        'status': 'ACTIVE',
      }),
    ).called(1);
  });

  testWidgets('tuile « Demandes à traiter » : sheet, puis les demandes', (
    tester,
  ) async {
    await pump(tester, trip: _trip(), bids: [_bid('b1', 'PENDING')]);
    await tester.tap(key('trip_owner-todo-requests'));
    await tester.pumpAndSettle();
    expect(key('trip-todo-request-b1'), findsOneWidget);
    await tester.tap(key('trip-todo-requests-button'));
    await tester.pumpAndSettle();
    expect(opened, ['/demandes?filter=aTraiter&announcement=trip-1']);
  });

  testWidgets('tuile « Itinéraire et lieux » : sheet de lecture', (
    tester,
  ) async {
    await pump(tester, trip: _trip());
    await tester.tap(key('trip-tile-itinerary'));
    await tester.pumpAndSettle();
    expect(key('trip-tile-itinerary-content'), findsOneWidget);
    expect(find.text('12 rue de Paris'), findsOneWidget);
  });

  testWidgets('360 dp : aucun débordement', (tester) async {
    tester.view.physicalSize = const Size(360, 3200);
    await pump(
      tester,
      trip: _trip(
        status: 'FULL',
        summary: _summary,
        instructions: 'Gare',
        methods: const {BidPaymentMethod.cash},
      ),
      bids: [_bid('b1', 'PENDING'), _bid('b2', 'ARRIVED')],
      group: true,
      stripeReady: true,
    );
    tester.view.physicalSize = const Size(360, 3200);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
